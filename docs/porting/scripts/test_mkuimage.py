#!/usr/bin/env python3
"""mkuimage.py 的回归测试（TDD: 先失败再实现）。

验证:
1. 对不存在的文件 verify 必须失败（RED 阶段即依赖此行为）。
2. pack 后头字段/CRC/DTB 偏移正确，verify 通过。
3. 篡改 payload 后 verify 必须失败。
"""
import os
import struct
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
MK = os.path.join(HERE, "mkuimage.py")
MAGIC = 0x27051956
FDT_MAGIC = 0xD00DFEED


def run(*args):
    return subprocess.run([sys.executable, MK, *args],
                          capture_output=True, text=True)


def main():
    failures = []

    # 1) RED: verify 不存在的文件必须非 0
    r = run("--verify", "/tmp/definitely-not-here-uimage")
    if r.returncode == 0:
        failures.append("verify of missing file returned 0")
    else:
        print(f"PASS: verify missing file -> rc={r.returncode}")

    with tempfile.TemporaryDirectory() as td:
        image = os.path.join(td, "Image")
        dtb = os.path.join(td, "board.dtb")
        out = os.path.join(td, "uImage")
        payload = bytes(range(256)) * 64          # 16384 bytes
        with open(image, "wb") as f:
            f.write(payload)
        with open(dtb, "wb") as f:
            f.write(struct.pack(">II", FDT_MAGIC, 0) + b"\x00" * 64)

        # 2) pack 并 verify
        r = run("--pack", "--image", image, "--dtb", dtb, "--out", out)
        if r.returncode != 0:
            failures.append(f"pack failed: {r.stderr}")
        else:
            print("PASS: pack ok")
        blob = open(out, "rb").read()
        magic, hcrc, _t, size, load, ep, dcrc, os_, arch, typ, comp, _n = \
            struct.unpack(">7IBBBB32s", blob[:64])
        if magic != MAGIC:
            failures.append("bad magic")
        if arch != 22:
            failures.append(f"bad arch {arch}")
        if size != len(payload):
            failures.append(f"bad size {size} != {len(payload)}")
        if load != 0x2000000 or ep != 0x2000000:
            failures.append("bad load/ep")
        if blob[64 + size:64 + size + 4] != struct.pack(">I", FDT_MAGIC):
            failures.append("dtb not appended after payload")
        if not failures:
            print(f"PASS: header magic=0x{magic:08x} arch={arch} size={size} "
                  f"load=0x{load:x} ep=0x{ep:x}")

        r = run("--verify", out)
        if r.returncode != 0:
            failures.append(f"verify failed: {r.stderr}")
        else:
            print("PASS: verify ok")

        # 3) 篡改 payload -> verify 必须失败
        bad = bytearray(blob)
        bad[64] ^= 0xFF
        badp = os.path.join(td, "uImage.bad")
        open(badp, "wb").write(bad)
        r = run("--verify", badp)
        if r.returncode == 0:
            failures.append("tampered payload verified ok")
        else:
            print("PASS: tampered payload rejected")

    if failures:
        for f in failures:
            print(f"FAIL: {f}")
        return 1
    print("ALL TESTS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
