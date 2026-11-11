#!/usr/bin/env python3
"""ymodem_send.py 的回归测试：用 pty 模拟 U-Boot loady 接收端（YMODEM-1K CRC）。

模拟端行为：持续发 'C'，收 header（SOH block0，含文件名/大小），ACK；
收 1024 字节数据块（STX）校验 CRC 并 ACK；EOT → ACK 再发 'C'；
收空 header 结束。
"""
import os
import pty
import select
import struct
import subprocess
import sys
import tempfile
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "ymodem_send.py")

SOH, STX, EOT, ACK, NAK, CAN = 0x01, 0x02, 0x04, 0x06, 0x15, 0x18


def crc16(data):
    crc = 0
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def read_exact(fd, n, timeout=10.0):
    buf = b""
    end = time.time() + timeout
    while len(buf) < n and time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.1)
        if r:
            try:
                buf += os.read(fd, n - len(buf))
            except OSError:
                break
    return buf


def receiver(fd, result, stop):
    out = []
    name = None
    size = 0
    # 反复发送 'C' 直到收到 block0
    while not stop.is_set():
        os.write(fd, bytes([ACK])) if False else None
        os.write(fd, b"C")
        h = read_exact(fd, 1 + 2 + 128 + 2, timeout=1.0)
        if len(h) == 133 and h[0] == SOH:
            seq = h[1]
            data = h[3:3 + 128]
            crc = struct.unpack(">H", h[131:133])[0]
            if seq == 0 and crc == crc16(data):
                name, _, rest = data.partition(b"\x00")
                sz, _, _ = rest.partition(b"\x00")
                try:
                    size = int(sz)
                except ValueError:
                    size = 0
                result["name"] = name.decode(errors="replace")
                result["size"] = size
                os.write(fd, bytes([ACK]))
                break
        if stop.is_set():
            return
        time.sleep(0.2)
    # 数据块
    while len(out) < size and not stop.is_set():
        hdr = read_exact(fd, 3, timeout=10)
        if len(hdr) < 3:
            break
        if hdr[0] == EOT:
            os.write(fd, bytes([ACK]))
            break
        if hdr[0] not in (SOH, STX):
            continue
        n = 128 if hdr[0] == SOH else 1024
        body = read_exact(fd, n + 2, timeout=10)
        if len(body) < n + 2:
            break
        crc = struct.unpack(">H", body[n:n + 2])[0]
        if crc != crc16(body[:n]):
            os.write(fd, bytes([NAK]))
            continue
        out.append(body[:n])
        os.write(fd, bytes([ACK]))
    # 批结束：发 'C'，收空 block0
    os.write(fd, bytes([ACK]))
    os.write(fd, b"C")
    h = read_exact(fd, 133, timeout=3.0)
    if len(h) == 133 and h[0] == SOH:
        os.write(fd, bytes([ACK]))
    result["data"] = b"".join(out)[:size]


def main():
    fails = []
    with tempfile.TemporaryDirectory() as td:
        src = os.path.join(td, "uImage")
        content = bytes(range(256)) * 20 + b"tail"  # 5125 bytes -> 6 blocks
        open(src, "wb").write(content)

        master, slave = pty.openpty()
        stop = threading.Event()
        result = {}
        t = threading.Thread(target=receiver, args=(master, result, stop), daemon=True)
        t.start()
        time.sleep(0.3)
        slave_name = os.ttyname(slave)

        p = subprocess.run(
            [sys.executable, TOOL, "--port", slave_name, "--baud", "115200",
             "--file", src, "--name", "uImage"],
            capture_output=True, text=True, timeout=60)
        time.sleep(0.5)
        stop.set()
        os.close(slave)
        os.close(master)

        if p.returncode != 0:
            fails.append(f"sender rc={p.returncode}: {p.stderr[-800:]}")
        if result.get("name") != "uImage":
            fails.append(f"bad name: {result.get('name')!r}")
        if result.get("size") != len(content):
            fails.append(f"bad size: {result.get('size')} != {len(content)}")
        if result.get("data") != content:
            fails.append(f"data mismatch: {len(result.get('data', b''))} bytes")

    if fails:
        for f in fails:
            print("FAIL:", f)
        return 1
    print(f"PASS: YMODEM transferred {len(content)} bytes, name/size/CRC ok")
    print("ALL TESTS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
