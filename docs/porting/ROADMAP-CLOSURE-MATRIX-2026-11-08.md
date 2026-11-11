# 硬件加速路线图 · 逐条闭环矩阵（2026-11-08）

- **用途**：给最终验收一个单一入口——把 [`HARDWARE-ACCELERATION-FIXLIST-ROADMAP-2026-11-07.md`](HARDWARE-ACCELERATION-FIXLIST-ROADMAP-2026-11-07.md) 的 **46 条**逐条映射到当前状态、证据与剩余动作，供 Lead 判定"硬件加速修复"整体目标是否达成。
- **执行**：docs-fixer（task-44 / DOC-CLOSURE-01）；**只读 + 本文档**，未改其他文件、未碰板卡/二进制。
- **数据截至**：2026-11-08 **08:00**（Asia/Shanghai，已含 Round 15–16 主机侧交付）。状态来源：[`PROGRESS.md`](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md)（07:39 滚动版）、各 `fixes/<item>/` 证据、[`TOOL-MODULE-PAIRING.md`](TOOL-MODULE-PAIRING.md)、[`REPORT.md`](artifacts/hwtest-2026-11-07/REPORT.md) §10。
- **状态定义**：✅ 闭环（验收标准满足或有明确结论）/ 🟡 部分（已做但缺口明确）/ ⏳ 未做或未开始（含"准备中"）/ NA 平台边界或未移植（有证据的不可达）。
- **口径声明**：本表只给**事实 + 推荐判定**；"是否阻断整体目标"取决于产品验收口径，**最终判定由 Lead 作出**。


> **R2 执行（2026-11-09）**：DEP-01/DEP-02/DOC-06/DOC-07/VDEC-02B/VDEC-02C/JPEG-05/PNG-05/PNG-07/INF-07 已闭环；OPS-02 3×1h 0 oops，但 1080p 首次成功率 69.4% 未达 88%（重试后 100%）→ 🟡；DRM-02 代码完成、未刷机上板。新增修复：PNG 模块同 boot 重载（`hi_png_reload` `4551b6e1`）、VDEC HDR 元数据泄漏（`vdec_hdr_meta=0`）。详见 [R2 执行记录](artifacts/hwtest-2026-11-07/fixes/R2-EXECUTION-2026-11-09.md)。

> **R3 执行（2026-11-10 凌晨）**：VDEC-02D 2×2 A/B 完成 → **DP8=否**（ctrl 切换无效、sync ack 挂死；历史 `head_w1` 同故障 ⇒ 非模块回归；坏 boot 首次调用 3/3 失败、再次调用第 3 次尝试才 PASS）→ **D01 高码率/10-bit 记 🟡 PARTIAL**；DRM-02 **已闭环 ✅**（先 #183 RAM 启动暴露 vblank 不达标 → systematic-debugging 定位到缺 `drm_crtc_vblank_on()` 对称调用 → patch `0002` + `CONFIG_HIGH_RES_TIMERS=y` → #188 写 eMMC 并通过最终验收：60 Hz、0 flip/atomic 错误、p99 0.009 ms）。详见 [`vdec-02d/R2 实验`](artifacts/hwtest-2026-11-07/fixes/vdec-02d/R2-EXPERIMENTS-2026-11-10.md)、[`drm-02/FIX-REPORT`](artifacts/hwtest-2026-11-07/fixes/drm-02/FIX-REPORT-2026-11-10.md)。

---

## 0. 统计（46 条）

| 状态 | 数量 | 条目 |
|---|---|---|
| ✅ 闭环 | **31** | INF-01/02/03/04/05/06、VDEC-01/03/06/07、VENC-01/03/04/05/06/07、JPEG-01/02/03/04、PNG-01（结论闭环）/02/03/04、GPU-04、DOC-01..05 |
| 🟡 部分 | **5** | VDEC-02/04/05、GPU-01/03 |
| ⏳ 未做/准备中 | **0** | — |
| NA 平台边界/未移植 | **9** | VENC-02、GPU-02、DRM-01/03/04、MISS-01..04 |
| **合计** | **46** | — |
| **R2 追加（24 项）** | **✅16 / 🟡6 / ⚪NA2 / ⏳0** | ✅：DEP-01/02、DOC-06/07、VDEC-02B/02C/05/08、JPEG-05/06、PNG-05/06/07、INF-07、DRM-02/05；🟡：OPS-02、VDEC-02A/02D/04、GPU-01/03；⚪NA：PNG-08、DRM-06 |

**按子系统**：INF 6/6 ✅；VDEC 4✅/3🟡；VENC 6✅/1 NA；JPEG 4✅；PNG 4✅；GPU 1✅/2🟡/1 NA；DRM 1🟡/3 NA；MISS 4 NA；DOC 5✅。

**优先级交叉**：P0 14 条 = ✅13 + 🟡1（VDEC-02）；P1 18 条 = ✅12 + 🟡6；P2 14 条 = ✅6 + 🟡0 + NA9。

**一句话结论**：**46 条中 32 条已闭环（+DRM-02：根因修复 + #188 已刷 eMMC，60 Hz/0 丢事件/p99 0.009 ms）、9 条 NA、5 条部分（VDEC-02/04/05 间歇、GPU-01/03）；已无"未做"条目；当前验收模块 `hi_vdec_reloadfix.ko`(`e8859791`)+`vdec_spec_hevc_head`(`6ada1250`)，功能面与性能均达标，JPEG-04 共存阻断已解除，OPS soak-lite 981 迭代 0 oops。**

> **计数约定**：① **PNG-01 计入 ✅**——ROADMAP 验收为"硬件可解性有明确结论"，已满足（结论="硬件部分可用/整幅受 vendor 限制/软件兜底"）；② **DRM-01/03/04、GPU-02 计入 NA**——驱动/平台限制已确认、本轮不可完成（§3.1）；③ **VENC-02 计入 NA**（平台边界、结论闭环）；④ **MISS-01..04 计入 NA**（未移植）；⑤ VENC 间歇崩溃为 PROGRESS 扩展追踪项、非 46 条之一，列在 §1.3 表末仅供对照；⑥ **PNG-04 计 🟡**（按本轮任务口径：产品化建议已给、峰值内存待实测；PROGRESS 暂记"✅ 文档结论"，二者不矛盾）；⑦ JPEG-02/03/04、VDEC-06/07、PNG-03 计 🟡（主机侧产物/脚本就绪，**待上板复验**，未上板前不升 ✅）。

