# Hi3798MV300 编解码规格验收 · 最终摘要（2026-11-08）

本页是**交付用一页摘要**：范围、判定、证据入口、推荐运行配置、遗留项。
细则在 [验收矩阵](CODEC-SPEC-ACCEPTANCE-2026-11-06.md)、[验收报告](CODEC-SPEC-ACCEPTANCE-REPORT-2026-11-07.md)、
[硬件加速路线图](HARDWARE-ACCELERATION-STATUS-ROADMAP-2026-11-07.md)，逐轮记录在 `artifacts/spec-acceptance/round01–120/`。

> **数据口径（2026-11-08 修订，DOC-01）**：本页 §2–§5 的数值与判定**全部来自历史轮次（round01–170）**，属"历史通过"，**不是当前保证**。
> 2026-11-07 板卡全量实测（干净 boot + 验收模块 + 固定配方）**未复现** D01/D02 的 PASS：HEVC 本次全部 0 帧（FAIL）、H.264 仅间歇成功（PARTIAL）；
> 当前结论见 [综合测试报告](artifacts/hwtest-2026-11-07/REPORT.md)（[§0 一页结论](artifacts/hwtest-2026-11-07/REPORT.md) / [§7.2 与历史结论的关系](artifacts/hwtest-2026-11-07/REPORT.md)）。
> 依据：[REPORT.md](artifacts/hwtest-2026-11-07/REPORT.md)、[历史基线表](artifacts/hwtest-2026-11-07/report/HISTORY-BASELINE.md)、[工具-模块配对登记](TOOL-MODULE-PAIRING.md)。
> **修复阶段（2026-11-08，最新 06:30）**：**当前验收对 = `hi_vdec_reloadfix.ko`（`e8859791`）+ `vdec_spec_hevc_head`（`6ada1250`）**（head_w1 `047cad9b` 的 7/7 为历史记录）；VDEC-01/03 闭环、VDEC-02 panic/rmmod/reload 已修（交付间歇仍在、按重试判定）、VDEC-04/05 状态见 §2.1。详见 [修复进度](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md)、[配对 §1.5/§1.9](TOOL-MODULE-PAIRING.md)。
> **R3 更新（2026-11-10）**：**D01 的 100 Mbps / Main10 判定下调为 🟡 PARTIAL**（随机 0 帧/部分交付；2×2 A/B 无改善（DP8=否）；历史 `head_w1` 同故障 ⇒ 非模块回归；坏 boot 首次调用 3/3 失败、第 2 次调用第 3 次尝试才 PASS）。8-bit 4K60 与 1080p 路径不变。证据：[VDEC-02D R2 实验](artifacts/hwtest-2026-11-07/fixes/vdec-02d/R2-EXPERIMENTS-2026-11-10.md)。DRM-02 的 #183 已完成 RAM 启动上板但 vblank 不达标（未写 eMMC），见 [RAMBOOT-VERIFY](artifacts/hwtest-2026-11-07/fixes/drm-02/RAMBOOT-VERIFY-2026-11-10.md)。

## 1. 范围（2026-11-08 按"现代主流/仍广泛使用"口径收窄）

**保留**：HEVC 解码、H.264 解码、JPEG 解码、**PNG 解码**、HEVC 编码、H.264 编码、CBR/AVBR（AVBR→驱动 VBR，见 §2 VBR 口径）码控。

**移出验收**（历史证据保留，仅供追溯）：MPEG-1、MPEG-2、MPEG-4 Part 2、AVS、AVS+、MVC、MJPEG、VC-1。

> 依据：范围表述沿用 [验收报告 §1](CODEC-SPEC-ACCEPTANCE-REPORT-2026-11-07.md)；VBR 口径见下方注。

## 2. 判定（保留范围内，均为"历史通过"；当前实测见 [REPORT.md](artifacts/hwtest-2026-11-07/REPORT.md)）

