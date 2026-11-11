#!/usr/bin/env bash
# 捕获 U-Boot 提示符 -> TFTP 加载带 initcall_debug 的 FIP -> bootm -> 保存启动日志。
# 用于定位内核启动卡住的位置。后台运行，用户任意时刻复位即可。
set -u
R=/home/jason/HiSTBLinuxV100R005C00SPC060
OUT=/home/jason/bringup-7.3/out
SER=/dev/ttyUSB0
UCU="$R/docs/porting/scripts/uboot_cmd_until.py"
CATCH="${CATCH_TIMEOUT:-1200}"
LOG=/tmp/p1_debug_boot.log
: > "$LOG"

echo "== phase0: wait for U-Boot prompt"
python3 - "$SER" "$CATCH" <<'PY'
import sys, time, serial
ser, tmo = sys.argv[1], float(sys.argv[2])
end = time.time() + tmo
s = None
try:
    while time.time() < end:
        if s is None:
            try:
                s = serial.Serial(ser, 115200, timeout=0.05)
            except Exception:
                time.sleep(2); continue
        try:
            s.write([b"\x03", b" ", b"\x1b", b"\r", b"\x03"][int(time.time()*10) % 5])
            time.sleep(0.05)
            d = s.read(8192)
            if d and b"fastboot#" in d:
                print("UBOOT_READY")
                sys.exit(0)
        except Exception:
            try: s.close()
            except Exception: pass
            s = None
            time.sleep(1)
finally:
    try:
        if s: s.close()
    except Exception:
        pass
sys.exit(3)
PY
[ $? -eq 0 ] || { echo "NO_PROMPT"; exit 2; }

echo "== phase1: tftp fip_root_dbg"
python3 "$UCU" --port "$SER" --send "tftp 0x1FFBE30 fip_root_dbg.bin" --timeout 90 2>/dev/null | grep -a "Bytes transferred" || { echo "TFTP_FAIL"; exit 1; }

echo "== phase2: bootm + capture"
python3 "$UCU" --port "$SER" --send "bootm 0x1FFBE30" --timeout 90 > "$LOG" 2>&1
echo "== last lines"
tail -40 "$LOG" | cat -v
echo "== last initcall"
grep -aE "calling  |initcall " "$LOG" | tail -10