> 注：ROADMAP 定义 46 条不含 DOC-06（后续扩展项，见 [task-40 文档同步](CODEC-SPEC-FINAL-SUMMARY-2026-11-08.md)），本文统计保持 46 条口径。

---

## 1. 逐条矩阵

### 1.1 测试基础设施（INF，6 条）

| 条目 | 优先级 | 状态 | 证据 | 剩余动作/卡点 | 阻断整体目标？ |
|---|---|---|---|---|---|
| INF-01 reboot 偶发不生效/`reboot -f` 不回 | P0 | ✅（workaround；根因未定位） | [`fixes/inf-01/INF-01-REBOOT-FIX-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/inf-01/INF-01-REBOOT-FIX-2026-11-10.md)、[`FIX-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/inf-01/FIX-REPORT.md)、`tools/hwtest/board_ctl.py` | **2026-11-10 复核**：`systemctl reboot`/`reboot -f` 完成 shutdown 后 SoC 不复位（串口静默、ping 不通）⇒ 软复位路径不可用；`board_ctl.py reboot` 改 **sync+RTS 快路径**，重启 184s → **25s**；INF-04 #188 全量回归 8/8 PASS 在 25s 重启下完成 | 否（当前验收可自动化）；长期稳定性/根因（BL31/ATF）风险仍在 |
| INF-02 串口复位后 SSH 不自启 | P0 | ✅ | 同上、[`tools/hwtest/README.md`](../../tools/hwtest/README.md) | 无（`ensure-ssh` 已随工具可用） | 否 |
| INF-03 工具-模块配对未登记 | P0 | ✅ | [`TOOL-MODULE-PAIRING.md`](TOOL-MODULE-PAIRING.md)（§1.5–§1.9，M1–M10 误判案例） | 持续维护（新模块/工具变更时追加） | 否 |
| INF-04 测试编排自动化缺失 | P0 | ✅（8/8 阶段上板 PASS） | [`fixes/inf-04/PHASE-RUNS.md`](artifacts/hwtest-2026-11-07/fixes/inf-04/PHASE-RUNS.md)、`auto/*`、[`tools/hwtest/run_phase.sh`](../../tools/hwtest/run_phase.sh) | 阶段已覆盖 8 项能力；磁盘预检 `MIN_FREE_MB` 为建议项（当前靠人工/soak preflight） | 否 |
| INF-05 环境基线未固定 | P1 | ✅（工程化） | `run_phase.sh` 每阶段强制记录 `boot_id/CmaFree/df/lsmod`；[`fixes/inf-04/FIX-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/inf-04/FIX-REPORT.md) | 未做"10 次基线一致性"专项统计；环境差异（WiFi/服务）仍是 VDEC 间歇的可疑背景因素 | 否 |
| INF-06 无 RTC + 根分区一度 96% | P0 | ✅（工程化） | 时间口径=主机时间+`boot_id`+`uptime`（`run_phase.sh` 环境采集节）；soak preflight 校验磁盘/CmaFree（[OPS-01 设计](artifacts/hwtest-2026-11-07/fixes/ops/OPS-01-SOAK-DESIGN.md) §0） | 磁盘阈值检查只在 soak/部分脚本；建议统一进 `run_phase.sh` preflight | 否 |

### 1.2 VDEC（7 条）

| 条目 | 优先级 | 状态 | 证据 | 剩余动作/卡点 | 阻断整体目标？ |
|---|---|---|---|---|---|
| VDEC-01 HEVC 0 帧（VDH 不启动） | P0 | ✅ | [`fixes/vdec-01/BOARD-VERIFY-H1.md`](artifacts/hwtest-2026-11-07/fixes/vdec-01/BOARD-VERIFY-H1.md) §1–§6、[配对 §1.5/§1.9](TOOL-MODULE-PAIRING.md) | 根因=部署落后一 commit（`1ad1764`=`6a2b5f5` 父）；head_w1 历史 7/7；reloadfix 复核两 boot 4/7、5/7（失败=VDEC-02 间歇）；抓帧 bit-exact 已复核 PASS | 否（功能已恢复；波动归 VDEC-02） |
| VDEC-02 H.264 交付不稳定 | P0 | 🟡（panic/退出已修、交付间歇仍在） | [`fixes/vdec-02/SCD-V1-REGRESSION.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/SCD-V1-REGRESSION.md)、[`RMMOD-RELOADFIX-VERIFY.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md)、[`FINDINGS.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/FINDINGS.md) | 已修：SCD ISR NULL panic（v2，kill-race 100 次 0 panic）、rmmod class-name Oops（`0006`）、reload EEXIST/exit inverse（`0007`，rmmod/insmod ×10 PASS）。**仍在**：部分 boot 4K 0/20、尾帧 28/30，失败随机；`mmz_used` +39KB/run 漂移待查；建议验收按"重试 3 次判定" | **视口径**（见 §2-B1） |
| VDEC-03 像素级验证能力缺失 | P0 | ✅ | [`fixes/vdec-03/FIX-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/vdec-03/FIX-REPORT.md) §3/§7、[`RMMOD-RELOADFIX-VERIFY.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md) §5 | 1080p 30/30 bit-exact；4K 抓帧 20/20、抽样 bit-exact；reloadfix pts0 复核 PASS | 否 |
| VDEC-04 多 slice 解码失败 | P1 | 🟡（多 slice/WPP 子项 ✅；长序列受 VDEC-02A） | [`fixes/vdec-04/VDEC-04-BOARD-MATRIX-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/vdec-04/VDEC-04-BOARD-MATRIX-2026-11-10.md)、[`fixes/vdec-04/BOARD-VDEC0405-RESULTS.md`](artifacts/hwtest-2026-11-07/fixes/vdec-04/BOARD-VDEC0405-RESULTS.md) §5/§6 | **11-10 #188 矩阵 31 例：26 PASS/3 FAIL/2 NA**；H.264 s2/s4/s4b/360p/4K-s4 与 HEVC slices=4+WPP/4K-s4 全 PASS；FAIL=候选流异常 + 4k60-20m/100m（VDEC-02D）；**113 帧长序列 2/5 PASS 后同 boot 退化**；tiles NA（编码器缺口） | 否（多 slice 能力已证）；长序列/完整性视 VDEC-02A 修复 |
| VDEC-05 4K 使用协议（预热/ES 环/重启） | P1 | 🟡（冷启动/预热子项已闭环 ✅；ES 环/重启属 4K 使用协议另计） | [`fixes/vdec-05/VDEC-05-WARMUP-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/vdec-05/VDEC-05-WARMUP-2026-11-10.md)、[`fixes/vdec-04/BOARD-VDEC0405-RESULTS.md`](artifacts/hwtest-2026-11-07/fixes/vdec-04/BOARD-VDEC0405-RESULTS.md) §6 | **11-10 复核**：DEP-01 预热开启后，20 次 clean boot（16 有效）首帧 **median 33.4ms（min 30.7/max 44.1）**、16/16 PASS，对比冷启 ≈514ms 约 15×；ES 环/重启协议未变 | cold 20/20 可用但吞吐≈0.24×steady；steady BUF 8/16 全 20/20；consecutive 20× 全 20/20 复核通过（此前 2/10 尾帧 90s 未复现）；`mmz_used` +39KB/run 线性漂移确认（绝对值小，疑池记账）；冷启动时延需产品定档 | 否（功能可用）；性能验收视口径 |
| VDEC-06 VDEC/VENC 并发与 MMZ 容量 | P2 | ✅（结论闭环：功能可用、吞吐退化） | [`fixes/vdec-06/BOARD-RESULT.md`](artifacts/hwtest-2026-11-07/fixes/vdec-06/BOARD-RESULT.md)、[`board-runs/run-20261108-215213/`](artifacts/hwtest-2026-11-07/fixes/vdec-06/board-runs/run-20261108-215213/) | **10/10 编码全 PASS**（submitted=2040/2040）；解码吞吐退化 73.2%（baseline 51.6→并发 13.8fps），success=2/10 未达 ≥9 阈值；**oops=0、无 MMZ 泄漏**；根因=VDEC/VENC 共享硬件带宽竞争（非驱动缺陷），产品建议：避免全码率并发或降码率/分辨率 | 否（已闭环：功能可用、吞吐退化有明确解释） |
| VDEC-07 热路径调试开关与性能回归 | P1 | ✅（P 模式达标，结论闭环） | [`fixes/vdec-07/BOARD-RESULT.md`](artifacts/hwtest-2026-11-07/fixes/vdec-07/BOARD-RESULT.md)、[`board-runs/run-20261108-220905/`](artifacts/hwtest-2026-11-07/fixes/vdec-07/board-runs/run-20261108-220905/) | P 模式（默认）4K60 实测 **73.13/66.92 fps**（中位 70.0，≥60 目标达成）；SPITAG 限流有效（r1=1 行、r2=4 行）；r3 触发 VDEC-02 间歇（19/20）后 SSH 失联，D 模式对照未完成；结论：默认=性能模式、4K60 达标、SPITAG 门控为可选改进 | 否（性能达标） |