> **2026-11-09 晚纯硬件复测（boot `3f42a7e7`，当前验收配对，取代下方"本轮"列）**：
>
> | 条目 | 当前判定 | 数据 |
> |---|---|---|
> | D01 | 🔴 回退 | 8-bit 4K60 2/3（约 72 fps）；**100 Mbps 0/3、Main10 0/3**（单次约 50% 随机 0 帧，见 [VDEC-02D](artifacts/hwtest-2026-11-07/fixes/vdec-02d/FINDINGS-2026-11-09.md)） |
> | D02 | 🟡 | H.264 4K 三 Profile 9/9（2 次靠重试） |
> | D09 | ✅ | 4:2:0/4:2:2/4:4:4/gray 硬件 5.38/7.10/10.59/3.58 ms，64MP 162.62 ms（[d09-jpeg](artifacts/hwtest-2026-11-07/fixes/d09-jpeg/D09-JPEG-HW-2026-11-09.md)） |
> | D11 | 🟡 | 软件 bit-exact 交付；硬件整幅待 PNG-08 |
> | E01 | ✅ | HEVC CBR 31.91 / AVBR 32.27 fps，level 120（[e02-venc](artifacts/hwtest-2026-11-07/fixes/e02-venc/E01-E02-VENC-2026-11-09.md)） |
> | E02 | ✅ | 六组合中位 32.72–33.82 fps，24/24 PASS |

> **前提**：下表判定是历史轮次结论。2026-11-07 全量实测（[REPORT §3 总矩阵](artifacts/hwtest-2026-11-07/REPORT.md)）的结果分列如下：
> D01 **FAIL（本次 0 帧；已定位=部署落后一 commit，HEVC 修复模块 20/20）**、D02 **PARTIAL（间歇）**、D09 **PASS（单帧，与历史一致）**、D11 **PARTIAL（整幅未达；head 可复现；软件可用）**、
> E01 **PARTIAL（level=0）**、E02 **PASS（有条件）**。**历史 PASS ≠ 当前保证**。

