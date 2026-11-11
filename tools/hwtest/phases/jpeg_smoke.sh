#!/usr/bin/env bash
# =============================================================================
# 阶段定义：jpeg_smoke
#
# 目标：JPEG 硬解"同一 handle 重复解码"稳定性（JPEG-01 修复验收）。
#   clean boot → hi_mmz_shim + hi_jpeg_noext.ko（8f39ceb0）
#   → jpeg_test_jpeg01（d3c64680）同一 handle loops=100（mode 默认为 1）
#   → 判据：rc=0、completed=100/100、per 5–11 ms、decode-only max ≤11 ms
#   → 输出一致性：loops=1 与 loops=100 的 YUV sha1 相同
#
# 注意：JPEG 与 VDEC 模块符号冲突（exports duplicate symbol），必须独立 boot；
#       本阶段 clean boot 且只加载 shim+jpeg。
# 用法：./tools/hwtest/run_phase.sh jpeg_smoke [--dry-run]
# =============================================================================

phase_name jpeg_smoke
phase_desc "JPEG 硬解 loops=100：hi_jpeg_noext(8f39ceb0) + jpeg_test_jpeg01(d3c64680)；判据 rc=0/100帧/5–11ms/YUV一致"
phase_boot clean
phase_board_m2 /root/m2
phase_retry_after_reboot 1

phase_module /root/m2/hi_mmz_shim.ko
phase_module /root/m2/hi_jpeg_noext.ko

phase_expect_sha1 /root/m2/hi_mmz_shim.ko 1ad0d7c7d5e2ba7b9e74d5de50a2277407708a09
phase_expect_sha1 /root/m2/hi_jpeg_noext.ko 8f39ceb0f7b18d7e87b81c2cf44d0e4c2d7c0793
phase_expect_sha1 /root/m2/jpeg_test_jpeg01 d3c64680934bfa5afe133accde7898cc3148c9f0

# 同一输入先跑 loops=1 作为基线，再跑 loops=100 主验收；比较两输出 YUV sha1。
# 工具输出（每轮）：decode: loops=100 total=...ms per=...ms fps=... rc=0
#                   jpeg01: mode=1 completed=100/100 fail_iter=-1 recreated=0
#                   jpeg01: decode-only ok=100 min=..ms avg=..ms max=..ms
phase_case jpeg_loops100 240 \
  "jpeg_rc==0;completed==100;expected_loops==100;per_ms>=5;per_ms<=11;max_ms<=11;fail_iter==-1;sha1_single==sha1_loops" 1 \
  --metric 'jpeg_rc=JPEG_RC2=(-?\d+)' \
  --metric 'per_ms=loops=100 total=[0-9.]+ms per=([0-9.]+)ms' \
  --metric 'completed=completed=(\d+)/\d+' \
  --metric 'expected_loops=completed=\d+/(\d+)' \
  --metric 'max_ms=decode-only ok=100 min=[0-9.]+ms avg=[0-9.]+ms max=([0-9.]+)ms' \
  --metric 'fail_iter=fail_iter=(-?\d+)' \
  --metric 'sha1_single=([0-9a-f]{40})  .*j_m1\.yuv' \
  --metric 'sha1_loops=([0-9a-f]{40})  .*j_m100\.yuv' \
  -- \
  "timeout 60 ./jpeg_test_jpeg01 j1080.jpg {out}/j_m1.yuv 1 > {out}/run1.log 2>&1; echo \"JPEG_RC1=\$?\"; timeout 180 ./jpeg_test_jpeg01 j1080.jpg {out}/j_m100.yuv 100 > {out}/run100.log 2>&1; echo \"JPEG_RC2=\$?\"; echo '--- loops=1 ---'; cat {out}/run1.log; echo '--- loops=100 ---'; cat {out}/run100.log; echo '--- YUV sha1 ---'; sha1sum {out}/j_m1.yuv {out}/j_m100.yuv; grep CmaFree /proc/meminfo"
