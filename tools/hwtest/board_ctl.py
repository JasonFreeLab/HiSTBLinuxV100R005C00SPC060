#!/usr/bin/env python3
"""Hi3798MV300 board control helper (INF-01/INF-02 workaround).

Subcommands:
  status                 print board state (ssh/uptime/boot_id)
  reboot [--timeout N]   sync+systemctl reboot; wait; if not back -> RTS reset; ensure SSH
  reset                  pulse /dev/ttyUSB1 RTS, wait for SSH, start ssh over serial if needed
  ensure-ssh             try SSH; if refused, start ssh.socket/ssh over serial console
  serial-cmd CMD         run CMD on serial console, print output
  serial-log [SECONDS]   dump serial console for SECONDS (default 10)

Environment overrides: BOARD (default root@192.168.2.10), BOARD_CONSOLE (/dev/ttyUSB0),
BOARD_RESET (/dev/ttyUSB1).
"""
import argparse
import os
import subprocess
import sys
import time

BOARD = os.environ.get("BOARD", "root@192.168.2.10")
CONSOLE = os.environ.get("BOARD_CONSOLE", "/dev/ttyUSB0")
RESET = os.environ.get("BOARD_RESET", "/dev/ttyUSB1")
SSH_OPTS = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=4",
            "-o", "StrictHostKeyChecking=no"]


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def ssh(cmd, timeout=15):
    try:
        r = subprocess.run(["ssh"] + SSH_OPTS + [BOARD, cmd],
                           capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout.strip(), r.stderr.strip()
    except Exception as exc:  # noqa: BLE001 - report as unreachable
        return 255, "", str(exc)


def board_state():
    rc, out, err = ssh("cut -d' ' -f1 /proc/uptime; cat /proc/sys/kernel/random/boot_id")
    if rc != 0:
        return None
    lines = out.splitlines()
    try:
        return {"uptime": float(lines[0]), "boot_id": lines[1] if len(lines) > 1 else "?"}
    except (ValueError, IndexError):
        return None


def wait_ssh(timeout=150):
    t0 = time.time()
    while time.time() - t0 < timeout:
        state = board_state()
        if state:
            return state
        time.sleep(3)
    return None


def serial_open():
    import serial  # pyserial is available on this host
    return serial.Serial(CONSOLE, 115200, timeout=0.3)


def serial_reset(pulse=0.4):
    import serial
    s = serial.Serial(RESET, 115200, timeout=0.2)
    s.rts = True
    time.sleep(pulse)
    s.rts = False
    time.sleep(0.2)
    s.close()
    log(f"RTS reset pulse sent on {RESET}")


def serial_cmd(cmd, wait=5.0):
    s = serial_open()
    time.sleep(0.3)
    s.write(b"\r\n")
    time.sleep(0.5)
    s.read(65536)
    s.write((cmd + "\r").encode())
    time.sleep(wait)
    buf = b""
    t0 = time.time()
    while time.time() - t0 < wait:
        chunk = s.read(8192)
        if chunk:
            buf += chunk
        else:
            time.sleep(0.1)
    s.close()
    return buf.decode("utf-8", "replace")


def serial_log(seconds=10):
    s = serial_open()
    buf = b""
    t0 = time.time()
    while time.time() - t0 < seconds:
        chunk = s.read(8192)
        if chunk:
            buf += chunk
    s.close()
    return buf.decode("utf-8", "replace")


def ensure_ssh():
    state = board_state()
    if state:
        return True, "ssh already up"
    log("SSH not reachable; trying to start ssh over serial console")
    out = serial_cmd("systemctl start ssh.socket ssh; systemctl is-active ssh.socket ssh")
    print(out[-1200:])
    state = wait_ssh(60)
    return bool(state), "ssh started via serial"


def cmd_status(_args):
    state = board_state()
    if not state:
        print("board: DOWN (ssh unreachable)")
        return 1
    print(f"board: UP uptime={state['uptime']:.1f}s boot_id={state['boot_id']}")
    return 0


def cmd_reset(args):
    serial_reset()
    time.sleep(25)
    state = wait_ssh(args.timeout)
    if state:
        print(f"board: UP uptime={state['uptime']:.1f}s boot_id={state['boot_id']}")
        return 0
    ok, why = ensure_ssh()
    print(f"ensure_ssh: {ok} ({why})")
    return 0 if ok else 1


def cmd_ensure_ssh(_args):
    ok, why = ensure_ssh()
    print(f"ensure_ssh: {ok} ({why})")
    return 0 if ok else 1


def _wait_new_boot(before, timeout):
    t0 = time.time()
    while time.time() - t0 < timeout:
        state = board_state()
        if state and (before is None or state["boot_id"] != before["boot_id"]) and state["uptime"] < 300:
            log(f"board back: uptime={state['uptime']:.1f}s boot_id={state['boot_id']}")
            return 0
        time.sleep(3)
    return 1


def cmd_reboot(args):
    """重启板卡。

    INF-01（2026-11-10 复核）：本内核/BL31 的软复位路径不可用——
    `systemctl reboot` 完成 systemd shutdown 后板卡停在**无输出、不 ping、SSH 不可达**的
    死状态（串口静默），`reboot -f` 同样如此；两次实测均需 RTS 硬复位才能恢复
    （`--soft` 仍会等 150s 再兜底）。因此默认走 **sync + RTS 硬复位** 的快路径：
    先 `sync; sync` 落盘（降低硬复位对 rootfs 的损坏风险），再拉 RTS，通常 40–60s 回板。
    """
    before = board_state()
    if before:
        log(f"before: uptime={before['uptime']:.1f}s boot_id={before['boot_id']}")
    else:
        log("board unreachable before reboot; using reset path")

    rc = 255
    if before:
        rc, out, err = ssh("sync; sync; sleep 1; echo synced", timeout=25)
        log(f"sync rc={rc} out={out!r} err={err!r}")
        if rc != 0:
            log("sync over ssh failed; resetting anyway (INF-01)")

    serial_reset()
    if _wait_new_boot(before, args.timeout) == 0:
        return 0
    log("board did not come back after reset")
    return 1


def cmd_serial_cmd(args):
    print(serial_cmd(" ".join(args.cmd), wait=args.wait))
    return 0


def cmd_serial_log(args):
    sys.stdout.write(serial_log(args.seconds))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("status")
    p.set_defaults(func=cmd_status)

    p = sub.add_parser("reboot")
    p.add_argument("--timeout", type=int, default=150)
    p.add_argument("--soft", action="store_true",
                   help="(保留参数) 历史上尝试 systemctl reboot；INF-01 下软复位不可用，仍走 sync+RTS")
    p.set_defaults(func=cmd_reboot)

    p = sub.add_parser("reset")
    p.add_argument("--timeout", type=int, default=150)
    p.set_defaults(func=cmd_reset)

    p = sub.add_parser("ensure-ssh")
    p.set_defaults(func=cmd_ensure_ssh)

    p = sub.add_parser("serial-cmd")
    p.add_argument("cmd", nargs=argparse.REMAINDER)
    p.add_argument("--wait", type=float, default=5.0)
    p.set_defaults(func=cmd_serial_cmd)

    p = sub.add_parser("serial-log")
    p.add_argument("seconds", type=int, nargs="?", default=10)
    p.set_defaults(func=cmd_serial_log)

    args = ap.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
