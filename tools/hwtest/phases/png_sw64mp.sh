#!/usr/bin/env bash
# =============================================================================
# 阶段定义：png_sw64mp
#
# 目标：PNG 软件兜底路径（PNG-02/PNG-04）——板上 ffmpeg 软件解码 8000×8000 PNG。
#   clean boot（不加载 png 硬件模块）→ 板上系统 ffmpeg 解码：
#     /root/hwtest/png/64mp-rgb.png  →  /tmp/inf04c_64mp.rgb (RGB24, 192,000,000 B)
#   → 板上 md5sum 输出；主机 --host-check 用 host 样本流式解码到 md5 作为独立参考
#   → 判据：ffmpeg rc=0、输出 md5 与主机参考一致、输出字节数=192000000
#   → 耗时（decode 段）记录；>20 s 只记 WARN（PNG-04 板上实测 11.08 s）
#
# 说明：64MP 解码需 192 MB 输出（板上 /tmp 为 tmpfs，png-04 实测可用；结束即删）；
#       属软件兜底，不加载 hi_png* 模块，也不要求 head/整幅硬件输出。
#
# 用法：./tools/hwtest/run_phase.sh png_sw64mp [--dry-run]
# =============================================================================

phase_name png_sw64mp
phase_desc "PNG 软件兜底 64MP：板上 ffmpeg 解码 8000x8000 rgb24（192MB）→ md5 与主机参考一致，耗时>20s 只记 WARN"
phase_boot clean
phase_board_m2 /root/m2
phase_retry_after_reboot 1

# 无内核模块：纯用户态软件路径（板上 /usr/bin/ffmpeg、md5sum）。
# 输入样本由 PNG-02 生成并部署到 /root/hwtest/png/（PNG-04 实测配方）。
phase_expect_sha1 /root/hwtest/png/64mp-rgb.png 120395561b3c

phase_case png_sw_64mp 180 \
  "ffmpeg_rc==0;out_md5==ref_md5;out_bytes==192000000" 1 \
  --warn-if "elapsed_ms<=20000" \
  --host-check 'ref=$(ffmpeg -v error -y -i "$HWTEST_REPO_ROOT/docs/porting/artifacts/hwtest-2026-11-07/fixes/png-02/samples/64mp-rgb.png" -pix_fmt rgb24 -f rawvideo - 2>/dev/null | md5sum | cut -d" " -f1); printf "REF_MD5=%s\n" "$ref"' \
  --metric 'ffmpeg_rc=FFMPEG_RC=(-?\d+)' \
  --metric 'elapsed_ms=ELAPSED_MS=(\d+)' \
  --metric 'out_md5=OUT_MD5=([0-9a-f]{32})' \
  --metric 'out_bytes=OUT_BYTES=(\d+)' \
  --metric 'ref_md5=REF_MD5=([0-9a-f]{32})' \
  -- \
  "rm -f /tmp/inf04c_64mp.rgb; t0=\$(date +%s%N); timeout 120 ffmpeg -v error -y -i /root/hwtest/png/64mp-rgb.png -pix_fmt rgb24 -f rawvideo /tmp/inf04c_64mp.rgb; echo \"FFMPEG_RC=\$?\"; t1=\$(date +%s%N); echo \"ELAPSED_MS=\$(( (t1 - t0) / 1000000 ))\"; echo \"OUT_BYTES=\$(stat -c %s /tmp/inf04c_64mp.rgb 2>/dev/null || echo 0)\"; echo \"OUT_MD5=\$(md5sum /tmp/inf04c_64mp.rgb 2>/dev/null | cut -d' ' -f1)\"; rm -f /tmp/inf04c_64mp.rgb; grep -E '^(CmaFree|MemFree|MemAvailable):' /proc/meminfo"
