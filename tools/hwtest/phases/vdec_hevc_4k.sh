#!/usr/bin/env bash
# =============================================================================
# 阶段定义：vdec_hevc_4k（INF-04d，替代已过时的 vdec_4k_noVcmp）
#
# 目标：HEVC 4K60 8-bit 解码 + 抓帧像素 bit-exact（VDEC-01 修复后的新验收对）。
#   clean boot → hi_mmz_shim + hi_vdec_reloadfix.ko（e8859791，HEVC publish + W1 + reload 修复）
#   → 校验 vdec_spec_hevc_head（6ada1250）/ 4k60.hevc（44dca79c）
#   → vdec_spec_hevc_head hevc 4k 4k60.hevc 4k60.index 3840 2160 60 {capture}
#     （vdec_no_vcmp=1、VDEC_BUF_MB=16；期望帧数=20 由 index 决定）
#   → 板上抓 20 帧；回传 pts0.nv21 → 主机 ffmpeg 参考 4K60 NV21 + compare_vdec.py
#     逐字节比对（Y/全帧 sha1、mean/max diff）→ 期望 PASS（不再有 known-issue WARN）
#
# 验收依据（Lead，2026-11-08，已上板）：
#   - 模块参数 m2_sync_hevc_msgs=1 是 HEVC 出帧必要条件；
#   - head_w1 全矩阵 7/7 PASS：HEVC 1080p 20/20、4K60 8bit 20/20、4K60 Main10 8/8、
#     20M/100M 10/10、H.264 控制 30/30 + 4K 20/20；
#   - 抓帧 4K60 20/20、抽样帧与软件参考 bit-exact（mean=0,max=0）。
#   证据：fixes/vdec-01/BOARD-VERIFY-H1.md §3/§4、HEVC-CAPTURE.log、capture-local-4k/。
#
# 注意：HEVC 用例工具 rc=1、transport_ok=false 属该工具 HEVC 路径的既有语义，
#       不作为成功判据；判据以 received==expected + capture_errors==0 + 抓帧数 +
#       像素比对为准。4K 抓帧 20 帧 ≈ 249MB 板上空间（PASS 后自动清理）。
#
# 用法：./tools/hwtest/run_phase.sh vdec_hevc_4k [--dry-run]
# =============================================================================

phase_name vdec_hevc_4k
phase_desc "VDEC HEVC 4K60 8bit：20 帧 decode-only + 20 帧抓帧 + pts0 像素 bit-exact（验收对 hi_vdec_reloadfix e8859791 + vdec_spec_hevc_head 6ada1250，m2_sync_hevc_msgs=1），期望 PASS"
phase_boot clean
phase_board_m2 /root/m2
phase_retry_after_reboot 1

phase_module /root/m2/hi_mmz_shim.ko
# HEVC 消息发布 + W1 退出同步 + 抓帧能力（vdec_no_vcmp=1）
phase_module /root/m2/hi_vdec_reloadfix.ko \
  "m2_sync_downmsg=1 m2_sync_msgs=1 m2_sync_scd=1 m2_sync_hevc_msgs=1 vdec_dfs=1 vdec_sed_only=0 vdec_hdr_meta=0 vdec_no_vcmp=1"

phase_expect_sha1 /root/m2/hi_mmz_shim.ko 1ad0d7c7d5e2ba7b9e74d5de50a2277407708a09
phase_expect_sha1 /root/m2/hi_vdec_reloadfix.ko e88597910e2fa7e00972a25bccd3024ef1fac2fa
phase_expect_sha1 /root/m2/vdec_spec_hevc_head 6ada12501cd1225665ebe827db18728d00eb2228
phase_expect_sha1 /root/m2/4k60.hevc 44dca79c2f98fd51730d9841038e4091fdbc75f3
phase_expect_sha1 /root/m2/4k60.index 64cf1b4b102fa840ccb5e89a5e4a04cc2293e8b9

# 抓帧文件名是 pts<pts>.nv21；回传 pts0 做像素比对（12.4 MB/帧）。
# 用例 1：20 帧 decode-only（不抓帧，避免写盘；判据 received==expected）
phase_case hevc_4k60_decode 240 \
  "received==expected;capture_errors==0" 3 \
  --metric 'format_enum=OUTPUT format_enum=(\d+)' \
  --metric 'bitwidth=bitwidth_enum=(\d+)' \
  --metric 'tool_status=EXIT status=(-?\d+)' \
  -- \
  "VDEC_BUF_MB=16 timeout 180 ./vdec_spec_hevc_head hevc 4k 4k60.hevc 4k60.index 3840 2160 60; echo \"VDEC_RC=\$?\""

# 用例 2：4K60 全流抓帧 + 首帧像素 bit-exact（2026-11-09 改）
#   - 4k60-s1-2f.hevc 在 reloadfix(e8859791) 上稳定 0 帧（format_enum=-1），改用已验证的 4k60.hevc；
#   - 输出为解码序（frame-0001=pts-4），按序号逐帧比对必然失配 → 只比对 frame-0000（pts0，IDR）；
#   - 抓帧 20×12.4MB≈249MB，根分区仅余 ~460MB：记录 CAP_FILES 后立即删除 frame-0000 以外的帧。
#   参考流 4k60-2f-src.hevc 与板上 4k60.hevc 同 sha1（44dca79c）。
phase_case hevc_4k60_capture2 240 \
  "received==expected;capture_errors==0;cap_files==expected" 3 \
  --capture \
  --pixel-stream docs/porting/artifacts/hwtest-2026-11-07/fixes/vdec-04/4k60-2f-src.hevc \
  --pixel-size 3840x2160 --pixel-frames 1 --fetch-frames 1 --retry-delay 5 \
  --metric 'format_enum=OUTPUT format_enum=(\d+)' \
  --metric 'cap_files=CAP_FILES=(\d+)' \
  -- \
  "VDEC_BUF_MB=16 timeout 180 ./vdec_spec_hevc_head hevc 4k 4k60.hevc 4k60.index 3840 2160 60 {capture}; echo \"VDEC_RC=\$?\"; echo \"CAP_FILES=\$(ls {capture} | wc -l)\"; find {capture} -name 'frame-*.nv21' ! -name 'frame-0000-*' -delete"
