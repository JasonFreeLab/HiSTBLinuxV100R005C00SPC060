#!/bin/bash
# install.sh —— DEP-01/DEP-02：把 hi-accel 部署到板卡（脚本 + 可选载荷），支持自检失败自动回滚
#
# 用法（主机上执行）：
#   install.sh [root@IP] [--payload DIR] [--enable] [--start] [--no-rollback]
#   install.sh [root@IP] --rollback            # 回滚到上一次安装前的备份
#   install.sh [root@IP] --verify              # 只校验板上件 sha1
#   在解开的发布包里：./scripts/install.sh root@IP --payload ./payload --enable --start
#
# 流程：
#   1. 主机侧：bash -n 脚本；若给了 --payload，先按 manifest 校验载荷 sha1（不符拒绝部署）
#   2. 板上：把当前已安装的脚本/配置/manifest 与 HI_DIR 中受管文件备份到 /var/lib/hi-accel/backup/<时间>
#   3. 安装新脚本与载荷（载荷写 HI_DIR；已有 /etc/hi-accel.conf 时只合并新增键，不覆盖用户值）
#   4. 板上按 manifest 校验 sha1（不符 → 回滚）
#   5. --start：重启 hi-accel.service 并读取 /run/hi-accel/status；state!=PASS → 回滚并重启旧版本
# 退出码：0=成功；1=校验失败或已回滚；2=用法错误。
set -eu
HOST=root@192.168.2.10
ENABLE=0; START=0; PAYLOAD=""; ROLLBACK_ONLY=0; VERIFY_ONLY=0; AUTO_RB=1
while [ "$#" -gt 0 ]; do
  case "$1" in
    --enable) ENABLE=1 ;;
    --start) START=1 ;;
    --payload) PAYLOAD=$(cd "$2" && pwd); shift ;;
    --rollback) ROLLBACK_ONLY=1 ;;
    --verify) VERIFY_ONLY=1 ;;
    --no-rollback) AUTO_RB=0 ;;
    *@*) HOST="$1" ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done
D=$(cd "$(dirname "$0")" && pwd)
SSH="ssh -o BatchMode=yes -o ConnectTimeout=8"
log() { echo "[install] $*"; }

