#!/usr/bin/env bash
# =============================================================================
# 阶段定义：png_hist
#
# 目标：PNG 历史 head 像素复现（PNG-01 E0 配方；整幅不作为要求）。
#   clean boot（**每个 boot 只解码一次**）→ hi_mmz_shim + hi_png_reload.ko（4551b6e1）
#   → png_test8（723a011b，IDAT 组帧）+ t1080.png（1252aba8）
#   → 回传 out.raw（8.29 MB）→ 主机 ffmpeg 解 t1080.png 为 rgb24 参考
#   → 主机 verify_png_head.py 判定：head 7e00fd、goodrows>0（HEAD_OK 级）
#
# 判据：head6=7e00fd、head_ok=True、goodrows≥1、bytes_ratio>0、host-check rc=0。
#       整幅（FULL）不作要求 —— 历史结论：整幅受 vendor 私有流控限制。
# 注意：解码会污染会话状态，失败重试只能靠 phase_retry_after_reboot（新 boot）。
# 用法：./tools/hwtest/run_phase.sh png_hist [--dry-run]
# =============================================================================

phase_name png_hist
phase_desc "PNG head 复现：hi_png_reload(4551b6e1)+png_test8(723a011b)+t1080.png，每 boot 一次；判 HEAD_OK(head=7e00fd, goodrows>0)，整幅不要求"
phase_boot clean
phase_board_m2 /root/m2
phase_retry_after_reboot 1

phase_module /root/m2/hi_mmz_shim.ko
phase_module /root/m2/hi_png_reload.ko

phase_expect_sha1 /root/m2/hi_mmz_shim.ko 1ad0d7c7d5e2ba7b9e74d5de50a2277407708a09
phase_expect_sha1 /root/m2/hi_png_reload.ko 4551b6e117a6d0b88c023c0cbbab87848ac25021
phase_expect_sha1 /root/m2/png_test8 723a011b
phase_expect_sha1 /root/m2/t1080.png 1252aba8

# 历史 rc=-2147483635 / state=3 属已知行为，rc 不是成功判据；只取 head 像素。
phase_case png_head 180 \
  "head6==7e00fd;head_ok==True;goodrows>=1;bytes_ratio>0;host_check_rc==0" 1 \
  --fetch "out.raw" \
  --host-check 'ffmpeg -v error -y -i "$HWTEST_REPO_ROOT/docs/porting/artifacts/hwtest-2026-11-07/fixes/png-01/E0/t1080.png" -frames:v 1 -f rawvideo -pix_fmt rgb24 "$HWTEST_ARTIFACTS/ref.rgb" && python3 "$HWTEST_LIB_DIR/verify_png_head.py" "$HWTEST_ARTIFACTS/out.raw" "$HWTEST_ARTIFACTS/ref.rgb" --width 1920 --height 1080 --rows 32; rc=$?; rm -f "$HWTEST_ARTIFACTS/ref.rgb"; exit $rc' \
  --metric 'head6=HEAD6=([0-9a-f]{6})' \
  --metric 'head_ok=HEAD_OK=(True|False)' \
  --metric 'goodrows=GOODROWS=(\d+)' \
  --metric 'bytes_ratio=BYTES_RATIO=([0-9.]+)' \
  --metric 'verdict=VERDICT=(\w+)' \
  --metric 'tool_rc=PNG_TOOL_RC=(\d+)' \
  -- \
  "timeout 90 ./png_test8 t1080.png {out}/out.raw 1 > {out}/run.log 2>&1; echo \"PNG_TOOL_RC=\$?\"; cat {out}/run.log; grep -ai png /proc/interrupts | head -2; dmesg 2>/dev/null | grep -aiE 'png' | tail -8; ls -l {out}/out.raw"