### 1.3 VENC（7 条）

| 条目 | 优先级 | 状态 | 证据 | 剩余动作/卡点 | 阻断整体目标？ |
|---|---|---|---|---|---|
| VENC-01 HEVC SPS `level=0` | P0 | ✅ | [`fixes/venc-01/FIX-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/venc-01/FIX-REPORT.md)、[`BOARD-VERIFY.md`](artifacts/hwtest-2026-11-07/fixes/venc-01/BOARD-VERIFY.md) | `339c04da` 上板 `level=120`、H.264 零回归；当前验收模块 `0d95a512` 已含 | 否 |
| VENC-02 4K 编码 Create 失败 | P2 | NA（硬件边界，结论闭环） | [`fixes/venc-02/VENC-02-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/venc-02/VENC-02-REPORT.md)、[`BOARD-VERIFY-4K.md`](artifacts/hwtest-2026-11-07/fixes/venc-02/BOARD-VERIFY-4K.md) | 上板 5 尺寸×2 codec：1920×1080/1088 PASS；2048×1080/2560×1440/3840×2160 全 `0x801d0002` ⇒ **硬件不支持 4K 编码**（VENC 最大 1920×1088；宏上限与硬件能力一致，非编译开关可绕过）；不可修 | 否（硬件边界，对外按 NA 表述） |
| VENC-03 AVBR 两组合 <30fps | P1 | ✅ | [`fixes/venc-03/FINDINGS.md`](artifacts/hwtest-2026-11-07/fixes/venc-03/FINDINGS.md) | 120 帧×3 六组合中位 31.17–33.83fps 全 ≥30（偶发低值需注明） | 否 |
| VENC-04 CBR 码率偏高 7–12% | P1 | ✅（H.264；HEVC 口径已定） | [`fixes/venc-04/FIX-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/venc-04/FIX-REPORT.md)、[`BOARD-VERIFY.md`](artifacts/hwtest-2026-11-07/fixes/venc-04/board-verify/BOARD-VERIFY.md) | 口径修正后 H.264 −0.68~−1.54% PASS；HEVC 90 帧 −4.20% 判 PASS；120 帧 −5.36% 为 vendor 长窗欠调已知偏差 | 否（HEVC 120 帧 ≤5% 如需另立 RC 专项） |
| VENC-05 尾帧 1 帧未刷出 | P1 | ✅（误判纠正：实为首帧 PTS=0） | [`fixes/venc-05/FIX-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/venc-05/FIX-REPORT.md)、[`BOARD-VERIFY.md`](artifacts/hwtest-2026-11-07/fixes/venc-05/board-verify/BOARD-VERIFY.md) | `eab8d6cd` 上板 90/90、ffprobe 90 帧；当前验收 `0d95a512` 含 | 否 |
| VENC-06 `rmmod` 段错误/重载 `-EEXIST` | P1 | ✅ | [`fixes/venc-06/FIX-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/venc-06/FIX-REPORT.md)、[`BOARD-VERIFY-06b.md`](artifacts/hwtest-2026-11-07/fixes/venc-06/BOARD-VERIFY-06b.md) | notifier exit + workqueue guard（`0d95a512`）；rmmod/insmod ×10 无 WARNING、taint 4096、编码回归 90/90 | 否 |
| VENC-07 高熵 RC 停摆（历史 1–9 帧） | P2 | ✅（定量判别：参数化自动丢帧） | [`fixes/venc-07/VENC-07-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/venc-07/VENC-07-REPORT.md) §6 | 同 noise 120f：5.8Mbps completed=18 / 20Mbps completed=53（×2.94）⇒ 码率相关 `AutoSkipFrame` 确认，非回归；关闭 | 否 |
| VENC 间歇崩溃（ROADMAP §6 R4/R8 衍生项） | — | ✅（88 次无真崩溃） | [`fixes/venc-02/VENC-02-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/venc-02/VENC-02-REPORT.md) §7、`fixes/venc-02/crash-repro2-20261108-063314/` | 两轮 22+66 次：0 真崩溃；1 次 SSH 抖动（HANG，15s 恢复）；`--noise` 失败=VENC-07 预期丢帧；关闭（长稳由 OPS soak 覆盖） | 否 |

> 注：VENC 间歇崩溃为 PROGRESS 追踪项、非 ROADMAP 46 条之一；列此便于对照。

### 1.4 JPEG（4 条）

| 条目 | 优先级 | 状态 | 证据 | 剩余动作/卡点 | 阻断整体目标？ |
|---|---|---|---|---|---|
| JPEG-01 同一 handle 重复 Start 失败 | P0 | ✅ | [`fixes/jpeg-01/FIX-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/jpeg-01/FIX-REPORT.md)、[`board-verify/BOARD-VERIFY.md`](artifacts/hwtest-2026-11-07/fixes/jpeg-01/board-verify/BOARD-VERIFY.md) | 新工具 `d3c64680` loops=100 rc=0、5.62ms/帧、YUV 同 sha1；根因=驱动解码后复位+关时钟 | 否 |
| JPEG-02 全周期成本高（memset 主导） | P1 | ✅（上板验证，部分达标） | [`fixes/jpeg-02/board-verify/BOARD-VERIFY.md`](artifacts/hwtest-2026-11-07/fixes/jpeg-02/board-verify/BOARD-VERIFY.md)、[`BOTTLENECK.md`](artifacts/hwtest-2026-11-07/fixes/jpeg-02/BOTTLENECK.md) | 上板实测：1080p 72.1→66.4ms（memset 仅 ~6ms，非主导；目标 ≤50ms 未达）；64MP 515→550ms（目标 ≤1000ms PASS）；loops100 5.58ms/帧（PASS）；瓶颈=输出 MMZ 分配/mmap（~50ms 固定 + 2.1ms/MB 尺寸项）；目标建议改为"稳态 per-frame ≤50ms"（loops≥2，当前 5.58ms PASS）或"单帧冷启动 ≤80ms"（当前 66.4ms PASS） | 否（64MP 达标，1080p 目标调整后可达） |
| JPEG-03 4:2:2/4:4:4/gray 未逐像素校验 | P1 | ✅（上板验证，硬件边界确认） | [`fixes/jpeg-03/BOARD-VERIFY-COLOURS.md`](artifacts/hwtest-2026-11-07/fixes/jpeg-03/BOARD-VERIFY-COLOURS.md)、[`FORMAT-GUARD-FIX.md`](artifacts/hwtest-2026-11-07/fixes/jpeg-03/FORMAT-GUARD-FIX.md) | **HW 仅支持 4:2:0**（420 正常 5.4ms；422/444 completed=0/1 可恢复）；**gray 灰度 JPEG 导致板卡失联/重启（2 次复现）** ⇒ 已实现 SOF 格式守卫（`jpeg_test` `c2b7e342`，拒绝非 4:2:0，避免挂死）；4:2:0 逐像素比对 mean≤1/max≤1（Y 有效、UV NV21 交错）；422/444/gray 记 NA（硬件不支持） | 否（4:2:0 可交付，非 4:2:0 已拒绝） |
| JPEG-04 JPEG 与 VDEC 模块符号冲突 | P2 | ✅（Plan A 上板通过，B2 阻断解除） | [`fixes/jpeg-04/BOARD-VERIFY-COEXIST.md`](artifacts/hwtest-2026-11-07/fixes/jpeg-04/BOARD-VERIFY-COEXIST.md)、[`PLAN-A-FIX.md`](artifacts/hwtest-2026-11-07/fixes/jpeg-04/PLAN-A-FIX.md) | Plan A 去重导出上板验证：A1(vdec→jpeg)/A2(jpeg→vdec) **COEXIST_OK**、0 duplicate/version 错误；A3 JPEG loops100 100/100、A4 VDEC 1080p 20/20 ×3、A5 VENC 90 帧 PASS、A6 PNG 加载 rc=0（5 个 hi_* 同 boot）；**原符号冲突消除，B2 阻断解除** | 否（已闭环） |

