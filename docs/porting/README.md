# Hi3798MV300 Linux 7.x + Ubuntu 项目文档索引

## 快速入门
- **[QUICK-START-用户指南.md](QUICK-START-用户指南.md)** — 开机、登录（HDMI/SSH/RDP/串口）、U盘、WiFi、播放、备份、恢复

## 交付与验收
- **[FINAL-STATUS-2026-11-10.md](FINAL-STATUS-2026-11-10.md)** — **硬件加速移植最终状态（#188，2026-11-10）**：R1/R2 条目判定、证据入口、残留限制
- [HARDWARE-ACCELERATION-FIXLIST-ROADMAP-2026-11-08.md](HARDWARE-ACCELERATION-FIXLIST-ROADMAP-2026-11-08.md) / [ROADMAP-CLOSURE-MATRIX-2026-11-08.md](ROADMAP-CLOSURE-MATRIX-2026-11-08.md) — 修复清单与闭环矩阵
- [CAPABILITY-MATRIX.md](CAPABILITY-MATRIX.md)、[TOOL-MODULE-PAIRING.md](TOOL-MODULE-PAIRING.md)、[ACCEPTANCE-RULES.md](ACCEPTANCE-RULES.md) — 能力矩阵/配对/验收口径
- **[FINAL-REPORT-2026-11-01.md](FINAL-REPORT-2026-11-01.md)** — 最终交接报告（成品规格/能力清单/限制/结论）
- [FINAL-DELIVERY-2026-11-01.md](FINAL-DELIVERY-2026-11-01.md) — 最终交付说明（成果/操作/工程结论/已知问题）
- [acceptance-report-2026-11-01.md](acceptance-report-2026-11-01.md) — 验收报告 + 实拍截图
- [spec-traceability-2026-11-01.md](spec-traceability-2026-11-01.md) — 规格→实现→证据追踪矩阵
- [feasibility-remaining-features-2026-11-01.md](feasibility-remaining-features-2026-11-01.md) — 未完成功能可行性（HDMI 音频/VDEC/VENC/BT/SATA 等）
- [TDE-PORT-2026-11-10.md](TDE-PORT-2026-11-10.md) — TDE 硬件加速移植交付（与 r11 同步）
- [FIP-EXPERIMENT-2026-11-11.md](FIP-EXPERIMENT-2026-11-11.md) / [BOARD-RECOVERY-2026-11-11.md](BOARD-RECOVERY-2026-11-11.md) — FIP 实验与板卡救援/恢复记录
- [SDK-BACKFILL-2026-11-11.md](SDK-BACKFILL-2026-11-11.md) — SDK 回灌记录
- [logs/](logs/) — 保留 12 份被引用证据日志/截图；其余 210 份早期 bringup 日志已于 2026-11-11 归档（见文末「清理归档说明」）

## 构建/运维
- [runbook-build-and-boot.md](runbook-build-and-boot.md) — 构建、刷写、救援、启动优化、外设、日常配置
- [driver-technical-spec.md](driver-technical-spec.md) — 寄存器/驱动实测细节（USB2 PHY、USB3、SDIO2、AIAO 等）
- [risk-register-and-decisions.md](risk-register-and-decisions.md) — 风险与决策记录
- [display/](display/) — 显示（VDP/DRM）技术资料
- [refs/](refs/) — 厂商 xlsm 寄存器表解析
- [scripts/](scripts/) — 构建/刷写/恢复脚本

## 上位计划与规格
- `docs/superpowers/plans/2026-10-30-hi3798mv300-linux7x-ubuntu-implementation-plan.md`
- `docs/superpowers/specs/2026-10-30-hi3798mv300-linux7x-ubuntu-design.md`
- 实施流水账：`.superpowers/sdd/2026-10-30-hi3798mv300-linux7x-ubuntu-implementation-plan/progress.md`

## 当前状态速览（2026-11-02 快照，已过期 ⚠）

> **本表为 2026-11-02 历史快照，多处已被后续工作取代**（例：72h soak 口径已改 1h×3 boot；thermal/PNG/TDE 已交付；最终固件 p6 md5 已由现网 FIP sha1 `2dea80c5…` 取代）。**最新状态以 [FINAL-STATUS-2026-11-10.md](FINAL-STATUS-2026-11-10.md)、[CAPABILITY-MATRIX.md](CAPABILITY-MATRIX.md)、[ROADMAP-CLOSURE-MATRIX-2026-11-08.md](ROADMAP-CLOSURE-MATRIX-2026-11-08.md) 为准。**

| 类别 | 状态（2026-11-02 快照） |
|---|---|
| 启动/系统 | ✅ Ubuntu 26.04.1 + Linux 7.3 arm64；冷启动回归 3/3 成功（~20.5s 到 login，无 oops）；开机 3min 自检 |
| 显示/桌面 | ✅ 1080p KMS + Weston + 壁纸/5 启动器 + 截图 + Xwayland + RDP；4K 已确认不可行（无 EDID 通道） |
| 网络 | ✅ 以太网静态 IP；**WiFi：Quectel FCS850R(RTL8822CS) 模组已连接**（SSID wifi）+ 互联网；SSH/RDP/Samba 可达；WiFi 看门狗自愈 |
| 存储 | ✅ eMMC + USB2(U盘自动挂载) + Samba + 每日备份（FIP/配置/脚本/单元/drop-in） |
| 内存 | 985MB + zram 768MB 压缩交换（swap 实测在用） |
| GPU/媒体 | ✅ lima（默认 pixman，GL 可选）；1080p H.264 软解 ~25fps；WebM 页内播放；mpv wlshm 实测 OK |
| 外设 | ✅ I2C / GPIO / SPI / WDT / **thermal（自研 hwmon，63°C）**（10/11） |
| 桌面应用 | ✅ 浏览器(WebKit)/LibreOffice/PDF/图片/视频/文件管理/终端 |
| 验收 | ✅ **28 项，PASS=28 WARN=0 FAIL=0**（开机/每小时/手动） |
| 自动化 | ✅ 开机自检 + 每分钟稳定性采样 + 每小时自检 + 每日日报/备份 + WiFi 看门狗 + 无限自愈 |
| 稳定性 | ⏳ 72h 混合负载 soak（视频/CPU/网络三相）进行中 |
| 缺失 | ❌ HDMI 音频 / 4K 输出 / 4K VDEC/VENC / PWM / RTC（无 IP 文档） / SATA（无接口）；BT：新模组 UART 链路已验证但芯片无响应（待 HOST_WAKE_BT/32K 排查） |
| 最终固件 | p6 md5 `310cc74ee70d0365c32b475ea889dbac` |

