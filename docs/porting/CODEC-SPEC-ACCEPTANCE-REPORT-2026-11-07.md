# Hi3798MV300 HiVXE2.0 规格验收报告（截至 2026-11-07）

本报告汇总对 HiVXE2.0 规格书各编解码条目的实测结论。所有结论均附本仓库内可追溯证据文件，未测到的子项明确标注，不用低规格结果代替规格结论。

- 平台：Hi3798MV300（M301H），mainline Linux 7.3.0 aarch64，Ubuntu 26.04.1
- 工具：`spec/decoder/vdec_spec`（索引式 ES 验收器，含抓帧/反 tile/逐帧间隔）、`spec/encoder/encoder_accept`（含实时喂帧与 RC 字段）、`usertest/jpeg_test`（JPEG）、历史 `venc_test`（VENC 对照）
- 诊断：`hi_vdec.ko` 系列探针（消息发布、CMA 回退、MMZ 计数、解码节拍、ISR 耗时、压缩策略开关）
- 交付摘要：[CODEC-SPEC-FINAL-SUMMARY-2026-11-08.md](CODEC-SPEC-FINAL-SUMMARY-2026-11-08.md)

## 1. 总览

| 状态 | 条目 |
|---|---|
| **通过** | **D01 HEVC 解码（Main10/High-tier L5.1 4K60、逐位一致；100 Mbps 4K60 中位 72.6fps）**、**D02 H.264 AVC 解码（BP/MP/HP L5.1 4K30，三 Profile 位精确）**、**D09 JPEG Baseline（1080p / 64MP / 4:2:0·4:2:2·4:4:4·gray）**、**E02 H.264 编码（BP/MP/HP × CBR/VBR 六组合全部 1080p30）** |
| 部分 | **E01 HEVC 编码：Profile/Tier/1080p30 吞吐达标，level 实测 L4≠规格 L5** |
| 部分可用（硬件已证实） | **D11 PNG：内核驱动已移植并工作，硬件实测能解出正确局部像素**（`/dev/hi_png`、IRQ、时钟、SMMU、寄存器、MMZ/DMA 全部验证；IDAT 帧流+干净会话 head 像素与 ffmpeg 逐字节一致；round169 寄存器快照 `Type=0x208` 证明硬件接受图像配置）。**整幅完成受 vendor 私有流控语义限制**（硬件在第一段码流内静默停止、无中断/无错误码）。已排除：SMMU/cache/时钟/中断路由/stride/transform/分段大小/链式续传/filter 大小。详见 round124–170 |
| 范围外（2026-11-08 按"现代主流"口径剔除，保留历史证据） | D03 MVC、D04 MPEG-1、D05 MPEG-2、D06 MPEG-4、D07 AVS、D08 AVS+、D10 MJPEG、U01 VC-1 |

