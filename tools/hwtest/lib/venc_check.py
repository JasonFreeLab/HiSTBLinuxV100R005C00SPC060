#!/usr/bin/env python3
"""Derive VENC metrics (bitrate / duration) for run_phase.sh --host-check (INF-04b).

Reads the raw encoder_accept10 case log (which run_phase.sh keeps in
$HWTEST_LOG) and optionally the encoded stream fetched by --fetch.

The tool prints one status line per run:
  status=PASS submitted=90 dequeued=90 completed=90 packets=93 bytes=2162585 \
  start_ns=... first_ns=... last_ns=... tail_unflushed=0 ...

Bitrate is defined by the **presentation/content timeline**:
    bitrate = bytes * 8 * fps / submitted_frames
(the driver rate control targets a per-frame bit budget; encoder_accept does not
pace by default, so wall-clock throughput is higher than fps and would inflate
the figure ~+10%).  The old wall-clock estimate is still printed for reference
as wall_bitrate_kbps.

Usage:
  venc_check.py --log LOG [--stream PATH] [--target-kbps 5800] [--tolerance 0.05]
                [--fps 30]

Outputs key=value lines consumed by parse_case.py --metric:
  venc_check_ok=true|false
  bytes_log=<n> bytes_file=<n|-1> size_ok=true|false
  submitted=<n> content_duration_s=<float> bitrate_kbps=<float>
  wall_duration_s=<float> wall_bitrate_kbps=<float>
  bitrate_ok=true|false target_kbps=<n> tolerance=<float>
Exit codes: 0 (metrics printed even when thresholds fail), 2 usage/IO error.
"""
import argparse
import os
import re
import sys

STATUS_RE = re.compile(
    r"bytes=(\d+)\s+start_ns=\d+\s+first_ns=(\d+)\s+last_ns=(\d+)")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--log", required=True)
    ap.add_argument("--stream", default="")
    ap.add_argument("--target-kbps", type=float, default=5800.0)
    ap.add_argument("--tolerance", type=float, default=0.05)
    ap.add_argument("--fps", type=float, default=30.0)
    args = ap.parse_args()

    try:
        with open(args.log, "r", encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except OSError as exc:
        print(f"venc_check_ok=false\nvenc_check_error=cannot_read_log:{exc}")
        return 2

    matches = STATUS_RE.findall(text)
    if not matches:
        print("venc_check_ok=false")
        print("venc_check_error=status_line_not_found")
        return 0
    bytes_log, first_ns, last_ns = (int(matches[-1][0]), int(matches[-1][1]),
                                    int(matches[-1][2]))
    sub = re.search(r"submitted=(\d+)", text)
    submitted = int(sub.group(1)) if sub else 0
    wall_duration_s = (last_ns - first_ns) / 1e9
    if wall_duration_s <= 0 or submitted <= 0 or args.fps <= 0:
        print("venc_check_ok=false")
        print("venc_check_error=non_positive_duration_or_frames")
        return 0
    content_duration_s = submitted / args.fps
    content_bitrate_kbps = bytes_log * 8 / content_duration_s / 1000.0
    wall_bitrate_kbps = bytes_log * 8 / wall_duration_s / 1000.0
    bitrate_kbps = content_bitrate_kbps
    bitrate_ok = abs(bitrate_kbps - args.target_kbps) <= args.target_kbps * args.tolerance

    size_ok = True
    bytes_file = -1
    if args.stream:
        try:
            bytes_file = os.path.getsize(args.stream)
            size_ok = bytes_file == bytes_log
        except OSError:
            size_ok = False

    print("venc_check_ok=true")
    print(f"bytes_log={bytes_log}")
    print(f"bytes_file={bytes_file}")
    print(f"size_ok={'true' if size_ok else 'false'}")
    print(f"submitted={submitted}")
    print(f"content_duration_s={content_duration_s:.6f}")
    print(f"wall_duration_s={wall_duration_s:.6f}")
    print(f"bitrate_kbps={content_bitrate_kbps:.1f}")
    print(f"wall_bitrate_kbps={wall_bitrate_kbps:.1f}")
    print(f"target_kbps={args.target_kbps:.0f}")
    print(f"tolerance={args.tolerance}")
    print(f"bitrate_ok={'true' if bitrate_ok else 'false'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
