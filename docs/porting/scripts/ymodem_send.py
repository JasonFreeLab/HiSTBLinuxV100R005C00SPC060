#!/usr/bin/env python3
"""通过串口用 YMODEM-1K(CRC) 向 U-Boot loady 发送文件。

用法:
    # 纯 YMODEM（对端已就绪、等待 C）
    ymodem_send.py --port /dev/ttyUSB0 --baud 115200 --file out/uImage --name uImage

    # 自动发送 loady 命令再传输
    ymodem_send.py --port /dev/ttyUSB0 --file out/uImage --name uImage \
        --cmd "loady 0x1FFFFC0"
"""
import argparse
import struct
import sys
import time

import serial

SOH = 0x01
STX = 0x02
EOT = 0x04
ACK = 0x06
NAK = 0x15
CAN = 0x18
C = 0x43


def crc16(data: bytes) -> int:
    crc = 0
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


class YModemSender:
    def __init__(self, port, baud, log=sys.stderr):
        self.ser = serial.Serial(port, baud, timeout=0.05)
        self.log = log
        self.sent = 0
        self.expect = None
        self.console_baud = baud
        self.load_baud = 0

    def close(self):
        self.ser.close()

    def switch_baud(self, baud):
        self.ser.close()
        time.sleep(0.2)
        self.ser = serial.Serial(self.ser.port, baud, timeout=0.05)

    def wait_byte(self, targets, timeout=10.0):
        end = time.time() + timeout
        while time.time() < end:
            b = self.ser.read(1)
            if not b:
                continue
            val = b[0]
            if targets is None or val in targets:
                return val
        return None

    def send_block(self, seq, payload, long_block=False, label=""):
        kind = STX if long_block else SOH
        n = 1024 if long_block else 128
        data = payload[:n]
        if len(data) < n:
            data += b"\x1a" * (n - len(data))
        pkt = bytes([kind, seq & 0xFF, 0xFF - (seq & 0xFF)]) + data + \
            struct.pack(">H", crc16(data))
        for _ in range(10):
            self.ser.write(pkt)
            resp = self.wait_byte({ACK, NAK, CAN}, timeout=10.0)
            if resp == ACK:
                return
            if resp == CAN:
                raise SystemExit(f"FAIL: receiver cancelled at {label or seq}")
            # NAK or timeout -> resend
        raise SystemExit(f"FAIL: no ACK for {label or seq}")

    def transfer(self, path, name):
        data = open(path, "rb").read()
        header = f"{name}".encode() + b"\x00" + str(len(data)).encode() + b"\x00"
        # 等待接收端 'C'，同时把 U-Boot 文本回显出来，并校验下载地址
        text = b""
        deadline = time.time() + 60.0
        while time.time() < deadline:
            b = self.ser.read(1)
            if not b:
                continue
            if b[0] == C:
                break
            text += b
            if self.load_baud and b"Switch baudrate" in text:
                self.log.write(text.decode(errors="replace"))
                self.switch_baud(self.load_baud)
                self.ser.write(b"\r")
                text = b""
        else:
            raise SystemExit("FAIL: no 'C' handshake; U-Boot text:\n" +
                             text.decode(errors="replace"))
        txt = text.decode(errors="replace")
        if txt.strip():
            self.log.write("U-Boot: " + txt.replace("\r", "\n") + "\n")
        import re
        m = re.search(r"download\s+to\s+0x([0-9A-Fa-f]+)", txt)
        if m:
            addr = int(m.group(1), 16)
            self.log.write(f"U-Boot load address: 0x{addr:X}\n")
            if self.expect is not None and addr != self.expect:
                raise SystemExit(
                    f"FAIL: U-Boot address 0x{addr:X} != expected 0x{self.expect:X}")
        elif self.expect is not None:
            raise SystemExit("FAIL: could not parse U-Boot load address; text:\n" + txt)
        self.send_block(0, header, long_block=False, label="header")
        self.log.write(f"YMODEM: header sent ({name}, {len(data)} bytes)\n")
        seq = 1
        off = 0
        while off < len(data):
            chunk = data[off:off + 1024]
            self.send_block(seq, chunk, long_block=True, label=f"block {seq}")
            off += len(chunk)
            seq += 1
            self.sent += len(chunk)
            if seq % 100 == 1:
                self.log.write(f"YMODEM: {off}/{len(data)} bytes\n")
                self.log.flush()
        # EOT
        for _ in range(5):
            self.ser.write(bytes([EOT]))
            if self.wait_byte({ACK}, timeout=3.0) == ACK:
                break
        else:
            raise SystemExit("FAIL: EOT not ACKed")
        # 若 loady 切换过波特率，U-Boot 会切回控制台波特率并等待 ESC
        if self.load_baud:
            time.sleep(0.3)
            self.switch_baud(self.console_baud)
            self.ser.write(b"\x1b")
        else:
            # 可选的批结束块
            if self.wait_byte({C}, timeout=2.0) == C:
                self.send_block(0, b"", long_block=False, label="batch-end")
        self.log.write(f"YMODEM: done, {len(data)} bytes sent\n")
        self.log.flush()
        return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", required=True)
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--file", required=True)
    ap.add_argument("--name", default="uImage")
    ap.add_argument("--cmd", default=None, help="可选：先发送该 U-Boot 命令（如 loady 0x1FFFFC0）")
    ap.add_argument("--expect", type=lambda x: int(x, 0), default=None,
                    help="期望的 U-Boot 下载地址（十六进制），不匹配则中止")
    ap.add_argument("--load-baud", type=int, default=0,
                    help="loady 传输使用的波特率（0=不切换，保持控制台 115200）")
    a = ap.parse_args()
    try:
        s = YModemSender(a.port, a.baud)
    except Exception as e:  # noqa: BLE001
        print(f"FAIL: open {a.port}: {e}", file=sys.stderr)
        return 2
    try:
        s.expect = a.expect
        s.load_baud = a.load_baud
        if a.cmd and a.load_baud and a.cmd.strip().startswith("loady"):
            a.cmd = a.cmd.rstrip() + " " + str(a.load_baud)
        if a.cmd:
            s.ser.write(b"\r")
            time.sleep(0.5)
            s.ser.write((a.cmd + "\r").encode())
            s.ser.flush()
        return s.transfer(a.file, a.name)
    finally:
        s.close()


if __name__ == "__main__":
    sys.exit(main())
