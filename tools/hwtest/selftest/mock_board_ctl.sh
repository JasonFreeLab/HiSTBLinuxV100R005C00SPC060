#!/usr/bin/env bash
# Host-side mock of board_ctl.py for run_phase.sh selftest.
# Simulates status / reboot / reset / ensure-ssh against $MOCK_ROOT/state/boot-epoch.
set -u
ROOT="${MOCK_ROOT:?MOCK_ROOT must be set}"
STATE="$ROOT/state"
mkdir -p "$STATE"

cmd="${1:-status}"
case "$cmd" in
  status)
    epoch=$(cat "$STATE/boot-epoch" 2>/dev/null || echo 1)
    printf 'board: UP uptime=12.0s boot_id=mock-boot-%s\n' "$epoch"
    exit 0
    ;;
  reboot|reset)
    epoch=$(( $(cat "$STATE/boot-epoch" 2>/dev/null || echo 1) + 1 ))
    printf '%s\n' "$epoch" > "$STATE/boot-epoch"
    printf 'mock-boot-%s\n' "$epoch" > "$ROOT/proc/sys/kernel/random/boot_id"
    printf '12.0 0.0\n' > "$ROOT/proc/uptime"
    # 真实 reboot 不保留任何已加载模块（模块换载一律 reboot）
    rm -rf "$ROOT/sys/module"/* 2>/dev/null || true
    : > "$STATE/lsmod"
    printf 'mock board_ctl %s -> boot mock-boot-%s (board: UP)\n' "$cmd" "$epoch"
    exit 0
    ;;
  ensure-ssh)
    printf 'ensure_ssh: True (mock)\n'
    exit 0
    ;;
  *)
    printf 'mock_board_ctl: unhandled: %s\n' "$*" >&2
    exit 99
    ;;
esac
