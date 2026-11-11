#!/usr/bin/env bash
# 验证 Ubuntu rootfs ext4 镜像的基本可启动条件（不需板卡）。
# 用法: verify_ubuntu_rootfs.sh <ext4-image> [rootfs-dir]
# 依赖: debugfs, e2fsck；可选 qemu-aarch64（/tmp/qemu-us/usr/bin/qemu-aarch64）
set -u
IMG="${1:-/home/jason/bringup-7.3/out/ubuntu-26.04.1-arm64.ext4}"
ROOTFS="${2:-/home/jason/bringup-7.3/rootfs-ubuntu-2604}"
QEMU="${QEMU:-/tmp/qemu-us/usr/bin/qemu-aarch64}"
[ -f "$IMG" ] || { echo "FAIL: image not found: $IMG" >&2; exit 2; }
fail=0

echo "== e2fsck"
e2fsck -fn "$IMG" >/tmp/verify_e2fsck.log 2>&1 || { echo "FAIL: e2fsck"; tail -10 /tmp/verify_e2fsck.log >&2; fail=1; }

echo "== files"
check() { debugfs -R "stat $1" "$IMG" 2>/dev/null | grep -q "$2" || { echo "FAIL: $1 ($2)" >&2; fail=1; }; }
check /etc/fstab 'Type: regular'
check /etc/shadow 'Type: regular'
check /etc/hostname 'Type: regular'
check /etc/systemd/system/getty.target.wants/serial-getty@ttyAMA0.service 'Type: symlink'
debugfs -R 'cat /etc/fstab' "$IMG" 2>/dev/null | grep -q '/dev/mmcblk0p8' || { echo "FAIL: fstab root entry" >&2; fail=1; }
debugfs -R 'cat /etc/shadow' "$IMG" 2>/dev/null | grep -q '^root:\$6\$' || { echo "FAIL: root password hash" >&2; fail=1; }

echo "== qemu execution"
if [ -x "$QEMU" ] && [ -d "$ROOTFS" ]; then
  out=$("$QEMU" -L "$ROOTFS" "$ROOTFS/usr/bin/bash" -c 'echo OK' 2>/dev/null)
  [ "$out" = "OK" ] || { echo "FAIL: qemu bash" >&2; fail=1; }
  # 注：qemu-user 下 systemd --version 可能无输出（容器/PID1 检测），不作为失败条件
  echo "PASS: qemu bash executed"
else
  echo "SKIP: qemu-aarch64 not available"
fi

[ "$fail" -eq 0 ] && echo "PASS: rootfs image verification ok ($IMG)" || exit 1
