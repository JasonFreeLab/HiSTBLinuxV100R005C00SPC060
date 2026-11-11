#!/usr/bin/env bash
# 构建 arm64 Image 并复制到 out/。
# 用法: build_kernel.sh <kernel-dir> [out-dir]
set -u
KD="${1:?usage: build_kernel.sh <kernel-dir> [out-dir]}"
OUT="${2:-/home/jason/bringup-7.3/out}"

if [ ! -d "$KD" ]; then
  echo "FAIL: kernel dir not found: $KD" >&2
  exit 2
fi

export PATH=/home/jason/bringup-7.3/toolchain/usr/bin:$PATH
export LD_LIBRARY_PATH=/home/jason/bringup-7.3/toolchain/usr/lib/x86_64-linux-gnu

if ! command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
  echo "FAIL: aarch64-linux-gnu-gcc not found in PATH" >&2
  exit 2
fi

mkdir -p "$OUT"
make -C "$KD" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image -j"$(nproc)" || {
  echo "FAIL: kernel build failed" >&2
  exit 1
}

cp -f "$KD/arch/arm64/boot/Image" "$OUT/Image" || {
  echo "FAIL: Image not produced" >&2
  exit 1
}
if ! file "$OUT/Image" | grep -qE 'ARM64|aarch64'; then
  echo "FAIL: output is not an aarch64 Image" >&2
  exit 1
fi
echo "PASS: $(file "$OUT/Image")"
ls -lh "$OUT/Image"
