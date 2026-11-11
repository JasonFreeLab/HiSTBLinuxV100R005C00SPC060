#!/usr/bin/env bash
# =============================================================================
# 阶段定义：vdec_hevc_smoke（INF-04d）
#
# 目标：HEVC 解码冒烟（1080p Main 20 帧 + 4K60 Main10 8 帧），新验收对：
#   clean boot → hi_mmz_shim + hi_vdec_reloadfix.ko（e8859791）
#   → 校验 vdec_spec_hevc_head（6ada1250）与输入流 sha1
#   → 两个 decode-only 用例（不抓帧）：
#       1) hevc 1080p: ht1080b.hevc / ht.index, 1920x1080, 期望 20/20，format 64/NV21
#       2) hevc 4K60 Main10: 4k60-10b.hevc / 4k10.index, 3840x2160, 期望 8/8，bitwidth=1
#   → 判据：received==expected（及 Main10 的 bitwidth==1）；期望 PASS。
#
# 验收依据（Lead，2026-11-08，已上板；fixes/vdec-01/BOARD-VERIFY-H1.md §3）：
#   head_w1 矩阵 7/7 PASS：HEVC 1080p 20/20、4K60 8bit 20/20、4K60 Main10 8/8、
#   20M/100M 10/10；参数必须含 m2_sync_hevc_msgs=1。
# 注意：该工具 HEVC 路径 rc=1 / transport_ok=false 属既有语义，不作为判据；
#       decode-only 用 VDEC_BUF_MB=8（抓帧才需要 16），不启用 vdec_no_vcmp 抓帧。
#
# 用法：./tools/hwtest/run_phase.sh vdec_hevc_smoke [--dry-run]
# =============================================================================

phase_name vdec_hevc_smoke
phase_desc "VDEC HEVC smoke：1080p Main 20/20 + 4K60 Main10 8/8（新验收对 reloadfix e8859791 + vdec_spec_hevc_head 6ada1250，m2_sync_hevc_msgs=1），期望 PASS"
phase_boot clean
phase_board_m2 /root/m2
phase_retry_after_reboot 1

phase_module /root/m2/hi_mmz_shim.ko
phase_module /root/m2/hi_vdec_reloadfix.ko \
  "m2_sync_downmsg=1 m2_sync_msgs=1 m2_sync_scd=1 m2_sync_hevc_msgs=1 vdec_dfs=1 vdec_sed_only=0 vdec_hdr_meta=0"

phase_expect_sha1 /root/m2/hi_mmz_shim.ko 1ad0d7c7d5e2ba7b9e74d5de50a2277407708a09
phase_expect_sha1 /root/m2/hi_vdec_reloadfix.ko e88597910e2fa7e00972a25bccd3024ef1fac2fa
phase_expect_sha1 /root/m2/vdec_spec_hevc_head 6ada12501cd1225665ebe827db18728d00eb2228
phase_expect_sha1 /root/m2/ht1080b.hevc 38bbbce8f357e11a46cc1e046c476ebbe7ef7965
phase_expect_sha1 /root/m2/4k60-10b.hevc 9a41d9e8dfaa05c767891a3fbcf7b8f84fbea12a

# 1080p Main（ht1080b.hevc，20 帧，format_enum=64 NV21）
phase_case hevc_1080p 120 \
  "received==expected;capture_errors==0" 3 \
  --metric 'format_enum=OUTPUT format_enum=(\d+)' \
  --metric 'bitwidth=bitwidth_enum=(\d+)' \
  --metric 'tool_status=EXIT status=(-?\d+)' \
  -- \
  "VDEC_BUF_MB=8 timeout 90 ./vdec_spec_hevc_head hevc fullhd ht1080b.hevc ht.index 1920 1080 30; echo \"VDEC_RC=\$?\""

# 4K60 Main10（4k60-10b.hevc，8 帧，format_enum=102 tile、bitwidth_enum=1）
phase_case hevc_4k60_main10 210 \
  "received==expected;capture_errors==0;bitwidth==1" 3 \
  --metric 'format_enum=OUTPUT format_enum=(\d+)' \
  --metric 'bitwidth=bitwidth_enum=(\d+)' \
  --metric 'tool_status=EXIT status=(-?\d+)' \
  -- \
  "VDEC_BUF_MB=8 timeout 180 ./vdec_spec_hevc_head hevc 4k 4k60-10b.hevc 4k10.index 3840 2160 60; echo \"VDEC_RC=\$?\""
