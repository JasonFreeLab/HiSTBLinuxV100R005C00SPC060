#!/usr/bin/env bash
# 验证 DTS 可被内核 dtc 编译通过。
# 用法: check_dts.sh <dts> [kernel-dir]
set -u
DTS="${1:?usage: check_dts.sh <dts> [kernel-dir]}"
KD="${2:-/home/jason/bringup-7.3/src/linux-7.3}"
DTC="$KD/scripts/dtc/dtc"

if [ ! -d "$KD" ]; then
  echo "FAIL: kernel dir not found: $KD" >&2
  exit 2
fi
if [ ! -x "$DTC" ]; then
  echo "FAIL: dtc not built: $DTC (run: make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- prepare)" >&2
  exit 2
fi
if [ ! -f "$DTS" ]; then
  echo "FAIL: dts not found: $DTS" >&2
  exit 1
fi

out="$(mktemp /tmp/dtscheck.XXXXXX.dtb)"
pre="$(mktemp /tmp/dtscheck.XXXXXX.dts)"
trap 'rm -f "$out" "$pre"' EXIT
# 内核构建会先用 cpp 预处理 DTS（-undef -D__DTS__），这里保持一致
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
    -I "$KD/include" -I "$KD/arch/arm64/boot/dts" \
    -o "$pre" "$DTS" || { echo "FAIL: cpp preprocess error" >&2; exit 1; }
if ! "$DTC" -I dts -O dtb -o "$out" "$pre"; then
  echo "FAIL: dtc compile error" >&2
  exit 1
fi
size="$(stat -c %s "$out")"
if [ "$size" -le 0 ]; then
  echo "FAIL: empty dtb" >&2
  exit 1
fi
echo "PASS: dtb size=$size bytes"
