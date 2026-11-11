#!/usr/bin/env python3
"""发一条 U-Boot 命令，读到提示符 'fastboot#' 或超时就返回（避免固定等待）。

用法:
  uboot_cmd_until.py --port /dev/ttyUSB0 --send "tftp 0x10000000 x.bin" --timeout 60
  uboot_cmd_until.py --port /dev/ttyUSB0 --sync --timeout 10
退出码: 0=看到提示符；1=超时；2=串口错误
"""
import argparse
import sys
import time

import serial


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyUSB0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--send", default="")
    ap.add_argument("--timeout", type=float, default=30.0)
    ap.add_argument("--sync", action="store_true", help="只同步提示符，不发命令")
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args()

    try:
        s = serial.Serial(a.port, a.baud, timeout=0.05)
    except Exception as e:  # noqa: BLE001
        print(f"FAIL open: {e}", file=sys.stderr)
        return 2

    buf = b""

    def read_until_prompt(end):
        nonlocal buf
        while time.time() < end:
            d = s.read(8192)
            if d:
                buf += d
                if b"fastboot#" in buf:
                    return True
        return b"fastboot#" in buf

    try:
        s.write(b"\r")
        sync_end = time.time() + min(3.0, a.timeout)
        have = read_until_prompt(sync_end)
        if not a.sync:
            buf = b""  # 清掉同步阶段的旧提示符，避免误判命令已完成
            s.write((a.send + "\r").encode())
            have = read_until_prompt(time.time() + a.timeout)
    finally:
        s.close()
    text = buf.decode(errors="replace")
    if not a.quiet:
        sys.stdout.write(text)
    return 0 if have else 1


if __name__ == "__main__":
    sys.exit(main())
