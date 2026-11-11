#!/usr/bin/env python3
"""Parse one board test-case log and evaluate the phase criteria (INF-04).

Usage:
  parse_case.py --log LOG --rc N --criteria "received==expected;capture_errors==0" \
                --json-out DIR/parsed-attempt-1.json \
                [--cap-frames N] [--cap-bytes-kb N] [--case NAME]

Criteria grammar (all clauses must hold, separated by ";"):
  FIELD OP VALUE
  - FIELD: any key of the tool's RESULT JSON (received/expected/transport_ok/
    capture_errors/pts_errors/geometry_errors/fake_frames/...), plus:
      frames           capture file count (from --cap-frames)
      cap_frames       alias of frames
      cap_bytes_kb     capture directory size
      smoke_frames     last "frames=N" printed by vdec_test
      rc               ssh/remote exit code
      result_present   whether a RESULT JSON line was found
  - OP: == != >= <= > <   (boolean fields only support == / !=)
  - VALUE: number, true/false, another FIELD name, or a plain string
  - --metric NAME=REGEX adds a FIELD extracted from the log text (last match,
    group(1) if the regex has groups; numeric/boolean values are coerced).
    Example: --metric 'status=status=(\\w+)' --metric 'level=level=(\\d+)'
  - --warn-criteria "FIELD OP VALUE;..." is evaluated only when the main
    criteria pass; if it does not hold the case is marked WARN (never FAIL).

Examples:
  "received==expected;capture_errors==0;transport_ok==true"
  "smoke_frames>=45"
  "frames==expected"

Outputs:
  - human readable lines on stdout (verdict=..., reason=...)
  - <json-out>: machine evidence (parsed log, fields, clause results)
  - <json-out minus .json>.env: shell-safe KEY='value' lines for the orchestrator
Exit codes: 0 = PASS, 1 = FAIL (criteria not met), 2 = usage/IO error.
"""
import argparse
import json
import os
import re
import shlex
import sys

RESULT_RE = re.compile(r"\bRESULT\s+(\{.*\})\s*$", re.MULTILINE)
FRAMES_RE = re.compile(r"\bframes=(\d+)")
CLAUSE_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*(==|!=|>=|<=|>|<)\s*(.*?)\s*$")
NUM_RE = re.compile(r"^-?\d+(?:\.\d+)?$")
BOOL_RE = re.compile(r"^(true|false)$", re.IGNORECASE)


