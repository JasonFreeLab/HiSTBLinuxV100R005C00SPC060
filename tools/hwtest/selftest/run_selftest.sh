#!/usr/bin/env bash
# =============================================================================
# run_selftest.sh — 在主机侧自检 tools/hwtest/run_phase.sh（INF-04）
#
# 不接触真板卡、不 scp/insmod/reboot：
#   1) 语法检查（bash -n / python3 -m py_compile；shellcheck 有则跑）
#   2) `run_phase.sh vdec_h264_smoke --dry-run` 计划输出
#   3) 用 selftest/ 下的 mock ssh/scp/board_ctl 完整跑一个阶段：
#      clean boot → insmod → smoke → warmup → 抓帧（0 帧重试）→ reboot 复测 →
#      抓帧回传 → 主机 ffmpeg 参考 → Y sha1 全列表比对 + compare_vdec.py 抽样
#   4) 用 vdec-03 归档的真实数据单独验证像素比对工具（30/30 已知正确）
#
# 用法：./tools/hwtest/selftest/run_selftest.sh [--keep-mock]
# 证据：docs/porting/artifacts/hwtest-2026-11-07/fixes/inf-04/selftest/<timestamp>/
# 退出码：0=全部检查通过；1=有检查失败
# =============================================================================
set -u

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TOOLS_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd -- "$TOOLS_DIR/../.." && pwd)
FIX_DIR="$REPO_ROOT/docs/porting/artifacts/hwtest-2026-11-07/fixes/inf-04"
ARCH="$REPO_ROOT/docs/porting/artifacts/hwtest-2026-11-07/fixes/vdec-03"

KEEP_MOCK=0
[ "${1:-}" = "--keep-mock" ] && KEEP_MOCK=1

TS=$(date +%Y%m%d-%H%M%S)
SELFTEST_DIR="$FIX_DIR/selftest/$TS"
MOCK=$(mktemp -d /tmp/hwtest-mock.XXXXXX)

PASSED=0
FAILED=0
FAIL_NOTES=""