# 板上辅助脚本：backup / rollback / verify（通过 stdin 传入执行）
remote_lib='
set -u
. /etc/hi-accel.conf 2>/dev/null || HI_DIR=/root/m2
BK=/var/lib/hi-accel/backup
SYS="/usr/local/sbin/hi-accel-load.sh /usr/local/bin/hi-vdec-run /usr/local/bin/hi_jpeg /usr/local/bin/hi_png /usr/local/bin/hi-imgdec /etc/systemd/system/hi-accel.service /etc/hi-accel.manifest /etc/hi-accel.conf"
managed() { awk "!/^#/ && NF==2 {print \$2}" /etc/hi-accel.manifest 2>/dev/null; }
do_backup() {
  local d="$BK/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$d/hi"
  # 用 tar 保留绝对路径（文件名含下划线，不能用 tr / _ 编码）
  local ex=""; for f in $SYS; do [ -e "$f" ] && ex="$ex ${f#/}"; done
  [ -n "$ex" ] && tar -C / -cpf "$d/sys.tar" $ex
  for f in $(managed); do [ -e "$HI_DIR/$f" ] && cp -p "$HI_DIR/$f" "$d/hi/"; done
  ln -sfn "$d" "$BK/last"; echo "backup=$d"
  ls -1dt "$BK"/2* 2>/dev/null | tail -n +4 | xargs -r rm -rf   # 只保留最近 3 份
}
do_rollback() {
  local d; d=$(readlink -f "$BK/last" 2>/dev/null) || true
  [ -n "$d" ] && [ -d "$d" ] || { echo "rollback: 无备份"; return 1; }
  # 先删掉本次新装、备份里没有的入口脚本，再解回备份
  for f in $SYS; do tar -tf "$d/sys.tar" "${f#/}" >/dev/null 2>&1 || rm -f "$f"; done
  [ -f "$d/sys.tar" ] && tar -C / -xpf "$d/sys.tar"
  for f in "$d"/hi/*; do [ -e "$f" ] || continue; cp -p "$f" "$HI_DIR/.$(basename "$f").rb" && mv -f "$HI_DIR/.$(basename "$f").rb" "$HI_DIR/$(basename "$f")"; done
  systemctl daemon-reload; echo "rolled_back_to=$d"
}
do_verify() {
  local bad=0 s f a
  while read -r s f; do case "$s" in \#*|"") continue;; esac
    a=$(sha1sum "$HI_DIR/$f" 2>/dev/null | cut -c1-40)
    case "$a" in "$s"*) echo "OK   $f";; *) echo "BAD  $f (actual=${a:0:8} expect=${s:0:8})"; bad=1;; esac
  done < /etc/hi-accel.manifest
  return $bad
}
'
rcall() { $SSH "$HOST" "bash -s" <<EOF
$remote_lib
$1
EOF
}

if [ "$VERIFY_ONLY" = 1 ]; then rcall do_verify; exit $?; fi
if [ "$ROLLBACK_ONLY" = 1 ]; then
  rcall 'do_rollback && systemctl restart hi-accel.service; cat /run/hi-accel/status 2>/dev/null'
  exit $?
fi

# 1) 主机侧预检
for f in hi-accel-load.sh hi-vdec-run hi_jpeg hi_png; do bash -n "$D/$f"; done
if [ -n "$PAYLOAD" ]; then
  log "校验载荷 $PAYLOAD"
  ( cd "$PAYLOAD" && awk '!/^#/ && NF==2 {print $1"  "$2}' "$D/hi-accel.manifest" | sha1sum -c --quiet ) \
    || { echo "install: 载荷 sha1 与 manifest 不符，拒绝部署" >&2; exit 1; }
fi

# 2) 备份
rcall do_backup

# 3) 安装脚本（conf 已存在则保留用户配置）
tar -C "$D" -cf - hi-accel-load.sh hi-vdec-run hi_jpeg hi_png hi-accel.service hi-accel.conf hi-accel.manifest \
  | $SSH "$HOST" 'set -e; t=$(mktemp -d); tar -C "$t" -xf -
      install -m 0755 "$t/hi-accel-load.sh" /usr/local/sbin/hi-accel-load.sh
      install -m 0755 "$t/hi-vdec-run"      /usr/local/bin/hi-vdec-run
      install -m 0755 "$t/hi_jpeg"          /usr/local/bin/hi_jpeg
      install -m 0755 "$t/hi_png"           /usr/local/bin/hi_png
      rm -f /usr/local/bin/hi-imgdec   # 已拆分为 hi_jpeg / hi_png
      install -m 0644 "$t/hi-accel.service" /etc/systemd/system/hi-accel.service
      install -m 0644 "$t/hi-accel.manifest" /etc/hi-accel.manifest
      if [ -e /etc/hi-accel.conf ]; then
        # 合并新增键（不覆盖用户已有值）：r4 新增 HI_LOAD_TDE/HI_TDE_KO 时必须能带上去
        for k in $(sed -n "s/^\([A-Z_][A-Z0-9_]*\)=.*/\1/p" "$t/hi-accel.conf" | sort -u); do
          grep -q "^$k=" /etc/hi-accel.conf || { echo "# merged r4" >> /etc/hi-accel.conf; grep "^$k=" "$t/hi-accel.conf" >> /etc/hi-accel.conf; }
        done
      else
        install -m 0644 "$t/hi-accel.conf" /etc/hi-accel.conf
      fi
      rm -rf "$t"; systemctl daemon-reload; echo "scripts installed on $(hostname)"'

# 3b) 载荷：先写 .new 再原子 mv
if [ -n "$PAYLOAD" ]; then
  HI_DIR=$($SSH "$HOST" '. /etc/hi-accel.conf; echo "$HI_DIR"')
  files=$(awk '!/^#/ && NF==2 {print $2}' "$D/hi-accel.manifest")
  # shellcheck disable=SC2086
  tar -C "$PAYLOAD" -cf - $files | $SSH "$HOST" "set -e; mkdir -p '$HI_DIR'; t=\$(mktemp -d '$HI_DIR/.inst.XXXX'); tar -C \"\$t\" -xf -
      for f in \$(ls \"\$t\"); do mv -f \"\$t/\$f\" '$HI_DIR/'\"\$f\"; done; rmdir \"\$t\"; echo payload installed to '$HI_DIR'"
fi

# 4) 板上校验
rb() {
  [ "$AUTO_RB" = 1 ] || { log "已禁用自动回滚（--no-rollback）"; exit 1; }
  log "回滚：$1"
  rcall 'do_rollback; systemctl restart hi-accel.service 2>/dev/null; cat /run/hi-accel/status 2>/dev/null'
  exit 1
}
rcall do_verify || rb "板上 sha1 校验失败"

[ "$ENABLE" = 1 ] && $SSH "$HOST" 'systemctl enable hi-accel.service'
# 5) 启动自检
if [ "$START" = 1 ]; then
  st=$($SSH "$HOST" 'systemctl restart hi-accel.service; cat /run/hi-accel/status' || true)
  log "status: $st"
  case "$st" in state=PASS*) ;; *) rb "hi-accel 自检未通过" ;; esac
fi
log "完成"
exit 0
