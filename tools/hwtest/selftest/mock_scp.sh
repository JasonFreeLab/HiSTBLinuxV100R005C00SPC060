#!/usr/bin/env bash
# Host-side mock of `scp` (download direction only) for run_phase.sh selftest.
# Translates <board>:/root/... into $MOCK_ROOT/root/... and copies locally.
set -u
ROOT="${MOCK_ROOT:?MOCK_ROOT must be set}"
src=""
dst=""
i=0
args=("$@")
while [ "$i" -lt "${#args[@]}" ]; do
  arg="${args[$i]}"
  case "$arg" in
    -*) ;;
    *:*)
      src="$arg"
      if [ $((i + 1)) -lt "${#args[@]}" ]; then
        dst="${args[$((i + 1))]}"
      fi
      ;;
  esac
  i=$((i + 1))
done
if [ -z "$src" ] || [ -z "$dst" ]; then
  printf 'mock_scp: cannot parse args: %s\n' "$*" >&2
  exit 2
fi
remote="${src#*:}"
remote=$(printf '%s' "$remote" | sed -e "s#/root#$ROOT/root#g")
mkdir -p "$(dirname "$dst")"
if printf '%s' "$remote" | grep -q '[*?]'; then
  # 远程 glob（scp 远程路径由远端 shell 展开）
  eval "cp -f $remote \"$dst\"" || exit $?
  exit 0
fi
cp -f "$remote" "$dst"
exit $?
