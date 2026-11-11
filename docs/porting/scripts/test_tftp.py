#!/usr/bin/env python3
"""tftp_server.py 的回归测试：RRQ 取文件、分块/ACK、404 错误。"""
import os
import socket
import struct
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SRV = os.path.join(HERE, "tftp_server.py")


def rrq_get(host, port, fname, expect_ok=True, timeout=5):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(timeout)
    pkt = struct.pack(">H", 1) + fname.encode() + b"\x00octet\x00"
    s.sendto(pkt, (host, port))
    data = b""
    err = None
    expect_block = 1
    try:
        while True:
            resp, addr = s.recvfrom(4096)
            op = struct.unpack(">H", resp[:2])[0]
            if op == 3:  # DATA
                blk = struct.unpack(">H", resp[2:4])[0]
                payload = resp[4:]
                if blk == expect_block:
                    data += payload
                    s.sendto(struct.pack(">HH", 4, blk), addr)
                    if len(payload) < 512:
                        break
                    expect_block += 1
                else:
                    s.sendto(struct.pack(">HH", 4, blk), addr)
            elif op == 5:  # ERROR
                err = resp[4:]
                break
    finally:
        s.close()
    if expect_ok:
        assert err is None, f"unexpected TFTP error: {err}"
        return data
    assert err is not None, "expected TFTP error but got success"
    return err


def main():
    fails = []
    with tempfile.TemporaryDirectory() as td:
        content = bytes(range(256)) * 7  # 1792 bytes -> 4 blocks
        open(os.path.join(td, "uImage"), "wb").write(content)

        proc = subprocess.Popen(
            [sys.executable, SRV, "--dir", td, "--port", "16969"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        time.sleep(0.5)
        try:
            got = rrq_get("127.0.0.1", 16969, "uImage")
            if got != content:
                fails.append(f"content mismatch {len(got)} != {len(content)}")
            else:
                print(f"PASS: fetched {len(got)} bytes over TFTP")
            rrq_get("127.0.0.1", 16969, "missing.bin", expect_ok=False)
            print("PASS: missing file -> TFTP ERROR")
        except Exception as e:
            fails.append(f"exception: {e!r}")
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
        err = proc.stderr.read()
        if fails:
            for f in fails:
                print("FAIL:", f)
            print("server stderr:\n", err[-2000:])
            return 1
    print("ALL TESTS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
