#!/usr/bin/env bash
# Host-side mock of `ssh <board> <remote-command>` used ONLY by selftest/run_selftest.sh.
# It emulates a fake board whose root is $MOCK_ROOT: /root/* paths are translated
# into $MOCK_ROOT/root/*, /proc/{uptime,meminfo,boot_id} and /sys/module into
# $MOCK_ROOT/...; insmod / vdec_test / vdec_spec are simulated.
# It never touches a real board or loads any kernel module.
set -u
ROOT="${MOCK_ROOT:?MOCK_ROOT must be set}"
STATE="$ROOT/state"
cmd="${*: -1}"

translate() {
  printf '%s' "$1" | sed \
    -e "s#/proc/sys/kernel/random/boot_id#$ROOT/proc/sys/kernel/random/boot_id#g" \
    -e "s#/proc/uptime#$ROOT/proc/uptime#g" \
    -e "s#/proc/meminfo#$ROOT/proc/meminfo#g" \
    -e "s#/sys/module/#$ROOT/sys/module/#g" \
    -e "s#/root#$ROOT/root#g"
}

translate_stdin_script() {
  sed \
    -e "s#/proc/sys/kernel/random/boot_id#$ROOT/proc/sys/kernel/random/boot_id#g" \
    -e "s#/proc/uptime#$ROOT/proc/uptime#g" \
    -e "s#/proc/meminfo#$ROOT/proc/meminfo#g" \
    -e "s#/sys/module/#$ROOT/sys/module/#g" \
    -e "s#/root#$ROOT/root#g" \
    -e "s#^lsmod 2>/dev/null || true#cat $STATE/lsmod#" \
    -e "s#^dmesg 2>/dev/null | tail -15 || true#cat $STATE/dmesg | tail -15#"
}

mock_vdec_spec() {
  local cmd="$1" epoch cap case_dir key n f
  epoch=$(cat "$STATE/boot-epoch" 2>/dev/null || echo 1)
  cap=$(printf '%s' "$cmd" | tr "'\"" '   ' | grep -o '/[^ ]*/cap' | tail -1)
  if [ -z "$cap" ]; then
    # warmup（无 capture 参数）：模拟"有交付但不达标"
    printf 'RESULT {"expected":30,"submitted":30,"received":3,"pts_errors":1,"geometry_errors":0,"capture_errors":0,"transport_ok":false,"fake_frames":1,"eos_submitted":1}\n'
    printf 'EXIT status=1\n'
    exit 1
  fi
  cap=$(translate "$cap")
  if printf '%s' "$cmd" | grep -q '3840 2160'; then
    # VDEC-03 4K known-issue：ok64 模块 4K 交付 0 帧 + 抓帧静默失败（format_enum=102）
    mkdir -p "$cap"
    printf 'OUTPUT format_enum=102 bitwidth_enum=0\n'
    printf 'RESULT {"expected":20,"submitted":20,"received":0,"pts_errors":0,"geometry_errors":0,"capture_errors":0,"transport_ok":false,"fake_frames":0,"eos_submitted":1}\n'
    printf 'EXIT status=1\n'
    printf 'VDEC_RC=1\n'
    exit 1
  fi
  mkdir -p "$STATE/attempts"
  case_dir=$(dirname "$cap")
  key=$(printf '%s' "$case_dir" | tr -c 'A-Za-z0-9' '_')
  n=$(( $(cat "$STATE/attempts/$key" 2>/dev/null || echo 0) + 1 ))
  printf '%s\n' "$n" > "$STATE/attempts/$key"
  mkdir -p "$cap"
  if [ "$epoch" -ge 3 ]; then
    for f in frame-0000-pts-0-w1920-h1080.nv21 frame-0001-pts-1-w1920-h1080.nv21 \
             frame-0002-pts-2-w1920-h1080.nv21 frame-0005-pts-5-w1920-h1080.nv21 \
             frame-0010-pts-10-w1920-h1080.nv21 frame-0015-pts-15-w1920-h1080.nv21; do
      [ -f "$MOCK_FRAMES/$f" ] && cp -f "$MOCK_FRAMES/$f" "$cap/$f"
    done
    printf 'CONFIG codec=h264 cap=fullhd expected_frames=6 width=1920 height=1080 mode=capture\n'
    printf 'RESULT {"expected":6,"submitted":6,"received":6,"pts_errors":0,"geometry_errors":0,"capture_errors":0,"transport_ok":true,"fake_frames":1,"eos_submitted":1}\n'
    printf 'EXIT status=0\n'
    exit 0
  fi
  printf 'RESULT {"expected":6,"submitted":6,"received":0,"pts_errors":0,"geometry_errors":0,"capture_errors":0,"transport_ok":false,"fake_frames":0,"eos_submitted":1}\n'
  printf 'EXIT status=1\n'
  exit 1
}

