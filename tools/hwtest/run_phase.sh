#!/usr/bin/env bash
# =============================================================================
# run_phase.sh — Hi3798MV300 板卡测试阶段编排器（路线图 INF-04）
#
# 一条命令完成：clean boot → insmod 模块 → 跑用例 → 抓帧/像素比对 → 取证。
# 复用 tools/hwtest/board_ctl.py 的 reboot / RTS 复位 / ensure-ssh 能力。
#
# 用法：
#   ./tools/hwtest/run_phase.sh <phase> [选项]
#   ./tools/hwtest/run_phase.sh --list
#
# 阶段定义文件：tools/hwtest/phases/<phase>.sh（bash 语法，调用下方 phase_* 函数）。
# 首个可用阶段：vdec_h264_smoke
#
# 常用选项：
#   --dry-run             只打印计划，不接触板卡、不创建证据目录
#   --no-reboot           不 reboot，在当前 boot 上直接跑（模块已加载则跳过 insmod）
#   --only <case>         只跑匹配的用例（支持通配符，如 'cap*'）
#   --list                列出可用阶段
#   --phase-file <path>   直接指定阶段定义文件
#   --evidence-dir <dir>  指定证据目录（默认 auto/<phase>-<timestamp>）
#   --skip-pixel          跳过像素比对（只做帧数/判据）
#   --keep-board          保留板上工作目录（默认 PASS 后清理）
#   --allow-sha1-mismatch sha1 不符合阶段期望时仅警告（默认判失败）
#   --verbose             用例失败时把原始日志尾部打到控制台
#   -h|--help             帮助
#
# 退出码：0=PASS；1=有 FAIL；2=用法/配置错误；3=板卡/环境不可用
#
# 环境变量覆盖：BOARD（默认 root@192.168.2.10）、BOARD_CONSOLE、BOARD_RESET
# 传给 board_ctl.py；HWTEST_SSH / HWTEST_SCP / HWTEST_BOARD_CTL 可替换实现
# （selftest/ 下的 mock 用来在主机侧验证编排逻辑）。
# =============================================================================
set -u
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
LIB_DIR="$SCRIPT_DIR/lib"
PHASE_DIR="$SCRIPT_DIR/phases"
DEFAULT_EVIDENCE_ROOT="$REPO_ROOT/docs/porting/artifacts/hwtest-2026-11-07/auto"

BOARD=${BOARD:-root@192.168.2.10}
SSH_BIN=${HWTEST_SSH:-ssh}
SCP_BIN=${HWTEST_SCP:-scp}
BOARD_CTL_BIN=${HWTEST_BOARD_CTL:-}
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o LogLevel=ERROR -o ServerAliveInterval=3 -o ServerAliveCountMax=20 -o TCPKeepAlive=yes)
SCP_OPTS=(-o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=no)

# ---- options ---------------------------------------------------------------
OPT_DRY_RUN=0
OPT_NO_REBOOT=0
OPT_ONLY=""
OPT_LIST=0
OPT_PHASE_FILE=""
OPT_EVIDENCE=""
OPT_KEEP_BOARD=0
MIN_FREE_MB=${MIN_FREE_MB:-300}   # 板上根分区最小余量（MB）；抓帧阶段建议 ≥300
OPT_SKIP_PIXEL=0
OPT_ALLOW_SHA1_MISMATCH=0
OPT_VERBOSE=0
PHASE_ARG=""

# ---- phase state -----------------------------------------------------------
PHASE_FILE=""
PHASE_NAME=""
PHASE_DESC=""
PHASE_BOOT="clean"            # clean | current
PHASE_BOARD_M2="/root/m2"
PHASE_RETRY_AFTER_REBOOT=1
PHASE_EVIDENCE_ROOT=""
MOD_PATHS=()
MOD_PARAMS=()
EXPECT_PATHS=()
EXPECT_SHAS=()
CASE_NAME=()
CASE_TIMEOUT=()
CASE_CRITERIA=()
CASE_ATTEMPTS=()
CASE_CAPTURE=()
CASE_CAP_GLOB=()
CASE_OPTIONAL=()
CASE_PIXEL_STREAM=()
CASE_PIXEL_W=()
CASE_PIXEL_H=()
CASE_PIXEL_FRAMES=()
CASE_FETCH=()
CASE_RETRY_DELAY=()
CASE_CMD=()
CASE_METRICS=()
CASE_WARN_CRITERIA=()
CASE_FETCH_ARTIFACTS=()
CASE_HOST_CHECK=()

# ---- runtime state ---------------------------------------------------------
RUN_ID=""
EV=""
RUN_LOG=""
RESULTS_CSV=""
ENV_FILE=""
ENV2_FILE=""
START_EPOCH=0
HOST_END=""
VERDICT="FAIL"
FINALIZED=0
BOOT_MODE="clean"
BOOT_ID="?"
UPTIME="0"
BOOT_CLEAN="no"
BOARD_WORK=""
DURATION=0
FINAL_STATUS=()
FINAL_REASON=()
FINAL_PIXEL=()
FINAL_PIXEL_FRAMES=()
LAST_RC=""
LAST_FRAMES=""
LAST_RECEIVED=""
LAST_EXPECTED=""
LAST_CAP_ERRORS=""
LAST_TRANSPORT=""
LAST_SMOKE=""

# ---------------------------------------------------------------------------
# logging / errors
# ---------------------------------------------------------------------------
log() {
  local line
  line="[$(date +%H:%M:%S)] $*"
  printf '%s\n' "$line"
  if [ -n "${RUN_LOG:-}" ]; then
    printf '%s\n' "$line" >> "$RUN_LOG"
  fi
  return 0
}

warn() {
  log "WARN: $*"
}

die() {
  local msg="$1" code="${2:-1}"
  log "FATAL: $msg"
  # 证据目录尚未初始化时（用法/配置错误）不生成摘要/证据
  if [ -n "$EV" ] && [ -d "$EV" ] && [ "$START_EPOCH" -ne 0 ]; then
    VERDICT="FAIL"
    finalize
  fi
  exit "$code"
}

# ---------------------------------------------------------------------------
# phase definition API (called by phases/<name>.sh while sourced)
# ---------------------------------------------------------------------------
phase_name() { PHASE_NAME="$1"; }
phase_desc() { PHASE_DESC="$*"; }
phase_boot() { PHASE_BOOT="$1"; }
phase_board_m2() { PHASE_BOARD_M2="$1"; }
phase_retry_after_reboot() { PHASE_RETRY_AFTER_REBOOT="$1"; }
phase_evidence_root() { PHASE_EVIDENCE_ROOT="$1"; }

phase_module() {
  local path="$1"; shift || true
  MOD_PATHS+=("$path")
  MOD_PARAMS+=("$*")
}

phase_expect_sha1() {
  EXPECT_PATHS+=("$1")
  EXPECT_SHAS+=("$2")
}