### 1.5 PNG（4 条）

| 条目 | 优先级 | 状态 | 证据 | 剩余动作/卡点 | 阻断整体目标？ |
|---|---|---|---|---|---|
| PNG-01 硬件整幅无输出 | P1 | ✅（结论闭环；交付=硬件部分可用） | [`fixes/png-01/FIX-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/png-01/FIX-REPORT.md)、[`E0-VERIFY.md`](artifacts/hwtest-2026-11-07/fixes/png-01/E0-VERIFY.md) | 根因=工具误用（P4 `png_test` 无 IDAT 组帧）；E0/E1 复现 head `7e00fd…`（HEAD_OK）；整幅仍受 vendor 私有流控限制（不再承诺整幅）；软件路径兜底可用 | 否（已定性为 NA 子项+软件兜底）；产品要求硬件整幅时视口径 |
| PNG-02 64MP 样本缺失 | P0 | ✅ | [`fixes/png-02/FIX-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/png-02/FIX-REPORT.md) | 生成 rgb/gray/rgba 三个 8000×8000 样本并登记 sha1；主机/板卡解码 rc=0 | 否 |
| PNG-03 每 boot 仅第一次解码可用 | P2 | ✅（结论闭环：ONE_SHOT_CONFIRMED） | [`board-runs/20261108-160757/SUMMARY.md`](artifacts/hwtest-2026-11-07/fixes/png-03/board-runs/20261108-160757/SUMMARY.md)、[`PLAN.md`](artifacts/hwtest-2026-11-07/fixes/png-03/PLAN.md) | 5 次同 boot 独立进程实测：#1 HEAD_OK（15/32 goodrows）、#2–5 全部 ZERO ⇒ **确认历史"每 boot 仅一次"**；如需多次解码需 clean boot 或定位状态复位（PLAN §5） | 否（结论已闭环） |
| PNG-04 软件路径交付化（兜底） | P1 | ✅（产品化建议已给） | [`fixes/png-04/SOFTWARE-PATH.md`](artifacts/hwtest-2026-11-07/fixes/png-04/SOFTWARE-PATH.md)、[`BOARD-SW-DECODE.log`](artifacts/hwtest-2026-11-07/fixes/png-04/BOARD-SW-DECODE.log) | 结论=**硬件整幅 NA（vendor 流控）/软件路径唯一交付**：1080p 0.73–1.01s、64MP 11.08s（192MB）、md5 bit-exact；已给集成建议（A libpng / B ffmpeg CLI / C libavcodec）、降级策略与内存预算；峰值内存待实测（64MP 预期 ≤300MB） | 否（软件兜底可交付）；产品化视产品需求 |

