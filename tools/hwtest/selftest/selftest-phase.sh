#!/usr/bin/env bash
# 自检用阶段定义 —— 只配 selftest/ 下的 mock 板卡使用，不要用于真板。
#   boot(clean) → insmod(2) → smoke → warmup(optional) → 抓帧用例：
#     第 1 个 boot 上两次 attempt 都"0 帧"失败 → 编排器 reboot 1 次后复测成功 →
#     抓帧回传 + 主机 ffmpeg 参考 + Y sha1 比对（用 vdec-03 归档的真实帧）。
# 依赖 runner 导出的环境变量：MOCK_STREAM（真实参考码流路径）。

phase_name selftest_mock
phase_desc "主机侧编排自检（mock 板卡）：boot→insmod→0帧重试→reboot复测→抓帧→像素比对"
phase_boot clean
phase_board_m2 /root/m2
phase_retry_after_reboot 1

phase_module /root/m2/hi_mmz_shim.ko
phase_module /root/m2/hi_vdec_downmsg_r51_final.ko "m2_sync_downmsg=1"

# 用例 1：vdec_test smoke（mock 返回 frames=49）
phase_case smoke 30 "rc==0;smoke_frames>=45" 1 -- \
  "STARTDELAY=1500 timeout 25 stdbuf -o0 ./vdec_test gen3_idr.h264 all"

# 用例 2：预热（optional，mock 返回 received=3 → 通过）
phase_case warmup 40 "received>=1" 1 --optional -- \
  "VDEC_BUF_MB=8 timeout 40 stdbuf -o0 ./vdec_spec h264 fullhd h264-1080p-bp.h264 h264-1080p-bp.index 1920 1080 20"

# 用例 3：抓帧（mock 只在 boot epoch>=3 时成功 → 强制走"reboot 后复测"路径）
phase_case capture 50 \
  "received==expected;capture_errors==0;transport_ok==true;frames==expected" 2 \
  --capture \
  --pixel-stream "${MOCK_STREAM:-}" \
  --pixel-size 1920x1080 --pixel-frames 6 --fetch-frames 3 --retry-delay 1 -- \
  "VDEC_BUF_MB=8 timeout 40 stdbuf -o0 ./vdec_spec h264 fullhd h264-1080p-bp.h264 h264-1080p-bp.index 1920 1080 20 {capture}"
