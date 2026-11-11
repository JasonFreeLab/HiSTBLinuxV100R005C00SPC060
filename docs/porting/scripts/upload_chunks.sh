#!/usr/bin/env bash
# 分块 YMODEM 上传（提高长传输可靠性：每块独立握手，可重试）。
# 用法: upload_chunks.sh <file> <base-addr-hex> [chunk-size-bytes]
set -u
FILE="${1:?usage: upload_chunks.sh <file> <base-addr> [chunk-size]}"
BASE="${2:?base address, e.g. 0x1FAE30}"
CHUNK="${3:-1048576}"
REPO="/home/jason/HiSTBLinuxV100R005C00SPC060"
YM="$REPO/docs/porting/scripts/ymodem_send.py"
SER="/dev/ttyUSB0"
TMP="$(mktemp -d /tmp/fipchunks.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

split -b "$CHUNK" -d -a 2 "$FILE" "$TMP/part_"
total=$(ls "$TMP"/part_* | wc -l)
echo "upload: $FILE -> $total chunks of $CHUNK bytes, base $BASE"

fail_total=0
i=0
for part in "$TMP"/part_*; do
  addr=$(printf '0x%X' $(( BASE + i * CHUNK )))
  ok=0
  for attempt in 1 2 3 4; do
    if [ ! -e "$SER" ]; then
      echo "  [warn] $SER missing, waiting for re-enumeration..."
      sleep 5
      continue
    fi
    echo "  chunk $i/$((total-1)) -> $addr (attempt $attempt): $(basename "$part")"
    if python3 "$YM" --port "$SER" --baud 115200 --file "$part" --name "p$i" \
         --cmd "loady $addr" --expect "$addr"; then
      ok=1
      break
    fi
    echo "  [retry] chunk $i failed; check prompt"
    python3 "$REPO/docs/porting/scripts/uboot_serial.py" --port "$SER" --cmd "" --timeout 1 >/dev/null 2>&1 || true
    sleep 2
  done
  if [ "$ok" -ne 1 ]; then
    echo "FAIL: chunk $i at $addr"
    fail_total=1
    break
  fi
  i=$((i+1))
done
if [ "$fail_total" -eq 0 ]; then
  echo "ALL CHUNKS UPLOADED: $(stat -c %s "$FILE") bytes at $BASE"
fi
exit "$fail_total"