| 条目 | 判定 | 关键证据 |
|---|---|---|
| D01 HEVC 解码（Main10/High-tier L5.1，4K60，100 Mbps） | ✅ **历史通过；2026-11-08 修复：根因=部署落后一 commit（6a2b5f5），修复模块 `047cad9b`（HEAD+W1）全矩阵 7/7 PASS（1080p/4K60/8-bit/Main10/100Mbps），抓帧像素 bit-exact** | 4K60 8-bit 20/20、73–74fps、逐帧 sha1 一致；Main10+High-tier 4K60 8/8、71.55fps、sha1 一致；**100 Mbps 4K60：10/10 帧、全 `err_mbs=0`、中位 72.6fps**（round61/62/108）。**当前实测：本次全部 0 帧（原因=缺 HEVC message-publish 补丁，非硬件回归），见 [REPORT §4.1](artifacts/hwtest-2026-11-07/REPORT.md) 与 [EVIDENCE](artifacts/hwtest-2026-11-07/fixes/vdec-01/BOARD-VERIFY-H1.md)**。**2026-11-08 reloadfix 复核**：矩阵两 boot 4/7、5/7（失败为 VDEC-02 交付间歇、随机，按重试规则判定、非回归）；**抓帧像素 bit-exact 复核 PASS**（HEVC 1080p pts0：`y_identical=True`/`max_diff=0`，见 [RMMOD-RELOADFIX-VERIFY §5](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md)） |
| D02 H.264 解码（BP/MP/HP L5.1，4K30） | ✅ **历史通过；当前未复现**（本次 PARTIAL 间歇） | 4K30 三 Profile 各 20/20 帧、全 `err_mbs=0`；**首帧 Y 平面 sha1 与软件参考逐字节一致**；多 slice 逐像素一致（round106/109/43）。**当前实测：仅 4K-BP 一次 20/20，其余 0–3/20，见 [REPORT §4.1](artifacts/hwtest-2026-11-07/REPORT.md)**。修复阶段补充：1080p 抓帧 30/30 bit-exact（[VDEC-03](artifacts/hwtest-2026-11-07/fixes/vdec-03/FIX-REPORT.md)）；**VDEC-02 的 SCD ISR NULL panic / rmmod class-name Oops / reload EEXIST 三层已修**（reloadfix `e8859791`，rmmod/insmod ×10 PASS、kill-race 100 次 0 panic）；**交付间歇仍在**（部分 boot 4K 0/20、尾帧 28/30），按"重试 3 次判定、非回归"表述，见 [修复进度](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md) 与 [RMMOD-RELOADFIX-VERIFY](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md) |
| D09 JPEG 解码（Baseline，1080p / 64MP） | ✅ **通过（历史与本轮一致）** | 1080p 5.39ms、64MP 162.63ms；**4:2:0/4:2:2/4:4:4/gray 四类均支持（输出 NV12）**，Y mean 0.00122/max 1（round12/112）。本轮单帧 5.31ms/162.63ms，见 [REPORT §4.3](artifacts/hwtest-2026-11-07/REPORT.md) |
| E02 H.264 编码（BP/MP/HP@L4.1，1080p30，CBR + AVBR→VBR） | ✅ **通过（历史）；本轮 PASS（有条件）** | **六组合（BP/MP/HP × CBR/AVBR）复杂内容 30.9–34.7fps 全部达标**，level 均 41（round104）。本轮 4/6 ≥30fps（MP/AVBR 27.27、HP/AVBR 28.39），见 [REPORT §4.2](artifacts/hwtest-2026-11-07/REPORT.md)。**注意：此处 VBR 指 AVBR→驱动 VBR，规格 VBR 见下注** |
| E01 HEVC 编码（MP@L5 Main Tier，1080p30） | ⚠️ **部分（平台边界）；本轮等级更差** | Main/Tier ✅、CBR 32.3fps、AVBR 30.5fps；**level 实测 L4 且 SDK 明确不可改；4K 编码 Create 返回 `0x801d0002` → L5 无触发场景**（round98/101–105）。本轮 SPS `level=0`（未设置），见 [REPORT §4.2](artifacts/hwtest-2026-11-07/REPORT.md)；**2026-11-08 已由 VENC-01 修复为 `level=120`**（模块 `339c04da`；当前验收 `0d95a512`），见 [VENC-01](artifacts/hwtest-2026-11-07/fixes/venc-01/FIX-REPORT.md) 与 [配对 §1.6](TOOL-MODULE-PAIRING.md)。4K 编码平台边界不变——**VENC-02 已确认硬件不支持 4K 编码**（VENC 最大 1920×1088，宏上限与硬件能力一致；2048×1080 也返回 `0x801d0002`）⇒ E01 的 4K 子项判定 **NA（硬件边界，不可修）**，见 [VENC-02 报告](artifacts/hwtest-2026-11-07/fixes/venc-02/VENC-02-REPORT.md) |
| D11 PNG 解码（最大 6400 万像素） | 🚧 **硬件部分可用（vendor 私有流控）；2026-11-08 更正：本次“全 0”是工具误用，历史 head 可复现（E0/E3/E1），整幅仍未达；软件兜底可用** | 内核驱动就绪（`/dev/hi_png`、IRQ、时钟、SMMU、MMZ/DMA、寄存器全验证）；历史 round159/161 用 IDAT 帧流 + 干净会话解出与 ffmpeg 逐字节一致的 head 像素，但整幅完成受 vendor 私有流控语义限制（round124–170）。**本次实测 ISR 1 次后静默、输出全 0、无任何像素；软件 1080p 729ms，见 [REPORT §4.4](artifacts/hwtest-2026-11-07/REPORT.md) 判定**。**2026-11-08 更正**：E0（`hi_png_nb`+`png_test8`+clean boot）复现 head `7e00fd…`（HEAD_OK，goodrows 15/32），E3（同模块+`png_test` 整文件）全 0，E1（P4 模块 `1dfac9e0`+`png_test8`）HEAD_OK ⇒ 原因是工具/IDAT 帧流组织，非硬件回归；整幅仍不可达。详见 [fixes/png-01/E0-VERIFY.md](artifacts/hwtest-2026-11-07/fixes/png-01/E0-VERIFY.md) |

