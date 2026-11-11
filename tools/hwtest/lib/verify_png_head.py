#!/usr/bin/env python3
"""PNG 硬件输出 head 判定（INF-04b，复制自 fixes/png-01/verify_head.py）。

差异：在原有输出末尾追加一行机器可读的紧凑指标，供 run_phase.sh 的
--metric / --host-check 提取（HEAD6 / HEAD_OK / VERDICT / GOODROWS /
BYTES_RATIO / ZERO）。判定口径与 png-01 完全一致。

FIX-PNG-01 主机侧判定：比较 PNG 硬件输出 raw 与 ffmpeg 软件参考。

用法:
  ffmpeg -v error -i t1080.png -frames:v 1 -f rawvideo -pix_fmt rgb24 ref_rgb24.rgb
  python3 verify_head.py out.raw ref_rgb24.rgb --width 1920 --height 1080 --rows 32 [--stride 7680] [--expect-rgba]

判定口径（沿用历史 round159/161/162/169）:
  ZERO             输出全 0（整文件提交 / 状态污染的典型结果）
  HEAD_OK          前 6 字节 = 7e 00 fd 7e 00 fd（RGB888；--expect-rgba 时前 8 字节 = 7e 00 fd ff 7e 00 fd ff）
  HISTORIC_PARTIAL HEAD_OK 且字节匹配率 0.45–0.55 且完全匹配行数 >= 10（历史 ≈15/1080 行）
  FULL             字节匹配率 >= 0.999 且（若工具输出含 state=FINISH，另由 run.log 判定）
"""
import argparse
import sys

HEAD_RGB = bytes.fromhex("7e00fd7e00fd")
HEAD_RGBA = bytes.fromhex("7e00fdff7e00fdff")
# 判 HEAD_OK 只需要首像素 3 字节；6/8 字节仅作与历史日志的对照打印
HEAD_PIX = bytes.fromhex("7e00fd")


def auto_strides(width, height, raw_len):
    """给出 (stride, bytes_per_pixel) 候选：RGB888 与 RGBX(4Bpp)。"""
    cands = []
    if raw_len == width * height * 3:
        cands.append((width * 3, 3))
    if raw_len == width * height * 4:
        cands.append((width * 4, 4))
    # 显式/非常规行宽无法自动推断时，仍然尝试两个常见值
    for s in (width * 3, width * 4):
        if (s, s // width) not in cands and raw_len % s == 0:
            cands.append((s, s // width))
    # 去重保序
    out = []
    for c in cands:
        if c not in out:
            out.append(c)
    return out


def compare(raw, ref, width, height, stride, bpp, rows):
    total = min(len(raw), len(ref))
    if total <= 0:
        return 0.0, 0, 0, 0
    # 逐像素比较（跨过 stride 中 bpp>3 的填充字节）
    same = 0
    for y in range(height):
        ro = y * stride
        fo = y * width * 3
        if ro + width * 3 > len(raw) or fo + width * 3 > len(ref):
            break
        a = raw[ro:ro + width * 3]
        b = ref[fo:fo + width * 3]
        same += sum(1 for i in range(0, width * 3, 3) if a[i:i + 3] == b[i:i + 3])
    ratio = same / float(width * height)
    goodrows = 0
    for y in range(min(rows, height)):
        ro = y * stride
        fo = y * width * 3
        if ro + width * 3 > len(raw) or fo + width * 3 > len(ref):
            break
        if raw[ro:ro + width * 3] == ref[fo:fo + width * 3]:
            goodrows += 1
    zero = raw.count(0) == len(raw) if raw else True
    return ratio, goodrows, same, zero


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("raw", help="板卡输出 raw")
    ap.add_argument("ref", help="ffmpeg rgb24 参考")
    ap.add_argument("--width", type=int, required=True)
    ap.add_argument("--height", type=int, required=True)
    ap.add_argument("--rows", type=int, default=32, help="统计前 N 行完全匹配数")
    ap.add_argument("--stride", type=int, default=0, help="强制 raw 行宽；0=自动")
    ap.add_argument("--expect-rgba", action="store_true", help="head 判据用 RGBA 8 字节")
    args = ap.parse_args()

    raw = open(args.raw, "rb").read()
    ref = open(args.ref, "rb").read()

    cands = [(args.stride, args.stride // args.width)] if args.stride else auto_strides(
        args.width, args.height, len(raw))
    if not cands:
        cands = [(args.width * 3, 3)]

    print(f"raw={len(raw)}B ref={len(ref)}B head={raw[:16].hex(' ')}")
    head_want = HEAD_RGBA if args.expect_rgba else HEAD_RGB
    head_ok = raw[:3] == HEAD_PIX
    allzero = raw.count(0) == len(raw) if raw else True
    print(f"HEAD_RAW={raw[:(len(head_want))].hex(' ')} HEAD_WANT={head_want.hex(' ')} HEAD_OK={head_ok}")

    best = None
    for stride, bpp in cands:
        if stride <= 0:
            continue
        ratio, goodrows, same, zero = compare(raw, ref, args.width, args.height, stride, bpp, args.rows)
        print(f"stride={stride} bpp={bpp}: bytes_ratio={ratio:.5f} goodrows(first {args.rows})={goodrows} zero={zero}")
        if best is None or ratio > best[1]:
            best = (stride, ratio, goodrows)

    if allzero:
        verdict = "ZERO"
    elif head_ok and best and 0.45 <= best[1] <= 0.55 and best[2] >= 10:
        verdict = "HISTORIC_PARTIAL"
    elif best and best[1] >= 0.999:
        verdict = "FULL"
    elif head_ok:
        verdict = "HEAD_OK"
    else:
        verdict = "FAILED"
    print(f"VERDICT={verdict}")
    # 机器可读紧凑指标（run_phase.sh --metric 用）
    print(f"HEAD6={raw[:3].hex()}")
    print(f"HEAD_OK={head_ok}")
    print(f"VERDICT={verdict}")
    print(f"GOODROWS={best[2] if best else 0}")
    print(f"BYTES_RATIO={(best[1] if best else 0.0):.5f}")
    print(f"ZERO={allzero}")
    # 退出码：0=HEAD_OK/HISTORIC_PARTIAL/FULL，2=ZERO，3=其他失败
    sys.exit(0 if verdict in ("HEAD_OK", "HISTORIC_PARTIAL", "FULL") else (2 if verdict == "ZERO" else 3))


if __name__ == "__main__":
    main()
