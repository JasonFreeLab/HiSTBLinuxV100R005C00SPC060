#!/usr/bin/env python3
"""极简只读 TFTP 服务器（RRQ/octet），用于 U-Boot tftpboot 加载 uImage。

端口可用高位端口（例如 6969），配合 U-Boot 环境变量 tftpdstp：
    setenv tftpdstp 6969
    setenv serverip <host-ip>
    tftpboot 0x1FFFFC0 uImage

用法:
    tftp_server.py --dir /home/jason/bringup-7.3/out --port 6969 [--bind 0.0.0.0]
"""
import argparse
import os
import socket
import struct
import sys

OP_RRQ = 1
OP_WRQ = 2
OP_DATA = 3
OP_ACK = 4
OP_ERROR = 5
OP_OACK = 6
DEFAULT_BLKSIZE = 512
MAX_BLKSIZE = 1468


def send_error(sock, addr, code, msg):
    sock.sendto(struct.pack(">HH", OP_ERROR, code) + msg.encode() + b"\x00", addr)


def parse_rrq(data):
    parts = data[2:].split(b"\x00")
    parts = [p.decode(errors="replace") for p in parts]
    fname = parts[0] if parts else ""
    mode = parts[1] if len(parts) > 1 else "octet"
    opts = {}
    rest = parts[2:]
    for i in range(0, len(rest) - 1, 2):
        if rest[i]:
            opts[rest[i].lower()] = rest[i + 1]
    return fname, mode, opts


def transfer(sock, addr, content, opts):
    blksize = DEFAULT_BLKSIZE
    oack = []
    if "blksize" in opts:
        try:
            req = int(opts["blksize"])
        except ValueError:
            req = DEFAULT_BLKSIZE
        blksize = max(8, min(MAX_BLKSIZE, req))
        oack += ["blksize", str(blksize)]
    if "tsize" in opts:
        oack += ["tsize", str(len(content))]
    if "timeout" in opts:
        oack += ["timeout", opts["timeout"]]

    def recv_ack(expected, timeout=3.0):
        sock.settimeout(timeout)
        while True:
            pkt, src = sock.recvfrom(2048)
            if src != addr:
                continue
            if len(pkt) < 2:
                continue
            op = struct.unpack(">H", pkt[:2])[0]
            if op == OP_ACK and len(pkt) >= 4:
                blk = struct.unpack(">H", pkt[2:4])[0]
                if blk == expected:
                    return True
            if op == OP_ERROR:
                return False

    if oack:
        sock.sendto(struct.pack(">H", OP_OACK) +
                    b"".join(o.encode() + b"\x00" for o in oack), addr)
        if not recv_ack(0):
            return
    blk = 1
    off = 0
    while True:
        chunk = content[off:off + blksize]
        pkt = struct.pack(">HH", OP_DATA, blk & 0xFFFF) + chunk
        ok = False
        for _ in range(8):
            sock.sendto(pkt, addr)
            if recv_ack(blk & 0xFFFF):
                ok = True
                break
        if not ok:
            raise TimeoutError(f"block {blk} not acked")
        off += len(chunk)
        blk += 1
        if len(chunk) < blksize:
            break


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--port", type=int, default=6969)
    ap.add_argument("--bind", default="0.0.0.0")
    a = ap.parse_args()
    root = os.path.realpath(a.dir)
    if not os.path.isdir(root):
        ap.error(f"not a directory: {root}")
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((a.bind, a.port))
    print(f"tftp serving {root} on {a.bind}:{a.port}", file=sys.stderr, flush=True)
    while True:
        try:
            data, addr = sock.recvfrom(4096)
        except KeyboardInterrupt:
            return 0
        except (socket.timeout, TimeoutError):
            continue
        if len(data) < 4:
            continue
        op = struct.unpack(">H", data[:2])[0]
        if op == OP_WRQ:
            send_error(sock, addr, 2, "read-only server")
            continue
        if op != OP_RRQ:
            send_error(sock, addr, 4, "only RRQ supported")
            continue
        fname, _mode, opts = parse_rrq(data)
        path = os.path.realpath(os.path.join(root, fname.lstrip("/")))
        if path != root and not path.startswith(root + os.sep):
            send_error(sock, addr, 2, "access violation")
            continue
        try:
            with open(path, "rb") as f:
                content = f.read()
        except OSError:
            send_error(sock, addr, 1, "file not found")
            print(f"RRQ {fname} from {addr} -> not found", file=sys.stderr, flush=True)
            continue
        print(f"RRQ {fname} from {addr} ({len(content)} bytes)", file=sys.stderr, flush=True)
        try:
            transfer(sock, addr, content, opts)
            print(f"done {fname}", file=sys.stderr, flush=True)
        except Exception as e:  # noqa: BLE001
            print(f"transfer {fname} failed: {e}", file=sys.stderr, flush=True)
            send_error(sock, addr, 0, str(e)[:100])


if __name__ == "__main__":
    sys.exit(main())
