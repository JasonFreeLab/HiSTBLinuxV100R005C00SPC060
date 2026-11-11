#!/usr/bin/env python3
"""U-Boot 串口交互小工具：发送命令并抓取输出；或只读一段时间。

用法:
    uboot_serial.py --port /dev/ttyUSB0 --baud 115200 --cmd "version" --timeout 3
    uboot_serial.py --port /dev/ttyUSB0 --seconds 20          # 抓启动日志
    uboot_serial.py --port /dev/ttyUSB0 --cmd "setenv ipaddr 192.168.2.10" \\
                    --cmd "setenv serverip 192.168.2.19" --cmd "tftpboot 0x1FFFFC0 uImage"
"""
import argparse
import sys
import time

import serial


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", required=True)
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--cmd", action="append", default=[])
    ap.add_argument("--timeout", type=float, default=3.0, help="每条命令后抓取秒数")
    ap.add_argument("--seconds", type=float, default=None, help="只读抓取秒数（不发送命令）")
    a = ap.parse_args()

    try:
        s = serial.Serial(a.port, a.baud, timeout=0.2)
    except Exception as e:  # noqa: BLE001
        print(f"FAIL: open {a.port}: {e}", file=sys.stderr)
        return 2

    def drain(dur):
        end = time.time() + dur
        while time.time() < end:
            chunk = s.read(4096)
            if chunk:
                sys.stdout.buffer.write(chunk)
                sys.stdout.buffer.flush()

    try:
        drain(0.5)
        if a.seconds is not None:
            drain(a.seconds)
            return 0
        for cmd in a.cmd:
            s.write((cmd + "\r").encode())
            s.flush()
            drain(a.timeout)
        return 0
    finally:
        s.close()


if __name__ == "__main__":
    sys.exit(main())