# phase_case NAME TIMEOUT_S CRITERIA ATTEMPTS [options] -- COMMAND
# options:
#   --capture            用例会向 {capture} 目录抓帧（目录由编排器预建并清空）
#   --capture-glob GLOB  抓帧文件名匹配（默认 frame-*.nv21）
#   --optional           失败只记 WARN，不影响阶段结论
#   --pixel-stream PATH  主机侧参考码流（用于 Y sha1 比对；相对路径基于仓库根）
#   --pixel-size WxH     参考分辨率（如 1920x1080）
#   --pixel-frames all|N 比对帧数（默认 all）
#   --fetch-frames N     抓帧回传抽样数（默认 3，all 表示全传）
#   --retry-delay N      重试间隔秒（默认 3）
#   --metric NAME=REGEX  从用例日志提取指标（可重复）；数值/布尔自动转换
#   --warn-if CRITERIA   主判据通过后再判"警告判据"，不满足只记 WARN 不 FAIL
#   --fetch GLOB         用例结束后从 {out} 回传匹配文件到证据 artifacts/（可重复）
#   --host-check CMD     回传后在主机执行的后处理命令；stdout 追加进用例日志，
#                        环境变量：HWTEST_LIB_DIR/HWTEST_REPO_ROOT/HWTEST_CASE_EV/
#                        HWTEST_ARTIFACTS/HWTEST_LOG/HWTEST_PHASE/HWTEST_BOOT_ID
phase_case() {
  local name="$1" timeout="$2" criteria="$3" attempts="$4"
  shift 4
  local capture=0 cap_glob="frame-*.nv21" optional=0
  local pixel_stream="" pixel_w="" pixel_h="" pixel_frames="all" fetch=3 retry_delay=3
  local metrics="" warn_criteria="" fetch_artifacts="" host_check=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --) shift; break ;;
      --capture) capture=1; shift ;;
      --capture-glob) cap_glob="$2"; shift 2 ;;
      --optional) optional=1; shift ;;
      --pixel-stream) pixel_stream="$2"; shift 2 ;;
      --pixel-size) pixel_w="${2%x*}"; pixel_h="${2#*x}"; shift 2 ;;
      --pixel-frames) pixel_frames="$2"; shift 2 ;;
      --fetch-frames) fetch="$2"; shift 2 ;;
      --retry-delay) retry_delay="$2"; shift 2 ;;
      --metric)
        [ $# -ge 2 ] || { printf 'phase_case(%s): --metric 缺少参数\n' "$name" >&2; return 1; }
        metrics="${metrics:+$metrics;;}$2"; shift 2 ;;
      --warn-if) warn_criteria="$2"; shift 2 ;;
      --fetch)
        [ $# -ge 2 ] || { printf 'phase_case(%s): --fetch 缺少参数\n' "$name" >&2; return 1; }
        fetch_artifacts="${fetch_artifacts:+$fetch_artifacts;;}$2"; shift 2 ;;
      --host-check)
        [ $# -ge 2 ] || { printf 'phase_case(%s): --host-check 缺少参数\n' "$name" >&2; return 1; }
        host_check="$2"; shift 2 ;;
      *)
        printf 'phase_case(%s): 未知选项 %s\n' "$name" "$1" >&2
        return 1
        ;;
    esac
  done
  if [ "$#" -eq 0 ] || [ -z "$*" ]; then
    printf 'phase_case(%s): 缺少 -- 之后的命令\n' "$name" >&2
    return 1
  fi
  CASE_NAME+=("$name")
  CASE_TIMEOUT+=("$timeout")
  CASE_CRITERIA+=("$criteria")
  CASE_ATTEMPTS+=("$attempts")
  CASE_CAPTURE+=("$capture")
  CASE_CAP_GLOB+=("$cap_glob")
  CASE_OPTIONAL+=("$optional")
  CASE_PIXEL_STREAM+=("$pixel_stream")
  CASE_PIXEL_W+=("$pixel_w")
  CASE_PIXEL_H+=("$pixel_h")
  CASE_PIXEL_FRAMES+=("$pixel_frames")
  CASE_FETCH+=("$fetch")
  CASE_RETRY_DELAY+=("$retry_delay")
  CASE_CMD+=("$*")
  CASE_METRICS+=("$metrics")
  CASE_WARN_CRITERIA+=("$warn_criteria")
  CASE_FETCH_ARTIFACTS+=("$fetch_artifacts")
  CASE_HOST_CHECK+=("$host_check")
  return 0
}

reset_phase_state() {
  PHASE_NAME=""
  PHASE_DESC=""
  PHASE_BOOT="clean"
  PHASE_BOARD_M2="/root/m2"
  PHASE_RETRY_AFTER_REBOOT=1
  PHASE_EVIDENCE_ROOT=""
  MOD_PATHS=(); MOD_PARAMS=()
  EXPECT_PATHS=(); EXPECT_SHAS=()
  CASE_NAME=(); CASE_TIMEOUT=(); CASE_CRITERIA=(); CASE_ATTEMPTS=()
  CASE_CAPTURE=(); CASE_CAP_GLOB=(); CASE_OPTIONAL=()
  CASE_PIXEL_STREAM=(); CASE_PIXEL_W=(); CASE_PIXEL_H=()
  CASE_PIXEL_FRAMES=(); CASE_FETCH=(); CASE_RETRY_DELAY=(); CASE_CMD=()
  CASE_METRICS=(); CASE_WARN_CRITERIA=(); CASE_FETCH_ARTIFACTS=(); CASE_HOST_CHECK=()
}

load_phase() {
  local file="$1"
  [ -f "$file" ] || die "阶段定义文件不存在: $file" 2
  reset_phase_state
  PHASE_FILE="$file"
  # shellcheck disable=SC1090
  if ! . "$file"; then
    die "阶段定义加载失败: $file" 2
  fi
  [ -n "$PHASE_NAME" ] || PHASE_NAME=$(basename "$file" .sh)
  if [ "${#CASE_NAME[@]}" -eq 0 ]; then
    die "阶段 $PHASE_NAME 没有定义任何用例（phase_case）" 2
  fi
  case "$PHASE_BOOT" in
    clean|current) ;;
    *) die "phase_boot 只支持 clean/current（当前: $PHASE_BOOT）" 2 ;;
  esac
  local i
  for i in "${!CASE_NAME[@]}"; do
    case "${CASE_TIMEOUT[$i]}" in
      ''|*[!0-9]*) die "用例 ${CASE_NAME[$i]} 的 timeout 必须是整数秒" 2 ;;
    esac
    case "${CASE_ATTEMPTS[$i]}" in
      ''|*[!0-9]*) die "用例 ${CASE_NAME[$i]} 的 attempts 必须是整数" 2 ;;
    esac
    [ "${CASE_ATTEMPTS[$i]}" -ge 1 ] || die "用例 ${CASE_NAME[$i]} 的 attempts 必须 >= 1" 2
    [ -n "${CASE_CMD[$i]}" ] || die "用例 ${CASE_NAME[$i]} 缺少命令" 2
    if [ -n "${CASE_PIXEL_STREAM[$i]}" ]; then
      case "${CASE_PIXEL_W[$i]}x${CASE_PIXEL_H[$i]}" in
        *[!0-9x]*|x*|*x) die "用例 ${CASE_NAME[$i]} 的 --pixel-size 必须是 WxH（如 1920x1080）" 2 ;;
      esac
    fi
    if [ -n "${CASE_METRICS[$i]}" ]; then
      local -a _metric_specs=() _metric_spec
      IFS=';;' read -r -a _metric_specs <<< "${CASE_METRICS[$i]}"
      for _metric_spec in "${_metric_specs[@]}"; do
        [ -z "$_metric_spec" ] && continue
        case "$_metric_spec" in
          *=*) ;;
          *) die "用例 ${CASE_NAME[$i]} 的 --metric 必须是 NAME=REGEX: $_metric_spec" 2 ;;
        esac
      done
    fi
    if [ -n "${CASE_WARN_CRITERIA[$i]}" ] && [ -z "${CASE_CRITERIA[$i]}" ]; then
      die "用例 ${CASE_NAME[$i]} 只声明了 --warn-if 而没有主判据" 2
    fi
  done
  [ -n "${HWTEST_BOARD_M2:-}" ] && PHASE_BOARD_M2="$HWTEST_BOARD_M2"
  return 0
}

# ---------------------------------------------------------------------------
# board helpers
# ---------------------------------------------------------------------------
board_ctl() {
  if [ -n "$BOARD_CTL_BIN" ]; then
    "$BOARD_CTL_BIN" "$@"
  else
    python3 "$SCRIPT_DIR/board_ctl.py" "$@"
  fi
}

ssh_run() {
  # 2026-11-10: WSL<->board 偶发瞬断（Connection reset/refused），对 ssh 传输层失败
  # （rc=255）做短退避重试，避免把网络瞬态误判为测试失败。
  local i rc
  for i in 1 2 3 4 5; do
    "$SSH_BIN" "${SSH_OPTS[@]}" "$BOARD" "$1"
    rc=$?
    [ "$rc" -ne 255 ] && return "$rc"
    sleep $((i * 2))
  done
  return 255
}

ssh_ok() {
  ssh_run "$1" >/dev/null 2>&1
}

parse_status() {
  local line="$1"
  BOOT_ID=$(printf '%s\n' "$line" | sed -n 's/.*boot_id=\([^ ]*\).*/\1/p')
  UPTIME=$(printf '%s\n' "$line" | sed -n 's/.*uptime=\([0-9.]*\)s.*/\1/p')
  BOOT_ID=${BOOT_ID:-?}
  UPTIME=${UPTIME:-0}
}

