#!/usr/bin/env python3
"""uboot_serial.py 的回归测试：用 pty 模拟 U-Boot 串口，验证命令发送与输出抓取。"""
import os
import pty
import select
import subprocess
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "uboot_serial.py")


def uboot_emulator(master_fd, stop):
    """模拟 fastboot# 提示符：回显命令并输出一行标记。"""
    buf = b""
    os.write(master_fd, b"\r\nfastboot# ")
    while not stop.is_set():
        r, _, _ = select.select([master_fd], [], [], 0.1)
        if not r:
            continue
        try:
            chunk = os.read(master_fd, 1024)
        except OSError:
            return
        if not chunk:
            return
        buf += chunk
        while b"\n" in buf or b"\r" in buf:
            for sep in (b"\r", b"\n"):
                if sep in buf:
                    line, buf = buf.split(sep, 1)
                    break
            else:
                break
            try:
                cmd = line.decode(errors="replace").strip()
            except Exception:
                continue
            if not cmd:
                continue
            os.write(master_fd, (f"\r\n{cmd}: emulated-ok\r\nfastboot# ").encode())


def main():
    fails = []
    master, slave = pty.openpty()
    stop = threading.Event()
    t = threading.Thread(target=uboot_emulator, args=(master, stop), daemon=True)
    t.start()
    time.sleep(0.3)
    slave_name = os.ttyname(slave)

    try:
        p = subprocess.run(
            [sys.executable, TOOL, "--port", slave_name, "--baud", "115200",
             "--cmd", "version", "--timeout", "3"],
            capture_output=True, text=True, timeout=20)
        out = p.stdout + p.stderr
        if p.returncode != 0:
            fails.append(f"tool rc={p.returncode}: {out[-500:]}")
        elif "version: emulated-ok" not in out:
            fails.append(f"missing emulated echo: {out[-500:]}")
        else:
            print("PASS: command sent and output captured")
    except Exception as e:
        fails.append(f"exception: {e!r}")
    finally:
        stop.set()
        os.close(slave)
        os.close(master)

    if fails:
        for f in fails:
            print("FAIL:", f)
        return 1
    print("ALL TESTS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
