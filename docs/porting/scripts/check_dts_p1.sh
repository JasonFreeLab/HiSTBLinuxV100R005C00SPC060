#!/usr/bin/env bash
# P1 DTS 验证：编译 DTS，并检查 PSCI、4 个 CPU、eMMC 与 CRG 节点。
# 用法: check_dts_p1.sh <dts> [kernel-dir]
set -u
DTS="${1:-/home/jason/bringup-7.3/src/linux-7.3/arch/arm64/boot/dts/hisilicon/hi3798mv300-poc.dts}"
KD="${2:-/home/jason/bringup-7.3/src/linux-7.3}"
DTC="$KD/scripts/dtc/dtc"
[ -x "$DTC" ] || { echo "FAIL: dtc not built: $DTC" >&2; exit 2; }
[ -f "$DTS" ] || { echo "FAIL: dts not found: $DTS" >&2; exit 1; }

tmpd="$(mktemp -d /tmp/dtscheckp1.XXXXXX)"
trap 'rm -rf "$tmpd"' EXIT
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
    -I "$KD/include" -I "$KD/arch/arm64/boot/dts" \
    -o "$tmpd/p.pre.dts" "$DTS" || { echo "FAIL: cpp" >&2; exit 1; }
"$DTC" -I dts -O dtb -o "$tmpd/p.dtb" "$tmpd/p.pre.dts" || { echo "FAIL: dtc compile" >&2; exit 1; }
"$DTC" -I dtb -O dts -o "$tmpd/p.dts" "$tmpd/p.dtb" || { echo "FAIL: dtc decompile" >&2; exit 1; }

fail=0
need() { grep -q "$1" "$tmpd/p.dts" || { echo "FAIL: missing $1" >&2; fail=1; }; }
need 'psci {'
need 'compatible = "arm,psci-0.2"'
need 'cpu@0'
need 'cpu@1'
need 'cpu@2'
need 'cpu@3'
need 'hisilicon,hi3798mv200-dw-mshc'
need 'mmc@f9830000'
need 'hisilicon,hi3798cv200-crg'
need '"ciu-sample"'
need 'hisilicon,sap-dll-reg'
[ "$(grep -c 'enable-method = "psci"' "$tmpd/p.dts")" -ge 4 ] || { echo "FAIL: <4 cpus with psci" >&2; fail=1; }
[ "$fail" -eq 0 ] || exit 1
echo "PASS: P1 DTS nodes ok (dtb $(stat -c %s "$tmpd/p.dtb") bytes)"