> **VBR 口径（2026-11-08 统一，DOC-02）**：必须分列，不得笼统写"VBR 通过"。
>
> | 口径 | 含义 | 结论 |
> |---|---|---|
> | **规格 VBR** | 公开 API `HI_UNF_VENC_RATECONTROL_TYPE_E` 中存在 VBR 枚举 | ❌ **不存在**（公开枚举只有 CBR/AVBR；`encoder_accept` 也只接受 `--rc CBR\|AVBR`） |
> | **AVBR→驱动 VBR** | 用户态 `AVBR` 映射到驱动 `ControlRateVariable`（即 VBR 路径），实测可跑通 | ✅ **已实测**（历史 round66/104；本轮 90 帧 AVBR 码流合法） |
>
> 正确表述："**AVBR（=驱动 VBR）已测；规格 VBR API 不存在**"。
> 依据：[round66](artifacts/spec-acceptance/round66-vbr-is-avbr.md)、[验收报告 E02 子项](CODEC-SPEC-ACCEPTANCE-REPORT-2026-11-07.md)、[REPORT §4.2](artifacts/hwtest-2026-11-07/REPORT.md)、[matrix/harnesses.csv](artifacts/hwtest-2026-11-07/matrix/harnesses.csv)。

### 2.1 修复阶段条目状态（2026-11-08 06:30，VDEC/VENC/其它）

> **验收模块变更**：VDEC 当前验收模块 = `hi_vdec_reloadfix.ko`（`e8859791…`，2,008,888 B）= head_w1(`047cad9b`) + `0005` SCD 防 panic/4K + `0006` class 名生命周期 + `0007` exit inverse；工具仍 `vdec_spec_hevc_head`（`6ada1250…`）。head_w1 的 7/7 PASS 保留为历史记录。详见 [配对 §1.9](TOOL-MODULE-PAIRING.md)。

