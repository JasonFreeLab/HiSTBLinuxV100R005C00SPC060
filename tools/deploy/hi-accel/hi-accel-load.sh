#!/bin/bash
# hi-accel-load.sh —— DEP-01：开机加载 Hi3798MV300 硬件加速模块 + 预热 + 自检
#
# 由 hi-accel.service 调用（也可手工执行）。行为：
#   1. 按 /etc/hi-accel.manifest 校验模块/工具 sha1（错配即拒绝加载，防止 VDEC-01 类"落后一个 commit"误部署）
#   2. 依次 insmod：mmz_shim → tde → vdec → venc → jpeg → png（已加载则跳过）
#   3. 可选预热：1080p HEVC 解码一次（VDEC-05）
#   4. 自检：模块在位、设备节点存在、无新 Oops；结果写 /run/hi-accel/status
# 失败不阻塞开机：单个模块失败只记录，退出码 = 失败模块数（systemd 记为 failed 便于发现）。

set -u
CONF=/etc/hi-accel.conf
MANIFEST=/etc/hi-accel.manifest
LOG=/var/log/hi-accel.log
STATE_DIR=/run/hi-accel
mkdir -p "$STATE_DIR"

# 默认值（conf 缺项时生效）
HI_DIR=/root/m2
HI_LOAD_VDEC=1; HI_LOAD_VENC=1; HI_LOAD_JPEG=1; HI_LOAD_PNG=1; HI_LOAD_TDE=1
HI_VDEC_PARAMS="m2_sync_downmsg=1 m2_sync_msgs=1 m2_sync_scd=1 m2_sync_hevc_msgs=1 vdec_dfs=1 vdec_sed_only=0 vdec_hdr_meta=0"
HI_WARMUP=1
HI_STRICT_SHA1=1
HI_PNG_KO=hi_png_reload.ko
HI_TDE_KO=hi_tde.ko
# shellcheck disable=SC1090
[ -r "$CONF" ] && . "$CONF"

exec >>"$LOG" 2>&1
log() { echo "[$(date '+%F %T')] $*"; }

FAIL=0
RESULT=()

# 期望 sha1（前缀匹配）
expect_sha1() {
  awk -v f="$1" '$0 !~ /^#/ && $2==f {print $1; exit}' "$MANIFEST" 2>/dev/null
}

verify() {
  local file="$1" exp act
  [ -f "$HI_DIR/$file" ] || { log "MISSING $file"; return 1; }
  exp=$(expect_sha1 "$file")
  [ -z "$exp" ] && { log "WARN $file 不在 manifest，跳过校验"; return 0; }
  act=$(sha1sum "$HI_DIR/$file" | cut -d' ' -f1)
  case "$act" in
    "$exp"*) return 0 ;;
    *) log "SHA1 MISMATCH $file actual=${act:0:8} expect=${exp:0:8}"
       [ "$HI_STRICT_SHA1" = 1 ] && return 1 || return 0 ;;
  esac
}

load() {
  local file="$1" name="$2"; shift 2
  if [ -d "/sys/module/$name" ]; then
    log "SKIP $name 已加载"; RESULT+=("$name=loaded"); return 0
  fi
  if ! verify "$file"; then
    log "FAIL $name 校验未通过，不加载"; RESULT+=("$name=sha1_fail"); FAIL=$((FAIL+1)); return 1
  fi
  if timeout 30 insmod "$HI_DIR/$file" "$@" && [ -d "/sys/module/$name" ]; then
    log "OK   insmod $file $*"; RESULT+=("$name=ok"); return 0
  fi
  log "FAIL insmod $file rc=$?"; dmesg | tail -5
  RESULT+=("$name=insmod_fail"); FAIL=$((FAIL+1)); return 1
}

log "===== hi-accel start boot_id=$(cat /proc/sys/kernel/random/boot_id | cut -c1-8) uptime=$(cut -d' ' -f1 /proc/uptime)s CmaFree=$(awk '/CmaFree/{print $2}' /proc/meminfo)kB"
OOPS_BEFORE=$(dmesg | grep -caE 'Internal error|kernel BUG|Oops')

# mmz_shim 是其余模块的依赖：失败则直接退出
if ! load hi_mmz_shim.ko hi_mmz_shim; then
  echo "state=FAIL reason=mmz_shim ${RESULT[*]}" > "$STATE_DIR/status"; exit 1
fi
# shellcheck disable=SC2086
[ "$HI_LOAD_TDE" = 1 ] && load "$HI_TDE_KO" hi_tde
[ "$HI_LOAD_VDEC" = 1 ] && load hi_vdec_reloadfix.ko hi_vdec $HI_VDEC_PARAMS
[ "$HI_LOAD_VENC" = 1 ] && load hi_venc_venc06b.ko hi_venc
[ "$HI_LOAD_JPEG" = 1 ] && load hi_jpeg_noext.ko hi_jpeg
[ "$HI_LOAD_PNG"  = 1 ] && load "$HI_PNG_KO" hi_png

# PNG 与 JPEG 同 boot 时 /dev/hi_png 必须存在（旧 noext 模块因 class 重名不会建节点）
if [ -d /sys/module/hi_png ] && [ ! -c /dev/hi_png ]; then
  log "FAIL hi_png 已加载但 /dev/hi_png 缺失（class 冲突？）"; RESULT+=("hi_png_node=missing"); FAIL=$((FAIL+1))
fi

# 预热（VDEC-05）：失败不计入 FAIL，只记录；走自愈包装（VDEC-02C）
WARM="skip"
if [ "$HI_WARMUP" = 1 ] && [ -d /sys/module/hi_vdec ] && verify vdec_spec_hevc_head && verify ht1080b.hevc; then
  t0=$(date +%s%N)
  if HI_DIR="$HI_DIR" /usr/local/bin/hi-vdec-run --tries 2 --quiet -- \
       hevc fullhd ht1080b.hevc ht.index 1920 1080 30; then WARM="ok"; else WARM="fail"; fi
  WARM="$WARM($(( ($(date +%s%N)-t0)/1000000 ))ms)"
fi
log "warmup=$WARM"

# 自检
OOPS_AFTER=$(dmesg | grep -caE 'Internal error|kernel BUG|Oops')
NODES=$(ls /dev/hi_* 2>/dev/null | tr '\n' ' ')
[ "$OOPS_AFTER" -gt "$OOPS_BEFORE" ] && { log "FAIL 加载期间出现新 Oops"; FAIL=$((FAIL+1)); }
STATE=PASS; [ "$FAIL" -gt 0 ] && STATE=FAIL
echo "state=$STATE fail=$FAIL warmup=$WARM ${RESULT[*]} nodes=[${NODES% }] cma_free_kb=$(awk '/CmaFree/{print $2}' /proc/meminfo)" | tee "$STATE_DIR/status"
log "===== hi-accel done state=$STATE"
exit "$FAIL"