section() { printf '\n== %s ==\n' "$*"; }
pass() { PASSED=$((PASSED + 1)); printf '  [ok]   %s\n' "$*"; }
fail() {
  FAILED=$((FAILED + 1))
  printf '  [FAIL] %s\n' "$*"
  FAIL_NOTES+="- $*"$'\n'
}
check_file() {
  if [ -f "$1" ]; then pass "存在文件 ${1#"$SELFTEST_DIR"/}"; else fail "缺少文件 $1"; fi
}
check_grep() {
  local file="$1" pattern="$2" desc="$3"
  if grep -q -- "$pattern" "$file" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc（未在 ${file#"$SELFTEST_DIR"/} 找到 '$pattern'）"
  fi
}
check_absent() {
  local file="$1" pattern="$2" desc="$3"
  if grep -q -- "$pattern" "$file" 2>/dev/null; then
    fail "$desc（${file#"$SELFTEST_DIR"/} 不应包含 '$pattern'）"
  else
    pass "$desc"
  fi
}
check_eq() {
  local actual="$1" expected="$2" desc="$3"
  if [ "$actual" = "$expected" ]; then pass "$desc"; else fail "$desc（actual='$actual' expected='$expected'）"; fi
}
check_no_file() {
  if [ -e "$1" ]; then fail "不应存在文件 ${1#"$SELFTEST_DIR"/}"; else pass "不存在 ${1#"$SELFTEST_DIR"/}"; fi
}

init_mock() {
  mkdir -p "$MOCK/root/m2" "$MOCK/root/hwtest/auto" "$MOCK/state" \
           "$MOCK/proc/sys/kernel/random" "$MOCK/sys/module"
  printf '12.0 0.0\n' > "$MOCK/proc/uptime"
  printf 'mock-boot-1\n' > "$MOCK/proc/sys/kernel/random/boot_id"
  cat > "$MOCK/proc/meminfo" <<'EOF'
MemTotal:         861184 kB
MemFree:          520000 kB
MemAvailable:     600000 kB
CmaTotal:         262144 kB
CmaFree:          123456 kB
EOF
  : > "$MOCK/state/lsmod"
  : > "$MOCK/state/dmesg"
  printf '1\n' > "$MOCK/state/boot-epoch"
  local f
  for f in hi_mmz_shim.ko hi_vdec_downmsg_r51_final.ko vdec_spec vdec_test \
           gen3_idr.h264 h264-1080p-bp.h264 h264-1080p-bp.index \
           hi_venc_venc05.ko encoder_accept10 \
           hi_jpeg_noext.ko jpeg_test_jpeg01 j1080.jpg \
           hi_png_reload.ko png_test8 t1080.png \
           hi_venc_venc06b.ko \
           hi_vdec_reloadfix.ko vdec_spec_hevc_head \
           ht1080b.hevc ht.index 4k60.hevc 4k60.index 4k60-10b.hevc 4k10.index \
           4k60-s1-2f.hevc 4k60-s1-2f.index; do
    printf 'mock file %s\n' "$f" > "$MOCK/root/m2/$f"
  done
  mkdir -p "$MOCK/root/hwtest/png"
  printf 'mock file 64mp-rgb.png\n' > "$MOCK/root/hwtest/png/64mp-rgb.png"
}

main() {
  mkdir -p "$SELFTEST_DIR"
  init_mock
  export MOCK_ROOT="$MOCK"
  export MOCK_FRAMES="$ARCH/cap-1080p"
  export MOCK_STREAM="$ARCH/cap-1080p/h264-1080p-bp.h264"
  export MOCK_VENC_STREAM="$REPO_ROOT/docs/porting/artifacts/hwtest-2026-11-07/fixes/venc-05/board-verify/h264-HP-CBR.h265"
  export MOCK_PNG_RAW="$REPO_ROOT/docs/porting/artifacts/hwtest-2026-11-07/fixes/png-01/E0/out.raw"
  export MOCK_VENC_HEVC_STREAM="$REPO_ROOT/docs/porting/artifacts/hwtest-2026-11-07/fixes/venc-05/board-verify/hevc-CBR.h265"
  export MOCK_HEVC_4K_PTS0="$REPO_ROOT/docs/porting/artifacts/hwtest-2026-11-07/fixes/vdec-01/capture-local-4k/pts0.nv21"
  export HWTEST_SSH="$SCRIPT_DIR/mock_ssh.sh"
  export HWTEST_SCP="$SCRIPT_DIR/mock_scp.sh"
  export HWTEST_BOARD_CTL="$SCRIPT_DIR/mock_board_ctl.sh"

  printf 'run_phase.sh selftest @ %s\n' "$(date -Is)"
  printf 'tools: %s\nevidence: %s\nmock root: %s\n' "$TOOLS_DIR" "$SELFTEST_DIR" "$MOCK"
  local auto_dir_before
  auto_dir_before=$(find "$REPO_ROOT/docs/porting/artifacts/hwtest-2026-11-07/auto" \
    -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)

  # ---------------------------------------------------------------- 1) syntax
  section "1) 语法/静态检查"
  local script rc
  for script in "$TOOLS_DIR/run_phase.sh" "$TOOLS_DIR"/phases/*.sh \
                "$SCRIPT_DIR"/*.sh; do
    if bash -n "$script" 2>"$SELFTEST_DIR/bash-n-$(basename "$script").log"; then
      pass "bash -n $(basename "$script")"
    else
      fail "bash -n $(basename "$script")"
    fi
  done
  rc=0
  python3 -m py_compile "$TOOLS_DIR"/lib/*.py 2>"$SELFTEST_DIR/py-compile.log" || rc=$?
  check_eq "$rc" "0" "python3 -m py_compile lib/*.py"
  if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -S warning "$TOOLS_DIR/run_phase.sh" > "$SELFTEST_DIR/shellcheck.log" 2>&1; then
      pass "shellcheck run_phase.sh（无 warning）"
    else
      fail "shellcheck run_phase.sh（见 shellcheck.log）"
    fi
  else
    printf '  [skip] shellcheck 未安装\n'
  fi

  # --------------------------------------------------------------- 2) dry-run
  section "2) --dry-run（真阶段）"
  "$TOOLS_DIR/run_phase.sh" vdec_h264_smoke --dry-run \
    > "$SELFTEST_DIR/dry-run-vdec_h264_smoke.txt" 2>&1
  rc=$?
  check_eq "$rc" "0" "dry-run 退出码 0"
  check_grep "$SELFTEST_DIR/dry-run-vdec_h264_smoke.txt" "phase:            vdec_h264_smoke" "dry-run 含阶段名"
  check_grep "$SELFTEST_DIR/dry-run-vdec_h264_smoke.txt" "boot:             clean boot" "dry-run 含 clean boot 计划"
  check_grep "$SELFTEST_DIR/dry-run-vdec_h264_smoke.txt" "h264_1080p_bp_capture" "dry-run 含抓帧用例"
  check_grep "$SELFTEST_DIR/dry-run-vdec_h264_smoke.txt" "pixel:    stream=" "dry-run 含像素比对计划"
  check_grep "$SELFTEST_DIR/dry-run-vdec_h264_smoke.txt" "module" "dry-run 含模块计划"
  local dry_artifacts
  dry_artifacts=$(find "$REPO_ROOT/docs/porting/artifacts/hwtest-2026-11-07/auto" \
    -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  check_eq "$dry_artifacts" "$auto_dir_before" "dry-run 未创建证据目录（auto/ 目录数不变）"

  section "2b) 配置错误路径"
  "$TOOLS_DIR/run_phase.sh" nope_phase > "$SELFTEST_DIR/config-error.log" 2>&1
  local cfg_rc=$?
  check_eq "$cfg_rc" "2" "未知阶段 → 退出码 2"
  check_grep "$SELFTEST_DIR/config-error.log" "阶段定义文件不存在" "未知阶段错误信息明确"
  check_absent "$SELFTEST_DIR/config-error.log" "证据:" "配置错误不生成证据/摘要"

  # ------------------------------------------------- 3) mock end-to-end run
  section "3) mock 板卡端到端跑阶段"
  local phase_ev="$SELFTEST_DIR/phase-run"
  "$TOOLS_DIR/run_phase.sh" --phase-file "$SCRIPT_DIR/selftest-phase.sh" \
    --evidence-dir "$phase_ev" > "$SELFTEST_DIR/phase-run-console.log" 2>&1
  local phase_rc=$?
  check_eq "$phase_rc" "0" "阶段退出码 0（经过 reboot 复测后 PASS）"
  check_file "$phase_ev/SUMMARY.md"
  check_file "$phase_ev/results.csv"
  check_file "$phase_ev/results-pass1.csv"
  check_file "$phase_ev/environment.txt"
  check_file "$phase_ev/environment-pass2.txt"
  check_file "$phase_ev/boot.log"
  check_file "$phase_ev/plan.txt"
  check_file "$phase_ev/RUN-LOG.txt"
  check_file "$phase_ev/VERDICT.txt"
  check_grep "$phase_ev/SUMMARY.md" "PASS" "SUMMARY 结论为 PASS"
  check_grep "$phase_ev/RUN-LOG.txt" "按预案 reboot 1 次后复测失败用例" "RUN-LOG 记录 reboot 复测"
  check_grep "$phase_ev/RUN-LOG.txt" "cap_size=" "RUN-LOG 记录 capture 目录预建（cap_size）"
  check_grep "$phase_ev/environment-after-load.txt" "hi_vdec_downmsg_r51_final" "环境快照记录模块 sha1"
  check_grep "$phase_ev/results.csv" '"capture","1","FAIL"' "pass1 capture 用例记录为 FAIL"
  check_grep "$phase_ev/results.csv" '"capture","2","PASS"' "pass2 capture 用例记录为 PASS"
  check_grep "$phase_ev/results.csv" '"smoke","1","PASS"' "smoke 用例 PASS"
  check_grep "$phase_ev/results.csv" '"true"' "results.csv 记录 pixel_ok=true"
  check_file "$phase_ev/cases/capture/pass-2/pixel/attempt-1/board-y-sha1.txt"
  check_file "$phase_ev/cases/capture/pass-2/pixel/attempt-1/host-ref-y-sha1.txt"
  check_file "$phase_ev/cases/capture/pass-2/pixel/attempt-1/compare.txt"
  check_grep "$phase_ev/cases/capture/pass-2/pixel/attempt-1/pixel-check.txt" "pixel_ok=true" "Y sha1 列表比对通过"
  check_grep "$phase_ev/cases/capture/pass-2/pixel/attempt-1/compare.txt" "y_identical=True" "compare_vdec.py 抽样帧 Y 一致"
  local board_frames
  board_frames=$(wc -l < "$phase_ev/cases/capture/pass-2/pixel/attempt-1/board-y-sha1.txt" 2>/dev/null || echo 0)
  check_eq "$board_frames" "6" "板上抓帧 sha1 列表 = 6 帧"
  local leftover
  leftover=$(find "$MOCK/root/hwtest/auto" -mindepth 1 2>/dev/null | wc -l)
  check_eq "$leftover" "0" "PASS 后清理板上工作目录（mock）"

  # ------------------------------------ 3b) --only / --no-reboot 选项路径
  section "3b) --only / --no-reboot 选项路径"
  local only_ev="$SELFTEST_DIR/phase-run-only-smoke"
  "$TOOLS_DIR/run_phase.sh" --phase-file "$SCRIPT_DIR/selftest-phase.sh" \
    --evidence-dir "$only_ev" --only smoke --no-reboot \
    > "$SELFTEST_DIR/phase-run-only-console.log" 2>&1
  local only_rc=$?
  check_eq "$only_rc" "0" "--only smoke --no-reboot 退出码 0"
  check_grep "$SELFTEST_DIR/phase-run-only-console.log" \
    "指定了 --no-reboot" "--no-reboot 给出污染告警"
  check_grep "$only_ev/results.csv" '"smoke","1","PASS"' "--only 只跑了 smoke"
  check_absent "$only_ev/results.csv" '"capture"' "未选中用例未执行（无 capture 行）"
  check_grep "$only_ev/RUN-LOG.txt" "已加载 → 跳过 insmod" "--no-reboot 复用已加载模块"

  # ------------------------------- 3c) 失败路径（新 mock：0 帧且禁止重启复测）
  section "3c) 失败路径（0 帧 + --no-reboot → 退出码 1）"
  local saved_mock="$MOCK"
  MOCK=$(mktemp -d /tmp/hwtest-mock-fail.XXXXXX)
  export MOCK_ROOT="$MOCK"
  init_mock
  local fail_ev="$SELFTEST_DIR/phase-run-fail"
  "$TOOLS_DIR/run_phase.sh" --phase-file "$SCRIPT_DIR/selftest-phase.sh" \
    --evidence-dir "$fail_ev" --only capture --no-reboot \
    > "$SELFTEST_DIR/phase-run-fail-console.log" 2>&1
  local fail_rc=$?
  check_eq "$fail_rc" "1" "失败用例退出码 1"
  check_grep "$fail_ev/VERDICT.txt" "FAIL" "VERDICT=FAIL"
  check_grep "$fail_ev/SUMMARY.md" "FAIL" "SUMMARY 结论 FAIL"
  check_grep "$fail_ev/RUN-LOG.txt" "重启复测被禁用" "记录重启复测被禁用的告警"
  rm -rf "$MOCK"
  MOCK="$saved_mock"
  export MOCK_ROOT="$MOCK"

  # ------------------------------------------- 4) 像素工具单元验证（真实数据）
  section "4) 像素比对工具单元验证（vdec-03 归档 30 帧真实数据）"
  local unit="$SELFTEST_DIR/pixel-unit"
  mkdir -p "$unit"
  if [ -f "$MOCK_STREAM" ] && [ -f "$ARCH/board-y-sha1.txt" ]; then
    rc=0
    ffmpeg -v error -y -i "$MOCK_STREAM" -f rawvideo -pix_fmt nv21 "$unit/ref.nv21" \
      > "$unit/ffmpeg.log" 2>&1 || rc=$?
    check_eq "$rc" "0" "主机 ffmpeg 生成 NV21 参考"
    if [ "$rc" -eq 0 ]; then
      python3 "$TOOLS_DIR/lib/reference_y_sha1.py" "$unit/ref.nv21" 1920 1080 \
        > "$unit/host-ref-y-sha1.txt" 2> "$unit/reference.log"
      check_eq "$?" "0" "reference_y_sha1.py 输出 30 帧参考 sha1"
      python3 "$TOOLS_DIR/lib/y_sha1_check.py" --board "$ARCH/board-y-sha1.txt" \
        --ref "$unit/host-ref-y-sha1.txt" --json-out "$unit/pixel-check.json" \
        > "$unit/pixel-check.txt" 2>&1
      check_eq "$?" "0" "y_sha1_check.py 归档 board vs host 30/30 一致"
      check_grep "$unit/pixel-check.txt" "pixel_frames=30" "归档数据比对帧数=30"
      python3 "$TOOLS_DIR/lib/compare_vdec.py" \
        "$ARCH/cap-1080p/frame-0000-pts-0-w1920-h1080.nv21" \
        "$unit/ref.nv21" 1920 1080 0 > "$unit/compare-frame0.txt" 2>&1
      check_grep "$unit/compare-frame0.txt" "y_identical=True" "compare_vdec.py 归档 frame0 Y 一致"
    fi
    rm -f "$unit/ref.nv21"
  else
    fail "缺少像素单元验证输入（$MOCK_STREAM 或 $ARCH/board-y-sha1.txt）"
  fi

  # ------------------------- 5) 新增阶段 VENC/JPEG/PNG（dry-run + mock 全流程）
  section "5) 新增阶段 dry-run + mock 端到端（VENC/JPEG/PNG）"
  local np_phase np_ev
  for np_phase in venc_h264_smoke jpeg_smoke png_hist; do
    "$TOOLS_DIR/run_phase.sh" "$np_phase" --dry-run \
      > "$SELFTEST_DIR/dry-run-$np_phase.txt" 2>&1
    check_eq "$?" "0" "dry-run $np_phase 退出码 0"
  done
  check_grep "$SELFTEST_DIR/dry-run-venc_h264_smoke.txt" "hi_venc_venc06b.ko" "VENC dry-run 含模块（0d95a512）"
  check_grep "$SELFTEST_DIR/dry-run-venc_h264_smoke.txt" "h264_hp_cbr" "VENC dry-run 含用例"
  check_grep "$SELFTEST_DIR/dry-run-venc_h264_smoke.txt" "warn-if:  bitrate_ok==true" "VENC dry-run 含码率 WARN 判据"
  check_grep "$SELFTEST_DIR/dry-run-jpeg_smoke.txt" "jpeg_loops100" "JPEG dry-run 含用例"
  check_grep "$SELFTEST_DIR/dry-run-jpeg_smoke.txt" "completed==100" "JPEG dry-run 含 100 帧判据"
  check_grep "$SELFTEST_DIR/dry-run-png_hist.txt" "png_head" "PNG dry-run 含用例"
  check_grep "$SELFTEST_DIR/dry-run-png_hist.txt" "head6==7e00fd" "PNG dry-run 含 head 判据"
  check_grep "$SELFTEST_DIR/dry-run-png_hist.txt" "host-check:" "PNG dry-run 含 host-check"
  local np_auto_after
  np_auto_after=$(find "$REPO_ROOT/docs/porting/artifacts/hwtest-2026-11-07/auto" \
    -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  check_eq "$np_auto_after" "$auto_dir_before" "新阶段 dry-run 未创建证据目录"

  # 5b) mock 端到端跑真实阶段文件（--allow-sha1-mismatch：mock 文件 sha1 必然不符）
  np_ev="$SELFTEST_DIR/phase-venc-mock"
  "$TOOLS_DIR/run_phase.sh" venc_h264_smoke --allow-sha1-mismatch \
    --evidence-dir "$np_ev" > "$SELFTEST_DIR/phase-venc-console.log" 2>&1
  check_eq "$?" "0" "venc_h264_smoke mock 退出码 0"
  check_grep "$np_ev/results.csv" '"h264_hp_cbr","1","PASS"' "VENC 用例状态 PASS（内容时间码率 5790kbps/−0.2%）"
  check_grep "$np_ev/results.csv" "bitrate_kbps=579" "VENC 记录内容时间码率指标"
  check_grep "$np_ev/VERDICT.txt" "PASS" "VENC 阶段 VERDICT=PASS"
  check_grep "$np_ev/cases/h264_hp_cbr/pass-1/attempt-1.log" "HOST_CHECK_RC=0" "VENC host-check 执行成功"
  check_file "$np_ev/cases/h264_hp_cbr/pass-1/artifacts/run.h265"

  np_ev="$SELFTEST_DIR/phase-jpeg-mock"
  "$TOOLS_DIR/run_phase.sh" jpeg_smoke --allow-sha1-mismatch \
    --evidence-dir "$np_ev" > "$SELFTEST_DIR/phase-jpeg-console.log" 2>&1
  check_eq "$?" "0" "jpeg_smoke mock 退出码 0"
  check_grep "$np_ev/results.csv" '"jpeg_loops100","1","PASS"' "JPEG 用例状态 PASS"
  check_grep "$np_ev/RUN-LOG.txt" "completed=100" "JPEG 记录 completed=100 指标"
  check_grep "$np_ev/results.csv" "sha1_single=" "JPEG 记录 YUV sha1 指标"
  check_grep "$np_ev/results.csv" "sha1_loops=" "JPEG 记录 loops=100 YUV sha1 指标"

  np_ev="$SELFTEST_DIR/phase-png-mock"
  "$TOOLS_DIR/run_phase.sh" png_hist --allow-sha1-mismatch \
    --evidence-dir "$np_ev" > "$SELFTEST_DIR/phase-png-console.log" 2>&1
  check_eq "$?" "0" "png_hist mock 退出码 0"
  check_grep "$np_ev/results.csv" '"png_head","1","PASS"' "PNG 用例状态 PASS"
  check_file "$np_ev/cases/png_head/pass-1/artifacts/out.raw"
  check_grep "$np_ev/cases/png_head/pass-1/attempt-1.log" "VERDICT=HEAD_OK" "PNG host-check 判定 HEAD_OK"
  check_grep "$np_ev/cases/png_head/pass-1/attempt-1.log" "GOODROWS=15" "PNG 记录 goodrows=15"
  check_grep "$np_ev/RUN-LOG.txt" "head6=7e00fd" "PNG 记录 head6 指标"

  # 5d) --warn-if 单元验证（不需要板卡：构造 bitrate_ok=false 日志）
  local warn_dir="$SELFTEST_DIR/warn-unit"
  mkdir -p "$warn_dir"
  printf 'status=PASS submitted=90\nbitrate_ok=false\n' > "$warn_dir/case.log"
  python3 "$TOOLS_DIR/lib/parse_case.py" --log "$warn_dir/case.log" \
    --criteria "status==PASS" --warn-criteria "bitrate_ok==true" \
    --metric 'status=status=(\w+)' \
    --metric 'bitrate_ok=bitrate_ok=(true|false)' \
    --json-out "$warn_dir/parsed.json" > "$warn_dir/parse.txt" 2>&1
  check_eq "$?" "0" "parse_case --warn-criteria 主判据通过仍返回 0"
  check_grep "$warn_dir/parsed.env" "^WARN=true" "parse_case 正确标记 WARN=true"
  check_grep "$warn_dir/parsed.env" "^PASS=true" "parse_case 主判据 PASS=true"

  # 5c) dry-run 输出归档到 fixes/inf-04（供 PHASES.md 引用）
  cp "$SELFTEST_DIR"/dry-run-venc_h264_smoke.txt "$FIX_DIR/dry-run-venc_h264_smoke.txt" 2>/dev/null || true
  cp "$SELFTEST_DIR"/dry-run-jpeg_smoke.txt "$FIX_DIR/dry-run-jpeg_smoke.txt" 2>/dev/null || true
  cp "$SELFTEST_DIR"/dry-run-png_hist.txt "$FIX_DIR/dry-run-png_hist.txt" 2>/dev/null || true

  # ------------------------- 6) INF-04d 新阶段/更新阶段（HEVC 新验收对 + VENC 0d95a512）
  section "6) INF-04d 新阶段 dry-run + mock 端到端（HEVC 4K / HEVC smoke / VENC 0d95a512）"
  local c_phase c_ev
  for c_phase in vdec_hevc_4k vdec_hevc_smoke venc_h264_smoke venc_hevc_smoke; do
    "$TOOLS_DIR/run_phase.sh" "$c_phase" --dry-run \
      > "$SELFTEST_DIR/dry-run-$c_phase.txt" 2>&1
    check_eq "$?" "0" "dry-run $c_phase 退出码 0"
  done
  # VENC 两阶段：模块 sha1 统一为 0d95a512 / hi_venc_venc06b.ko
  check_grep "$SELFTEST_DIR/dry-run-venc_h264_smoke.txt" "hi_venc_venc06b.ko" "VENC-H264 dry-run 含新模块名"
  check_grep "$SELFTEST_DIR/dry-run-venc_h264_smoke.txt" "0d95a512bff7ccbfc068f61aa99ca50b7e4dd7b8" "VENC-H264 dry-run 含模块 sha1 0d95a512"
  check_grep "$SELFTEST_DIR/dry-run-venc_hevc_smoke.txt" "0d95a512bff7ccbfc068f61aa99ca50b7e4dd7b8" "VENC-HEVC dry-run 含模块 sha1 0d95a512"
  check_grep "$SELFTEST_DIR/dry-run-venc_hevc_smoke.txt" "level==120" "VENC-HEVC dry-run 含 level=120 判据"
  # VDEC HEVC 新验收对
  check_grep "$SELFTEST_DIR/dry-run-vdec_hevc_4k.txt" "hi_vdec_reloadfix.ko" "HEVC-4K dry-run 含 reloadfix 模块"
  check_grep "$SELFTEST_DIR/dry-run-vdec_hevc_4k.txt" "e88597910e2fa7e00972a25bccd3024ef1fac2fa" "HEVC-4K dry-run 含模块 sha1 e8859791"
  check_grep "$SELFTEST_DIR/dry-run-vdec_hevc_4k.txt" "m2_sync_hevc_msgs=1" "HEVC-4K dry-run 含 hevc sync 参数"
  check_grep "$SELFTEST_DIR/dry-run-vdec_hevc_4k.txt" "hevc_4k60_capture2" "HEVC-4K dry-run 含 4K60 抓帧用例"
  check_grep "$SELFTEST_DIR/dry-run-vdec_hevc_4k.txt" "cap_files==expected" "HEVC-4K dry-run 含抓帧数判据"
  check_grep "$SELFTEST_DIR/dry-run-vdec_hevc_smoke.txt" "hevc_1080p" "HEVC-smoke dry-run 含 1080p 用例"
  check_grep "$SELFTEST_DIR/dry-run-vdec_hevc_smoke.txt" "hevc_4k60_main10" "HEVC-smoke dry-run 含 Main10 用例"
  check_grep "$SELFTEST_DIR/dry-run-vdec_hevc_smoke.txt" "bitwidth==1" "HEVC-smoke dry-run 含 10-bit 判据"
  local c_auto_after
  c_auto_after=$(find "$REPO_ROOT/docs/porting/artifacts/hwtest-2026-11-07/auto" \
    -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  check_eq "$c_auto_after" "$auto_dir_before" "INF-04d dry-run 未创建证据目录"

  # 6b) mock 端到端
  c_ev="$SELFTEST_DIR/phase-hevc-venc-mock"
  "$TOOLS_DIR/run_phase.sh" venc_hevc_smoke --allow-sha1-mismatch \
    --evidence-dir "$c_ev" > "$SELFTEST_DIR/phase-hevc-venc-console.log" 2>&1
  check_eq "$?" "0" "venc_hevc_smoke mock 退出码 0"
  check_grep "$c_ev/results.csv" '"hevc_cbr","1","PASS"' "VENC-HEVC 用例 PASS（内容码率 5556kbps/−4.2%）"
  check_grep "$c_ev/results.csv" "level=120" "VENC-HEVC 记录 level=120 指标"
  check_grep "$c_ev/results.csv" "bitrate_kbps=555" "VENC-HEVC 记录内容时间码率"
  check_file "$c_ev/cases/hevc_cbr/pass-1/artifacts/run.h265"
  check_grep "$c_ev/cases/hevc_cbr/pass-1/attempt-1.log" "HOST_CHECK_RC=0" "VENC-HEVC host-check 执行成功"

  c_ev="$SELFTEST_DIR/phase-png-sw64mp-mock"
  "$TOOLS_DIR/run_phase.sh" png_sw64mp --allow-sha1-mismatch \
    --evidence-dir "$c_ev" > "$SELFTEST_DIR/phase-png-sw64mp-console.log" 2>&1
  check_eq "$?" "0" "png_sw64mp mock 退出码 0"
  check_grep "$c_ev/results.csv" '"png_sw_64mp","1","PASS"' "PNG-SW 用例 PASS"
  check_grep "$c_ev/results.csv" "out_md5=10d99dcafdc837842f91cbfc19ac0f92" "PNG-SW 记录输出 md5"
  check_grep "$c_ev/results.csv" "ref_md5=10d99dcafdc837842f91cbfc19ac0f92" "PNG-SW host-check 参考 md5 与输出一致"
  check_grep "$c_ev/results.csv" "out_bytes=192000000" "PNG-SW 记录 192MB 输出"

  c_ev="$SELFTEST_DIR/phase-vdec-hevc-4k-mock"
  "$TOOLS_DIR/run_phase.sh" vdec_hevc_4k --allow-sha1-mismatch \
    --evidence-dir "$c_ev" > "$SELFTEST_DIR/phase-vdec-hevc-4k-console.log" 2>&1
  check_eq "$?" "0" "vdec_hevc_4k mock 退出码 0（期望 PASS）"
  check_grep "$c_ev/results.csv" '"hevc_4k60_capture2","1","PASS"' "HEVC-4K 抓帧用例 PASS（20/20）"
  check_grep "$c_ev/results.csv" '"true","1（抽样 compare_vdec.py 1/1 帧 Y 一致）"' "HEVC-4K 记录像素 Y 一致"
  check_grep "$c_ev/results.csv" "cap_files=20" "HEVC-4K 记录 cap_files=20"
  check_grep "$c_ev/results.csv" "format_enum=99" "HEVC-4K 记录 format_enum=99（4K de-tile）"
  check_file "$c_ev/cases/hevc_4k60_capture2/pass-1/pixel/attempt-1/compare.txt"
  check_grep "$c_ev/cases/hevc_4k60_capture2/pass-1/pixel/attempt-1/compare.txt" "y_identical=True" "HEVC-4K host-check compare_vdec 通过"
  check_grep "$c_ev/cases/hevc_4k60_capture2/pass-1/pixel/attempt-1/compare.txt" "y_max_diff=0" "HEVC-4K 像素 diff 为 0"

  c_ev="$SELFTEST_DIR/phase-vdec-hevc-smoke-mock"
  "$TOOLS_DIR/run_phase.sh" vdec_hevc_smoke --allow-sha1-mismatch \
    --evidence-dir "$c_ev" > "$SELFTEST_DIR/phase-vdec-hevc-smoke-console.log" 2>&1
  check_eq "$?" "0" "vdec_hevc_smoke mock 退出码 0"
  check_grep "$c_ev/results.csv" '"hevc_1080p","1","PASS"' "HEVC-smoke 1080p PASS（20/20）"
  check_grep "$c_ev/results.csv" '"hevc_4k60_main10","1","PASS"' "HEVC-smoke Main10 4K PASS（8/8）"
  check_grep "$c_ev/results.csv" "bitwidth=1" "HEVC-smoke 记录 10-bit 指标"
  check_grep "$c_ev/results.csv" "format_enum=64" "HEVC-smoke 1080p format 64 指标"

  # 6c) dry-run 归档
  cp "$SELFTEST_DIR"/dry-run-vdec_hevc_4k.txt "$FIX_DIR/dry-run-vdec_hevc_4k.txt" 2>/dev/null || true
  cp "$SELFTEST_DIR"/dry-run-vdec_hevc_smoke.txt "$FIX_DIR/dry-run-vdec_hevc_smoke.txt" 2>/dev/null || true
  cp "$SELFTEST_DIR"/dry-run-venc_hevc_smoke.txt "$FIX_DIR/dry-run-venc_hevc_smoke.txt" 2>/dev/null || true
  cp "$SELFTEST_DIR"/dry-run-png_sw64mp.txt "$FIX_DIR/dry-run-png_sw64mp.txt" 2>/dev/null || true
  rm -f "$FIX_DIR/dry-run-vdec_4k_noVcmp.txt"

  # ------------------------------------------------------------------ 汇总
  section "汇总"
  {
    printf 'run_phase.sh selftest\n'
    printf 'timestamp: %s\n' "$(date -Is)"
    printf 'evidence: %s\n' "$SELFTEST_DIR"
    printf 'mock_root: %s\n' "$MOCK"
    printf 'checks_passed: %s\n' "$PASSED"
    printf 'checks_failed: %s\n' "$FAILED"
    printf 'verdict: %s\n' "$( [ "$FAILED" -eq 0 ] && echo PASS || echo FAIL)"
    if [ "$FAILED" -gt 0 ]; then
      printf 'failures:\n%s' "$FAIL_NOTES"
    fi
  } > "$SELFTEST_DIR/RESULT.txt"
  cp "$SELFTEST_DIR/RESULT.txt" "$FIX_DIR/selftest/LATEST-RESULT.txt"
  cp "$SELFTEST_DIR/dry-run-vdec_h264_smoke.txt" "$FIX_DIR/dry-run-vdec_h264_smoke.txt" 2>/dev/null || true
  cat "$SELFTEST_DIR/RESULT.txt"
  printf '\n证据目录: %s\n' "$SELFTEST_DIR"

  if [ "$KEEP_MOCK" -eq 1 ] || [ "$FAILED" -gt 0 ]; then
    printf 'mock root 保留: %s\n' "$MOCK"
  else
    rm -rf "$MOCK"
  fi
  rm -rf "$TOOLS_DIR/lib/__pycache__"

  [ "$FAILED" -eq 0 ] && return 0
  return 1
}

main "$@"