| 条目 | 状态 | 关键结论（截至 06:30） | 证据 |
|---|---|---|---|
| **VDEC-01** HEVC 0 帧 | ✅ 闭环 | 根因=部署落后一 commit（`1ad1764` = `6a2b5f5` 父提交，缺 HEVC message-publish）；head_w1 历史 7/7；reloadfix 复核矩阵两 boot **4/7+5/7**（VDEC-02 间歇、非回归）；抓帧 bit-exact 复核 PASS | [BOARD-VERIFY-H1](artifacts/hwtest-2026-11-07/fixes/vdec-01/BOARD-VERIFY-H1.md)、[RMMOD-RELOADFIX-VERIFY](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md) |
| **VDEC-02** 交付稳定性 | 🟡 部分闭环（panic/退出已修、交付间歇仍在） | ① **SCD ISR NULL panic 已修**（v2 `b62e5504`：close/exit 竞态解引用 NULL，串口取证；kill-race 100 次 0 panic）；② **rmmod class-name Oops**（`0006`）与 **reload EEXIST/proc WARN/Oops**（`0007` exit inverse）三层已修，reloadfix rmmod/insmod ×10 PASS（taint 4096、0 WARN）；③ **交付间歇仍在**：部分 boot 4K 0/20、尾帧 28/30，按"重试 3 次判定、非回归"表述；④ `mmz_used` 漂移（约 +40 KB/次，待查是否泄漏） | [SCD-V1-REGRESSION](artifacts/hwtest-2026-11-07/fixes/vdec-02/SCD-V1-REGRESSION.md)、[RMMOD-UNLOAD-FIX](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-UNLOAD-FIX.md)、[RMMOD-RELOAD-FIX](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOAD-FIX.md)、[FINDINGS](artifacts/hwtest-2026-11-07/fixes/vdec-02/FINDINGS.md) |
| **VDEC-03** 抓帧/像素验证 | ✅ 闭环 | 1080p H.264 30/30 逐帧 Y bit-exact；4K/HEVC 抓帧 20/20、抽样 bit-exact；**reloadfix 下 1080p pts0 复核 `y_identical=True`/`max_diff=0`** | [FIX-REPORT](artifacts/hwtest-2026-11-07/fixes/vdec-03/FIX-REPORT.md)、[RMMOD-RELOADFIX-VERIFY §5](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md) |
| **VDEC-04** 多 slice | 🟡 大部分 PASS（4K 长序列待复测） | 1080p 多 slice（2/4 slices、含 B 帧、360p）**全 PASS**；HEVC 1080p s4/wppon **30/30**；4K 单/多 slice **单用例均 20/20**；此前长序列失联=SCD panic（已修）；4K 长序列/HEVC tiles 待复测 | [BOARD-VDEC0405-RESULTS](artifacts/hwtest-2026-11-07/fixes/vdec-04/BOARD-VDEC0405-RESULTS.md) |
| **VDEC-05** 4K 预热 | 🟡 判据已明确（功能可用、性能需预热） | 五相：cold **20/20 可用**但吞吐 ≈0.24×steady、first_ms 514.7 > 2×warm；steady 12/12 全 20/20（BUF 8/16 无差异）；consecutive 10 连发 **2/10 尾帧 90 s 超时**（VDEC-02 模式 B）；`mmz_used` +40 KB/次待查。**判据：cold `received==expected` 但 fps<0.5×steady、first>2×warm ⇒ 预热仍有益，VDEC-05 部分达成** | [BOARD-VDEC0405-RESULTS](artifacts/hwtest-2026-11-07/fixes/vdec-04/BOARD-VDEC0405-RESULTS.md) |
| **VENC-02** 4K 编码 | ✅ 定性为硬件边界（NA） | `0x801d0002`=`INVALID_PARA`；**硬件不支持 4K 编码**（VENC 最大 1920×1088，宏上限与硬件能力一致、非编译开关）；2048×1080 也被拒 ⇒ **NA（硬件边界，不可修）** | [VENC-02 报告](artifacts/hwtest-2026-11-07/fixes/venc-02/VENC-02-REPORT.md)、[BOARD-VERIFY-4K](artifacts/hwtest-2026-11-07/fixes/venc-02/BOARD-VERIFY-4K.md) |
| **VENC-07** 高熵 RC | ✅ 结论闭环（非缺陷） | "停摆"=驱动 RC 自动丢帧（`AutoSkipFrameEn`/`Drift`，默认 1.2× 预算）；纯噪声必触发、motion 内容 PASS；`--drift 101` 判别实验待跑 | [VENC-07-REPORT](artifacts/hwtest-2026-11-07/fixes/venc-07/VENC-07-REPORT.md) |
| **VENC 间歇崩溃** | 🟡 长时复现中 | crash-repro 首轮 **22 次记录无崩溃**（已中止让位 SCD 验证；1 例噪声 120f `completed=18` = VENC-07 预期丢帧）；脚本 `crash-repro.sh` 就绪 | [VENC-02 报告 §crash-repro](artifacts/hwtest-2026-11-07/fixes/venc-02/VENC-02-REPORT.md)、`fixes/venc-02/crash-repro-20261108-044917/` |
| **INF-04** 编排 | ✅ | **8/8 阶段上板 PASS**（含 4K 阶段修复为 decode-only + 2 帧抓帧并 Y sha1 一致） | [PHASE-RUNS](artifacts/hwtest-2026-11-07/fixes/inf-04/PHASE-RUNS.md) |
| **GPU / DRM** | 🟡 轻载 PASS / 重载 PARTIAL / 限制确认 | GPU-01 轻载 PASS（`GL_RENDERER=Mali450`）；重载触发 pp 复位（PARTIAL）；GPU-02 200 MHz 定频；GPU-03 weston GL 可初始化、生产 pixman→llvmpipe；DRM-01/03/04 限制确认，DRM-02 无 atomic props（运行级待测） | [GPU/DRM FINDINGS](artifacts/hwtest-2026-11-07/fixes/gpu-drm/FINDINGS.md) |
| **MISS-01..04** | NA（全部） | VPSS/TDE+GFX2D/SEC/音频均未移植（无驱动/节点/用户态入口）⇒ NA + 证据；AIAO 仅寄存器级上电旁证，不构成音频可用 | [MISS-AUDIT](artifacts/hwtest-2026-11-07/fixes/miss/MISS-AUDIT.md) |
| **OPS-01** 长稳 | ✅ soak-lite 981 迭代 0 oops；**口径 1h ×3 boot** | 981 迭代（≈2.5 h 有效负载）：**0 oops**、VDEC 1080p 88.9% / HEVC 4K 98.7%、VENC 579/579、JPEG 579/579、GPU 981/981；**8h/24h 取消**（2026-11-08 定档：最多 1h） | [soak-lite 报告](artifacts/hwtest-2026-11-07/fixes/ops/OPS-01-SOAK-LITE-REPORT.md) |