def read_text(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError as exc:
        raise SystemExit(f"parse_case: cannot read log {path}: {exc}")


def parse_text(text):
    """Return (last valid RESULT dict or None, last smoke frames count or None)."""
    result = None
    for match in RESULT_RE.finditer(text):
        try:
            candidate = json.loads(match.group(1))
        except json.JSONDecodeError:
            continue
        if isinstance(candidate, dict):
            result = candidate
    smoke = FRAMES_RE.findall(text)
    smoke_frames = int(smoke[-1]) if smoke else None
    return result, smoke_frames


def build_fields(result, rc, cap_frames, cap_bytes_kb, smoke_frames):
    fields = {}
    if result:
        fields.update(result)
    fields["result_present"] = result is not None
    fields["rc"] = rc
    fields["frames"] = cap_frames
    fields["cap_frames"] = cap_frames
    fields["cap_bytes_kb"] = cap_bytes_kb
    if smoke_frames is not None:
        fields["smoke_frames"] = smoke_frames
    return fields


def resolve_value(token, fields):
    if token in fields:
        return fields[token], True
    if BOOL_RE.match(token):
        return token.lower() == "true", True
    if NUM_RE.match(token):
        number = float(token)
        return (int(number) if number.is_integer() else number), True
    return token.strip("'\""), True


def compare(lhs, op, rhs):
    if isinstance(lhs, bool) or isinstance(rhs, bool):
        if op not in ("==", "!="):
            raise ValueError("boolean fields only support == / !=")
        return (lhs == rhs) if op == "==" else (lhs != rhs)
    if isinstance(lhs, (int, float)) and isinstance(rhs, (int, float)):
        a, b = float(lhs), float(rhs)
    else:
        a, b = str(lhs), str(rhs)
        if op not in ("==", "!="):
            raise ValueError("string fields only support == / !=")
    if op == "==":
        return a == b
    if op == "!=":
        return a != b
    if op == ">=":
        return a >= b
    if op == "<=":
        return a <= b
    if op == ">":
        return a > b
    if op == "<":
        return a < b
    raise ValueError(f"unknown operator {op}")


def evaluate(criteria, fields):
    clauses, reasons = [], []
    for raw in [c for c in criteria.split(";") if c.strip()]:
        match = CLAUSE_RE.match(raw)
        if not match:
            clauses.append({"clause": raw.strip(), "ok": False,
                            "reason": "unparseable_clause"})
            reasons.append(f"unparseable:{raw.strip()}")
            continue
        lhs_name, op, rhs_token = match.group(1), match.group(2), match.group(3)
        if lhs_name not in fields:
            clauses.append({"clause": raw.strip(), "ok": False,
                            "reason": f"missing_field:{lhs_name}"})
            reasons.append(f"missing_field:{lhs_name}")
            continue
        rhs, _ = resolve_value(rhs_token, fields)
        lhs = fields[lhs_name]
        try:
            ok = compare(lhs, op, rhs)
        except (ValueError, TypeError) as exc:
            clauses.append({"clause": raw.strip(), "ok": False,
                            "reason": f"type_error:{exc}"})
            reasons.append(f"type_error:{lhs_name}{op}{rhs_token}")
            continue
        entry = {"clause": raw.strip(), "ok": bool(ok), "lhs": lhs_name,
                 "op": op, "rhs": rhs_token, "lhs_value": lhs, "rhs_value": rhs}
        clauses.append(entry)
        if not ok:
            reasons.append(f"{lhs_name}({lhs}){op}{rhs_token}({rhs})")
    return clauses, reasons


def sanitize(key):
    return re.sub(r"[^A-Za-z0-9_]", "_", key).upper()


METRIC_NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def coerce_value(raw):
    text = str(raw).strip()
    if BOOL_RE.match(text):
        return text.lower() == "true"
    if NUM_RE.match(text):
        number = float(text)
        return int(number) if number.is_integer() else number
    return text


def apply_metrics(specs, text):
    """Extract NAME=REGEX metrics from log text -> (metrics, errors)."""
    metrics, errors = {}, []
    for spec in specs:
        if "=" not in spec:
            errors.append(f"bad_metric_spec:{spec}")
            continue
        name, regex = spec.split("=", 1)
        name = name.strip()
        if not METRIC_NAME_RE.match(name):
            errors.append(f"bad_metric_name:{name}")
            continue
        try:
            matches = re.findall(regex, text, re.MULTILINE)
        except re.error as exc:
            errors.append(f"bad_metric_regex:{name}:{exc}")
            continue
        if not matches:
            continue
        value = matches[-1]
        if isinstance(value, tuple):
            value = value[0]
        metrics[name] = coerce_value(value)
    return metrics, errors


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--log", required=True)
    ap.add_argument("--rc", type=int, default=0)
    ap.add_argument("--criteria", default="")
    ap.add_argument("--cap-frames", type=int, default=0)
    ap.add_argument("--cap-bytes-kb", type=int, default=0)
    ap.add_argument("--case", default="")
    ap.add_argument("--json-out", required=True)
    ap.add_argument("--metric", action="append", default=[], metavar="NAME=REGEX",
                    help="extract a metric from the log text (repeatable)")
    ap.add_argument("--warn-criteria", default="",
                    help="criteria evaluated only when the main criteria pass")
    args = ap.parse_args()

    text = read_text(args.log)
    result, smoke_frames = parse_text(text)
    fields = build_fields(result, args.rc, args.cap_frames,
                          args.cap_bytes_kb, smoke_frames)
    metrics, metric_errors = apply_metrics(args.metric, text)
    fields.update(metrics)
    clauses, reasons = evaluate(args.criteria, fields) if args.criteria else ([], [])
    passed = not reasons
    warn_reasons = []
    if passed and args.warn_criteria:
        _, warn_reasons = evaluate(args.warn_criteria, fields)
    warn = bool(passed and warn_reasons)
    metrics_summary = ";".join(f"{key}={value}" for key, value in metrics.items())

    payload = {
        "case": args.case,
        "log": os.path.abspath(args.log),
        "rc": args.rc,
        "criteria": args.criteria,
        "pass": passed,
        "reasons": reasons,
        "clauses": clauses,
        "metrics": metrics,
        "metric_errors": metric_errors,
        "warn_criteria": args.warn_criteria,
        "warn": warn,
        "warn_reasons": warn_reasons,
        "result": result,
        "smoke_frames": smoke_frames,
        "fields": {k: v for k, v in fields.items()
                   if not isinstance(v, (dict, list))},
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.json_out)), exist_ok=True)
    with open(args.json_out, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    env_path = re.sub(r"\.json$", "", args.json_out) + ".env"
    lines = [
        f"PASS={'true' if passed else 'false'}",
        f"REASON={shlex.quote('; '.join(reasons) if reasons else 'all criteria met')}",
        f"RC={args.rc}",
        f"CAP_FRAMES={args.cap_frames}",
        f"CAP_BYTES_KB={args.cap_bytes_kb}",
        f"SMOKE_FRAMES={shlex.quote('' if smoke_frames is None else str(smoke_frames))}",
        f"WARN={'true' if warn else 'false'}",
        f"WARN_REASON={shlex.quote('; '.join(warn_reasons))}",
        f"METRICS_SUMMARY={shlex.quote(metrics_summary)}",
    ]
    for key, value in metrics.items():
        lines.append(f"M_{sanitize(key)}={shlex.quote(str(value))}")
    for key, value in fields.items():
        if isinstance(value, (dict, list)):
            value = json.dumps(value, ensure_ascii=False)
        lines.append(f"R_{sanitize(key)}={shlex.quote(str(value))}")
    with open(env_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")

    print(f"verdict={'PASS' if passed else 'FAIL'}")
    print(f"reason={'; '.join(reasons) if reasons else 'all criteria met'}")
    interesting = ("expected", "received", "capture_errors", "transport_ok",
                   "pts_errors", "geometry_errors", "fake_frames",
                   "frames", "smoke_frames", "rc")
    for key in interesting:
        if key in fields:
            print(f"_k {key}={fields[key]}")
    for key, value in metrics.items():
        print(f"_m {key}={value}")
    if warn:
        print(f"warn=true reason={'; '.join(warn_reasons)}")
    return 0 if passed else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SystemExit as exc:
        if isinstance(exc.code, str):
            print(exc.code, file=sys.stderr)
            sys.exit(2)
        raise
