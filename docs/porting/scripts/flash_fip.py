#!/usr/bin/env python3
"""用法: flash_fip.py <fip文件(在Windows TFTP根目录)> <blocks十六进制>
执行 RTS 复位 -> 抓 fastboot# -> tftp -> mmc write -> setenv bootcmd -> 复位 -> 等登录
"""
import serial, time, sys, re

TFTP_DIR = "/mnt/c/Users/yujia/Desktop/hi3798_boot"

def main():
    fip = sys.argv[1]
    blocks = int(sys.argv[2], 16)
    blocks_s = "0x%X" % blocks
    ctl = serial.Serial('/dev/ttyUSB1', 115200, timeout=0.1)
    mon = serial.Serial('/dev/ttyUSB0', 115200, timeout=0.02)

    def reset():
        ctl.rts = True; time.sleep(0.6); ctl.rts = False

    def read_until(needle, t):
        b = bytearray(); e = time.time() + t
        while time.time() < e:
            d = mon.read(65536)
            if d:
                b += d
                if needle.encode() in b:
                    return True, bytes(b)
        return False, bytes(b)

    def ensure(t=8):
        e = time.time() + t
        while time.time() < e:
            mon.write(b"\r")
            if read_until("fastboot#", 0.4)[0]:
                return True
        return False

    def cmd(c, needle, t):
        mon.reset_input_buffer()
        mon.write((" " + c + "\r").encode())
        return read_until(needle, t)

    def catch(t=30):
        b = bytearray(); e = time.time() + t; i = 0
        while time.time() < e:
            mon.write(b"\x03")
            if i % 2: mon.write(b"\r")
            i += 1; time.sleep(0.01)
            d = mon.read(65536)
            if d: b += d
            if b"fastboot#" in b: return True
        return False

    time.sleep(0.2); reset()
    ok = catch()
    if not ok:
        reset(); ok = catch(40)
    print("CATCH", ok)
    if not ok: return 1
    ensure()

    ok = False
    for i in range(4):
        ok, _ = cmd("tftp 0x1FFAE30 %s" % fip, "Bytes transferred", 220)
        print("TFTP", i, ok)
        if ok: break
        ensure()
    if not ok: return 1

    ok = False
    for i in range(4):
        ok, _ = cmd("mmc write 0 0x1FFAE30 0x7000 %s" % blocks_s, "blocks written", 100)
        print("WRITE", i, ok)
        if ok: break
        ensure()
    if not ok: return 1
    cmd("setenv bootcmd 'mmc read 0 0x1FFAE30 0x7000 %s; bootm 0x1FFAE30'; saveenv" % blocks_s, 'done', 20)
    reset()
    out = bytearray(); e = time.time() + 150; got = False; saw_boot = False
    while time.time() < e:
        d = mon.read(65536)
        if d:
            out += d
            if b"Booting Linux" in out or b"U-Boot" in out:
                saw_boot = True
            if saw_boot and b"hi3798mv300 login:" in out:
                got = True; break
    print("LOGIN", got)
    open('/tmp/last_boot.log', 'wb').write(out)
    time.sleep(4)
    ctl.close(); mon.close()
    return 0

if __name__ == '__main__':
    sys.exit(main())