> 依据：以上逐条证据链均与 [PROGRESS.md](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md) 一致；抓帧复核见 [RMMOD-RELOADFIX-VERIFY §5](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md)（`y_identical=True/max_diff=0`）。

## 3. 性能参考（历史值，**非当前保证**）

> 下表全部为历史轮次数值，**不得写成"可复现"或当前性能**（DOC-01）。本轮在干净 boot + 验收模块 + 固定配方下：
> HEVC 解码 0 帧（性能不可测；2026-11-08 修复模块已恢复出帧，见 §2 D01）、H.264 仅 4K-BP 一次 20/20（16.1fps）、编码 27.27–34.29fps、JPEG 5.31ms/162.63ms。
> 当前实测见 [REPORT §3 总矩阵](artifacts/hwtest-2026-11-07/REPORT.md) 与 [§4 逐子系统](artifacts/hwtest-2026-11-07/REPORT.md)、[修复进度](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md)。

| 项目 | 历史数值 |
|---|---|
| HEVC 4K60 8-bit 解码 | 73–74 fps |
| HEVC 4K60 / 100 Mbps 解码 | 中位 72.6 fps（无 trace；trace 会降到 37–52） |
| H.264 4K30 三 Profile | 各 20/20 帧、`err_mbs=0` |
| H.264 编码 1080p30（六组合） | 30.9–34.7 fps |
| HEVC 编码 1080p30 | CBR 复杂 32.3 fps / AVBR（=VBR）30.5 fps |
| JPEG 1080p / 64MP（纯解码） | 5.39 ms / 162.63 ms |
| JPEG 1080p / 64MP（全周期 create+parse+decode+destroy） | ~200 ms / 4,188 ms（输出缓冲 memset 主导） |

> 依据：历史数值来自 [验收报告](CODEC-SPEC-ACCEPTANCE-REPORT-2026-11-07.md) 与 `artifacts/spec-acceptance/round*.md`；
> 本轮数值来自 [REPORT.md](artifacts/hwtest-2026-11-07/REPORT.md) §3/§4，两份不得混写为同一结论。

## 4. 推荐运行配置（历史实测得来）

> 下表是**历史轮次**验证过的配方（尤其"4K 三次 66.8–75.2fps""预热消除冷启动 0 帧"），本轮**未复现**这些性能与稳定性效果：
> 预热后仍可能退化、HEVC 连 VDH 启动都为 0。配方仍按此执行，但结果判定以 [REPORT.md](artifacts/hwtest-2026-11-07/REPORT.md) 为准。
> 依据：[REPORT §4.1/§5.1](artifacts/hwtest-2026-11-07/REPORT.md)、[工具-模块配对登记](TOOL-MODULE-PAIRING.md)。

| 场景 | 配置 | 依据 |
|---|---|---|
| 4K 解码（吞吐/交付） | **`VDEC_BUF_MB=8`** | 三次 66.8–75.2fps 无损失，且避免 MMZ 挤压（round119/120） |
| 4K 抓帧 | `vdec_no_vcmp=1` + `VDEC_BUF_MB=16` | 抓帧路径要求（round109） |
| 任何 4K 使用 | **先预热一次**；**每条新流/新 Profile 首次解码前也要预热** | 消除冷启动 0 帧（round116/121/122） |
| 解码与编码并存 | 用 8MB 缓冲；避免高频交替 | MMZ 容量根因（round119） |
| JPEG 测试 | **不与 `hi_vdec` 同 boot** | 重复导出 `HI_DRV_MODULE_Register`（round111） |
| 部署 `.ko` | **先校验 sha1** | 曾因损坏文件误判 "Invalid module format"（round111） |
| 性能测量 | 无 trace；判定取 N 次中位数、窗口 ≥90 帧 | trace 显著拖慢（round108）、短窗口方差大（round121） |

## 5. 稳定性结论（历史轮次；本轮未复现）

