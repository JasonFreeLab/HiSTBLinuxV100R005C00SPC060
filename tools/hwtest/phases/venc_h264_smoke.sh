#!/usr/bin/env bash
# =============================================================================
# 阶段定义：venc_h264_smoke
#
# 目标：VENC H.264 编码链路冒烟（VENC-05 首帧 PTS 修复后的验收配方）。
#   clean boot → hi_mmz_shim + hi_venc_venc06b.ko（0d95a512，VENC-06b：PTS0 + 生命周期修复）
#   → encoder_accept10 H.264 High@L4.1 / CBR / 1920x1080@30 / 5.8 Mbps / 90 帧 / --motion
#   → 板上 ffprobe（90 帧、level=41）+ ffmpeg 解码 rc=0
#   → 回传 run.h265 证据；主机侧 venc_check.py 计算 CBR 码率（只记 WARN，VENC-04 未修）
#
# 判据：tool_rc=0、status=PASS、submitted=completed=90、ffprobe 90 帧/level 41、
#       ffmpeg rc=0；码率 5.8 Mbps ±5% 不满足时记 WARN（不判 FAIL）。
#
# 部署说明（2026-11-08 验收模块）：板上文件名 /root/m2/hi_venc_venc06b.ko
#   sha1 0d95a512bff7ccbfc068f61aa99ca50b7e4dd7b8（内部模块名 hi_venc，由 modinfo -F name 解析）。
#   若板上仍是旧名 hi_venc_venc05.ko（eab8d6cd），部署：
#     scp /home/jason/bringup-7.3/port/venc/hi_venc.ko root@192.168.2.10:/root/m2/hi_venc_venc06b.ko
# 用法：./tools/hwtest/run_phase.sh venc_h264_smoke [--dry-run]
# =============================================================================

phase_name venc_h264_smoke
phase_desc "VENC H.264 HP/CBR 90帧冒烟：hi_venc_venc06b(0d95a512,VENC-06b) + encoder_accept10 --motion；内容时间码率偏差只记 WARN"
phase_boot clean
phase_board_m2 /root/m2
phase_retry_after_reboot 1

phase_module /root/m2/hi_mmz_shim.ko
phase_module /root/m2/hi_venc_venc06b.ko

phase_expect_sha1 /root/m2/hi_mmz_shim.ko 1ad0d7c7d5e2ba7b9e74d5de50a2277407708a09
phase_expect_sha1 /root/m2/hi_venc_venc06b.ko 0d95a512bff7ccbfc068f61aa99ca50b7e4dd7b8
phase_expect_sha1 /root/m2/encoder_accept10 a0458c9026e9ac7c748aed01b20fe8ea5fe12f07

# 90 帧、HP/CBR、--motion；码率目标 5800 kbps。
# 工具输出 status=PASS ... bytes=... first_ns=... last_ns=...；随后板上 ffprobe/ffmpeg。
phase_case h264_hp_cbr 240 \
  "tool_rc==0;status==PASS;submitted==90;completed==90;nb_read_frames==90;level==41;ffmpeg_rc==0" 1 \
  --warn-if "bitrate_ok==true" \
  --fetch "run.h265" \
  --host-check 'python3 "$HWTEST_LIB_DIR/venc_check.py" --log "$HWTEST_LOG" --stream "$HWTEST_ARTIFACTS/run.h265" --target-kbps 5800 --tolerance 0.05 --fps 30' \
  --metric 'tool_rc=VENC_TOOL_RC=(\d+)' \
  --metric 'status=status=(\w+)' \
  --metric 'submitted=submitted=(\d+)' \
  --metric 'completed=completed=(\d+)' \
  --metric 'bytes_log=bytes=(\d+)\s+start_ns=' \
  --metric 'nb_read_frames=nb_read_frames=(\d+)' \
  --metric 'level=level=(\d+)' \
  --metric 'ffmpeg_rc=FFMPEG_RC=(\d+)' \
  --metric 'bitrate_kbps=^bitrate_kbps=([0-9.]+)' \
  --metric 'bitrate_ok=^bitrate_ok=(true|false)' \
  -- \
  "VENC_MOTION_PX=8 timeout 180 ./encoder_accept10 --codec H264 --profile HP --rc CBR --width 1920 --height 1080 --fps 30 --bitrate 5800000 --frames 90 --output {out}/run.h265 --motion > {out}/run.log 2>&1; echo \"VENC_TOOL_RC=\$?\"; cat {out}/run.log; ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=codec_name,profile,level,nb_read_frames -of default=nw=1 {out}/run.h265 2>&1; ffmpeg -v error -i {out}/run.h265 -f null - > /dev/null 2>{out}/ffmpeg.log; echo \"FFMPEG_RC=\$?\"; ls -l {out}/run.h265"
