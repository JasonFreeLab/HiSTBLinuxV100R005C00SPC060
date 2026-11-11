#!/usr/bin/env bash
# 分块把镜像写入 eMMC 分区：TFTP -> RAM -> mmc write -> 回读 CRC。
# 用 uboot_cmd_until 等到提示符即返回，每块开销接近实际传输时间。
# 已写入的块持久化；中断/复位后可用第 4 个参数 START_INDEX 续传。
# 用法: flash_image_emmc.sh <image> <start-block-hex> [chunk-size] [start-index]
# 例:   flash_image_emmc.sh ubuntu.ext4 0x97000 33554432 0
set -u
IMG="${1:?usage: flash_image_emmc.sh <image> <start-block-hex> [chunk-size] [start-index]}"
BASE_BLK="${2:?start block, e.g. 0x97000}"
CHUNK="${3:-33554432}"
START="${4:-0}"
TFTPDIR="/mnt/c/Users/yujia/Desktop/hi3798_boot"
SER=/dev/ttyUSB0
REPO=/home/jason/HiSTBLinuxV100R005C00SPC060
UCU="$REPO/docs/porting/scripts/uboot_cmd_until.py"
LOAD=0x10000000
VERIFY=0x12000000

[ -f "$IMG" ] || { echo "FAIL: image not found: $IMG" >&2; exit 2; }
[ -e "$SER" ] || { echo "FAIL: serial not found: $SER" >&2; exit 2; }
mkdir -p "$TFTPDIR"
BLK_PER_CHUNK=$((CHUNK / 512))
total=$(( ( $(stat -c %s "$IMG") + CHUNK - 1 ) / CHUNK ))
echo "image=$IMG size=$(stat -c %s "$IMG") chunks=$total chunk=$CHUNK base_blk=$BASE_BLK start=$START"

sync_prompt() { python3 "$UCU" --port "$SER" --sync --timeout 3 --quiet >/dev/null 2>&1; }
ensure_prompt() {
  for _ in 1 2 3 4 5; do
    sync_prompt && return 0
    python3 - "$SER" <<'PY' || true
import sys, time, serial
s = serial.Serial(sys.argv[1], 115200, timeout=0.05)
s.write(b"\r"); time.sleep(0.3); s.reset_input_buffer()
s.write(b"reboot -f\r"); time.sleep(1.0)
end = time.time() + 10; i = 0
while time.time() < end:
    s.write([b"\x03", b" ", b"\x1b", b"\r", b"\x03"][i % 5]); i += 1; time.sleep(0.06)
s.close()
PY
    sleep 2
  done
  sync_prompt
}

i=$START
while [ "$i" -lt "$total" ]; do
  off=$((i * CHUNK))
  len=$CHUNK
  remain=$(( $(stat -c %s "$IMG") - off ))
  [ "$remain" -lt "$len" ] && len=$remain
  part="$TFTPDIR/p8_$(printf '%03d' "$i").bin"
  dd if="$IMG" of="$part" bs=1M skip=$((off / 1048576)) count=$(( (len + 1048575) / 1048576 )) status=none
  truncate -s "$len" "$part"
  crc=$(python3 - "$part" <<'PY'
import sys, zlib
print("%08x" % (zlib.crc32(open(sys.argv[1],'rb').read()) & 0xffffffff))
PY
)
  blk=$((BASE_BLK + i * BLK_PER_CHUNK))
  blk_hex=$(printf '0x%X' "$blk"); cnt_hex=$(printf '0x%X' $(( (len + 511) / 512 )))
  len_hex=$(printf '0x%X' "$len")
  printf 'chunk %d/%d: off=%d len=%d blk=%s crc=%s\n' "$i" "$((total-1))" "$off" "$len" "$blk_hex" "$crc"
  ok=0
  for attempt in 1 2 3; do
    ensure_prompt || { sleep 2; continue; }
    fname=$(basename "$part")
    if ! python3 "$UCU" --port "$SER" --send "tftp $LOAD $fname" --timeout 90 2>/dev/null | grep -q "Bytes transferred"; then
      echo "  tftp retry"; sleep 1; continue
    fi
    out=$(python3 "$UCU" --port "$SER" --send "mmc write 0 $LOAD $blk_hex $cnt_hex; mmc read 0 $VERIFY $blk_hex $cnt_hex; crc32 $VERIFY $len_hex" --timeout 20 2>/dev/null)
    if echo "$out" | grep -q "blocks written: OK" && echo "$out" | grep -q "==> $crc"; then
      ok=1; break
    fi
    echo "  write/verify retry"; sleep 1
  done
  if [ "$ok" -ne 1 ]; then echo "FAIL at chunk $i (resume with start index $i)"; exit 1; fi
  rm -f "$part"
  i=$((i + 1))
done
echo "DONE: all chunks written from $START to $((total-1))"