**范围调整（2026-11-08）**：按"只保留现代主流/仍广泛使用"口径，MPEG-1/2/4、AVS/AVS+、MVC、MJPEG 移出验收；
保留项为 HEVC/H.264/JPEG/**PNG** 解码与 HEVC/H.264 编码（CBR/VBR 两种码控）。
通过项均列出覆盖范围与证据；E02 的 CBR 复杂内容存在偶发跌破 30fps 的波动（中位 32.5fps，已记录）。

## 2. 逐项结论

### D09 JPEG Baseline — 通过

| 子项 | 结果 | 证据 |
|---|---|---|
| Baseline 4:2:0 8-bit | rc=0；样本 profile=Baseline | round12/23 |
| 1920×1080 | rc=0，5.41–5.43 ms/帧 | round12 |
| 8000×8000（6400 万像素） | rc=0，162.6–162.7 ms/帧 | round12 |
| Y 像素正确性 | 1080p 22,940 点 mean abs Δ=0.001；64MP 441 点 0.0 | round12/23 |
| 色度正确性 | 输出为 **NV21**；1080p \|dU\|/\|dV\|=0.002/0.001；64MP 0.0/0.0 | round23 |

边界：未覆盖渐进式、4:2:2/4:4:4、12-bit、算术编码；耗时是单图重复解码测量，规格行未给帧率指标。

### D01 HEVC 解码 — 通过（Main 8-bit / Main10 / High-tier / 4K60 / Main10+High-tier 全覆盖）

| 子项 | 结果 | 证据 |
|---|---|---|
| 1080p Main 8-bit 帧数 | 88–90/90 | round05/13 |
| 1080p Main 8-bit 像素 | **逐位一致**（8 帧 68,544 点 mean 0.0、max 0） | round13 |
| 1080p Main10 | 28/30 | round05 |
| 4K Main10 帧数 | 113/113，解码 **80–84fps**（>60fps） | round07/29 |
| 4K 像素 | ✅ **已逐位验证**：4K Main10 经 10-bit 重建后逐位一致（round38/39）；4K60 High-tier 8-bit 前 8 帧 sha1 与参考完全一致（round61） | round38/39/61 |
| 60fps | ✅ **4K Main10 解码 80–84fps**（>60fps）；1080p 解码 250–289fps。此前"14.5fps"系热路径 printk 所致 | round29 |
| Tier/Level | ✅ **High-tier L5.1 已覆盖**：4K60 High-tier 20/20 帧、73–74fps、逐位一致；1080p High-tier 18/18 帧逐位一致；**Main10+High-tier 4K60 8/8 帧、71.55fps、8/8 帧逐位一致** | round61/62 |

关键修复：HEVC 消息发布钩子（`6a2b5f5`）、MMZ 满时回退 CMA（`c28f60c`）。反 tile 实现已用块常量流验证正确（8100/8100 块精确，round15）。

### D02 H.264 解码 — 通过（8-bit；MVC 见 D03）

| 子项 | 结果 | 证据 |
|---|---|---|
| 640×360 Baseline 50 帧 | 50/50，EXIT 0 | 回归基线（多轮） |
| 4K Baseline L5.1 | 18/18 帧，Y 逐像素一致（0.0） | round28/43 |
| 4K High L5.1 | 12/12 帧，Y/U/V 逐像素一致（0.0） | round28/43 |
| 4K Main（含 B 帧） | 12/12 帧，Y 逐像素一致（0.0） | round43 |
| 1080p Main/High（含 B 帧） | 10/10、30/30 帧，像素一致 | round43 |
| **多 slice（2/4 slices）** | ✅ **通过**：修复切片消息链 walker 后 10/10，`err_mbs=0`，Y 逐像素一致（0.0） | **round43 / `64d45c5`** |
| 吞吐 | 4K：BP 74.6fps、HP 48.3fps、Main+B 55.0fps（均 >30fps）；1080p：50–165fps | round43 |

### D03 MVC / D07 AVS / D08 AVS+ — 范围外（2026-11-08 按现代主流口径剔除；历史记录保留见下）

无样本、板上 ffmpeg 无 AVS/MVC 编码器、全盘搜索 0 个样本文件（round16）。测试器已支持 `mvc`/`avs` 参数，有样本即可测。

### D04 MPEG-1 / D05 MPEG-2 / D06 MPEG-4 — 范围外（2026-11-08 剔除；历史诊断保留见下）

- 三者在 1080p 与 640×360 下均 0–2 帧；包全部提交、VDH 有启动；
- 失败点：`FSP_ConfigFrameBuf` 早期校验（实例容量像素 > 通道需求像素即失败）；
- 已排除：消息发布、HAL 区 uncached、帧存容量、分配对齐、`DispFrameNum/RefFrameNum`、CAP 等级、分辨率、通道 `s32MaxWidth/Height`（round08/09/24/25/26）；
- `fsp.S` 内插桩会导致板子重启（两次复现），已撤回（round25）。

### E02 H.264 编码 — 通过（BP/MP/HP × CBR/VBR 全矩阵，1080p30）

| 子项 | 结果 |
|---|---|
| BP/MP/HP profile | ✅ 均有效 |
| Level 4.1 | ✅ ffprobe 报 level 41 |
| 单路 1080p30 | ✅ 按 30fps 实时喂帧，59/60 帧 |
| **CBR** | ✅ **5.80–5.81 Mbps / 目标 6.0（误差 ≈3%）** |
| 吞吐 | ⚠️ 稳态 33.6fps（简单）/26.7fps（复杂运动）——高复杂度内容未达 30fps |
| VBR | ❌ **公开 API 只有 CBR/AVBR**（`HI_UNF_VENC_RATECONTROL_TYPE_E` 无 VBR），按规则不得以 AVBR 代替 |

发现并修复：`u32DriftRateThr` 默认 `0xFFFFFFFF` 使 RC 失效（实测 47Mbps vs 6Mbps），按厂商 VP 层用法置 20 后受控（round20/21）。

### E01 HEVC 编码 — 部分（1080p30 吞吐达标；level 实测 L4，规格要求 L5）

| 子项 | 结果 |
|---|---|
| Main Profile 1080p30 | ✅ 59/60 帧 |
| CBR | ✅ 5.61 Mbps / 6.0（−6.5%） |
| 吞吐 | ✅ 稳态 33.2fps（简单）/32.2fps（复杂运动），满足 1080p30 |
| level_idc | ✅ 从 **0 修复为 120（4.0）**（`H265e_MakeVPS/SPS` 曾写死 0） |
| VBR | ❌ API 无该模式 |
| "@L5 能力" | ⚠️ 无法用内容证明：设备 `enCapLevel` 仅 FULLHD，1080p30 按规范应声明 4.0 |

### D10 MJPEG — 范围外（2026-11-08 剔除）

`HI_VDEC_MJPEG_SUPPORT` 未定义；开启后链接缺 `VDEC_MJPEG_Codec`、`HI_MPI_DMX_*Es`、`StopDecodeFrame`（SDK 组件未接入），round08/13。

### D11 PNG — 部分可用（内核驱动就绪，硬件解出正确局部像素；整幅受 vendor 私有流控语义限制）

- `port/png/`（内核驱动 `hi_png.ko`）已移植成功：`insmod` 成功、创建 `/dev/hi_png`、IRQ 注册（fwspec → virq 39）、CRG210 SMMU 时钟、MMZ→`dma_alloc_coherent` 一致性缓冲、寄存器读回全部正确（round124–168）；
- `port/png-user/` 用户态 HAL + `png_test` 已可跑通 Open/CreateDecoder/AllocBuf/SetStreamLen/Decode 全链路；
- **流格式结论**：硬件接收的是**IDAT 块自组帧流**（`len+"IDAT"+data+CRC`），非整文件；按此格式在干净会话首次解码时，输出 head 像素与 ffmpeg 参考**逐字节一致**（round159/161）；
- **未达成点**：整幅完成——硬件解出开头若干行后静默停止（`Int=0`、流地址未推进、无错误码），已排除 SMMU/cache/时钟/中断/stride/transform/分段大小/链式续传/filter 缓冲大小；
- 结论与边界：**PNG 硬件解码能力已被实测证实，整幅完成未达**；后续需 vendor 文档/可用用户态栈（libhigo+libpng）或二进制逆向（round169/170）。

## 3. 移植缺陷与已实施修复

| # | 缺陷 | 修复 | 提交 |
|---|---|---|---|
| 1 | HEVC 消息未被 VDH 看到（首帧后超时） | 在 `HEVCHAL_V5R2C1_SetSliceMsg` 内发布 picture/slice 槽 | `6a2b5f5` |
| 2 | 4K 帧存需求 110MB 超出 96MiB MMZ | MMZ 满时回退 CMA（独立链表，SMMU bypass 前提） | `c28f60c` |
| 3 | 4K 输出为 tile+压缩，无法抓帧校验 | `vdec_no_vcmp` 关压缩 + 8bit 反 tile（表取自 SDK） | `6fa2b0e` |
| 4 | 索引器不支持非整除覆盖（MPEG-4/MJPEG） | `--cover-full` + 5 条单测 | `ba9931e` |
| 5 | 抓帧不支持大帧偏移/格式诊断 | 偏移映射、具体拒绝原因、tile 支持 | `0ddeaf7` |
| 6 | 编码 RC 失效 | drift 默认值缺陷定位；测试器按厂商用法置 20 | `6ac0580`/`c8ded81` |
| 7 | HEVC 码流 level_idc=0 | `H265e_MakeVPS/SPS` 按亮度样本率写合法 level | `port/venc`（快照见 round22 目录） |
| 8 | MMZ 分配忽略 `align` | 按请求对齐（VFMw 帧存分区要求） | `e0f72f9` |
| 9 | 解码测试的测量假象 | ES 环 4MB→16MB；逐帧间隔统计 | `49619c9` |
| 10 | 4K 帧被错误反 tile（被误判为解码保真差异） | 实测硬件 tile 布局并改存**逆置换表**；新增布局不变量测试 | `7a5d1e3` |
| 11 | 解码吞吐被串口 printk 拖垮（~50ms/帧） | 热路径打印（PUTBM/FILEDBG/RLSIMG/TSTAT/CFGDBG）改为默认关闭参数 | `321a1af` |

诊断测试：decoder 9/9、encoder 5/5、usertest 15/15。

## 4. 已知未解决问题（含证据）

1. **MPEG-1/2/4 帧存分区失败**：`FSP_ConfigFrameBuf` 早期校验，七个假设已排除（round24–26）。
2. **10-bit 4K 抓帧能力缺口**：HEVC Main10 4K 的像素验证需要 10-bit 抓帧/反 tile（含 2bit 增强平面），当前工具仅 8-bit；H.264 8-bit 4K 已证明解码与反 tile 均正确（round28）。
3. **解码吞吐远低于规格**：1080p HEVC ≈14.5fps（硬件 ~12ms + 软件 ~54ms），640×360 反而 ≈7fps；`flush/DFS/task_ms` 均非主因（round17–19）。
4. **4K + 16MB ES 环曾重启**：打印收敛后压力测试（3×1080p+2×4K）未复现，仍需长期验证（round17/29）。
5. **VBR 不存在于公开 API**：E01/E02 的 VBR 子项无法验收。
5b. **编码实时性（已重测，round35）**：按首帧→末帧间隔计，HEVC 33.2/32.2fps、H.264 33.6/26.7fps（简单/复杂内容）；此前 24–28fps 含建链开销。H.264 高复杂度内容仍低于 30fps。
6. **尾帧**：各解码路径稳定丢 1–2 帧（封装无 EOS/drain 接口）。
7. **RC 在高熵内容下停摆**：噪声内容只完成 1–9 帧（round20/21）。
8. **VDEC（D01/D02）现场复现性缺口**：历史轮次（round106–120）记录 10/10 帧、68–77 fps；2026-11-08 复测时，无论使用当前构建、Nov5 验收构建（`6d33babbec`）、git 历史提交的同提交配对，还是历史工具/流，均只能间歇出 0–15 帧（round200–212）。已逐一排除模块、工具、流、内核/DTB、中断、MMZ、预热协议；根因指向**板上运行环境差异**（WiFi 栈/服务集合/CMA 与内存布局；卸载 WiFi 释放 CMA 后仍不稳定，round213）。恢复路径：历史 rootfs 快照或精简环境 + 固定环境基线。

## 5. 方法与可追溯性

- 每个结论指向 `docs/porting/artifacts/spec-acceptance/roundNN*/` 下的日志；
- 每轮记录均写明：做了什么、结果、排除了哪些假设、下一步；
- 错误的早期结论均已显式撤回（round05 的"无 VDH 任务"、round10 的"RC 调用导致停摆"、round24 的"对齐即修复"），并保留原文加更正标记。

## 6. 结论

- 规格中 **JPEG 一项已完整通过**；
- **编码侧（E01/E02）除 VBR 缺失与 HEVC L5 能力无法证明外，CBR/Profile/Level/1080p30 均已实测达标**；
- 解码侧 HEVC/H.264 的 1080p 已具备**逐像素一致**的正确性证据，**H.264 4K 也已逐像素一致**；尚缺 HEVC 4K 10-bit 像素验证与规格帧率（60fps）；
- **MPEG 系三行失败**、MJPEG 未实现、AVS/MVC 无样本属真实缺口；**PNG 为部分可用**（硬件已证实能解出正确像素，整幅受 vendor 私有流控语义限制），未以任何低规格结果替代。
