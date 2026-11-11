#!/usr/bin/env python3
"""Compute per-frame Y-plane sha1 list from an NV21 raw video reference.

Used by run_phase.sh after decoding the host-side stream with:
    ffmpeg -v error -y -i <stream> -f rawvideo -pix_fmt nv21 ref.nv21
The output format matches the board-side list produced by run_phase.sh:
    <sha1> frame-0000
so that lib/y_sha1_check.py can compare the two files line by line.

Usage:
  reference_y_sha1.py REF.nv21 WIDTH HEIGHT [--limit N] [--out FILE]

Exit codes: 0 ok, 2 usage/IO error (including a truncated trailing frame).
"""
import argparse
import hashlib
import sys


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("ref")
    ap.add_argument("width", type=int)
    ap.add_argument("height", type=int)
    ap.add_argument("--limit", type=int, default=0,
                    help="stop after N frames (0 = all)")
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    width, height = args.width, args.height
    if width <= 0 or height <= 0:
        print("reference_y_sha1: width/height must be positive", file=sys.stderr)
        return 2
    y_bytes = width * height
    frame_bytes = y_bytes * 3 // 2

    lines = []
    with open(args.ref, "rb") as fh:
        while True:
            data = fh.read(frame_bytes)
            if not data:
                break
            if len(data) < frame_bytes:
                print(f"reference_y_sha1: truncated frame {len(lines)} "
                      f"({len(data)} of {frame_bytes} bytes)", file=sys.stderr)
                return 2
            digest = hashlib.sha1(data[:y_bytes]).hexdigest()
            lines.append(f"{digest} frame-{len(lines):04d}")
            if args.limit and len(lines) >= args.limit:
                break

    text = "\n".join(lines) + ("\n" if lines else "")
    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(text)
    else:
        sys.stdout.write(text)
    print(f"frames={len(lines)} width={width} height={height}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
