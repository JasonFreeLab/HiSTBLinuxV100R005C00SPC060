#!/usr/bin/env python3
"""Generate Adam7-interlaced PNGs + reference raws for the PNGD interlace probe.

Outputs (per image, into OUTDIR):
  <name>.png             interlaced PNG (color type 2 / 0 / 6, bd 8)
  <name>.final.rgb       expected final non-interlaced pixels (w*h*bpp)
  <name>.passN.rgb       expected sub-image of Adam7 pass N (contiguous, stride = pass width*bpp)
  <name>.meta.txt        geometry of all passes

Usage:
  gen_adam7.py OUTDIR [--w 16 --h 16 --ct 2 --pattern gradient]
  gen_adam7.py OUTDIR --set         # generate the standard probe set
"""
import os
import struct
import sys
import zlib

# Adam7 pass geometry: (x0, y0, dx, dy)
ADAM7 = [(0, 0, 8, 8), (4, 0, 8, 8), (0, 4, 4, 8), (2, 0, 4, 4),
         (0, 2, 2, 4), (1, 0, 2, 2), (0, 1, 1, 2)]
CH = {0: 1, 2: 3, 6: 4}


def pixel(pattern, x, y, w, h, ct):
    """Return a tuple/list of channel bytes for pixel (x,y)."""
    if pattern == "gradient":
        r = (x * 255) // max(1, w - 1) if w > 1 else 0
        g = (y * 255) // max(1, h - 1) if h > 1 else 0
        b = ((x + y) * 7) & 0xFF
    elif pattern == "checker":
        v = 255 if ((x // 2) + (y // 2)) & 1 else 16
        r = g = b = v
    elif pattern == "index":
        v = (x * 16 + y * 3) & 0xFF
        r = g = b = v
    else:
        raise SystemExit("bad pattern")
    if ct == 0:
        return [g]
    if ct == 2:
        return [r, g, b]
    if ct == 6:
        return [r, g, b, (x * 3 + y * 5) & 0xFF]
    raise SystemExit("bad ct")


def pass_geom(w, h, p):
    x0, y0, dx, dy = ADAM7[p]
    pw = (w - x0 + dx - 1) // dx
    ph = (h - y0 + dy - 1) // dy
    return x0, y0, max(0, pw), max(0, ph), dx, dy


def make_png(w, h, ct, pattern):
    ch = CH[ct]
    # final reference
    final = bytearray()
    for y in range(h):
        for x in range(w):
            final += bytes(pixel(pattern, x, y, w, h, ct))
    # per-pass sub-images + filtered scanlines
    raw = bytearray()
    passes = []
    for p in range(7):
        x0, y0, pw, ph, dx, dy = pass_geom(w, h, p)
        sub = bytearray()
        for j in range(ph):
            raw.append(0)  # filter type 0
            for i in range(pw):
                raw += bytes(pixel(pattern, x0 + dx * i, y0 + dy * j, w, h, ct))
        for j in range(ph):
            for i in range(pw):
                sub += bytes(pixel(pattern, x0 + dx * i, y0 + dy * j, w, h, ct))
        passes.append((p, x0, y0, pw, ph, bytes(sub)))
    comp = zlib.compress(bytes(raw), 9)
    def chunk(typ, data):
        c = struct.pack(">I", len(data)) + typ + data
        crc = zlib.crc32(typ + data) & 0xFFFFFFFF
        return c + struct.pack(">I", crc)
    ihdr = struct.pack(">IIBBBBB", w, h, 8, ct, 0, 0, 1)  # interlace = 1
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", comp) + chunk(b"IEND", b"")
    return png, bytes(final), passes


def emit(outdir, name, w, h, ct, pattern):
    os.makedirs(outdir, exist_ok=True)
    png, final, passes = make_png(w, h, ct, pattern)
    open(os.path.join(outdir, name + ".png"), "wb").write(png)
    open(os.path.join(outdir, name + ".final.rgb"), "wb").write(final)
    meta = [f"w={w} h={h} ct={ct} pattern={pattern} interlace=adam7"]
    for p, x0, y0, pw, ph, sub in passes:
        if pw == 0 or ph == 0:
            meta.append(f"pass{p}: empty")
            continue
        open(os.path.join(outdir, f"{name}.pass{p}.rgb"), "wb").write(sub)
        meta.append(f"pass{p}: x0={x0} y0={y0} w={pw} h={ph} bytes={len(sub)}")
    open(os.path.join(outdir, name + ".meta.txt"), "w").write("\n".join(meta) + "\n")
    print(f"{name}: {w}x{h} ct={ct} png={len(png)}B final={len(final)}B")


def main():
    args = sys.argv[1:]
    if not args:
        raise SystemExit(__doc__)
    outdir = args[0]
    if "--set" in args:
        emit(outdir, "ilace-rgb16x16", 16, 16, 2, "gradient")
        emit(outdir, "ilace-rgb33x17", 33, 17, 2, "gradient")
        emit(outdir, "ilace-rgb64x64", 64, 64, 2, "checker")
        emit(outdir, "ilace-gray17x17", 17, 17, 0, "index")
        emit(outdir, "ilace-rgba19x11", 19, 11, 6, "gradient")
        return
    w = 16
    h = 16
    ct = 2
    pattern = "gradient"
    for i, a in enumerate(args):
        if a == "--w":
            w = int(args[i + 1])
        elif a == "--h":
            h = int(args[i + 1])
        elif a == "--ct":
            ct = int(args[i + 1])
        elif a == "--pattern":
            pattern = args[i + 1]
    emit(outdir, f"ilace-{w}x{h}-ct{ct}-{pattern}", w, h, ct, pattern)


if __name__ == "__main__":
    main()
