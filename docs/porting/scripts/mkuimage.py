#!/usr/bin/env python3
"""U-Boot legacy uImage 打包/校验（arm64，用于板载 fastboot bootm）。

布局（与 fastboot bootm 的约定一致）：
    [64B uImage header][payload=Image][DTB]
header.size 只统计 payload；DTB 追加在 payload 之后，由 fastboot 用
image_get_image_end() 定位并校验 FDT。

用法:
    mkuimage.py --pack --image Image --dtb board.dtb --out uImage
    mkuimage.py --verify uImage
"""
import argparse
import binascii
import struct
import sys

MAGIC = 0x27051956
IH_OS_LINUX = 5
IH_ARCH_ARM64 = 22
IH_TYPE_KERNEL = 2
IH_COMP_NONE = 0
HDR_FMT = ">7IBBBB32s"
HDR_LEN = struct.calcsize(HDR_FMT)  # 64
FDT_MAGIC = 0xD00DFEED


def _hdr(magic, hcrc, time, size, load, ep, dcrc, os_, arch, type_, comp, name):
    return struct.pack(HDR_FMT, magic, hcrc, time, size, load, ep, dcrc,
                       os_, arch, type_, comp, name)


def pack(image_path, dtb_path, out_path, load=0x2000000, ep=0x2000000, pad_to=0):
    with open(image_path, "rb") as f:
        payload = f.read()
    if pad_to and pad_to > len(payload):
        # 补零到内核 image_size：让 load_fip 推算出的 DTB 地址越过 BSS 区间，
        # 否则内核清 BSS 时会把内嵌 DTB 清零。
        payload = payload + b"\x00" * (pad_to - len(payload))
    with open(dtb_path, "rb") as f:
        dtb = f.read()
    if len(dtb) < 4 or struct.unpack(">I", dtb[:4])[0] != FDT_MAGIC:
        raise SystemExit(f"FAIL: not a DTB: {dtb_path}")
    size = len(payload)
    dcrc = binascii.crc32(payload) & 0xFFFFFFFF
    name = b"Linux-7.3-hi3798mv300"
    blank = _hdr(MAGIC, 0, 0, size, load, ep, dcrc,
                 IH_OS_LINUX, IH_ARCH_ARM64, IH_TYPE_KERNEL, IH_COMP_NONE, name)
    hcrc = binascii.crc32(blank) & 0xFFFFFFFF
    hdr = _hdr(MAGIC, hcrc, 0, size, load, ep, dcrc,
               IH_OS_LINUX, IH_ARCH_ARM64, IH_TYPE_KERNEL, IH_COMP_NONE, name)
    with open(out_path, "wb") as f:
        f.write(hdr)
        f.write(payload)
        f.write(dtb)
    return len(payload), len(dtb)


def verify(path):
    with open(path, "rb") as f:
        blob = f.read()
    if len(blob) < HDR_LEN:
        raise SystemExit("FAIL: file shorter than uImage header")
    fields = struct.unpack(HDR_FMT, blob[:HDR_LEN])
    magic, hcrc, _time, size, load, ep, dcrc, os_, arch, type_, comp, name = fields
    if magic != MAGIC:
        raise SystemExit(f"FAIL: bad magic 0x{magic:08x}")
    blank = _hdr(MAGIC, 0, 0, size, load, ep, dcrc, os_, arch, type_, comp, name)
    calc = binascii.crc32(blank) & 0xFFFFFFFF
    if calc != hcrc:
        raise SystemExit(f"FAIL: header crc mismatch 0x{calc:08x} != 0x{hcrc:08x}")
    payload = blob[HDR_LEN:HDR_LEN + size]
    if len(payload) != size:
        raise SystemExit(f"FAIL: payload truncated: {len(payload)} != {size}")
    calc_dcrc = binascii.crc32(payload) & 0xFFFFFFFF
    if calc_dcrc != dcrc:
        raise SystemExit(f"FAIL: data crc mismatch 0x{calc_dcrc:08x} != 0x{dcrc:08x}")
    off = HDR_LEN + size
    if len(blob) < off + 4:
        raise SystemExit("FAIL: no DTB appended after payload")
    fdt_magic = struct.unpack(">I", blob[off:off + 4])[0]
    if fdt_magic != FDT_MAGIC:
        raise SystemExit(f"FAIL: bad FDT magic 0x{fdt_magic:08x} at offset {off}")
    if arch != IH_ARCH_ARM64:
        raise SystemExit(f"FAIL: arch {arch} != ARM64({IH_ARCH_ARM64})")
    print(f"PASS: magic=0x{magic:08x} arch={arch} size={size} load=0x{load:x} ep=0x{ep:x} "
          f"dtb_offset={off} dtb_len={len(blob) - off} total={len(blob)}")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack", action="store_true")
    ap.add_argument("--image")
    ap.add_argument("--dtb")
    ap.add_argument("--out")
    ap.add_argument("--load", type=lambda x: int(x, 0), default=0x2000000)
    ap.add_argument("--ep", type=lambda x: int(x, 0), default=0x2000000)
    ap.add_argument("--pad-to", type=lambda x: int(x, 0), default=0,
                    help="把 payload 补零到该大小（hex），用于把 DTB 放到内核 BSS 之后")
    ap.add_argument("--verify", metavar="FILE")
    a = ap.parse_args()
    if a.pack:
        if not (a.image and a.dtb and a.out):
            ap.error("--pack requires --image --dtb --out")
        n, d = pack(a.image, a.dtb, a.out, a.load, a.ep, a.pad_to)
        print(f"PACKED: image={n} dtb={d} total={HDR_LEN + n + d} -> {a.out}")
        return verify(a.out)
    if a.verify:
        return verify(a.verify)
    ap.error("nothing to do (use --pack or --verify)")


if __name__ == "__main__":
    sys.exit(main())
