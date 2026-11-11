#!/usr/bin/env python3
"""Compare a captured NV21 frame (vdec_spec capture output) with ffmpeg reference NV21 frame 0.

Usage: compare_vdec.py <captured.nv21> <reference.nv21> <width> <height> [frame_index]
Reference is `ffmpeg -i stream -f rawvideo -pix_fmt nv21 ref.nv21`; frames are w*h*3/2 bytes.
Prints JSON-ish stats: sha1(Y), sha1(all), mean_abs_diff(Y/all), max_diff, sizes.
"""
import hashlib
import sys


def main():
    cap_path, ref_path, w, h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    idx = int(sys.argv[5]) if len(sys.argv) > 5 else 0
    frame = w * h * 3 // 2
    cap = open(cap_path, "rb").read()
    ref = open(ref_path, "rb").read()
    if len(cap) < frame or len(ref) < frame * (idx + 1):
        print(f"ERROR size cap={len(cap)} ref={len(ref)} need={frame} idx={idx}")
        return 2
    cap, ref = cap[:frame], ref[idx * frame:(idx + 1) * frame]
    ybytes = w * h
    stats = {
        "width": w, "height": h, "frame_bytes": frame, "frame_index": idx,
        "cap_sha1_y": hashlib.sha1(cap[:ybytes]).hexdigest(),
        "ref_sha1_y": hashlib.sha1(ref[:ybytes]).hexdigest(),
        "cap_sha1_all": hashlib.sha1(cap).hexdigest(),
        "ref_sha1_all": hashlib.sha1(ref).hexdigest(),
        "y_identical": cap[:ybytes] == ref[:ybytes],
        "all_identical": cap == ref,
    }
    y_total = y_max = 0
    c_total = c_max = 0
    for i in range(ybytes):
        d = cap[i] - ref[i]
        if d < 0:
            d = -d
        y_total += d
        if d > y_max:
            y_max = d
    for i in range(ybytes, frame):
        d = cap[i] - ref[i]
        if d < 0:
            d = -d
        c_total += d
        if d > c_max:
            c_max = d
    stats["y_mean_abs_diff"] = round(y_total / ybytes, 6)
    stats["y_max_diff"] = y_max
    stats["c_mean_abs_diff"] = round(c_total / (frame - ybytes), 6)
    stats["c_max_diff"] = c_max
    for k, v in stats.items():
        print(f"{k}={v}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
