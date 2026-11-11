#!/usr/bin/env bash
# =============================================================================
# 阶段定义：vdec_h264_smoke
#
# 目标：验证 VDEC H.264 硬解链路 + 抓帧/像素验证能力（VDEC-03 配方固化）。
#   1) clean boot（不加载任何编解码模块）
#   2) insmod hi_mmz_shim → hi_vdec_downmsg_r51_final（m2_sync_* 全开）
#   3) vdec_test gen3_idr.h264 all —— 640×360 历史稳定 smoke（帧数判据）
#   4) vdec_spec 1080p BP 预热（optional，不判失败）
#   5) vdec_spec 1080p BP 抓帧（预建 capture 目录；0 帧重试 3 次）
#      → 主机 ffmpeg 解参考 → Y 平面 sha1 逐帧比对 + compare_vdec.py 抽样统计
#
# 模块对说明（2026-11-08 新验收对）：hi_vdec_reloadfix.ko(e8859791)+vdec_spec_hevc_head(6ada1250)
#   同样支持 H.264 控制用例（1080p BP 30/30、4K baseline 20/20，已上板验证）；本阶段保留
#   downmsg_r51_final(d4337a64)+vdec_spec(25abbfdf) 这条已端到端 PASS 的 1080p 抓帧路径。
#   如需切到新验收对：把本文件的模块/工具 sha1 换成 e8859791/6ada1250，并相应调整 vdec_spec 参数。
# 用法：./tools/hwtest/run_phase.sh vdec_h264_smoke
#      ./tools/hwtest/run_phase.sh vdec_h264_smoke --dry-run
#      ./tools/hwtest/run_phase.sh vdec_h264_smoke --no-reboot   # 当前 boot 快检
# =============================================================================

phase_name vdec_h264_smoke
phase_desc "VDEC H.264 smoke：clean boot → shim+downmsg 模块 → vdec_test smoke → 1080p BP 抓帧 → Y sha1 像素比对"
phase_boot clean
phase_board_m2 /root/m2
phase_retry_after_reboot 1

# ---- 模块加载顺序与参数（hi_mmz_shim 必须先于 hi_vdec） ---------------------
phase_module /root/m2/hi_mmz_shim.ko
phase_module /root/m2/hi_vdec_reloadfix.ko \
  "m2_sync_downmsg=1 m2_sync_msgs=1 m2_sync_scd=1 m2_sync_hevc_msgs=1 vdec_dfs=1 vdec_sed_only=0 vdec_hdr_meta=0"

# ---- 工具/模块/输入流 sha1 期望（配对：模块 e8859791 reloadfix + 工具 25abbfdf；2026-11-09 切到当前验收模块） --
phase_expect_sha1 /root/m2/hi_mmz_shim.ko 1ad0d7c7d5e2
phase_expect_sha1 /root/m2/hi_vdec_reloadfix.ko e88597910e2f
phase_expect_sha1 /root/m2/vdec_spec 25abbfdf860d
phase_expect_sha1 /root/m2/vdec_test 0bdf305a75f7
phase_expect_sha1 /root/m2/gen3_idr.h264 9287998f482d
phase_expect_sha1 /root/m2/h264-1080p-bp.h264 8110aa2d80ab

# ---- 用例 1：640×360 vdec_test smoke（历史稳定基线，期望 frames≈49–50/50） --
phase_case smoke 60 "rc==0;smoke_frames>=45" 2 -- \
  "STARTDELAY=1500 timeout 25 stdbuf -o0 ./vdec_test gen3_idr.h264 all"

# ---- 用例 2：1080p BP 预热（optional：只要求硬件有交付，不判整体失败） ------
phase_case h264_1080p_bp_warmup 70 "received>=1" 1 --optional -- \
  "VDEC_BUF_MB=8 timeout 40 stdbuf -o0 ./vdec_spec h264 fullhd h264-1080p-bp.h264 h264-1080p-bp.index 1920 1080 20"

# ---- 用例 3：1080p BP 抓帧 + 逐帧 Y sha1 比对 -------------------------------
# capture 目录由编排器在每次 attempt 前 rm -rf + mkdir -p（vdec_spec 不创建目录），
# 0 帧/抓帧失败重试 3 次；仍失败则整体 reboot 一次后复测（phase_retry_after_reboot 1）。
phase_case h264_1080p_bp_capture 100 \
  "received==expected;capture_errors==0;transport_ok==true;frames==expected" 3 \
  --capture \
  --pixel-stream docs/porting/artifacts/hwtest-2026-11-07/fixes/vdec-03/cap-1080p/h264-1080p-bp.h264 \
  --pixel-size 1920x1080 --pixel-frames all --fetch-frames 3 --retry-delay 5 -- \
  "VDEC_BUF_MB=8 timeout 60 stdbuf -o0 ./vdec_spec h264 fullhd h264-1080p-bp.h264 h264-1080p-bp.index 1920 1080 20 {capture}"