board_boot() {
  local rc=0 state
  if [ "$BOOT_MODE" = "clean" ]; then
    log "board: clean boot（board_ctl.py reboot，失败自动 RTS 复位/拉起 SSH）"
    board_ctl reboot --timeout 180 > "$EV/boot.log" 2>&1 || rc=$?
  else
    log "board: 使用当前 boot（不 reboot）"
    board_ctl ensure-ssh > "$EV/boot.log" 2>&1 || rc=$?
  fi
  if [ -f "$EV/boot.log" ]; then
    sed 's/^/[board_ctl] /' "$EV/boot.log" >> "$RUN_LOG" 2>/dev/null || true
  fi
  if [ "$rc" -ne 0 ]; then
    log "board_ctl 输出："
    cat "$EV/boot.log" >&2 2>/dev/null || true
    die "板卡引导失败（board_ctl rc=$rc）" 3
  fi
  state=$(board_ctl status 2>&1) || true
  if ! printf '%s' "$state" | grep -q "board: UP"; then
    log "board_ctl status: $state"
    die "板卡 SSH 不可达（请检查串口/网线/电源）" 3
  fi
  log "board: $state"
  parse_status "$state"

  # 2026-11-10：板卡根分区接近满盘时抓帧会写失败（capture_errors>0）并连带 SSH 瞬断。
  # 先在 boot 后做磁盘预检：自动清理残留 /root/hwtest/auto/*，仍不足则快速失败。
  local free_mb
  free_mb=$(ssh_run "df -Pm / | awk 'NR==2{print \$4}'" 2>/dev/null | tr -d ' \r')
  if [ -n "$free_mb" ] && [ "$free_mb" -lt "$MIN_FREE_MB" ] 2>/dev/null; then
    log "board: 根分区余量 ${free_mb}MB < ${MIN_FREE_MB}MB，清理残留 workdir 后重试"
    ssh_run "rm -rf /root/hwtest/auto/*" >/dev/null 2>&1 || true
    free_mb=$(ssh_run "df -Pm / | awk 'NR==2{print \$4}'" 2>/dev/null | tr -d ' \r')
    if [ -n "$free_mb" ] && [ "$free_mb" -lt "$MIN_FREE_MB" ] 2>/dev/null; then
      die "板上根分区余量 ${free_mb}MB < ${MIN_FREE_MB}MB（MIN_FREE_MB 可调）：先清盘（rm -rf /root/hwtest/auto/*）再跑" 4
    fi
    log "board: 清理后根分区余量 ${free_mb}MB"
  fi
  if [ "$BOOT_MODE" = "clean" ]; then BOOT_CLEAN="yes"; else BOOT_CLEAN="no"; fi

  local i
  for i in $(seq 1 30); do
    ssh_ok "test -d '$PHASE_BOARD_M2'" && break
    sleep 2
  done
  if ! ssh_ok "test -d '$PHASE_BOARD_M2'"; then
    die "板上工具目录不存在: $PHASE_BOARD_M2" 3
  fi
  if [ "$BOOT_MODE" = "clean" ] && awk -v u="$UPTIME" 'BEGIN{exit !(u>180)}' 2>/dev/null; then
    warn "reboot 后 uptime=${UPTIME}s 偏大，boot 可能不干净"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# environment snapshot / sha1 checks / module loading
# ---------------------------------------------------------------------------
unique_paths() {
  local seen=" " p out=()
  for p in "$@"; do
    case "$seen" in
      *" $p "*) ;;
      *) out+=("$p"); seen="$seen$p " ;;
    esac
  done
  [ "${#out[@]}" -eq 0 ] && return 0
  printf '%s\n' "${out[@]}"
}