mock_insmod() {
  local cmd="$1" path name
  path=$(printf '%s' "$cmd" | sed -n "s/.*insmod '\([^']*\)'.*/\1/p")
  if [ -z "$path" ]; then
    path=$(printf '%s' "$cmd" | sed -n 's/.*insmod \([^ ]*\).*/\1/p')
  fi
  name=$(basename "$path" .ko)
  name=${name//-/_}
  mkdir -p "$ROOT/sys/module/$name"
  printf '%s 16384 0 - Live 0x0000000000000000\n' "$name" >> "$STATE/lsmod"
  printf '[  mock] %s loaded\n' "$name" >> "$STATE/dmesg"
  exit 0
}

extract_path() {
  printf '%s' "$1" | tr "'\"" '   ' | grep -o "$2" | head -1
}

mock_venc() {
  local cmd="$1" out bytes codec stream
  out=$(extract_path "$cmd" '/[^ ]*/run\.h265')
  [ -z "$out" ] && out="/root/hwtest/auto/mock/run.h265"
  out=$(translate "$out")
  mkdir -p "$(dirname "$out")"
  if printf '%s' "$cmd" | grep -q -- '--codec HEVC'; then
    codec="hevc"
    stream="${MOCK_VENC_HEVC_STREAM:-}"
  else
    codec="h264"
    stream="${MOCK_VENC_STREAM:-}"
  fi
  if [ -n "$stream" ] && [ -f "$stream" ]; then
    cp -f "$stream" "$out"
  else
    printf 'mock-%s\n' "$codec" > "$out"
  fi
  bytes=$(stat -c %s "$out" 2>/dev/null || echo 2171263)
  if [ "$codec" = "hevc" ]; then
    # 真实参考：venc-05 board-verify HEVC/CBR（90 帧、level=120、bytes=2083588）
    printf 'status=PASS submitted=90 dequeued=90 completed=90 packets=93 bytes=%s start_ns=86206945674 first_ns=86295140709 last_ns=89072674776 tail_unflushed=0 eos=unsupported completion=count-based\n' "$bytes"
    printf 'codec_name=hevc\nprofile=Main\nlevel=120\nnb_read_frames=90\n'
  else
    printf 'status=PASS submitted=90 dequeued=90 completed=90 packets=93 bytes=%s start_ns=66589580274 first_ns=66575992409 last_ns=69276581714 tail_unflushed=0 eos=unsupported completion=count-based\n' "$bytes"
    printf 'codec_name=h264\nprofile=High\nlevel=41\nnb_read_frames=90\n'
  fi
  printf 'VENC_TOOL_RC=0\n'
  printf 'FFMPEG_RC=0\n'
  ls -l "$out"
  exit 0
}

mock_jpeg() {
  local cmd="$1" p1 p100
  p1=$(extract_path "$cmd" '/[^ ]*/j_m1\.yuv')
  p100=$(extract_path "$cmd" '/[^ ]*/j_m100\.yuv')
  [ -z "$p1" ] && p1="/root/hwtest/auto/mock/j_m1.yuv"
  [ -z "$p100" ] && p100="/root/hwtest/auto/mock/j_m100.yuv"
  p1=$(translate "$p1")
  p100=$(translate "$p100")
  mkdir -p "$(dirname "$p1")" "$(dirname "$p100")"
  printf 'mock-yuv-payload\n' > "$p1"
  printf 'mock-yuv-payload\n' > "$p100"
  printf 'JPEG_RC1=0\n'
  printf 'jpeg01: loops=1 mode=1 (hw-reinit+full-reprogram)\n'
  printf 'decode: loops=1 total=5.5ms per=5.46ms fps=183.1 rc=0\n'
  printf 'jpeg01: mode=1 completed=1/1 fail_iter=-1 recreated=0\n'
  printf 'jpeg01: decode-only ok=1 min=5.436ms avg=5.436ms max=5.436ms\n'
  printf 'yuv: bytes=2088960+1044480+2088960 fnv1a64=0x3c2b6e8857176ec5\n'
  printf 'JPEG_RC2=0\n'
  printf 'jpeg01: loops=100 mode=1 (hw-reinit+full-reprogram)\n'
  printf 'decode: loops=100 total=561.9ms per=5.62ms fps=178.0 rc=0\n'
  printf 'jpeg01: mode=1 completed=100/100 fail_iter=-1 recreated=0\n'
  printf 'jpeg01: decode-only ok=100 min=5.376ms avg=5.584ms max=10.145ms\n'
  printf 'yuv: bytes=2088960+1044480+2088960 fnv1a64=0x3c2b6e8857176ec5\n'
  sha1sum "$p1" "$p100"
  grep CmaFree "$ROOT/proc/meminfo" 2>/dev/null || true
  exit 0
}

mock_png() {
  local cmd="$1" out bytes
  out=$(extract_path "$cmd" '/[^ ]*/out\.raw')
  [ -z "$out" ] && out="/root/hwtest/auto/mock/out.raw"
  out=$(translate "$out")
  mkdir -p "$(dirname "$out")"
  if [ -f "${MOCK_PNG_RAW:-}" ]; then
    cp -f "$MOCK_PNG_RAW" "$out"
  else
    printf 'mock-raw\n' > "$out"
  fi
  bytes=$(stat -c %s "$out" 2>/dev/null || echo 0)
  printf 'IHDR 1920x1080 depth=8 fmt=2 size=215688\n'
  printf 'Open rc=0\n'
  printf 'CreateDecoder rc=0 h=1\n'
  printf 'idat stream 215622 bytes (file 215688)\n'
  printf 'Decode rc=-2147483635\n'
  printf 'GetResult rc=0 state=3\n'
  printf 'total 2197.15 ms\n'
  printf 'saved %s (%s bytes, stride 7680)\n' "$out" "$bytes"
  printf 'PNG_TOOL_RC=2\n'
  printf '  39:          0          0          0          0  GIC-0  128 Level     png\n'
  printf '[   52.0] PNGDBG: mock png line\n'
  ls -l "$out"
  exit 0
}

mock_png_sw() {
  # PNG-04 板上 ffmpeg 64MP 实测：11.08 s、md5 10d99d…、输出 192,000,000 B
  printf 'FFMPEG_RC=0\n'
  printf 'ELAPSED_MS=11080\n'
  printf 'OUT_BYTES=192000000\n'
  printf 'OUT_MD5=10d99dcafdc837842f91cbfc19ac0f92\n'
  grep -E '^(CmaFree|MemFree|MemAvailable):' "$ROOT/proc/meminfo" 2>/dev/null || true
  exit 0
}

mock_vdec_hevc() {
  # 新验收对 vdec_spec_hevc_head（HEVC）：decode-only 或 4K 抓帧。
  # 4K 抓帧用例会把真实归档 pts0.nv21 放进 cap/，让主机侧 compare_vdec.py 做真比对。
  local cmd="$1" cap expected received fmt bw i f
  expected=20; received=20; fmt=64; bw=0
  cap=$(printf '%s' "$cmd" | tr "'\"" '   ' | grep -o '/[^ ]*/cap' | tail -1)
  if printf '%s' "$cmd" | grep -qE '4k60(-s1-2f)?\.hevc'; then
    fmt=99; bw=0
  elif printf '%s' "$cmd" | grep -q '4k60-10b\.hevc'; then
    fmt=102; bw=1; expected=8; received=8
  fi
  if [ -n "$cap" ]; then
    cap=$(translate "$cap"); mkdir -p "$cap"
    for i in $(seq 0 19); do
      f=$(printf '%s/frame-%04d-pts-%d-w3840-h2160.nv21' "$cap" "$i" "$i")
      if [ "$i" -eq 0 ] && [ -f "${MOCK_HEVC_4K_PTS0:-}" ]; then
        cp -f "$MOCK_HEVC_4K_PTS0" "$f"
      else
        printf 'mock-pts-%s\n' "$i" > "$f"
      fi
    done
    expected=20; received=20
  fi
  printf 'CONFIG codec=hevc cap=fullhd bytes=2319770 expected_frames=%s width=3840 height=2160 mode=capture\n' "$expected"
  printf 'OUTPUT format_enum=%s bitwidth_enum=%s\n' "$fmt" "$bw"
  printf 'RESULT {"expected":%s,"submitted":%s,"received":%s,"pts_errors":5,"geometry_errors":0,"capture_errors":0,"buffer_retries":0,"idle_polls":14,"fake_frames":0,"eos_submitted":1,"feed_ms":6.187,"first_ms":63.852,"last_ms":31836.148,"wall_ms":37427.511,"output_fps":0.598,"end_to_end_fps":0.628,"iters":0,"order_breaks":11,"coded_order_output":true,"transport_ok":false,"pixels_verified":false}\n' "$expected" "$expected" "$received"
  printf 'EXIT status=1\n'
  printf 'VDEC_RC=1\n'
  [ -n "$cap" ] && printf 'CAP_FILES=%s\n' "$(ls "$cap" | wc -l)"
  exit 1
}

# 多行远程脚本（环境快照）：整体翻译后在本地执行
if [ "$(printf '%s' "$cmd" | wc -l)" -gt 0 ]; then
  translated=$(translate "$cmd")
  translated=$(printf '%s\n' "$translated" | translate_stdin_script)
  ( cd "$ROOT" && eval "$translated" )
  exit $?
fi

# 通过 stdin 传入的远程脚本（`... sh -s`）：先翻译 stdin 再执行
if [ "${cmd%sh -s}" != "$cmd" ]; then
  script=$(translate_stdin_script)
  prefix=${cmd%sh -s}
  prefix=$(translate "$prefix")
  ( cd "$ROOT" && eval "${prefix}"$'\n'"${script}" )
  exit $?
fi

case "$cmd" in
  *"dmesg -C"*) : > "$STATE/dmesg"; exit 0 ;;
  *insmod*) mock_insmod "$cmd" ;;
  *vdec_test*)
    printf 'frames=49 time=12600.0ms fps=3.89\n'
    printf '[   45.681128] VTSTAT: put=50 read=578 img=49 ack=1 | vdh=49 scd=51 | voacq=0\n'
    exit 0
    ;;
  *vdec_spec_hevc_head*) mock_vdec_hevc "$cmd" ;;
  *vdec_spec*) mock_vdec_spec "$cmd" ;;
  *encoder_accept10*) mock_venc "$cmd" ;;
  *jpeg_test_jpeg01*) mock_jpeg "$cmd" ;;
  *png_test8*) mock_png "$cmd" ;;
  *64mp-rgb.png*) mock_png_sw ;;
  *dmesg*) cat "$STATE/dmesg" 2>/dev/null | tail -20; exit 0 ;;
esac

translated=$(translate "$cmd")
( cd "$ROOT" && eval "$translated" )
