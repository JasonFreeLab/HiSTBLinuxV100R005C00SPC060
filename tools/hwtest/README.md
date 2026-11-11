# tools/hwtest — 板卡测试基础设施

## board_ctl.py（INF-01/INF-02 workaround）

板卡 reboot 在本机不稳定（`systemctl reboot` 偶发不生效；`reboot -f` 后不自动回来），
且串口复位后 `ssh.socket`/`ssh` 可能不自启。本工具用"SSH + 串口（ttyUSB0 控制台 / ttyUSB1 RTS 复位）"
自动恢复板卡，供所有测试脚本复用。

```sh
python3 tools/hwtest/board_ctl.py status        # 板卡状态（uptime/boot_id）
python3 tools/hwtest/board_ctl.py reboot        # 重启并在失败时自动 RTS 复位/拉起 SSH
python3 tools/hwtest/board_ctl.py reset         # 直接 RTS 复位并等待 SSH
python3 tools/hwtest/board_ctl.py ensure-ssh    # 不通则用串口执行 systemctl start ssh.socket ssh
python3 tools/hwtest/board_ctl.py serial-cmd 'uptime; systemctl is-active ssh'   # 串口执行命令
python3 tools/hwtest/board_ctl.py serial-log 10 # 抓 10s 串口日志
```

环境变量：`BOARD`（默认 `root@192.168.2.10`）、`BOARD_CONSOLE`（默认 `/dev/ttyUSB0`）、
`BOARD_RESET`（默认 `/dev/ttyUSB1`）。

### 实测记录（详见 docs/porting/artifacts/hwtest-2026-11-07/fixes/inf-01/）

- 2026-11-07 22:47：`systemctl reboot --no-block` 正常（SSH 约 2 min 恢复）。
- 23:00 起：多次 `systemctl reboot` 不生效 / 掉线后不回；`reboot -f` 不自动回来；**RTS 复位可恢复**。
- 00:07 / 00:10（本工具自动流程）：reboot 后 100–120 s 未回 → 自动 RTS 脉冲 → 新 boot_id、SSH 恢复，全程无需人工。
- 00:10 抓串口日志确认复位后 BootROM→systemd 启动完整；`ensure-ssh` 可在 SSH 不自启时用串口拉起。

### 说明/限制

- 典型 boot：内核 ~17 s + 用户态 ~14 s；RTS 复位后 SSH 通常在 25–40 s 内可用。
- `reboot` 子命令默认等待 75 s（`--timeout` 可调），超时自动复位；日志会打印 `before/rebooted/forcing RTS reset` 便于取证。
- **根因未修**（INF-01 仍列 P0）：需要对照 BL31/ATF 复位路径与 systemd shutdown 日志；本工具是 workaround。
- 依赖：主机 `python3` + `pyserial`（已安装）、`ssh`，串口设备 `/dev/ttyUSB0`/`/dev/ttyUSB1`。

## run_phase.sh（INF-04 阶段编排）

一条命令完成 `reboot → insmod → 测试 → 抓帧/取证 → 对比`；阶段定义在 `phases/`。

```sh
./tools/hwtest/run_phase.sh --list
./tools/hwtest/run_phase.sh vdec_h264_smoke --dry-run                  # 只打印计划，不碰板卡
./tools/hwtest/run_phase.sh vdec_h264_smoke                            # clean boot 全自动跑
./tools/hwtest/run_phase.sh vdec_h264_smoke --no-reboot --only smoke   # 当前 boot 快检
```

- 证据默认写入 `docs/porting/artifacts/hwtest-2026-11-07/auto/<phase>-<timestamp>/`
  （`SUMMARY.md` + `results.csv` + 每用例原始日志/解析结果/像素比对/环境快照）。
- 失败策略：用例内重试（0 帧重试 N 次）→ 仍失败则 reboot 1 次后复测失败用例 → 再判 FAIL。
- 阶段定义格式、判据语法、证据结构、已验证/未验证项见
  `docs/porting/artifacts/hwtest-2026-11-07/fixes/inf-04/FIX-REPORT.md`。
- 主机侧自检（mock 板卡，不接触真板、不 reboot/insmod）：
  `./tools/hwtest/selftest/run_selftest.sh`。

### 已交付阶段（INF-04 / INF-04b / INF-04c / INF-04d）

| 阶段 | 用途 | boot | 上板状态 |
|---|---|---|---|
| `vdec_h264_smoke` | VDEC H.264 smoke + 1080p BP 抓帧 + 逐帧 Y sha1 | clean | ✅ Lead 已端到端 PASS（`auto/vdec_h264_smoke-20261108-005210/`） |
| `venc_h264_smoke` | VENC H.264 HP/CBR 90 帧 + ffprobe/ffmpeg + 内容时间码率 WARN（模块 `hi_venc_venc06b.ko` 0d95a512） | clean | ✅ 曾 PASS（旧模块，`auto/venc_h264_smoke-20261108-012518/`）；新模块待复跑 |
| `jpeg_smoke` | JPEG 同一 handle loops=100（rc=0、5–11ms、YUV sha1 一致） | clean（JPEG 独立 boot） | ✅ Lead 已上板 PASS（`auto/jpeg_smoke-20261108-012733/`） |
| `png_hist` | PNG 历史 head 复现（hi_png_nb + png_test8，HEAD_OK；整幅不要求） | clean（每 boot 一次） | ✅ Lead 已上板 PASS（`auto/png_hist-20261108-013126/`） |
| `venc_hevc_smoke` | VENC HEVC CBR 90 帧（`hi_venc_venc06b.ko` 0d95a512，level=120；码率只记 WARN） | clean | ✅ Lead 已上板 PASS（`auto/venc_hevc_smoke-20261108-022100/`，0d95a512） |
| `png_sw64mp` | PNG 软件兜底 64MP（板上 ffmpeg 解码 192MB，md5 与主机参考一致；耗时只记 WARN） | clean（无模块） | ✅ Lead 已上板 PASS（`auto/png_sw64mp-20261108-022506/`，11.74 s） |
| `vdec_hevc_4k` | VDEC HEVC 4K60 8bit 20 帧 + 抓帧 1 帧像素 bit-exact（新验收对 head_w1 047cad9b + vdec_spec_hevc_head 6ada1250，`m2_sync_hevc_msgs=1`） | clean | 🟡 待上板（INF-04d，**预期 PASS**） |
| `vdec_hevc_smoke` | VDEC HEVC smoke：1080p Main 20 帧 + 4K60 Main10 8 帧（同上新验收对） | clean | 🟡 待上板（INF-04d，**预期 PASS**） |

旧 `vdec_4k_noVcmp`（ok64 + known-issue WARN）已删除，历史证据保留在 `auto/vdec_4k_noVcmp-20261108-022907/`。
新阶段设计/判据/上板命令见
`docs/porting/artifacts/hwtest-2026-11-07/fixes/inf-04/PHASES.md`。
新增阶段 DSL 能力：`--metric NAME=REGEX`（日志指标）、`--warn-if`（只记 WARN）、`--fetch GLOB`（回传产物）、`--host-check CMD`（主机侧后处理）。
码率口径：`lib/venc_check.py` 用**内容时间** `bytes*8*fps/submitted`（`--fps`，保留 `wall_bitrate_kbps` 参考）。
