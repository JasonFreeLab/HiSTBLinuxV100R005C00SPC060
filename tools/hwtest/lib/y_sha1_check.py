#!/usr/bin/env python3
"""Compare per-frame Y-plane sha1 lists (board capture vs host ffmpeg reference).

Board-side list (produced on the board by run_phase.sh):
    <sha1> frame-0000-pts-0-w1920-h1080.nv21
Host-side list (produced by lib/reference_y_sha1.py):
    <sha1> frame-0000

Frames are matched by the ORDINAL embedded in the file name (`frame-%04u`),
not by list position, so capture directories whose filenames are filtered
(e.g. only sampled frames) still compare correctly against the full reference.

Usage:
  y_sha1_check.py --board BOARD-y-sha1.txt --ref host-ref-y-sha1.txt \
                  [--limit N] [--json-out FILE]

Outputs key=value lines on stdout:
  pixel_frames=<compared> pixel_matched=<n> pixel_mismatch=<n>
  pixel_ok=true|false pixel_board_count=<n> pixel_ref_count=<n> [pixel_reason=...]
Exit codes: 0 all compared frames identical, 1 mismatch/missing, 2 usage/IO.
"""
import argparse
import json
import re
import sys

BOARD_NAME_RE = re.compile(r"frame[-_](\d+)")
SHA_RE = re.compile(r"^[0-9a-fA-F]{40}$")


def read_board_list(path):
    entries = []
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for lineno, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            parts = line.split(None, 1)
            if len(parts) != 2 or not SHA_RE.match(parts[0]):
                raise ValueError(f"{path}:{lineno}: unexpected board list line: {line!r}")
            ordinal = None
            match = BOARD_NAME_RE.search(parts[1])
            if match:
                ordinal = int(match.group(1))
            entries.append((ordinal, parts[0].lower(), parts[1]))
    return entries


def read_ref_list(path):
    entries = {}
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for lineno, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            parts = line.split(None, 1)
            if len(parts) != 2 or not SHA_RE.match(parts[0]):
                raise ValueError(f"{path}:{lineno}: unexpected ref list line: {line!r}")
            match = re.search(r"(\d+)\s*$", parts[1])
            if not match:
                raise ValueError(f"{path}:{lineno}: no frame ordinal in {parts[1]!r}")
            entries[int(match.group(1))] = parts[0].lower()
    return entries


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--board", required=True)
    ap.add_argument("--ref", required=True)
    ap.add_argument("--limit", type=int, default=0, help="compare first N board frames only")
    ap.add_argument("--json-out", default="")
    args = ap.parse_args()

    try:
        board = read_board_list(args.board)
        ref = read_ref_list(args.ref)
    except (OSError, ValueError) as exc:
        print(f"pixel_ok=false\npixel_reason={exc}")
        return 2

    if args.limit:
        board = board[:args.limit]

    mismatches, missing = [], []
    for ordinal, sha, name in board:
        if ordinal is None:
            missing.append(f"{name}(no-ordinal)")
            continue
        if ordinal not in ref:
            missing.append(f"{name}(ordinal={ordinal} absent in ref)")
            continue
        if ref[ordinal] != sha:
            mismatches.append(f"{name}(ordinal={ordinal})")
    compared = len(board)
    matched = compared - len(mismatches) - len(missing)
    ok = compared > 0 and not mismatches and not missing

    if not board:
        reason = "no board frames"
    elif mismatches or missing:
        reason = f"mismatch:{','.join(mismatches)};missing:{','.join(missing)}"
    else:
        reason = "all identical"

    payload = {
        "board": args.board, "ref": args.ref, "limit": args.limit,
        "frames": compared, "matched": matched,
        "mismatch": len(mismatches), "missing": len(missing),
        "mismatch_frames": mismatches, "missing_frames": missing,
        "board_count": len(read_board_list(args.board)),
        "ref_count": len(ref), "ok": ok, "reason": reason,
    }
    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2, ensure_ascii=False)
            fh.write("\n")

    print(f"pixel_frames={compared}")
    print(f"pixel_matched={matched}")
    print(f"pixel_mismatch={len(mismatches)}")
    print(f"pixel_board_count={payload['board_count']}")
    print(f"pixel_ref_count={payload['ref_count']}")
    print(f"pixel_ok={'true' if ok else 'false'}")
    print(f"pixel_reason={reason}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