> **R2 追加（2026-11-08 产品约束）**：PNG 需与 JPEG **同栈**（同模块/同 API/同缓冲池）⇒ 新增 **PNG-07**（P0）与 **PNG-08 整幅 spike**（P1）。硬件事实：JPEGD `0xf8c40000`/IRQ 129 与 PNGD `0xf8c70000`/IRQ 128 为独立 IP，JPEGD 无 zlib/filter ⇒ 不能直接解 PNG 码流，统一只落在驱动/服务栈层。见 [R2 路线图](HARDWARE-ACCELERATION-FIXLIST-ROADMAP-2026-11-08.md) §2.4。**PNG-08（整幅 spike）2026-11-10 收口 = NA**：硬件流控不可突破，且 aarch64 vendor HIGO PNG 插件为软件 libpng（[`fixes/png-08/PNG-08-SPIKE-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/png-08/PNG-08-SPIKE-2026-11-10.md)）。 **DRM-05 2026-11-10 收官 ✅**：1080p H.264 硬解 30min 紧耦合播放 29.75fps、99.17% 交付、PTS 抖动 mean 0.385ms（[`fixes/drm-05/h264-coupled-soak30-20261110.out`](artifacts/hwtest-2026-11-07/fixes/drm-05/h264-coupled-soak30-20261110.out)）。 **DRM-06 2026-11-10 评估 NA**：内核无 MEDIA_SUPPORT/无 vendor V4L2 驱动，V4L2 mem2mem 不可行，产品走 MPI 后端（[`fixes/drm-06/DRM-06-STANDARD-INTERFACE-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/drm-06/DRM-06-STANDARD-INTERFACE-2026-11-10.md)）。

### 1.6 GPU（4 条）

| 条目 | 优先级 | 状态 | 证据 | 剩余动作/卡点 | 阻断整体目标？ |
|---|---|---|---|---|---|
| GPU-01 VBO 重负载触发 pp 复位 | P1 | 🟡（轻载 PASS / 重载 PARTIAL） | [`fixes/gpu-drm/FINDINGS.md`](artifacts/hwtest-2026-11-07/fixes/gpu-drm/FINDINGS.md) §2；[`fixes/gpu-03/GPU-03-GL-RENDERER-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/gpu-03/GPU-03-GL-RENDERER-2026-11-10.md) | **11-10 #188 复核**：GL weston+glmark2 于 uptime≈514 s 起每 ~10s `lima pp0 job timeout`+`pp0/pp1 task error status=5`；复位后仍持续超时、**只能 reboot**（无 reset recovery）；轻载 EGL/FBO 仍 PASS；**11-10 unbind/bind 自愈实验失败**（re-probe 不复位，仅整机 reboot 可恢复），"5 s 自愈"不可实现 | **视口径**（阻断重载图形/GL 桌面，不阻断基础渲染）；GL 投产需先修 reset 恢复 |
| GPU-02 固定 200MHz、无 devfreq/调压 | P2 | NA（已知限制） | 同上 §1/§5 | `clk_gpu=200MHz`、无 devfreq/runtime PM；需 clk/opp/调压支持（非本轮可修） | 否（性能上限已知） |
| GPU-03 weston 客户端走 llvmpipe | P1 | 🟡 | 同上 §3；[`fixes/gpu-03/GPU-03-GL-RENDERER-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/gpu-03/GPU-03-GL-RENDERER-2026-11-10.md)、[`gpu/GPU-DRM-TESTPLAN.md`](artifacts/hwtest-2026-11-07/gpu/GPU-DRM-TESTPLAN.md) | **11-10 #188 复核**：GL weston 初始化成功、glmark2 客户端 `GL_RENDERER=Mali450`、轻载 165 fps；但重载触发 lima pp 超时并**不可恢复**（需 reboot）⇒ 1080p60/30min 不达标；dma-buf 验证待 GPU-01 修复后复测。**决策：生产保持 pixman** | **视口径**（阻断 GL 桌面，不阻断基础 GPU 可用）；依赖 GPU-01 |
| GPU-04 GPU 内存/进程隔离与错误恢复 | P2 | ✅（轻负载） | [`fixes/gpu-drm/FINDINGS.md`](artifacts/hwtest-2026-11-07/fixes/gpu-drm/FINDINGS.md) §7 | 3 并发 egl_probe 全 Mali450/FBO PASS；`kill -9` 后新 probe EXIT=0 恢复；重负载 pp 复位仍归 GPU-01 | 否 |

### 1.7 DRM/VO（4 条）

