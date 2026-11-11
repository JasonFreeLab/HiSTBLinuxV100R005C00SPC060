#!/usr/bin/env python3
"""Generate SUMMARY.md for one run_phase.sh evidence directory (INF-04).

Reads results.csv (written incrementally by run_phase.sh) and meta.env
(key=value lines) and writes SUMMARY.md.  Only the standard library is used.

Usage:
  make_report.py --results results.csv --meta meta.env --out SUMMARY.md \
                 [--env environment.txt] [--env2 environment-pass2.txt] \
                 [--phase-file PATH]
Exit codes: 0 ok, 2 IO error.
"""
import argparse
import csv
import os
import sys

COLUMNS = ["phase", "case", "pass", "status", "attempts", "rc", "frames",
           "received", "expected", "capture_errors", "transport_ok",
           "pixel_ok", "pixel_frames", "smoke_frames", "boot_id",
           "duration_s", "reason", "evidence"]

STATUS_ICON = {"PASS": "✅ PASS", "FAIL": "❌ FAIL", "WARN": "⚠️ WARN",
               "SKIP": "⏭️ SKIP"}
PASS_ORDER = {"PASS": 4, "WARN": 3, "SKIP": 2, "FAIL": 1}


def read_meta(path):
    meta = {}
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.rstrip("\n")
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                meta[key.strip()] = value.strip()
    except OSError:
        pass
    return meta


def read_results(path):
    rows = []
    try:
        with open(path, "r", encoding="utf-8", errors="replace", newline="") as fh:
            for row in csv.DictReader(fh):
                rows.append(row)
    except OSError as exc:
        raise SystemExit(f"make_report: cannot read {path}: {exc}")
    return rows


def final_rows(rows):
    """Collapse retry passes: keep the best-status row per case.

    Keeps a reference to the row with the highest pass number for the same
    final status so the summary shows the successful last attempt.
    """
    best = {}
    for row in rows:
        case = row.get("case", "?")
        current = best.get(case)
        if current is None:
            best[case] = row
            continue
        cur_score = PASS_ORDER.get(current.get("status", "FAIL"), 0)
        new_score = PASS_ORDER.get(row.get("status", "FAIL"), 0)
        if new_score > cur_score:
            best[case] = row
        elif new_score == cur_score and row.get("pass", "0") > current.get("pass", "0"):
            best[case] = row
    return list(best.values())


def md_cell(value):
    text = "" if value is None else str(value)
    return text.replace("|", "\\|").replace("\n", " ")


def verdict_of(rows):
    statuses = [row.get("status", "FAIL") for row in rows]
    if any(status == "FAIL" for status in statuses):
        return "FAIL"
    if any(status == "WARN" for status in statuses):
        return "PASS (with warnings)"
    if not statuses:
        return "EMPTY"
    return "PASS"


