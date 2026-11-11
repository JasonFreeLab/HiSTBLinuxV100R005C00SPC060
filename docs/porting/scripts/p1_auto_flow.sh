#!/usr/bin/env bash
# P1 自动化流程：等待用户复位 -> 捕获 U-Boot -> 写 Ubuntu 26.04.1 rootfs 到 eMMC p8
# -> 写 fip_root 到 p6 -> 复位 -> 抓 Ubuntu 启动日志。
# 在后台运行，用户任意时刻复位都会被捕获。
set -u
R=/home/jason/HiSTBLinuxV100R005C00SPC060
OUT=/home/jason/bringup-7.3/out
US=$R/docs/porting/scripts/uboot_serial.py
SER=/dev/ttyUSB0
CATCH_TIMEOUT="${CATCH_TIMEOUT:-1800}"
LOG=/tmp/p1_auto_flow.log
exec > >(tee -a "$LOG") 2>&1
echo "=== P1 auto flow start $(date) ==="

echo "== phase 0: wait for U-Boot prompt (spam Ctrl-C while board boots)"
python3 - "$SER" "$CATCH_TIMEOUT" <<'PY'
import sys, time, serial
ser, tmo = sys.argv[1], float(sys.argv[2])
s = serial.Serial(ser, 115200, timeout=0.05)
end = time.time() + tmo
buf = b""
try:
    while time.time() < end:
        s.write([b"\x03", b" ", b"\x1b", b"\r", b"\x03"][int(time.time()*10) % 5])
        time.sleep(0.05)
        d = s.read(8192)
        if d:
            buf += d
            if b"fastboot#" in buf:
                print("UBOOT_READY")
                break
    else:
        print("TIMEOUT_WAITING_PROMPT")
        sys.exit(3)
finally:
    s.close()
PY
[ $? -eq 0 ] || { echo "NO_PROMPT: 需要用户复位"; exit 2; }

echo "== phase 1: disable U-Boot watchdog, then flash Ubuntu rootfs to eMMC p8 (0x97000)"
python3 "$US" --port "$SER" --cmd "mw 0xF8A2CC00 0x1ACCE551; mw 0xF8A2C008 0x0; md 0xF8A2C008 1" --timeout 2 >/dev/null 2>&1
bash "$R/docs/porting/scripts/flash_image_emmc.sh" "$OUT/ubuntu-26.04.1-arm64.ext4" 0x97000 67108864 || { echo "FAIL: rootfs flash"; exit 1; }

echo "== phase 2: write fip_root to p6 and set bootcmd"
for a in 1 2 3; do
  if python3 "$US" --port "$SER" --cmd " tftp 0x1FFBE30 fip_root.bin" --timeout 12 2>/dev/null | grep -q "Bytes transferred"; then break; fi
  [ "$a" = 3 ] && { echo "FAIL: tftp fip_root"; exit 1; }
done
python3 "$US" --port "$SER" --cmd "mmc write 0 0x1FFBE30 0x7000 0x47A7" --timeout 5 >/tmp/p1_auto_p6.log 2>&1
grep -q "blocks written: OK" /tmp/p1_auto_p6.log || { echo "FAIL: mmc write p6"; cat /tmp/p1_auto_p6.log; exit 1; }
python3 "$US" --port "$SER" --cmd "setenv bootcmd 'mmc read 0 0x1FFBE30 0x7000 0x47A7; bootm 0x1FFBE30'; saveenv" --timeout 3 >/dev/null 2>&1

echo "== phase 3: reset and capture Ubuntu boot"
python3 "$US" --port "$SER" --cmd "reset" --timeout 1 >/dev/null 2>&1
sleep 3
python3 "$US" --port "$SER" --baud 115200 --seconds 120 > /tmp/p1_ubuntu_boot.log 2>&1
echo "----- Ubuntu boot log tail -----"
tail -50 /tmp/p1_ubuntu_boot.log | cat -v
if grep -q "login:" /tmp/p1_ubuntu_boot.log; then echo "PASS: Ubuntu login prompt"; else echo "CHECK: login prompt not yet (see /tmp/p1_ubuntu_boot.log)"; fi
echo "=== P1 auto flow done $(date) ==="