| 项目 | 结论 |
|---|---|
| 4K 重启（历史 G 项） | 10 次连续运行**未复现**，无 oops（round115） |
| 冷启动瞬态（0 帧） | 历史定位并"预热可消除"（round115/116）；**本轮预热后仍退化**（HEVC 0 帧、H.264 间歇） |
| VDEC/VENC 交替 0 帧 | **根因=MMZ 容量**；8MB 缓冲下 4/4 全成功（round117–119） |

> 依据：历史结论来自 round115–119；本轮实测的稳定性/复现性缺口见 [REPORT.md §5.1/§6 R1](artifacts/hwtest-2026-11-07/REPORT.md)
> 与 [历史基线表](artifacts/hwtest-2026-11-07/report/HISTORY-BASELINE.md)（C01–C16）。**"预热可消除"不构成当前保证。**

## 6. 遗留与决策项

1. **PNG 口径**：统一为"**硬件部分可用（vendor 私有流控；本次实测无像素输出）/软件兜底可用**"——历史 round159/161 曾解出正确 head 像素，整幅完成受 vendor 私有流控语义限制；本次实测 ISR 1 次后静默、输出全 0；软件 1080p 729ms（64MP 本轮无样本、历史 8.13s）。详见 [REPORT §4.4](artifacts/hwtest-2026-11-07/REPORT.md)。**2026-11-08 更正**：本次全 0 系**工具误用**（`png_test` `c90dc820` 为整文件提交、无 IDAT 组帧），E0/E1 换 `png_test8`（`723a011b`）后复现 head `7e00fd…`（HEAD_OK，goodrows 15/32）；整幅仍未达。见 [fixes/png-01/E0-VERIFY.md](artifacts/hwtest-2026-11-07/fixes/png-01/E0-VERIFY.md)、[配对 §1.4/§3](TOOL-MODULE-PAIRING.md)、[修复进度](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md)（PNG-01）。
2. **E01 Level5**：平台能力边界（不可通过移植修复）；**4K 编码为硬件不支持（VENC 最大 1920×1088），换 SDK/固件亦不可解决，只能换芯片**。本轮另见 SPS `level=0`（当前 VENC 构建未含 level 修复）——**2026-11-08 更正：level 已由 VENC-01 修复为 `120`**（模块 `339c04da`；当前验收 `0d95a512`），仅"L5 平台边界 + 4K 编码硬件不支持"不变；见 [VENC-01](artifacts/hwtest-2026-11-07/fixes/venc-01/FIX-REPORT.md)、[PROGRESS](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md)。
3. 历史范围外条目（MPEG/AVS/MVC/MJPEG）保留诊断记录，不再投入。
4. **VDEC-02 交付间歇（未根治）**：部分 boot 4K 0/20、尾帧 28/30；验收统一按"重试 3 次 + clean boot"判定，**不得据单次 <7/7 或 0 帧判硬件回归**；`mmz_used` +40 KB/次漂移待查（[VDEC-02](artifacts/hwtest-2026-11-07/fixes/vdec-02/FINDINGS.md)、[BOARD-VDEC0405-RESULTS](artifacts/hwtest-2026-11-07/fixes/vdec-04/BOARD-VDEC0405-RESULTS.md)）。
5. **VDEC-04 4K 长序列**：单用例 4K 单/多 slice 均 20/20，但长序列曾触发失联（根因=SCD ISR panic，已修）；需在 reloadfix 上复测 4K 长序列与 HEVC tiles。
6. **VDEC-05 预热判据**：cold 20/20 可用但吞吐≈0.24×steady、first_ms>2×warm ⇒ 预热仍有益；产品是否接受冷启动时延需定档。
7. **VENC 间歇崩溃**：crash-repro 首轮 22 次无崩溃（script 就绪），需长时/多 boot 继续；VENC-07 `--drift 101` 判别实验待跑。
8. **GPU/DRM/MISS/OPS**：GPU-01 轻载 PASS、重载 PARTIAL；DRM-02 无 atomic（运行级待测）；MISS-01..04 全部 NA；**OPS-01 soak-lite 981 迭代 0 oops**（口径改为 **1h ×3 boot**，8h/24h 取消）（[GPU/DRM](artifacts/hwtest-2026-11-07/fixes/gpu-drm/FINDINGS.md)、[MISS](artifacts/hwtest-2026-11-07/fixes/miss/MISS-AUDIT.md)、[OPS](artifacts/hwtest-2026-11-07/fixes/ops/OPS-01-SOAK-LITE-REPORT.md)）。

