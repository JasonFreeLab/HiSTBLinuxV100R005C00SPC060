#!/usr/bin/env bash
# P1 板卡验证一键流程：
#   1) 确认 U-Boot 提示符（否则提示手动复位）
#   2) TFTP 加载 fip_p1 -> bootm，验证 4 核 SMP 与 eMMC
#   3) 成功后：写 Ubuntu rootfs 到 eMMC p8，写 fip_p1root 到 p6，设 bootcmd，复位
#   4) 抓取 Ubuntu 登录日志
# 用法: p1_board_verify.sh [--skip-rootfs]
set -u
REPO=/home/jason/bringup-7.3
OUT=$REPO/out
R=/home/jason/HiSTBLinuxV100R005C00SPC060
SER=/dev/ttyUSB0
US=$R/docs/porting/scripts/uboot_serial.py
TFTPDIR="/mnt/c/Users/yujia/Desktop/hi3798_boot"
SKIP_ROOTFS=0
[ "${1:-}" = "--skip-rootfs" ] && SKIP_ROOTFS=1

prompt_ok() { python3 "$US" --port "$SER" --cmd "" --timeout 1 2>/dev/null | grep -q 'fastboot#'; }
ensure_prompt() {
  prompt_ok && return 0
  python3 - "$SER" <<'PY' || true
import sys, time, serial
s = serial.Serial(sys.argv[1], 115200, timeout=0.05)
s.write(b"\r"); time.sleep(0.3); s.reset_input_buffer()
s.write(b"reboot -f\r"); time.sleep(1.0)
end = time.time() + 12; i = 0
while time.time() < end:
    s.write([b"\x03", b" ", b"\x1b", b"\r", b"\x03"][i % 5]); i += 1; time.sleep(0.06)
s.close()
PY
  sleep 2
  prompt_ok
}

if ! ensure_prompt; then
  echo "NEED_MANUAL_RESET: board not at U-Boot prompt (kernel hung/panic). 请断电复位后重试。" >&2
  exit 2
fi
echo "PASS: U-Boot prompt"

echo "== tftp fip_p1 -> 0x1FFBE30"
for a in 1 2 3; do
  if python3 "$US" --port "$SER" --cmd " tftp 0x1FFBE30 fip_noroot.bin" --timeout 12 2>/dev/null | grep -q "Bytes transferred"; then echo "PASS: tftp"; break; fi
  [ "$a" = 3 ] && { echo "FAIL: tftp fip_p1"; exit 1; }
done

echo "== boot fip_p1 and capture"
python3 "$US" --port "$SER" --cmd " bootm 0x1FFBE30" --timeout 45 > /tmp/p1_verify_boot.log 2>&1
grep -aE "smp: Brought up|CPU1|CPU2|CPU3|mmcblk0|mmc0|dwmmc|Kernel panic" /tmp/p1_verify_boot.log | head -20
if grep -q "Brought up 4 CPUs" /tmp/p1_verify_boot.log && grep -q "mmcblk0" /tmp/p1_verify_boot.log; then
  echo "PASS: 4 CPUs + eMMC detected"
else
  echo "FAIL: expected 4 CPUs and mmcblk0 (see /tmp/p1_verify_boot.log tail)"
  tail -30 /tmp/p1_verify_boot.log
  exit 1
fi

if [ "$SKIP_ROOTFS" = 1 ]; then echo "SKIP rootfs flashing (--skip-rootfs)"; exit 0; fi

echo "== flash Ubuntu rootfs to eMMC p8 (block 0x97000)"
python3 "$US" --port "$SER" --cmd "" --timeout 1 >/dev/null 2>&1
# 先回到 U-Boot：内核会 panic 挂住，需要复位
if ! ensure_prompt; then echo "NEED_MANUAL_RESET: 内核已挂起，请复位后再运行续传" >&2; exit 2; fi
bash "$R/docs/porting/scripts/flash_image_emmc.sh" "$OUT/ubuntu-26.04.1-arm64.ext4" 0x97000 33554432 || exit 1

echo "== write fip_p1root to p6 and set bootcmd"
for a in 1 2 3; do
  if python3 "$US" --port "$SER" --cmd " tftp 0x1FFBE30 fip_root.bin" --timeout 12 2>/dev/null | grep -q "Bytes transferred"; then break; fi
  [ "$a" = 3 ] && { echo "FAIL: tftp fip_p1root"; exit 1; }
done
python3 "$US" --port "$SER" --cmd "mmc write 0 0x1FFBE30 0x7000 0x47A7" --timeout 4 >/tmp/p1_p6.log 2>&1
grep -q "blocks written: OK" /tmp/p1_p6.log || { echo "FAIL: mmc write p6"; cat /tmp/p1_p6.log; exit 1; }
python3 "$US" --port "$SER" --cmd "setenv bootcmd 'mmc read 0 0x1FFBE30 0x7000 0x47A7; bootm 0x1FFBE30'; saveenv" --timeout 3 >/dev/null 2>&1
echo "PASS: p6 updated + bootcmd"

echo "== reset and capture Ubuntu boot"
python3 "$US" --port "$SER" --cmd "reset" --timeout 1 >/dev/null 2>&1
sleep 3
python3 "$US" --port "$SER" --baud 115200 --seconds 60 > /tmp/p1_ubuntu_boot.log 2>&1
echo "----- tail -----"
tail -40 /tmp/p1_ubuntu_boot.log | cat -v
if grep -q "login:" /tmp/p1_ubuntu_boot.log; then echo "PASS: Ubuntu login prompt"; else echo "CHECK: login prompt not seen yet"; fi
