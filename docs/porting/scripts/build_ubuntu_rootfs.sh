#!/usr/bin/env bash
# 构建 Ubuntu 26.04 arm64 base rootfs 的 ext4 镜像（P1.4）。
# 用法: build_ubuntu_rootfs.sh [输出镜像路径] [镜像大小，如 2G]
# 依赖: curl, fakeroot, e2fsprogs（mke2fs -d / debugfs / e2fsck）
set -eu
OUT_IMG="${1:-/home/jason/bringup-7.3/out/ubuntu-26.04-arm64.ext4}"
IMG_SIZE="${2:-2G}"
TOOLS=/home/jason/bringup-7.3/tools/ubuntu-base
BASE_URL=https://cloud-images.ubuntu.com/releases/resolute/release-20261016
TARBALL="$TOOLS/ubuntu-26.04-server-cloudimg-arm64-root.tar.xz"
SHA256=482791c2480b396ca8f879b4bba0f49a1414086f1a5d318ccdf4e33d7d364134
ROOTFS=/home/jason/bringup-7.3/rootfs-ubuntu-2604

mkdir -p "$TOOLS"
if [ ! -f "$TARBALL" ]; then
  echo "== download $TARBALL"
  curl -L --fail --retry 3 -o "$TARBALL.part" "$BASE_URL/$(basename "$TARBALL")"
  mv "$TARBALL.part" "$TARBALL"
fi
echo "$SHA256  $TARBALL" | sha256sum -c - >/dev/null
echo "PASS: tarball sha256 ok"

rm -rf "$ROOTFS"
mkdir -p "$ROOTFS"
echo "== extract with fakeroot (preserve device nodes)"
fakeroot tar -xJf "$TARBALL" -C "$ROOTFS"
[ -x "$ROOTFS/usr/bin/bash" ] || { echo "FAIL: rootfs/usr/bin/bash missing" >&2; exit 1; }

echo "== configure rootfs"
# fstab：root 在 eMMC p8
cat > "$ROOTFS/etc/fstab" <<'EOF'
/dev/mmcblk0p8  /       ext4    defaults,noatime 0 1
proc            /proc   proc    defaults        0 0
sysfs           /sys    sysfs   defaults        0 0
devtmpfs        /dev    devtmpfs mode=0755,nosuid 0 0
tmpfs           /tmp    tmpfs   defaults        0 0
EOF
echo "hi3798mv300" > "$ROOTFS/etc/hostname"
mkdir -p "$ROOTFS/etc/cloud"
touch "$ROOTFS/etc/cloud/cloud-init.disabled"
rm -f "$ROOTFS/etc/resolv.conf"
printf 'nameserver 223.5.5.5\nnameserver 8.8.8.8\n' > "$ROOTFS/etc/resolv.conf"
# 串口 getty（ttyAMA0, 115200）
mkdir -p "$ROOTFS/etc/systemd/system/getty.target.wants"
ln -sf /lib/systemd/system/serial-getty@.service \
  "$ROOTFS/etc/systemd/system/getty.target.wants/serial-getty@ttyAMA0.service"
# 屏蔽会等待网络 2 分钟的 service（P1 板卡暂无网络驱动）
ln -sf /dev/null "$ROOTFS/etc/systemd/system/systemd-networkd-wait-online.service"
ln -sf /dev/null "$ROOTFS/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service" 2>/dev/null || true
# 允许 root 串口登录：设置 root 密码为 "root"
if command -v openssl >/dev/null; then
  HASH="$(openssl passwd -6 root)"
  if grep -q '^root:' "$ROOTFS/etc/shadow"; then
    sed -i "s#^root:[^:]*:#root:${HASH}:#" "$ROOTFS/etc/shadow"
  fi
fi
# systemd 首次启动生成 machine-id
: > "$ROOTFS/etc/machine-id"
# 清理 apt 缓存/临时文件
rm -rf "$ROOTFS/var/cache/apt/archives"/*.deb 2>/dev/null || true

echo "== build ext4 image ($IMG_SIZE)"
rm -f "$OUT_IMG"
fakeroot mke2fs -q -t ext4 -F -L ubuntu-rootfs -d "$ROOTFS" -E lazy_itable_init=0,lazy_journal_init=0 "$OUT_IMG" "$IMG_SIZE"
e2fsck -fn "$OUT_IMG" >/tmp/e2fsck-p1.log 2>&1 || { echo "FAIL: e2fsck"; tail -20 /tmp/e2fsck-p1.log >&2; exit 1; }
echo "PASS: ext4 image ok"
ls -lh "$OUT_IMG"
sha256sum "$OUT_IMG"
debugfs -R 'ls -l /' "$OUT_IMG" 2>/dev/null | head -15