collect_environment() {
  local file="$1" label="$2"
  local paths=() p sha_list="" script="$EV/_env_script.sh"
  mapfile -t paths < <(unique_paths "${MOD_PATHS[@]}" "${EXPECT_PATHS[@]}")
  if [ "${#paths[@]}" -gt 0 ]; then
    sha_list="${paths[*]}"
  fi
  {
    printf 'echo "### board clock (untrusted)"\n'
    printf 'date -Is 2>/dev/null || true\n'
    printf 'echo "### uptime_s"\n'
    printf 'cut -d" " -f1 /proc/uptime\n'
    printf 'echo "### boot_id"\n'
    printf 'cat /proc/sys/kernel/random/boot_id\n'
    printf 'echo "### uname"\n'
    printf 'uname -a\n'
    printf 'echo "### meminfo"\n'
    printf 'grep -E "^(MemTotal|MemFree|MemAvailable|CmaTotal|CmaFree):" /proc/meminfo\n'
    printf 'echo "### df"\n'
    printf 'df -h / /tmp 2>/dev/null || true\n'
    printf 'echo "### lsmod"\n'
    printf 'lsmod 2>/dev/null || true\n'
    if [ -n "$sha_list" ]; then
      printf 'echo "### tools/modules sha1"\n'
      printf 'sha1sum %s 2>&1 || true\n' "$sha_list"
      printf 'echo "### sizes"\n'
      printf 'ls -l %s 2>&1 || true\n' "$sha_list"
    fi
    printf 'echo "### module params"\n'
    printf 'for m in hi_vdec hi_venc hi_jpeg hi_png hi_mmz_shim; do if [ -d /sys/module/$m/parameters ]; then echo "$m: $(ls /sys/module/$m/parameters 2>/dev/null | xargs echo)"; fi; done\n'
    printf 'echo "### dmesg tail"\n'
    printf 'dmesg 2>/dev/null | tail -15 || true\n'
  } > "$script"
  {
    printf '# environment snapshot: %s\n' "$label"
    printf '# host_time=%s\n' "$(date -Is)"
    printf '# host=%s\n' "$(hostname 2>/dev/null || echo unknown)"
    printf '# repo_root=%s\n' "$REPO_ROOT"
    printf '## host uname: %s\n' "$(uname -a)"
    printf '## host git: %s\n' "$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    printf '## orchestrator sha1:\n'
    sha1sum "$SCRIPT_DIR/run_phase.sh" "$LIB_DIR"/*.py "$PHASE_FILE" 2>/dev/null || true
    printf '## board (via ssh):\n'
    ssh_run "sh -s" < "$script" 2>&1 || true
  } > "$file"
  rm -f "$script"
}

check_sha1_expectations() {
  [ "${#EXPECT_PATHS[@]}" -eq 0 ] && return 0
  local i path expected actual
  for i in "${!EXPECT_PATHS[@]}"; do
    path="${EXPECT_PATHS[$i]}"
    expected="${EXPECT_SHAS[$i]}"
    actual=$(ssh_run "sha1sum '$path' 2>/dev/null | cut -d' ' -f1" 2>/dev/null)
    actual=${actual//[[:space:]]/}
    if [ -z "$actual" ]; then
      die "sha1 校验失败：板上文件不存在或不可读: $path" 3
    fi
    local ok=0
    if [ "${#expected}" -lt 40 ]; then
      case "$actual" in "$expected"*) ok=1 ;; esac
    else
      [ "$actual" = "$expected" ] && ok=1
    fi
    if [ "$ok" -eq 1 ]; then
      log "sha1 ok: $path ${actual:0:12}…"
    elif [ "$OPT_ALLOW_SHA1_MISMATCH" -eq 1 ]; then
      warn "sha1 不符（已忽略）: $path actual=${actual:0:12}… expect=${expected:0:12}…"
    else
      die "sha1 不符: $path actual=$actual expect=$expected（如为有意更新，用 --allow-sha1-mismatch）" 3
    fi
  done
  return 0
}

load_modules() {
  if [ "${#MOD_PATHS[@]}" -eq 0 ]; then
    log "phase 未声明模块，跳过 insmod"
    return 0
  fi
  # DEP-01：hi-accel.service 开机加载 + VDEC 预热期间占用 /dev/hi_vdec，
  # 必须等其结束（最多 180s），否则后续 rmmod/解码会与预热冲突。
  local w st
  for w in $(seq 1 90); do
    st=$(ssh_run "systemctl is-active hi-accel 2>/dev/null" 2>/dev/null | tr -d '[:space:]')
    [ "$st" = "activating" ] || break
    [ "$w" -eq 1 ] && log "等待 hi-accel.service 完成开机加载/预热…"
    sleep 2
  done
  [ "$st" = "activating" ] && warn "hi-accel.service 180s 仍未完成（继续执行）"
  ssh_run "dmesg -C 2>/dev/null; true" >/dev/null 2>&1 || true
  local i path params name cmd rc
  for i in "${!MOD_PATHS[@]}"; do
    path="${MOD_PATHS[$i]}"
    params="${MOD_PARAMS[$i]}"
    # 模块文件名不一定等于内核模块名（例如 hi_vdec_downmsg_r51_final.ko 的模块名是 hi_vdec）。
    # 优先用 modinfo -F name 取真实模块名，取不到再退回文件名。
    name=$(ssh_run "modinfo -F name '$path' 2>/dev/null | head -1" 2>/dev/null | tr -d '\r' | head -1)
    if [ -z "$name" ] || [ "$name" = "$path" ]; then
      name=$(basename "$path" .ko)
      name=${name//-/_}
    fi
    if ssh_ok "test -d /sys/module/$name"; then
      # DEP-01（hi-accel.service）开机即按默认参数加载模块。阶段若声明了不同参数
      # （如 4K 抓帧需 vdec_no_vcmp=1，运行时写 sysfs 不生效）或模块文件不同
      # （srcversion 不一致），则 rmmod 后按阶段配方重载；一致则保留现场。
      local mismatch="" kv key val cur want_src cur_src
      for kv in $params; do
        key=${kv%%=*}; val=${kv#*=}
        cur=$(ssh_run "cat /sys/module/$name/parameters/$key 2>/dev/null" 2>/dev/null | tr -d '[:space:]')
        # bool 参数在 sysfs 中读出为 Y/N，统一成 1/0 再比较
        case "$cur" in Y|y) cur=1 ;; N|n) cur=0 ;; esac
        case "$val" in Y|y|true) val=1 ;; N|n|false) val=0 ;; esac
        [ -n "$cur" ] && [ "$cur" != "$val" ] && mismatch+=" $key=$cur(want $val)"
      done
      want_src=$(ssh_run "modinfo -F srcversion '$path' 2>/dev/null" 2>/dev/null | tr -d '[:space:]')
      cur_src=$(ssh_run "cat /sys/module/$name/srcversion 2>/dev/null" 2>/dev/null | tr -d '[:space:]')
      [ -n "$want_src" ] && [ -n "$cur_src" ] && [ "$want_src" != "$cur_src" ] && \
        mismatch+=" srcversion=$cur_src(want $want_src)"
      if [ -z "$mismatch" ]; then
        log "模块 $name 已加载 → 跳过 insmod（参数/srcversion 与阶段一致）"
        continue
      fi
      warn "模块 $name 已加载但不符:${mismatch} → rmmod 后按阶段配方重载"
      if ! ssh_run "for t in 1 2 3 4 5; do timeout 30 rmmod $name && exit 0; sleep 3; done; exit 1" > "$EV/rmmod-$name.log" 2>&1; then
        die "rmmod $name 失败（可能被占用，见 $EV/rmmod-$name.log）；请 reboot 并在 /etc/hi-accel.conf 关闭对应模块" 3
      fi
    fi
    cmd="cd '$PHASE_BOARD_M2' && timeout 30 insmod '$path'"
    [ -n "$params" ] && cmd="$cmd $params"
    log "insmod: $path${params:+ params=$params}"
    rc=0
    ssh_run "$cmd" > "$EV/insmod-$name.log" 2>&1 || rc=$?
    if [ "$rc" -ne 0 ] || ! ssh_ok "test -d /sys/module/$name"; then
      log "insmod 输出: $(tr '\n' ' ' < "$EV/insmod-$name.log" 2>/dev/null | cut -c1-400)"
      die "模块加载失败: $path (rc=$rc)" 3
    fi
    log "模块已加载: $name"
  done
  ssh_run "dmesg 2>/dev/null | grep -aE 'VDEC_OpenDev|VDEC_InitHardware|VCTRL_OpenVfmw|CHANOPT|hi_vdec|hi_venc|hi_jpeg|hi_png|hi_mmz' | tail -20" > "$EV/dmesg-after-load.txt" 2>&1 || true
  return 0
}

# ---------------------------------------------------------------------------
# case helpers
# ---------------------------------------------------------------------------
case_selected() {
  local name="$1"
  [ -z "$OPT_ONLY" ] && return 0
  # shellcheck disable=SC2053
  [[ "$name" == $OPT_ONLY ]]
}

expand_cmd() {
  local c="$1" bdir="$2" bcap="$3" attempt="$4"
  c=${c//\{m2\}/$PHASE_BOARD_M2}
  c=${c//\{out\}/$bdir}
  c=${c//\{capture\}/$bcap}
  c=${c//\{attempt\}/$attempt}
  printf '%s' "$c"
}

# 组装远程命令行：cd 到板上工具目录后用外层 timeout 兜底。
# 命令可能带 `VAR=值 cmd` 形式的环境变量前缀，因此用 sh -c 包一层，
# 避免 `timeout N VAR=值 cmd` 把赋值当成可执行文件。
remote_case_command() {
  local cmd="$1" outer="$2" escaped
  escaped=${cmd//\'/\'\\\'\'}
  printf "cd '%s' && timeout %s sh -c '%s'" "$PHASE_BOARD_M2" "$outer" "$escaped"
}

csv_escape() {
  local s="$1"
  s=${s//$'\n'/ }
  s=${s//\"/\"\"}
  printf '"%s"' "$s"
}

append_result_row() {
  local line="" field
  for field in "$@"; do
    line+="$(csv_escape "$field"),"
  done
  printf '%s\n' "${line%,}" >> "$RESULTS_CSV"
  return 0
}

contains() {
  local needle="$1"; shift
  local item
  for item in "$@"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

# verify_pixel CASE_INDEX CASE_EV_DIR BOARD_CASE_DIR [ATTEMPT]
# 通过全局变量返回：PIXEL_OK / PIXEL_FRAMES / PIXEL_REASON
verify_pixel() {
  local idx="$1" case_ev="$2" bdir="$3" attempt="${4:-1}"
  PIXEL_OK=""
  PIXEL_FRAMES=""
  PIXEL_REASON=""
  local stream="${CASE_PIXEL_STREAM[$idx]}"
  local pw="${CASE_PIXEL_W[$idx]}" ph="${CASE_PIXEL_H[$idx]}"
  if [ "$OPT_SKIP_PIXEL" -eq 1 ]; then
    PIXEL_OK="skipped"
    PIXEL_REASON="--skip-pixel"
    log "pixel: 跳过（--skip-pixel）"
    return 0
  fi
  case "$stream" in
    /*) ;;
    *) stream="$REPO_ROOT/$stream" ;;
  esac
  if [ ! -f "$stream" ]; then
    PIXEL_OK="skipped"
    PIXEL_REASON="host ref stream not found: $stream"
    warn "pixel 跳过：主机参考码流不存在 $stream"
    return 0
  fi
  if [ -z "$pw" ] || [ -z "$ph" ]; then
    PIXEL_OK="false"
    PIXEL_REASON="pixel-size not declared"
    return 1
  fi

  local pdir="$case_ev/pixel/attempt-$attempt" yb=$(( pw * ph )) cap_glob="${CASE_CAP_GLOB[$idx]}"
  local bcap="$bdir/cap"
  mkdir -p "$pdir"
  local rc=0

  # 1) 板上逐帧 Y sha1（前 w*h 字节 = NV21 的 Y 平面）
  cat > "$pdir/board_pixel.sh" <<'PIXEOF'
cd "$CAP" || exit 2
: > "$OUT"
for f in $(ls $GLOB 2>/dev/null | sort); do
  s=$(head -c "$YB" "$f" 2>/dev/null | sha1sum | cut -d' ' -f1)
  [ -n "$s" ] && printf '%s %s\n' "$s" "$f" >> "$OUT"
done
wc -l < "$OUT"
PIXEOF
  local remote_list="$bdir/board-y-sha1.txt"
  ssh_run "CAP='$bcap' GLOB='$cap_glob' YB=$yb OUT='$remote_list' sh -s" \
    < "$pdir/board_pixel.sh" > "$pdir/board-sha1.log" 2>&1 || rc=$?
  if [ "$rc" -ne 0 ]; then
    PIXEL_OK="false"
    PIXEL_REASON="board Y sha1 failed rc=$rc"
    log "pixel: 板上 sha1 计算失败 rc=$rc"
    return 1
  fi
  ssh_run "cat '$remote_list'" > "$pdir/board-y-sha1.txt" 2>>"$pdir/board-sha1.log" || true
  if [ ! -s "$pdir/board-y-sha1.txt" ]; then
    PIXEL_OK="false"
    PIXEL_REASON="board Y sha1 list empty"
    log "pixel: 板上 Y sha1 列表为空"
    return 1
  fi

  # 2) 主机 ffmpeg 参考 + 逐帧 Y sha1
  local tmpd="$EV/.tmp" ref="$EV/.tmp/ref.nv21"
  mkdir -p "$tmpd"
  if ! ffmpeg -v error -y -i "$stream" -f rawvideo -pix_fmt nv21 "$ref" \
       > "$pdir/ffmpeg.log" 2>&1; then
    PIXEL_OK="false"
    PIXEL_REASON="host ffmpeg failed"
    log "pixel: 主机 ffmpeg 解参考失败（见 $pdir/ffmpeg.log）"
    rm -f "$ref"
    return 1
  fi
  python3 "$LIB_DIR/reference_y_sha1.py" "$ref" "$pw" "$ph" \
    > "$pdir/host-ref-y-sha1.txt" 2> "$pdir/reference.log" || true
  if [ ! -s "$pdir/host-ref-y-sha1.txt" ]; then
    PIXEL_OK="false"
    PIXEL_REASON="host reference Y sha1 empty"
    rm -f "$ref"
    return 1
  fi

  # 3) 列表比对（按帧序号）
  local limit_args=()
  if [ "${CASE_PIXEL_FRAMES[$idx]}" != "all" ]; then
    limit_args=(--limit "${CASE_PIXEL_FRAMES[$idx]}")
  fi
  python3 "$LIB_DIR/y_sha1_check.py" --board "$pdir/board-y-sha1.txt" \
    --ref "$pdir/host-ref-y-sha1.txt" "${limit_args[@]}" \
    --json-out "$pdir/pixel-check.json" > "$pdir/pixel-check.txt" 2>&1 || rc=$?
  local p_ok p_frames p_reason
  p_ok=$(sed -n 's/^pixel_ok=//p' "$pdir/pixel-check.txt" | tail -1)
  p_frames=$(sed -n 's/^pixel_frames=//p' "$pdir/pixel-check.txt" | tail -1)
  p_reason=$(sed -n 's/^pixel_reason=//p' "$pdir/pixel-check.txt" | tail -1)
  if [ "$rc" -ne 0 ] || [ "$p_ok" != "true" ]; then
    PIXEL_OK="false"
    PIXEL_FRAMES="${p_frames:-?}"
    PIXEL_REASON="${p_reason:-frame sha1 mismatch}"
    log "pixel: FAIL（${PIXEL_REASON}，frames=${PIXEL_FRAMES}）"
    rm -f "$ref"
    return 1
  fi
  log "pixel: Y sha1 全部一致（frames=${p_frames}）"

  # 4) 抽样帧回传 + compare_vdec.py 详细统计
  local -a files=()
  mapfile -t files < <(awk '{print $2}' "$pdir/board-y-sha1.txt")
  local n=${#files[@]} fetch_n="${CASE_FETCH[$idx]}"
  case "$fetch_n" in
    all) fetch_n=$n ;;
    *[!0-9]*) fetch_n=3 ;;
  esac
  [ "$fetch_n" -lt 0 ] && fetch_n=0
  [ "$fetch_n" -gt "$n" ] && fetch_n=$n
  local -a idxs=()
  local k
  if [ "$fetch_n" -ge "$n" ]; then
    for ((k = 0; k < n; k++)); do idxs+=("$k"); done
  elif [ "$fetch_n" -eq 0 ]; then
    idxs=()
  elif [ "$fetch_n" -eq 1 ]; then
    idxs=(0)
  elif [ "$fetch_n" -eq 2 ]; then
    idxs=(0 $((n - 1)))
  else
    idxs=(0 $(((n - 1) / 2)) $((n - 1)))
  fi
  local cmp_log="$pdir/compare.txt" sample_ok=0 sample_total=0
  : > "$cmp_log"
  if [ "$fetch_n" -gt 0 ] && ! command -v "$SCP_BIN" >/dev/null 2>&1; then
    warn "scp 不可用（$SCP_BIN）→ 跳过抽样帧回传，仅做全列表 Y sha1 比对"
    idxs=()
  fi
  for k in "${idxs[@]}"; do
    local f="${files[$k]}" ordinal expect_sha actual_sha cmp_one
    ordinal=$(printf '%s\n' "$f" | sed -n 's/^frame-\([0-9]*\)-.*/\1/p')
    [ -n "$ordinal" ] || ordinal="$k"
    mkdir -p "$pdir/cap"
    # shellcheck disable=SC2086
    $SCP_BIN "${SCP_OPTS[@]}" -q "${BOARD}:${bcap}/$f" "$pdir/cap/$f" 2>>"$pdir/scp.log" || true
    sample_total=$((sample_total + 1))
    if [ ! -f "$pdir/cap/$f" ]; then
      printf 'FETCH-FAIL %s\n' "$f" >> "$cmp_log"
      continue
    fi
    cmp_one="$pdir/.cmp-$k.txt"
    {
      printf '### %s (ref frame %s)\n' "$f" "$ordinal"
      python3 "$LIB_DIR/compare_vdec.py" "$pdir/cap/$f" "$ref" "$pw" "$ph" "$ordinal" 2>&1
    } > "$cmp_one"
    cat "$cmp_one" >> "$cmp_log"
    expect_sha=$(awk -v f="$f" '$2 == f {print $1}' "$pdir/board-y-sha1.txt")
    actual_sha=$(head -c "$yb" "$pdir/cap/$f" 2>/dev/null | sha1sum | cut -d' ' -f1)
    if [ -n "$expect_sha" ] && [ "$expect_sha" = "$actual_sha" ] && \
       grep -q '^y_identical=True' "$cmp_one"; then
      sample_ok=$((sample_ok + 1))
    fi
    rm -f "$cmp_one"
  done
  rm -f "$ref"
  if [ "$sample_total" -eq 0 ]; then
    PIXEL_OK="true"
    PIXEL_FRAMES="${p_frames}（仅列表比对，未回传抽样帧）"
    PIXEL_REASON="all Y sha1 identical (list only)"
    log "pixel: Y sha1 列表一致（未回传抽样帧）"
  elif [ "$sample_ok" -eq "$sample_total" ]; then
    PIXEL_OK="true"
    PIXEL_FRAMES="${p_frames}（抽样 compare_vdec.py ${sample_ok}/${sample_total} 帧 Y 一致）"
    PIXEL_REASON="all Y sha1 identical"
    log "pixel: 抽样 compare_vdec.py ${sample_ok}/${sample_total} 帧通过"
  else
    PIXEL_OK="false"
    PIXEL_FRAMES="${p_frames}"
    PIXEL_REASON="sample compare failed ${sample_ok}/${sample_total}"
    log "pixel: FAIL（抽样比对 ${sample_ok}/${sample_total}）"
    return 1
  fi
  return 0
}

run_case() {
  local idx="$1" pass="$2"
  local name="${CASE_NAME[$idx]}"
  local case_ev="$EV/cases/$name/pass-$pass"
  local start_ts end_ts
  mkdir -p "$case_ev"
  start_ts=$(date +%s)

  local attempt=0 attempts="${CASE_ATTEMPTS[$idx]}"
  local outer="${CASE_TIMEOUT[$idx]}"
  local case_pass="false" cap_frames=0 cap_kb=0
  local reason="" parse_out="" parsed_env="" attempt_log=""
  local bdir="" bcap="" rc=0

  PIXEL_OK=""
  PIXEL_FRAMES=""
  PIXEL_REASON=""
  LAST_WARN=""
  LAST_METRICS=""
  local warn_note="" artifacts=0 fail_reason=""

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    case_ev="$EV/cases/$name/pass-$pass"
    bdir="$BOARD_WORK/cases/$name/pass-$pass/attempt-$attempt"
    bcap="$bdir/cap"
    attempt_log="$case_ev/attempt-$attempt.log"
    ssh_run "mkdir -p '$bdir'" >/dev/null 2>&1 || true
    if [ "${CASE_CAPTURE[$idx]}" -eq 1 ]; then
      # vdec_spec 不创建 capture 目录（wbx 独占创建，必须预建且清空）
      ssh_run "rm -rf '$bcap'; mkdir -p '$bcap'" >/dev/null 2>&1 || true
    fi
    local cmd
    cmd=$(expand_cmd "${CASE_CMD[$idx]}" "$bdir" "$bcap" "$attempt")
    log "case ${name} pass=${pass} attempt=${attempt}/${attempts} timeout=${outer}s"
    log "  cmd: $cmd"
    rc=0
    ssh_run "$(remote_case_command "$cmd" "$outer")" > "$attempt_log" 2>&1 || rc=$?
    LAST_RC="$rc"
    {
      printf '\n### dmesg tail (host-side appended)\n'
      ssh_run "dmesg 2>/dev/null | grep -aE 'VTSTAT|vdec|VDEC|oops|BUG|Call trace|hi_vdec' | tail -20" 2>&1 || true
    } >> "$attempt_log"

    # 4b) 回传产物（--fetch）：供 host-check 与证据使用
    artifacts=0
    if [ -n "${CASE_FETCH_ARTIFACTS[$idx]}" ]; then
      mkdir -p "$case_ev/artifacts"
      local -a _fetch_globs=() _fetch_glob
      IFS=';;' read -r -a _fetch_globs <<< "${CASE_FETCH_ARTIFACTS[$idx]}"
      for _fetch_glob in "${_fetch_globs[@]}"; do
        [ -z "$_fetch_glob" ] && continue
        if "$SCP_BIN" "${SCP_OPTS[@]}" -q "${BOARD}:${bdir}/$_fetch_glob" "$case_ev/artifacts/" 2>>"$case_ev/fetch.log"; then
          log "  fetch ok: $_fetch_glob"
        else
          log "  fetch FAIL: $_fetch_glob"
        fi
      done
      artifacts=$(find "$case_ev/artifacts" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d '[:space:]')
      log "  artifacts=${artifacts}"
    fi

    # 4c) 主机侧后处理（--host-check）：输出追加进用例日志，供 --metric 提取
    if [ -n "${CASE_HOST_CHECK[$idx]}" ]; then
      {
        printf '\n### host-check\n'
      } >> "$attempt_log"
      local host_rc=0
      HWTEST_LIB_DIR="$LIB_DIR" HWTEST_REPO_ROOT="$REPO_ROOT" \
        HWTEST_CASE_EV="$case_ev" HWTEST_ARTIFACTS="$case_ev/artifacts" \
        HWTEST_LOG="$attempt_log" HWTEST_PHASE="$PHASE_NAME" \
        HWTEST_BOARD_DIR="$bdir" HWTEST_BOOT_ID="$BOOT_ID" \
        bash -c "${CASE_HOST_CHECK[$idx]}" >> "$attempt_log" 2>&1 || host_rc=$?
      printf 'HOST_CHECK_RC=%s\n' "$host_rc" >> "$attempt_log"
      log "  host-check rc=${host_rc}"
    fi

    cap_frames=0
    cap_kb=0
    if [ "${CASE_CAPTURE[$idx]}" -eq 1 ]; then
      cap_frames=$(ssh_run "find '$bcap' -maxdepth 1 -type f -name '${CASE_CAP_GLOB[$idx]}' 2>/dev/null | wc -l" 2>/dev/null | tr -d '[:space:]')
      cap_frames=${cap_frames//[!0-9]/}
      cap_frames=${cap_frames:-0}
      cap_kb=$(ssh_run "du -sk '$bcap' 2>/dev/null | cut -f1" 2>/dev/null | tr -d '[:space:]')
      cap_kb=${cap_kb//[!0-9]/}
      cap_kb=${cap_kb:-0}
      log "  frames=${cap_frames} cap_size=${cap_kb}KB"
    fi

    parsed_env="$case_ev/parsed-attempt-$attempt.json"
    parsed_env="${parsed_env%.json}.env"
    parse_out="$case_ev/parse-attempt-$attempt.txt"
    local -a metric_args=()
    if [ -n "${CASE_METRICS[$idx]}" ]; then
      local -a _metric_specs=() _metric_spec
      IFS=';;' read -r -a _metric_specs <<< "${CASE_METRICS[$idx]}"
      for _metric_spec in "${_metric_specs[@]}"; do
        [ -n "$_metric_spec" ] && metric_args+=(--metric "$_metric_spec")
      done
    fi
    # host-check 的执行结果自动作为 host_check_rc 指标
    if [ -n "${CASE_HOST_CHECK[$idx]}" ]; then
      metric_args+=(--metric 'host_check_rc=HOST_CHECK_RC=(\d+)')
    fi
    python3 "$LIB_DIR/parse_case.py" --log "$attempt_log" --rc "$rc" \
      --criteria "${CASE_CRITERIA[$idx]}" --warn-criteria "${CASE_WARN_CRITERIA[$idx]}" \
      --cap-frames "$cap_frames" --cap-bytes-kb "$cap_kb" --case "$name" \
      "${metric_args[@]}" \
      --json-out "$case_ev/parsed-attempt-$attempt.json" \
      > "$parse_out" 2>&1
    local parse_rc=$?
    if [ "$parse_rc" -eq 2 ]; then
      log "解析错误：$(tail -3 "$parse_out" | tr '\n' ' ')"
      die "parse_case.py 执行失败: $name" 2
    fi
    local PASS="false" REASON="parse produced no verdict"
    if [ -f "$parsed_env" ]; then
      # shellcheck disable=SC1090
      . "$parsed_env"
    fi
    log "  verdict=${PASS} reason=${REASON}"
    while IFS= read -r line; do
      [ -n "$line" ] && log "  $line"
    done < "$parse_out"
    if [ "$OPT_VERBOSE" -eq 1 ] && [ "$PASS" != "true" ]; then
      tail -15 "$attempt_log" 2>/dev/null | sed 's/^/  | /' | while IFS= read -r l; do log "$l"; done
    fi

    # 记录最近一次字段供 results.csv 使用
    LAST_RC="$rc"
    LAST_FRAMES="$cap_frames"
    LAST_RECEIVED="${R_RECEIVED:-}"
    LAST_EXPECTED="${R_EXPECTED:-}"
    LAST_CAP_ERRORS="${R_CAPTURE_ERRORS:-}"
    LAST_TRANSPORT="${R_TRANSPORT_OK:-}"
    LAST_SMOKE="${SMOKE_FRAMES:-}"
    LAST_METRICS="${METRICS_SUMMARY:-}"
    fail_reason="${REASON:-}"
    if [ -n "$LAST_METRICS" ]; then
      log "  metrics: $LAST_METRICS"
    fi

    if [ "$PASS" = "true" ]; then
      case_pass="true"
      reason="${REASON}"
      LAST_WARN="${WARN:-false}"
      if [ "$LAST_WARN" = "true" ]; then
        warn_note="warn: ${WARN_REASON:-warn criteria not met}"
        log "  warn: ${WARN_REASON:-warn criteria not met}"
      else
        warn_note=""
      fi
      # 像素验证只在抓帧用例且声明了参考流时进行
      if [ "${CASE_CAPTURE[$idx]}" -eq 1 ] && [ -n "${CASE_PIXEL_STREAM[$idx]}" ]; then
        if ! verify_pixel "$idx" "$case_ev" "$bdir" "$attempt"; then
          case_pass="false"
          reason="criteria ok 但 pixel 失败: ${PIXEL_REASON}"
          log "  pixel verdict=${PIXEL_OK} ${PIXEL_REASON}"
        fi
      fi
      if [ "$case_pass" = "true" ]; then
        log "case ${name}: PASS${warn_note:+（$warn_note）}"
        break
      fi
    fi

    if [ "$attempt" -lt "$attempts" ]; then
      log "case ${name}: retry（attempt ${attempt}/${attempts} 未通过）"
      sleep "${CASE_RETRY_DELAY[$idx]}"
    fi
  done

  end_ts=$(date +%s)
  local duration=$((end_ts - start_ts))
  local attempts_used="$attempt"
  [ "$attempts_used" -gt "$attempts" ] && attempts_used="$attempts"
  local status="FAIL"
  if [ "$case_pass" = "true" ]; then
    if [ -n "$warn_note" ]; then status="WARN"; else status="PASS"; fi
  elif [ "${CASE_OPTIONAL[$idx]}" -eq 1 ]; then
    status="WARN"
  fi
  FINAL_STATUS[$idx]="$status"
  if [ "$status" = "WARN" ] && [ -n "$warn_note" ]; then
    FINAL_REASON[$idx]="$warn_note"
  else
    FINAL_REASON[$idx]="${reason:-${fail_reason:-criteria not met}}"
  fi
  FINAL_PIXEL[$idx]="${PIXEL_OK:-}"
  FINAL_PIXEL_FRAMES[$idx]="${PIXEL_FRAMES:-}"

  append_result_row "${PHASE_NAME}" "${name}" "${pass}" "${status}" \
    "${attempts_used}" "${LAST_RC}" "${LAST_FRAMES}" "${LAST_RECEIVED}" \
    "${LAST_EXPECTED}" "${LAST_CAP_ERRORS}" "${LAST_TRANSPORT}" \
    "${PIXEL_OK:-}" "${PIXEL_FRAMES:-}" "${LAST_SMOKE}" "${BOOT_ID}" \
    "${duration}" "${FINAL_REASON[$idx]}" "$case_ev" \
    "${warn_note}" "${LAST_METRICS}"
  log "case ${name}: ${status}（attempts=${attempts_used}/${attempts}, ${duration}s）"
  [ "$status" = "FAIL" ] && return 1
  return 0
}

# ---------------------------------------------------------------------------
# plan / list / meta / finalize
# ---------------------------------------------------------------------------
usage() {
  awk 'NR > 1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
}

print_plan() {
  local boot_desc total=0 i names="" pixel=""
  if [ "$BOOT_MODE" = "clean" ]; then
    boot_desc="clean boot（board_ctl.py reboot；失败自动 RTS 复位 + 串口拉起 SSH）"
  else
    boot_desc="当前 boot（不 reboot）"
  fi
  printf '=== run_phase.sh 计划（dry-run）===\n'
  printf 'phase:            %s\n' "$PHASE_NAME"
  printf 'description:      %s\n' "${PHASE_DESC:-（无）}"
  printf 'phase file:       %s\n' "$PHASE_FILE"
  printf 'board:            %s\n' "$BOARD"
  printf 'board m2:         %s\n' "$PHASE_BOARD_M2"
  printf 'boot:             %s\n' "$boot_desc"
  printf 'retry after boot: %s 次（失败用例 reboot 后复测；--no-reboot 时禁用）\n' "$PHASE_RETRY_AFTER_REBOOT"
  printf 'evidence:         %s\n' "$EV"
  printf 'board workdir:    %s\n' "$BOARD_WORK"
  printf '\nmodules（按顺序 insmod）：\n'
  if [ "${#MOD_PATHS[@]}" -eq 0 ]; then
    printf '  （none）\n'
  else
    for i in "${!MOD_PATHS[@]}"; do
      printf '  %d. insmod %s' "$((i + 1))" "${MOD_PATHS[$i]}"
      [ -n "${MOD_PARAMS[$i]}" ] && printf ' %s' "${MOD_PARAMS[$i]}"
      printf '\n'
    done
  fi
  printf '\nsha1 期望：\n'
  if [ "${#EXPECT_PATHS[@]}" -eq 0 ]; then
    printf '  （none）\n'
  else
    for i in "${!EXPECT_PATHS[@]}"; do
      printf '  %s  %s\n' "${EXPECT_SHAS[$i]}" "${EXPECT_PATHS[$i]}"
    done
  fi
  printf '\ncases：\n'
  for i in "${!CASE_NAME[@]}"; do
    [ "$OPT_ONLY" != "" ] && ! case_selected "${CASE_NAME[$i]}" && continue
    total=$((total + CASE_TIMEOUT[$i]))
    printf '  [%d] %s\n' "$i" "${CASE_NAME[$i]}"
    printf '      attempts=%s timeout=%ss optional=%s capture=%s\n' \
      "${CASE_ATTEMPTS[$i]}" "${CASE_TIMEOUT[$i]}" \
      "$([ "${CASE_OPTIONAL[$i]}" -eq 1 ] && echo yes || echo no)" \
      "$([ "${CASE_CAPTURE[$i]}" -eq 1 ] && echo yes || echo no)"
    printf '      criteria: %s\n' "${CASE_CRITERIA[$i]}"
    printf '      command:  %s\n' "${CASE_CMD[$i]}"
    if [ "${CASE_CAPTURE[$i]}" -eq 1 ] && [ -n "${CASE_PIXEL_STREAM[$i]}" ]; then
      printf '      pixel:    stream=%s size=%sx%s frames=%s fetch=%s\n' \
        "${CASE_PIXEL_STREAM[$i]}" "${CASE_PIXEL_W[$i]}" \
        "${CASE_PIXEL_H[$i]}" "${CASE_PIXEL_FRAMES[$i]}" "${CASE_FETCH[$i]}"
    fi
    if [ -n "${CASE_WARN_CRITERIA[$i]}" ]; then
      printf '      warn-if:  %s\n' "${CASE_WARN_CRITERIA[$i]}"
    fi
    if [ -n "${CASE_METRICS[$i]}" ]; then
      printf '      metrics:  %s\n' "${CASE_METRICS[$i]//;;/  }"
    fi
    if [ -n "${CASE_FETCH_ARTIFACTS[$i]}" ]; then
      printf '      fetch:    %s\n' "${CASE_FETCH_ARTIFACTS[$i]//;;/  }"
    fi
    if [ -n "${CASE_HOST_CHECK[$i]}" ]; then
      printf '      host-check: %s\n' "${CASE_HOST_CHECK[$i]}"
    fi
  done
  printf '\n最坏情况用例超时合计：约 %s 分钟（不含 reboot/重试/像素比对）\n' "$((total / 60))"
  printf '实际执行时还会生成 SUMMARY.md + results.csv，见 FIX-REPORT.md。\n'
}

list_phases() {
  local f
  for f in "$PHASE_DIR"/*.sh; do
    [ -e "$f" ] || continue
    (
      reset_phase_state
      # shellcheck disable=SC1090
      . "$f" >/dev/null 2>&1 || exit 1
      printf '%-24s %s\n' "${PHASE_NAME:-$(basename "$f" .sh)}" "${PHASE_DESC:-}"
    )
  done
}

write_meta() {
  [ -z "$EV" ] && return 0
  local f="$EV/meta.env"
  {
    printf 'run_id=%s\n' "$RUN_ID"
    printf 'phase=%s\n' "$PHASE_NAME"
    printf 'phase_file=%s\n' "$PHASE_FILE"
    printf 'board=%s\n' "$BOARD"
    printf 'boot_mode=%s\n' "$( [ "$BOOT_MODE" = clean ] && echo clean || echo current)"
    printf 'boot_id=%s\n' "$BOOT_ID"
    printf 'boot_clean=%s\n' "$BOOT_CLEAN"
    printf 'board_m2=%s\n' "$PHASE_BOARD_M2"
    printf 'board_work=%s\n' "$BOARD_WORK"
    printf 'evidence_dir=%s\n' "$EV"
    printf 'host_start=%s\n' "${HOST_START:-?}"
    printf 'host_end=%s\n' "${HOST_END:-?}"
    printf 'duration_s=%s\n' "$DURATION"
    printf 'verdict=%s\n' "$VERDICT"
    printf 'run_phase_sha1=%s\n' "$(sha1sum "$SCRIPT_DIR/run_phase.sh" | cut -d' ' -f1)"
    printf 'board_ctl_sha1=%s\n' "$(sha1sum "$SCRIPT_DIR/board_ctl.py" | cut -d' ' -f1)"
  } > "$f"
}

finalize() {
  [ "$FINALIZED" -eq 1 ] && return 0
  [ -z "$EV" ] && return 0
  FINALIZED=1
  HOST_END=$(date -Is)
  DURATION=$(( $(date +%s) - START_EPOCH ))
  write_meta
  printf '%s\n' "$VERDICT" > "$EV/VERDICT.txt"
  if [ -s "$RESULTS_CSV" ]; then
    local -a report_args=(--results "$RESULTS_CSV" --meta "$EV/meta.env"
                          --out "$EV/SUMMARY.md" --env "$EV/environment.txt")
    [ -n "${ENV2_FILE:-}" ] && report_args+=(--env2 "$ENV2_FILE")
    {
      printf '## report\n'
      python3 "$LIB_DIR/make_report.py" "${report_args[@]}" 2>&1
    } >> "$RUN_LOG" 2>&1 || true
  fi
  log "结论: $VERDICT"
  if [ -f "$EV/SUMMARY.md" ]; then
    log "摘要: $EV/SUMMARY.md"
  fi
  log "证据: $EV/"
  if [ -n "$BOARD_WORK" ]; then
    if [ "$OPT_KEEP_BOARD" -eq 1 ]; then
      log "板上工作目录保留（--keep-board）: $BOARD_WORK"
    else
      # 2026-11-10：无论 PASS/FAIL 都清理板卡工作目录（证据已回传主机；抓帧失败残留会挤爆 94% 的根分区）
      ssh_run "rm -rf '$BOARD_WORK'" >/dev/null 2>&1 || true
      log "已清理板上工作目录: $BOARD_WORK（失败证据在主机 $EV）"
    fi
  fi
  return 0
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) OPT_DRY_RUN=1; shift ;;
    --no-reboot) OPT_NO_REBOOT=1; shift ;;
    --only) OPT_ONLY="${2:-}"; shift 2 ;;
    --list) OPT_LIST=1; shift ;;
    --phase-file) OPT_PHASE_FILE="${2:-}"; shift 2 ;;
    --evidence-dir) OPT_EVIDENCE="${2:-}"; shift 2 ;;
    --keep-board) OPT_KEEP_BOARD=1; shift ;;
    --skip-pixel) OPT_SKIP_PIXEL=1; shift ;;
    --allow-sha1-mismatch) OPT_ALLOW_SHA1_MISMATCH=1; shift ;;
    --verbose) OPT_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) printf 'run_phase.sh: 未知选项 %s\n' "$1" >&2; usage; exit 2 ;;
    *) PHASE_ARG="$1"; shift ;;
  esac
done

if [ "$OPT_LIST" -eq 1 ]; then
  list_phases
  exit 0
fi

if [ -n "$OPT_PHASE_FILE" ]; then
  PHASE_FILE="$OPT_PHASE_FILE"
  case "$PHASE_FILE" in
    /*) ;;
    *) PHASE_FILE="$REPO_ROOT/$PHASE_FILE" ;;
  esac
elif [ -n "$PHASE_ARG" ]; then
  PHASE_FILE="$PHASE_DIR/$PHASE_ARG.sh"
else
  usage
  exit 2
fi
load_phase "$PHASE_FILE"

BOOT_MODE="$PHASE_BOOT"
if [ "$OPT_NO_REBOOT" -eq 1 ]; then
  if [ "$PHASE_BOOT" = "clean" ]; then
    printf 'run_phase.sh: 注意：phase 要求 clean boot，但指定了 --no-reboot（在当前 boot 上跑，结果可能受污染）\n' >&2
  fi
  BOOT_MODE="current"
fi

RUN_ID="${PHASE_NAME}-$(date +%Y%m%d-%H%M%S)"
if [ -n "$OPT_EVIDENCE" ]; then
  case "$OPT_EVIDENCE" in
    /*) EV="$OPT_EVIDENCE" ;;
    *) EV="$REPO_ROOT/$OPT_EVIDENCE" ;;
  esac
else
  local_root="${PHASE_EVIDENCE_ROOT:-$DEFAULT_EVIDENCE_ROOT}"
  case "$local_root" in
    /*) EV="$local_root/$RUN_ID" ;;
    *) EV="$REPO_ROOT/$local_root/$RUN_ID" ;;
  esac
fi
BOARD_WORK="/root/hwtest/auto/$RUN_ID"

if [ "$OPT_DRY_RUN" -eq 1 ]; then
  print_plan
  exit 0
fi

mkdir -p "$EV/cases"
RUN_LOG="$EV/RUN-LOG.txt"
RESULTS_CSV="$EV/results.csv"
ENV_FILE="$EV/environment.txt"
HOST_START=$(date -Is)
START_EPOCH=$(date +%s)
: > "$RUN_LOG"
: > "$RESULTS_CSV"
printf 'phase,case,pass,status,attempts,rc,frames,received,expected,capture_errors,transport_ok,pixel_ok,pixel_frames,smoke_frames,boot_id,duration_s,reason,evidence,warn,metrics\n' > "$RESULTS_CSV"
printf 'run_phase.sh pid=%s argv=%s\n' "$$" "$*" >> "$RUN_LOG"
log "=== phase: $PHASE_NAME ==="
log "run id: $RUN_ID"
log "evidence: $EV"
log "board: $BOARD  boot mode: $BOOT_MODE  board m2: $PHASE_BOARD_M2"
print_plan > "$EV/plan.txt"
write_meta

# 1) boot / ensure ssh
board_boot

# 2) environment + sha1 + modules
collect_environment "$ENV_FILE" "boot 后、模块加载前"
check_sha1_expectations
write_meta
load_modules
collect_environment "$EV/environment-after-load.txt" "模块加载后"
write_meta

# 3) run cases (pass 1)
selected=()
for i in "${!CASE_NAME[@]}"; do
  case_selected "${CASE_NAME[$i]}" && selected+=("$i")
done
if [ "${#selected[@]}" -eq 0 ]; then
  die "--only '$OPT_ONLY' 未匹配任何用例" 2
fi
for i in "${!CASE_NAME[@]}"; do
  FINAL_STATUS[$i]="SKIP"
  FINAL_REASON[$i]="not selected"
done

for i in "${selected[@]}"; do
  run_case "$i" 1 || true
done

# 4) reboot once and re-run failed required cases (既定配方)
failed=()
for i in "${selected[@]}"; do
  [ "${FINAL_STATUS[$i]}" = "FAIL" ] && failed+=("$i")
done
RESTART_ALLOWED=0
if [ "$PHASE_RETRY_AFTER_REBOOT" -gt 0 ] && [ "$OPT_NO_REBOOT" -eq 0 ] && \
   [ "$PHASE_BOOT" = "clean" ]; then
  RESTART_ALLOWED=1
fi
if [ "${#failed[@]}" -gt 0 ] && [ "$RESTART_ALLOWED" -eq 1 ]; then
  log "pass1 有 ${#failed[@]} 个必选用例失败 → 按预案 reboot 1 次后复测失败用例"
  cp "$RESULTS_CSV" "$EV/results-pass1.csv"
  ENV2_FILE="$EV/environment-pass2.txt"
  BOOT_MODE="clean"
  board_boot
  collect_environment "$ENV2_FILE" "reboot 后（pass 2）"
  check_sha1_expectations
  load_modules
  collect_environment "$EV/environment-after-load-pass2.txt" "pass2 模块加载后"
  write_meta
  for i in "${failed[@]}"; do
    run_case "$i" 2 || true
  done
elif [ "${#failed[@]}" -gt 0 ]; then
  warn "有 ${#failed[@]} 个用例失败，但重启复测被禁用（--no-reboot 或 phase_retry_after_reboot=0）"
fi

# 5) verdict
fails=0
warns=0
passes=0
for i in "${selected[@]}"; do
  case "${FINAL_STATUS[$i]}" in
    PASS) passes=$((passes + 1)) ;;
    WARN) warns=$((warns + 1)) ;;
    FAIL) fails=$((fails + 1)) ;;
  esac
done
log "用例统计：PASS=${passes} WARN=${warns} FAIL=${fails}"
if [ "$fails" -gt 0 ]; then VERDICT="FAIL"; else VERDICT="PASS"; fi

finalize
if [ "$VERDICT" = "PASS" ]; then
  exit 0
fi
exit 1