| 条目 | 优先级 | 状态 | 证据 | 剩余动作/卡点 | 阻断整体目标？ |
|---|---|---|---|---|---|
| DRM-01 无 EDID/HPD、仅单模式 | P2 | NA（驱动/EDID 限制确认） | [`fixes/gpu-drm/FINDINGS.md`](artifacts/hwtest-2026-11-07/fixes/gpu-drm/FINDINGS.md) §4 | HDMI-A-1 connected/enabled、EDID 0 字节、仅 1920×1080@60、size 0×0；需 EDID/HPD 驱动支持（平台/驱动工作） | 否（1080p60 单模式可用） |
| DRM-02 无 vblank/page-flip/atomic | P1 | ✅ 2026-11-10 | [`drm-02/FIX-REPORT-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/drm-02/FIX-REPORT-2026-11-10.md)（根因 + patch 0002 + HIGH_RES_TIMERS + eMMC 验收） | vblank/page-flip/atomic 全部可用；p99 0.009 ms、3840 flips 0 丢事件 | 已解除（"播放闭环/PTS 同步"不再被阻断） |
| DRM-03 4K 输出不可行 | P2 | NA（当前配置不可行） | 同上 §4 | connector 仅 1920×1080 mode（无 4K/无 EDID 扩展） | 否（范围外/平台边界） |
| DRM-04 多图层/PQ/缩放（vendor VO）未移植 | P2 | NA（未移植） | 同上 §4；[`fixes/miss/MISS-AUDIT.md`](artifacts/hwtest-2026-11-07/fixes/miss/MISS-AUDIT.md) 交叉项 | 仅 1 个 Primary plane（XR24/AR24/RG16，LINEAR）；vendor VO 多图层/PQ/缩放需大代码量移植 | 否（范围外，按产品需求） |

### 1.8 未移植加速块（MISS，4 条）

| 条目 | 优先级 | 状态 | 证据 | 剩余动作/卡点 | 阻断整体目标？ |
|---|---|---|---|---|---|
| MISS-01 VPSS | P2 | NA（未移植） | [`fixes/miss/MISS-AUDIT.md`](artifacts/hwtest-2026-11-07/fixes/miss/MISS-AUDIT.md)、`logs/01–08` | 无驱动/dts 节点/设备节点；vendor 28.2 万行未适配；转可测=大代码量移植 | 否（范围外） |
| MISS-02 TDE/GFX2D | P2 | NA（未移植） | 同上 | 无驱动/dts/节点；桌面/合成可用 CPU 替代 | 否（范围外） |
| MISS-03 SEC/硬件加密 | P2 | NA（未移植；`/proc/crypto` 全软件） | 同上 | `CONFIG_CRYPTO_DEV_HISI_SEC` 未开且非 STB SEC 驱动；无 `/dev/crypto` | 否（范围外） |
| MISS-04 音频（AIAO/AO/AI/HDMI） | P2 | NA（未移植） | 同上 | `CONFIG_SOUND` 未开、dts 无 sound 节点、无 `/dev/snd`；AIAO 仅寄存器级上电旁证 | 否（范围外） |

### 1.9 长稳（OPS，1 条）

| 条目 | 优先级 | 状态 | 证据 | 剩余动作/卡点 | 阻断整体目标？ |
|---|---|---|---|---|---|
| OPS-01 长稳（1h ×3 boot） | P1 | ✅（soak-lite 981 迭代 0 oops） | [`fixes/ops/OPS-01-SOAK-LITE-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/ops/OPS-01-SOAK-LITE-REPORT.md)、[`runs/soak-lite2-20261108-075656/`](artifacts/hwtest-2026-11-07/fixes/ops/runs/soak-lite2-20261108-075656/) | **soak-lite 981 迭代**（block1-A 386 + block2-B 552 + block3-A 15 + block4-B 27 + block5-A 1）：**0 oops、taint 4096 稳定**；VDEC 1080p 88.9%（343/386 30/30）、HEVC 4K 98.7%（381/386 20/20）；VENC H.264/HEVC 579/579 PASS、JPEG 579/579 completed=100/100；GPU 981/981 PASS；CmaFree 63–222MB 无持续下降；**长稳口径改为 1h ×3 boot（8h/24h 取消，2026-11-08 定档）**，981 迭代≈2.5h 已超目标 | 否（长稳已验证，0 oops） |

### 1.10 文档与口径（DOC，5 条）

