#!/bin/bash
# release.sh —— DEP-02：打 hi-accel 发布包（模块 + 工具 + 预热样本 + 脚本 + sha1 清单）
#
# 用法：release.sh <版本号> [payload目录] [输出目录]
#   payload 默认 docs/porting/artifacts/hwtest-2026-11-07/fixes/dep-02/payload
#   输出    默认 dist/hi-accel-<版本>.tar.gz（仓库根下）
# 打包前按 hi-accel.manifest 逐个校验 payload sha1，任何不符即中止（防止错配件进包）。
set -euo pipefail
VER=${1:?usage: release.sh VERSION [PAYLOAD] [OUTDIR]}
D=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$D/../../.." && pwd)
PAY=${2:-$ROOT/docs/porting/artifacts/hwtest-2026-11-07/fixes/dep-02/payload}
OUTD=${3:-$ROOT/dist}
MAN="$D/hi-accel.manifest"

echo "== 校验 payload（$PAY）"
( cd "$PAY" && awk '!/^#/ && NF==2 {print $1"  "$2}' "$MAN" | sha1sum -c --quiet ) \
  || { echo "release: payload 与 manifest 不符，中止" >&2; exit 1; }
for f in hi-accel-load.sh hi-vdec-run hi_jpeg hi_png install.sh; do bash -n "$D/$f"; done

STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT
P="$STAGE/hi-accel-$VER"
mkdir -p "$P/payload" "$P/scripts"
awk '!/^#/ && NF==2 {print $2}' "$MAN" | while read -r f; do cp -p "$PAY/$f" "$P/payload/"; done
cp -p "$D"/{hi-accel-load.sh,hi-vdec-run,hi_jpeg,hi_png,hi-accel.service,hi-accel.conf,hi-accel.manifest,install.sh} "$P/scripts/"
{
  echo "version=$VER"
  echo "built=$(date -Is)"
  echo "git=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  echo "kernel=7.3.0 #188 (aarch64, Hi3798MV300)"
} > "$P/VERSION"
( cd "$P" && find payload scripts VERSION -type f | sort | xargs sha1sum > SHA1SUMS )
mkdir -p "$OUTD"
tar -C "$STAGE" -czf "$OUTD/hi-accel-$VER.tar.gz" "hi-accel-$VER"
( cd "$OUTD" && sha1sum "hi-accel-$VER.tar.gz" > "hi-accel-$VER.tar.gz.sha1" )
echo "== 发布包：$OUTD/hi-accel-$VER.tar.gz（$(du -h "$OUTD/hi-accel-$VER.tar.gz" | cut -f1)）"
cat "$OUTD/hi-accel-$VER.tar.gz.sha1"
