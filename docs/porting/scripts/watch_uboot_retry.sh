#!/usr/bin/env bash
# 等待串口权限可用后，持续发送 Ctrl-C 捕获 U-Boot 提示符（用于自动打断 autoboot）。
# 用法: watch_uboot_retry.sh [timeout-seconds]
set -u
TMO="${1:-3600}"
SER=/dev/ttyUSB0
python3 - "$SER" "$TMO" <<'PY'
import sys, time, serial

ser, tmo = sys.argv[1], float(sys.argv[2])
end = time.time() + tmo
s = None
try:
    while time.time() < end:
        if s is None:
            try:
                s = serial.Serial(ser, 115200, timeout=0.05)
                print("SERIAL_OPEN", flush=True)
            except Exception:
                time.sleep(2)
                continue
        try:
            s.write([b"\x03", b" ", b"\x1b", b"\r", b"\x03"][int(time.time() * 10) % 5])
            time.sleep(0.05)
            d = s.read(8192)
            if d and b"fastboot#" in d:
                print("UBOOT_READY", flush=True)
                break
        except Exception:
            try:
                s.close()
            except Exception:
                pass
            s = None
            time.sleep(1)
    else:
        print("TIMEOUT_WAITING_PROMPT", flush=True)
finally:
    try:
        if s:
            s.close()
    except Exception:
        pass
PY