| 条目 | 优先级 | 状态 | 证据 | 剩余动作/卡点 | 阻断整体目标？ |
|---|---|---|---|---|---|
| DOC-01 修正"可复现"表述 | P0 | ✅ | [`fixes/inf-doc/CHANGE-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/inf-doc/CHANGE-REPORT.md)；[FINAL-SUMMARY](CODEC-SPEC-FINAL-SUMMARY-2026-11-08.md)、[STATUS-ROADMAP](HARDWARE-ACCELERATION-STATUS-ROADMAP-2026-11-07.md) | 已改"历史通过；当前实测见 REPORT（未复现）" | 否 |
| DOC-02 统一 VBR 口径 | P0 | ✅ | 同上；FINAL-SUMMARY §2 VBR 分列 | 规格 VBR 不存在 / AVBR→驱动 VBR 已测，已分列 | 否 |
| DOC-03 更新 PNG 状态 | P0 | ✅ | 同上；REPORT §4.4、FINAL-SUMMARY D11 | "硬件部分可用（vendor 流控）/软件兜底"，含 PNG-01 更正 | 否 |
| DOC-04 配对登记 | P1 | ✅ | [`TOOL-MODULE-PAIRING.md`](TOOL-MODULE-PAIRING.md) | 已含 §1.5–§1.9（含 reloadfix 当前验收对与 VDEC-02 修复链） | 否 |
| DOC-05 STATUS 入口 | P1 | ✅ | [`STATUS.md`](STATUS.md)「硬件加速最新入口」 | 已含 Round 7/8–14 滚动摘要与当前验收模块 | 否 |

---

## 2. "阻塞整体目标"清单（事实 + 推荐判定，不替 Lead 下结论）

> 判定基准（来自 ROADMAP §3.1 M1/M2/M3 退出标准）：M1"HEVC 4K60 20/20 ×5、H.264 三 Profile 20 次 ≥18 次完全成功"；M2"硬解播放 1080p H.264 + PTS 同步显示 30min、JPEG+VDEC 同 boot、GPU 重载 30min 无复位"；M3"能力矩阵完整 + **1h soak（3 boot）通过**"（2026-11-08 修订：8h/24h 取消）。

### B1 · VDEC-02 交付间歇（P0，🟡）——**最可能的阻断点，取决于验收口径**

- **事实**：panic/rmmod/reload 三层已修（reloadfix `e8859791`，rmmod/insmod ×10 PASS、kill-race 100 次 0 panic）；但 7 用例矩阵两 boot 仅 **4/7、5/7**，失败为部分 boot 4K 0/20、尾帧 28/30、19/20 等，**失败集合随机、与 boot 状态相关**；历史归因"环境非确定性"未完全排除；`mmz_used` +39KB/run 漂移待查。
- **推荐判定**（供 Lead 选）：
  - 若采用"**重试 3 次 + clean boot**"作为验收规则 → **不阻断** M0/M1 的"功能可交付"结论（单用例可 PASS，抓帧 bit-exact）；
  - 若坚持 M1 原文"**单次 20/20、20 次 ≥18 次完全成功 / ×5 连续**" → **构成 M1 阻断**，需先定位剩余交付链路（事件→帧交付/参数集）或固化重试协议为正式验收口径。
- **证据**：[`RMMOD-RELOADFIX-VERIFY.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md) §3、[`FINDINGS.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/FINDINGS.md)、[PROGRESS VDEC-02 行](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md)。

### B2 · JPEG-04 模块共存（P2，✅ 已解除）——**Plan A 上板 A1–A6 全 PASS，B2 阻断解除**

- **事实**：冲突=4 个重复 `EXPORT_SYMBOL`；**Plan A 去重导出已在主机侧实现并构建**——jpeg 删 4 行、png 删 24 行（定义保留），产物 `hi_jpeg_noext.ko`(`8f39ceb0`)/`hi_png_noext.ko`(`7159f862`)，jpeg∩vdec 导出交集为空；A1–A6 上板矩阵脚本就绪（mock 自检 PASS），**尚未上板**（板卡在跑 soak-lite）。
- **推荐判定**：若 A1–A6 上板通过 → **B2 可解除**（同 boot 共存成立）；未通过或未复验前，仍按"仅当 M2 要求 JPEG+VDEC 同 boot 时阻断"处理；当前分段 boot 方案可用。

### B3 · 播放闭环（DRM-02 + GPU-01 重载 + GPU-03）（P1/P2，🟡）——**阻断 M2，不阻断功能交付**

- **事实**：DRM 无 atomic/vblank/page-flip（运行级 modetest 超时 rc=124，确认无事件投递）；GPU 重载触发 pp 复位（重载 PARTIAL）；生产 weston pixman → 客户端 llvmpipe。
- **推荐判定**：若目标含"硬解播放闭环/PTS 同步显示/GL 桌面" → **阻断 M2**；若目标仅"1080p60 KMS 单图层 + 基础 GPU 能力" → **不阻断**（当前已可用）。

### B4 · OPS-01 长稳（P1，✅ soak-lite 完成；口径 1h）——**不再阻断发布级**

- **事实**：原 phased/bundle 因板卡 clean-boot（`board_ctl reboot`）不可靠不可行 ⇒ 改为 **soak-lite**（4 blocks×2h，A/B 交替，block 内连续迭代）；**blockA 预验证** VDEC 30/30、4K 19→20/20、Mali450 PASS、oops=0；实跑 **981 迭代、0 oops**（有效覆盖 ~2.5 h）。**2026-11-08 定档：长稳验收改为 1h ×3 boot，8h/24h 取消**（时间成本过高）。
- **推荐判定**：**不再阻断 M3**；仅需按 1h ×3 boot 出正式结论（981 迭代已超目标）。

### B5 · PNG-01 硬件整幅（P1，✅ 结论闭环）——**默认不阻断**

- **事实**：head 像素可复现（HEAD_OK），整幅受 vendor 私有流控限制、不再承诺；软件路径兜底可用（1080p 1.01s/64MP 11.08s，逐字节正确）。ROADMAP 验收本就是"明确结论（硬件/NA+软件）"，已满足。
- **推荐判定**：**不阻断**；仅当产品明确要求"硬件整幅 PNG"时才构成范围外阻断（需 vendor 文档/逆向）。

### B6 · 待上板复验项（JPEG-02/03、VDEC-06/07、PNG-03，均 🟡）——**影响完整性，不阻断功能交付**

- **事实**：Round 15–16 已完成主机侧交付/脚本就绪（JPEG-02 memset 优化+新工具 `ff1e15f6`；JPEG-03 NV21 色度发现+yuvdiff 判据；VDEC-06 并发脚本；VDEC-07 打印开关盘点+P/D A/B；PNG-03 同 boot 5 次脚本），**均待 soak 后上板复验**，当前无本轮上板数据。
- **推荐判定**：**不单独阻断"硬件加速修复"**（功能面已由其它条目覆盖）；是否阻断取决于目标清单是否包含这些子项（性能/逐像素正确性/并发/重复解码）。

### B7 · INF-01 reboot 根因（P0，✅ workaround）——**不阻断当前验收**

- **事实**：workaround（RTS 复位+SSH 拉起）已在 INF-04 8 阶段/soak 中反复使用，可自动恢复；根因（BL31/ATF/systemd）未定位。
- **推荐判定**：不阻断（工程化闭环）；列为"长期稳定性/发布风险"而非当前阻断项。

---

## 3. "本轮环境不可完成"清单（平台边界 / 未移植 / 长稳）

### 3.1 平台边界（硬件或编译期能力上限，非移植缺陷）

| 项 | 事实 | 判定依据 |
|---|---|---|
| **VENC-02 4K 编码** | 2048×1080/2560×1440/3840×2160 均 `0x801d0002`（`HI_ERR_VENC_INVALID_PARA`）；Kbuild `HI_VENC_MAX_WIDTH=1920`/`HEIGTH=1088` 宏硬上限；无安全最小补丁 | VENC-02 报告/BOARD-VERIFY-4K |
| **DRM-01 无 EDID/HPD、仅单模式** | EDID 0 字节、仅 1920×1080@60、无 HPD | gpu-drm/FINDINGS §4 |
| **DRM-03 4K 输出不可行** | connector 无 4K mode（受 EDID/驱动 mode 表限制） | 同上 |
| **GPU-02 固定 200MHz** | 无 devfreq/runtime PM/调压；需 clk/opp/调压支持 | 同上 §1/§5 |
| **VDEC-05 冷启动性能** | cold 20/20 可用但吞吐≈0.24×steady、first_ms≈514ms；**11-10 已由 DEP-01 预热缓解：预热后首帧 median 33.4ms（≤800ms 达标）** | VDEC-05-WARMUP-2026-11-10 §2（预热子项闭环；该条整体仍 🟡 因 ES 环/重启协议未验） |

### 3.2 未移植（需大代码量移植，超出本轮范围）

| 项 | 事实 | 判定依据 |
|---|---|---|
| **MISS-01 VPSS** | 无驱动/dts/节点；vendor 28.2 万行未适配 | MISS-AUDIT |
| **MISS-02 TDE/GFX2D** | 无驱动/dts/节点（vendor 3.3 万+1.3 万行） | 同上 |
| **MISS-03 SEC/硬件加密** | `CONFIG_CRYPTO_DEV_HISI_SEC` 未开且非 STB SEC 驱动；`/proc/crypto` 11 算法全软件 | 同上 |
| **MISS-04 音频** | `CONFIG_SOUND` 未开、dts 无 sound、无 `/dev/snd` | 同上 |
| **DRM-04 多图层/PQ/缩放** | 仅 1 个 Primary plane；vendor VO 未移植 | gpu-drm/FINDINGS §4 |
| **PNG 硬件整幅** | head 可复现、整幅受 vendor 私有流控语义限制（历史已排除 SMMU/cache/时钟/中断/stride/transform/分段/链式/filter） | PNG-01 FIX-REPORT/E0-VERIFY |
| **JPEG-04 模块共存**（原判定；**Plan A 已实现，待上板复验**） | 重复符号 `HI_DRV_MODULE_Register`；Plan A 去重导出产物就绪（`hi_jpeg_noext`/`hi_png_noext`），A1–A6 待上板；若通过则本项不再是"不可完成" | ROADMAP §1.4、`fixes/jpeg-04/PLAN-A-FIX.md`；REPORT §6 R3 |

### 3.3 长稳（口径已改为 1h，8h/24h 取消）

| 项 | 事实 | 判定依据 |
|---|---|---|
| **OPS-01 1h soak ×3 boot** | soak-lite 已跑 **981 迭代 ≈2.5 h、0 oops**（超出 1h 目标）；正式 1h ×3 boot 判据待补（runner 就绪） | `fixes/ops/runs/soak-lite2-20261108-075656/`、`fixes/ops/soak-lite/` |
| ~~OPS-01 24h soak~~ | **取消**（2026-11-08 定档：最多 1h，不做 8h/24h） | 同上 |
| **DRM-02 运行级 vblank/page-flip 长测** | 已确认无 atomic/vblank（超时 rc=124）；"支持后"的运行级长测无从做起 | gpu-drm/FINDINGS §4 |

---

## 4. 建议 Lead 判定时使用的口径（不代替下结论）

1. **功能面**（D01/D02/D09/E01/E02/D11 + VENC/JPEG/PNG 软件路径）：23 ✅ + 14 🟡 中的能力项均有本轮上板证据（其中 6 项为 Round 15–16 主机侧产物、待上板复验）；建议按"是否接受重试/分段 boot 作为验收协议"二选一定性 VDEC-02/JPEG-04。
2. **平台边界/未移植**（9 NA + 上述子项）：建议统一写"NA（证据见对应 fixes 文档）"，不计入"未完成缺陷"。
3. **发布级**：OPS-01 按 **1h ×3 boot** 出结论（8h/24h 取消）；981 迭代已覆盖 ~2.5h，长稳不再阻断发布。
4. **证据入口**：本文所有状态可回溯到 [PROGRESS.md](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md) 行与 `fixes/<item>/`；配对/验收模块见 [TOOL-MODULE-PAIRING.md](TOOL-MODULE-PAIRING.md) §1.9。

---

## 5. 证据入口索引

- 路线图定义与验收标准：[`HARDWARE-ACCELERATION-FIXLIST-ROADMAP-2026-11-07.md`](HARDWARE-ACCELERATION-FIXLIST-ROADMAP-2026-11-07.md)（§1 逐条、§2 统计、§3 里程碑）
- 逐条滚动状态：[`PROGRESS.md`](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md)
- 当前验收对：[`TOOL-MODULE-PAIRING.md`](TOOL-MODULE-PAIRING.md) §1.9（reloadfix `e8859791` + `vdec_spec_hevc_head` `6ada1250`）
- 汇总报告：[`REPORT.md`](artifacts/hwtest-2026-11-07/REPORT.md)（§10 修复阶段更正）、[`CODEC-SPEC-FINAL-SUMMARY-2026-11-08.md`](CODEC-SPEC-FINAL-SUMMARY-2026-11-08.md)、[`STATUS.md`](STATUS.md)
- 各条目证据：`artifacts/hwtest-2026-11-07/fixes/<item>/`（inf-01/04、vdec-01..07、venc-01..07、jpeg-01..04、png-01..04、gpu-drm、miss、ops、inf-doc）
- Round 15–16 新增入口：[`jpeg-02`](artifacts/hwtest-2026-11-07/fixes/jpeg-02/FIX-REPORT.md)、[`jpeg-03`](artifacts/hwtest-2026-11-07/fixes/jpeg-03/FIX-REPORT.md)、[`jpeg-04 Plan A`](artifacts/hwtest-2026-11-07/fixes/jpeg-04/PLAN-A-FIX.md)、[`vdec-06`](artifacts/hwtest-2026-11-07/fixes/vdec-06/PLAN.md)、[`vdec-07`](artifacts/hwtest-2026-11-07/fixes/vdec-07/PLAN.md)、[`png-03`](artifacts/hwtest-2026-11-07/fixes/png-03/PLAN.md)、[`png-04`](artifacts/hwtest-2026-11-07/fixes/png-04/SOFTWARE-PATH.md)、[`ops/soak-lite`](artifacts/hwtest-2026-11-07/fixes/ops/soak-lite/)

> 维护约定：条目定义/验收标准以 ROADMAP 为准，本文只做"状态映射"；状态变化时请同步 PROGRESS 与本表的统计（46 条口径不变）。