def build_report(args):
    meta = read_meta(args.meta)
    rows = read_results(args.results)
    finals = final_rows(rows)
    # meta.env 由编排器在 finalize 时写入权威结论；行级统计仅用于计数
    verdict = meta.get("verdict") or verdict_of(finals)
    counts = {status: sum(1 for r in finals if r.get("status") == status)
              for status in ("PASS", "FAIL", "WARN", "SKIP")}

    lines = []
    lines.append(f"# 阶段运行摘要：{meta.get('phase', '?')}")
    lines.append("")
    lines.append(f"**结论：{verdict}**  "
                 f"（通过 {counts['PASS']} / 失败 {counts['FAIL']} / "
                 f"警告 {counts['WARN']} / 跳过 {counts['SKIP']}）")
    lines.append("")
    lines.append("## 基本信息")
    lines.append("")
    lines.append("| 项 | 值 |")
    lines.append("|---|---|")
    for key, label in (
            ("run_id", "run id"),
            ("phase", "阶段"),
            ("board", "板卡"),
            ("boot_mode", "boot 模式"),
            ("boot_id", "boot_id"),
            ("boot_clean", "干净 boot"),
            ("host_start", "开始（主机时间）"),
            ("host_end", "结束（主机时间）"),
            ("duration_s", "总耗时（秒）"),
            ("board_m2", "板上工具目录"),
            ("board_work", "板上工作目录"),
            ("evidence_dir", "证据目录"),
            ("phase_file", "阶段定义文件"),
            ("run_phase_sha1", "run_phase.sh sha1"),
            ("board_ctl_sha1", "board_ctl.py sha1"),
    ):
        if key in meta:
            lines.append(f"| {label} | `{md_cell(meta[key])}` |")
    lines.append("")

    lines.append("## 用例结果")
    lines.append("")
    lines.append("| 用例 | 最终状态 | pass | 尝试 | rc | frames | "
                 "received/expected | capture_errors | transport_ok | pixel | "
                 "boot_id | 耗时 | 说明 |")
    lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for row in finals:
        pixel = row.get("pixel_ok", "")
        if pixel == "true":
            pixel = f"✅ {row.get('pixel_frames', '')}"
        elif pixel == "false":
            pixel = f"❌ {row.get('pixel_frames', '')}"
        elif pixel in ("", "skipped"):
            pixel = "—"
        received = row.get("received", "")
        expected = row.get("expected", "")
        ratio = f"{received}/{expected}" if (received or expected) else "—"
        lines.append("| " + " | ".join([
            f"`{md_cell(row.get('case', ''))}`",
            STATUS_ICON.get(row.get("status", ""), row.get("status", "")),
            md_cell(row.get("pass", "")),
            md_cell(row.get("attempts", "")),
            md_cell(row.get("rc", "")),
            md_cell(row.get("frames", "")),
            md_cell(ratio),
            md_cell(row.get("capture_errors", "")),
            md_cell(row.get("transport_ok", "")),
            md_cell(pixel),
            md_cell(row.get("boot_id", "")),
            md_cell(row.get("duration_s", "")),
            md_cell(row.get("reason", "")),
        ]) + " |")
    lines.append("")

    pixel_rows = [r for r in finals if r.get("pixel_ok") in ("true", "false")]
    if pixel_rows:
        lines.append("## 像素比对（Y 平面 sha1，board 抓帧 vs 主机 ffmpeg 参考）")
        lines.append("")
        for row in pixel_rows:
            lines.append(f"- `{row.get('case')}`：pixel_ok={row.get('pixel_ok')}，"
                         f"{row.get('pixel_frames', '')}，"
                         f"证据 `{row.get('evidence', '')}`")
        lines.append("")
        lines.append("> 方法：板上对每个抓帧取前 `w*h` 字节算 sha1（= Y 平面）；"
                     "主机用 `ffmpeg ... -pix_fmt nv21` 解参考并按帧号算 Y sha1；"
                     "`lib/y_sha1_check.py` 按帧序号比对；"
                     "`lib/compare_vdec.py` 对抽样帧输出均值/最大值差异。")
        lines.append("")

    retry_rows = [r for r in rows if r.get("pass") not in ("", "1")]
    if retry_rows:
        lines.append("## 重启后复测（pass 2）")
        lines.append("")
        lines.append("| 用例 | pass | 状态 | 尝试 | rc | 说明 |")
        lines.append("|---|---|---|---|---|---|")
        for row in retry_rows:
            lines.append("| " + " | ".join([
                f"`{md_cell(row.get('case', ''))}`",
                md_cell(row.get("pass", "")),
                STATUS_ICON.get(row.get("status", ""), row.get("status", "")),
                md_cell(row.get("attempts", "")),
                md_cell(row.get("rc", "")),
                md_cell(row.get("reason", "")),
            ]) + " |")
        lines.append("")

    for env_path, title in ((args.env, "环境基线（boot 后、模块加载前）"),
                            (args.env2, "环境基线（重启后复测）")):
        if not env_path or not os.path.exists(env_path):
            continue
        lines.append(f"## {title}")
        lines.append("")
        lines.append("```text")
        try:
            with open(env_path, "r", encoding="utf-8", errors="replace") as fh:
                content = fh.read().splitlines()
        except OSError:
            content = ["(unreadable)"]
        max_lines = 80
        lines.extend(content[:max_lines])
        if len(content) > max_lines:
            lines.append(f"...（共 {len(content)} 行，完整内容见 {env_path}）")
        lines.append("```")
        lines.append("")

    lines.append("## 证据结构")
    lines.append("")
    lines.append("```text")
    ev = meta.get("evidence_dir", ".")
    lines.append(f"{ev}/")
    lines.append("├── SUMMARY.md            # 本文件")
    lines.append("├── results.csv           # 逐次运行结果（含重启后 pass=2 行）")
    lines.append("├── results-pass1.csv     # 重启前结果快照（如有重试）")
    lines.append("├── environment.txt       # boot_id/uptime/sha1/CmaFree/df/lsmod")
    lines.append("├── environment-after-load.txt")
    lines.append("├── boot.log              # board_ctl.py reboot/ensure-ssh 输出")
    lines.append("├── plan.txt              # 本次运行解析后的计划")
    lines.append("├── RUN-LOG.txt           # 编排器日志")
    lines.append("└── cases/<case>/pass-1/")
    lines.append("    ├── attempt-N.log     # 原始 stdout/stderr + dmesg VTSTAT")
    lines.append("    ├── parsed-attempt-N.json/.env")
    lines.append("    └── pixel/            # board-y-sha1.txt、host-ref-y-sha1.txt、compare.txt")
    lines.append("```")
    lines.append("")
    lines.append("## 复现")
    lines.append("")
    lines.append("```sh")
    lines.append(f"./tools/hwtest/run_phase.sh {meta.get('phase', '<phase>')}")
    lines.append("```")
    lines.append("")
    lines.append("> 判据与重试策略见 `docs/porting/artifacts/hwtest-2026-11-07/fixes/inf-04/FIX-REPORT.md`。")
    lines.append("")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--results", required=True)
    ap.add_argument("--meta", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--env", default="")
    ap.add_argument("--env2", default="")
    ap.add_argument("--phase-file", default="")
    args = ap.parse_args()
    report = build_report(args)
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write(report)
    print(f"wrote {args.out} ({len(report.splitlines())} lines)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