> 依据：DOC-03 统一 PNG 口径，来源 [REPORT §4.4](artifacts/hwtest-2026-11-07/REPORT.md) 与 [§7.1 交付边界](artifacts/hwtest-2026-11-07/REPORT.md)；§2.1/§6 第 4–8 项同步自 [PROGRESS](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md) 与各 `fixes/<item>/` 证据。

## 7. 证据索引

- **本次实测报告（当前结论）**：[REPORT.md](artifacts/hwtest-2026-11-07/REPORT.md)（§3 总矩阵、§4 逐子系统、§6 风险、§7 结论）
- **工具-模块配对登记**：[TOOL-MODULE-PAIRING.md](TOOL-MODULE-PAIRING.md)（模块 sha1 × 工具 sha1 × 输入流 × 期望 × 证据；§1.5 VDEC HEVC 修复对、§1.6 VENC 演进、§1.8 抓帧；错配症状）
- **修复进度（滚动）**：[fixes/PROGRESS.md](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md)（各条目状态/证据/下一轮建议）
- **修复阶段关键证据**：[VDEC-01 上板验证（7/7 + 抓帧）](artifacts/hwtest-2026-11-07/fixes/vdec-01/BOARD-VERIFY-H1.md)、[VDEC-02 reloadfix 复核（rmmod×10 + 抓帧 §5）](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md)、[VDEC-02 修复链](artifacts/hwtest-2026-11-07/fixes/vdec-02/SCD-V1-REGRESSION.md)、[VDEC-03 抓帧闭环](artifacts/hwtest-2026-11-07/fixes/vdec-03/FIX-REPORT.md)、[VDEC-04/05 结果](artifacts/hwtest-2026-11-07/fixes/vdec-04/BOARD-VDEC0405-RESULTS.md)、[VENC-01 level](artifacts/hwtest-2026-11-07/fixes/venc-01/FIX-REPORT.md)、[VENC-02 4K 边界](artifacts/hwtest-2026-11-07/fixes/venc-02/VENC-02-REPORT.md)、[PNG-01 工具误用澄清](artifacts/hwtest-2026-11-07/fixes/png-01/E0-VERIFY.md)、[GPU/DRM](artifacts/hwtest-2026-11-07/fixes/gpu-drm/FINDINGS.md)、[MISS](artifacts/hwtest-2026-11-07/fixes/miss/MISS-AUDIT.md)、[OPS](artifacts/hwtest-2026-11-07/fixes/ops/OPS-01-SOAK-DESIGN.md)
- 历史基线对照：[HISTORY-BASELINE.md](artifacts/hwtest-2026-11-07/report/HISTORY-BASELINE.md)
- 矩阵：[CODEC-SPEC-ACCEPTANCE-2026-11-06.md](CODEC-SPEC-ACCEPTANCE-2026-11-06.md)
- 报告：[CODEC-SPEC-ACCEPTANCE-REPORT-2026-11-07.md](CODEC-SPEC-ACCEPTANCE-REPORT-2026-11-07.md)
- 路线图：[HARDWARE-ACCELERATION-STATUS-ROADMAP-2026-11-07.md](HARDWARE-ACCELERATION-STATUS-ROADMAP-2026-11-07.md)
- 逐轮记录：`artifacts/spec-acceptance/roundNN-*.md`（round01–120）
- 关键轮次：round61/62（HEVC 4K60）、round104（E02 六组合）、round106/109（H.264 4K30 三 Profile）、
  round108（100Mbps）、round112（JPEG 颜色矩阵）、round99/100（PNG）、round116/119/120（稳定性与配置）

> 依据（DOC-01/03/04）：本页所有"历史通过/可复现"表述已改为"历史值 + 当前实测见 REPORT"，并加 REPORT 与配对登记链接。
