#!/usr/bin/env bash
# 分块把 FIP 写入 eMMC kernel 分区(p6, 块偏移 0x7000)，每块：loady -> mmc write。
# 适合看门狗会中断长传输的板子：已写入的块持久化，失败/复位后可从失败块继续。
# 用法: flash_fip_p6.sh <fip.bin> [start-block-hex]
set -u
FIP="${1:?usage: flash_fip_p6.sh <fip.bin> [start-block-hex]}"
BASE_BLK="${2:-0x7000}"
CHUNK=1048576
BLK_PER_CHUNK=$((CHUNK / 512))
LOAD=0x1000000
SER=/dev/ttyUSB0
REPO=/home/jason/HiSTBLinuxV100R005C00SPC060
YM=$REPO/docs/porting/scripts/ymodem_send.py
US=$REPO/docs/porting/scripts/uboot_serial.py
TMP=$(mktemp -d /tmp/fipchunks.XXXXXX)
trap 'rm -rf "$TMP"' EXIT

split -b $CHUNK -d -a 2 "$FIP" "$TMP/p_"
total=$(ls "$TMP"/p_* | wc -l)
echo "FIP $FIP -> $total chunks, start block $BASE_BLK"

i=0
for part in "$TMP"/p_*; do
  blk=$((BASE_BLK + i * BLK_PER_CHUNK))
  sz=$(stat -c %s "$part")
  blocks=$(( (sz + 511) / 512 ))
  blk_hex=$(printf '0x%X' "$blk")
  blocks_hex=$(printf '0x%X' "$blocks")
  printf 'chunk %d/%d: %s -> blk %s (%s blocks)\n' "$i" "$((total-1))" "$(basename "$part")" "$blk_hex" "$blocks_hex"
  ok=0
  for attempt in 1 2 3 4; do
    [ -e "$SER" ] || { sleep 5; continue; }
    # 先同步提示符；若板子已进 Linux，则尝试回 U-Boot
    if ! python3 "$US" --port "$SER" --cmd "" --timeout 1 2>/dev/null | grep -q 'fastboot#'; then
      python3 - "$SER" <<'PY' || true
import sys, time, serial
s = serial.Serial(sys.argv[1], 115200, timeout=0.05)
s.write(b"\r"); time.sleep(0.3); s.reset_input_buffer()
s.write(b"reboot -f\r"); time.sleep(1.0)
end = time.time() + 10; i = 0
while time.time() < end:
    s.write([b"\x03", b" ", b"\x1b", b"\r"][i % 4]); i += 1; time.sleep(0.08)
s.close()
PY
      sleep 2
    fi
    if python3 "$YM" --port "$SER" --baud 115200 --file "$part" --name "fip$i" \
         --cmd "loady $LOAD" --expect "$LOAD" >/tmp/flash_chunk_$i.log 2>&1; then
      # 写入 eMMC（U-Boot 的 mmc 命令按十六进制解析参数）
      python3 "$US" --port "$SER" --cmd "" --timeout 1 \
        --cmd "mmc write 0 $LOAD $blk_hex $blocks_hex" --timeout 3 >/tmp/flash_write_$i.log 2>&1
      if grep -q "blocks written: OK" /tmp/flash_write_$i.log; then ok=1; break; fi
      echo "  mmc write failed; retry"
    else
      echo "  upload failed (attempt $attempt)"
    fi
    sleep 2
  done
  if [ "$ok" -ne 1 ]; then echo "FAIL at chunk $i"; exit 1; fi
  i=$((i + 1))
done
echo "ALL CHUNKS WRITTEN to blocks 0x$(printf %X "$BASE_BLK")+"
echo "下一步: mmc read 0 0x1FBE38 $BASE_BLK 0x2610; bootm 0x1FBE38"