---

## 历史文档（已被取代 / 纯交接，**保留在原地**以便追溯）

> 2026-11-11 清理时对这 22 篇只做状态标注、**未删除**：总大小 <1.5 MB，且部分当前文档仍引用其中篇目（删了会断链），保留成本远低于重建成本。

| 文档 | 状态 | 取代者 / 说明 |
|---|---|---|
| STATUS.md | 已被取代 | 文首自述：以闭环矩阵/能力矩阵/路线图为准 |
| HARDWARE-ACCELERATION-FIXLIST-ROADMAP-2026-11-07.md | 已被取代 | → FIXLIST-2026-11-08 |
| HARDWARE-ACCELERATION-STATUS-ROADMAP-2026-11-06.md / -11-07.md | 已被取代 | → FIXLIST-2026-11-08 / FINAL-STATUS |
| CODEC-SPEC-ACCEPTANCE-2026-11-06.md / CODEC-SPEC-ACCEPTANCE-REPORT-2026-11-07.md / CODEC-SPEC-FINAL-SUMMARY-2026-11-08.md | 已被取代 | → FINAL-STATUS-2026-11-10 |
| FINAL-DELIVERY-2026-11-01.md / FINAL-REPORT-2026-11-01.md / acceptance-report-2026-11-01.md / spec-traceability-2026-11-01.md | 已被取代 | → FINAL-STATUS / CAPABILITY-MATRIX |
| soak-progress-2026-11-02.md | 已被取代 | 长稳口径已改 1h×3 boot |
| p4-hardware-acceleration-final-report-2026-11-04.md / p4-vdec-m2-status-report-2026-11-03.md / p4-venc-m4-status-report-2026-11-03.md | 已被取代 | → 路线图 / FINAL-STATUS |
| HANDOFF-M2-vdec-2026-11-05.md / HANDOFF-hardware-acceleration-2026-11-04.md / M2-VDEC-STATUS-SUMMARY-2026-11-06.md | 历史交接 | 被后续 status/roadmap 全面覆盖 |
| driver-technical-spec.md / feasibility-remaining-features-2026-11-01.md / risk-register-and-decisions.md / vdec-venc-porting-plan-2026-11-03.md | 历史规格/决策 | 部分已被实现取代；决策记录仍有参考价值 |

## 2026-11-11 过期内容清理归档说明

清理原则：**先归档、校验后删除**；当前权威文档引用的证据按白名单保留（白名单见 `.cleanup/docs-report.md` §六）。
归档位置：`/home/jason/cleanup-archive-20261111/`（含 `manifests/` 与 SHA1SUMS，可回溯恢复）。

| 类别 | 释放 | 归档文件 |
|---|---|---|
| `artifacts/venc-reverse/m2-diag/*.nv21`（2349 个 NV21 原始帧） | 778 M | `workspace/docs/m2-diag-nv21-frames-20261111.tar.xz` |
| `artifacts/png-hw` 中间 run（98 项，保留 62/64/65 验收件、tde-*/fip-* 证据） | 279 M | `workspace/docs/png-hw-intermediate-runs-20261111.tar.xz` |
| `artifacts/hwtest-2026-11-07` 中间 run + 旧内核 `uImage`/`uImage_p1`（48 项） | 498 M | `workspace/docs/hwtest-intermediate-and-legacy-kernels-20261111.tar.xz` |
| `logs/` 未被引用的早期 bringup 日志（210 份） | 11 M | `workspace/docs/porting-logs-unreferenced-20261111.tar.xz`（保留 12 份被引日志） |
| `docs/fcs850r/fcs850r.tar`（厂商 git 仓库副本，与目录内驱动 zip/PDF 重复） | 165 M | `workspace/docs/fcs850r.tar.xz` |
| `docs/Hi3798mv200`（厂商文档，porting 0 引用，含已淘汰 RTL8822BS 模组资料） | 209 M | `workspace/docs/Hi3798mv200-vendor-docs-20261111.tar.xz` |
| `dist/` 旧发布包 r2–r10（16 个版本 + sha1，仅留 r11） | 116 M | `workspace/dist/hi-accel-old-releases-r2-r10.tar.xz` |
| `out/`（2026-10-30 旧 BSP 构建产物，可重编） | 109 M | `workspace/out/out-hi3798mv300-build-20261030.tar.xz` |
| 根目录误建 `--help/`、旧模块 `build-final*`、`__pycache__` | 4 M | `workspace/junk/junk-20261111.tar.xz` |

结果：`docs/` 2.6 G → 0.7 G（其中 `artifacts` 2.1 G → 0.6 G），`dist/` 124 M → 12 M，工程目录 10 G → 7.9 G。保留白名单证据、全部历史 `.md` 与 `ref/`、`ref-png/` 均未动。
