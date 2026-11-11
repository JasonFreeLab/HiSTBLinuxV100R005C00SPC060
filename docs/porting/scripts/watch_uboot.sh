#!/usr/bin/env bash
# 持续监听串口并在板卡启动阶段发送 Ctrl-C，捕获 U-Boot 提示符，解决 bootcmd 自动启动无法停留的问题。
# 用法: watch_uboot.sh [timeout-seconds]
set -u
TMO="${1:-3600}"
SER=/dev/ttyUSB0
python3 - "$SER" "$TMO" <<'PY'
import sys, time, serial
ser, tmo = sys.argv[1], float(sys.argv[2])
s = serial.Serial(ser, 115200, timeout=0.05)
end = time.time() + tmo
buf = b""
try:
    while time.time() < end:
        s.write([b"\x03", b" ", b"\x1b", b"\r", b"\x03"][int(time.time()*10) % 5])
        time.sleep(0.05)
        d = s.read(8192)
        if d:
            buf += d
            if b"fastboot#" in buf:
                print("UBOOT_READY")
                break
finally:
    s.close()
PY
echo "watch done"
