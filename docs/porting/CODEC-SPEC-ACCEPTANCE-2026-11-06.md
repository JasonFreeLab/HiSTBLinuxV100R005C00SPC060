# HiVXE2.0 编解码规格逐项验收

创建时间：2026-11-06（Asia/Shanghai）。状态：**2026-11-08 按"现代主流"口径收窄范围**。保留范围内：**D01 HEVC 解码、D02 H.264 解码、D09 JPEG、E01 HEVC 编码、E02 H.264 编码（均达 1080p30）通过**；**D11 PNG 部分可用**（内核驱动就绪、硬件实测解出正确局部像素，整幅受 vendor 私有流控语义限制；软件可解 64MP，8.13s）。

## 1. 验收依据与判定规则

依据用户提供的[规格书截图](artifacts/spec-acceptance/hivxe2-spec.png)，对象为当前Hi3798MV300板卡上的Linux 7.3/AArch64移植。原厂Android结果仅作参考，不代替本移植验收。本文取代旧路线图中1080p25等较低的建议指标：编码目标按规格书为单路1080p30。

每个条目分别记录：**能力配置、正确性、吞吐、持续稳定性**。只有同一被测版本在对应规格下全部通过，条目才标记“通过”。低分辨率功能成功、驱动枚举出codec、ISR计数、码流包数均不等于规格通过。

状态定义：待测试 / 缺工具或样本 / 实测失败 / 通过。缺少可运行路径时写明缺口，不能推断硬件不支持；一次成功不能覆盖未测试的Profile、位深或分辨率。

**范围调整（2026-11-08，按用户"只保留现代主流/仍广泛使用"口径）**：MPEG-1、MPEG-2、MPEG-4 Part 2、
AVS、AVS+、MVC、MJPEG 移出验收范围（D03/D04/D05/D06/D07/D08/D10 与 U01 中的 VC-1），
行内保留历史证据仅供追溯，不再作为通过/失败判定依据。保留的验收项为：
HEVC 解码（D01）、H.264 解码（D02）、JPEG 解码（D09）、**PNG 解码（D11，新增必需项）**、
HEVC/H.264 编码（E01/E02）及 CBR/VBR 两种码控。

## 2. 逐项矩阵

下表Profile组合必须分开出报告，不能用一个Profile代表整行。

| ID | 方向/格式 | 规格书宣称 | 必须覆盖的子项 | 当前完整规格状态 |
|---|---|---|---|---|
| D01 | HEVC解码 | Main/Main10，Level5.1(HIGH) 4K×2K@60fps，最大码率100M | Main Profile 8bit/Main10 10bit，L5.1/HIGH，4K60，最大100Mbps | **通过**：1080p Main/Main10 逐位一致；4K Main10 逐位一致；High-tier L5.1 4K60 8-bit 20/20、73–74fps 逐位一致；1080p 18/18 逐位一致；Main10+High-tier 4K60 8/8、71.55fps 逐位一致；**100 Mbps 4K60 压测：10/10 帧、全任务 `err_mbs=0`，吞吐中位 72.6fps（单次 54.8–77.6；20Mbps 对照 90.3fps）**；**trace 会显著拖慢吞吐（37–52fps），吞吐结论均取无 trace 值**。round61/62/107/108 |
| D02 | H.264 AVC | BP/MP/HP，Level5.1，4K×2K@30fps | Baseline/Main/High分别验证，覆盖P/B帧及多slice | **通过**（8-bit）：4K BP 18/18、HP 12/12、Main+B 12/12 均 Y 逐像素 0.0；1080p Main/High（含 B 帧）一致；**多 slice（2/4）修复后 10/10、err_mbs=0、像素一致**；吞吐 4K 48–75fps、1080p 50–165fps。round12–15/27/28/43；**round106：4K30 下 BP/MP/HP 各 20/20 帧、每帧 `err_mbs=0`（三 Profile 全覆盖；位精确仍以 High 的 4K30 sha1 结论为准）**。；**round109：`vdec_no_vcmp=1`+`VDEC_BUF_MB=16` 配置下 4K30 三 Profile 各 20/20 帧、首帧 Y 平面 sha1 与 ffmpeg 参考完全一致（Baseline 23a2ba01…、Main 2ceb8e4b…、High 5d7d450f…）**。|
| D03 | H.264 MVC | 支持MVC，4K×2K@30fps（同一规格条目） | MVC 立体（多视图）样本；4K×30fps；base+enhancement 同流 | **范围外（2026-11-08 按"现代主流"口径剔除；保留历史证据）****未具备测试条件**：无 MVC 立体样本、无 MVC 编码器；测试器已支持 mvc 参数。round16|
| D04 | MPEG-1 | 最大1080p@60fps | MPEG-1 与 MPEG-2 共用 codec 类型；1080p 样本；profile/level 以码流为准 | **范围外（2026-11-08 按"现代主流"口径剔除；保留历史证据）****实测失败**：0–1 帧；解码可发生但 **VFMW 不发布 EVNT_NEW_IMAGE**（显示序模式下），已定位为交付层共性卡点。round16/24/32/47/57|
| D05 | MPEG-2 | SP@ML、MP@HL；最大1080p@60fps | SP@ML按其合法level范围；1080p60使用MP@HL，勿造SP@ML超限样本 | **范围外（2026-11-08 按"现代主流"口径剔除；保留历史证据）****实测失败（缺陷=帧间任务状态）**：单帧预热后可完全正确（round93）；**两个连续 I 帧序列中第二个 I 帧同样出错**（361/240/4942）→ 与 P 帧语法无关，问题在**帧间任务状态/缓冲复用**（消息区、参考帧状态、描述符清理）；热身不能解决多帧错误。round05/08/24/31–33/44/57/69–94|
| D06 | MPEG-4 Part 2 | SP@L0–3、ASP@L0–5，GMC、短头格式；最大1080p@60fps | SP/ASP、GMC、short-header单独样本；profile/level与最大分辨率的组合合法性需核对 | **范围外（2026-11-08 按"现代主流"口径剔除；保留历史证据）****实测失败（进展最大）**：原 ES 0 帧；**重复序列头**后 VDH 任务可提交且出现 `err_mbs=0` 完美帧；剩余卡点为交付层——显示序下无 `EVNT_NEW_IMAGE`，解码序下出现但用户态读取阻塞。round49/56/57|
| D07 | AVS | 基准档次@级别6.0，最大1080p@60fps | AVS 基准档次 6.0；1080p 样本；需 AVS 编码器或外部样本 | **范围外（2026-11-08 按"现代主流"口径剔除；保留历史证据）****未具备测试条件**：测试器支持 avs，但无任何 AVS 样本、板上 ffmpeg 无 AVS 编码器。round16|
| D08 | AVS+ | AVS-P16，最大1080p@60fps | AVS-P16；1080p 样本；需 AVS+ 编码器或外部样本 | **范围外（2026-11-08 按"现代主流"口径剔除；保留历史证据）****未具备测试条件**：同 AVS，无样本与编码器。round16|
| D09 | JPEG Baseline | 全高清，最大6400万像素 | 1080p及64MP；子采样/最大边长须从完整规格或实现约束核实 | **通过（复验）**：Baseline 4:2:0 8-bit；1080p `rc=0` 5.39ms、64MP `rc=0` 162.63ms；Y 像素 0.001/0.0007（max 1），色度为 **NV21(VU)** 顺序、U 0.0025/V 0.0015（max 1）。未覆盖渐进式/4:2:2/4:4:4/12-bit。round01/02/51；**round110：颜色类型逐项记录子项被环境回归阻塞**（`hi_jpeg` 模块当前 boot 无法加载，含按当前内核重建版本，`Invalid module format`；4:2:0/4:2:2/4:4:4/gray 均 `CreateDecompress failed`）→ 该子项待模块恢复后补测。；**round111：`Invalid module format` 实为板上 .ko 文件损坏（sha1 不一致），校验重传后 insmod 成功**；四类颜色（420/422/444/gray）均可解出数据，但当前 `jpeg_test_v` 单帧约 5s、`rc=-1`，与历史 5.39ms 差三个数量级 → 颜色类型性能与语义需用 HAL 直连工具复测；另记录 JPEG 与 VDEC 模块因重复符号互斥。；**round112：颜色类型矩阵完成——4:2:0/4:2:2/4:4:4/gray 四类均解码成功（HAL 统一输出 NV12，整周期 197–204ms），4:2:0 与 4:4:4 的 Y 平面平均误差 0.00122/max 1（与软件参考舍入级一致）→ D09 恢复"通过"**（round110/111 的"部分"系文件损坏环境问题，已修复）。|
| D10 | MJPEG Baseline | 最大1080@40fps | 按1920×1080、40fps准备视频样本，保留原文未写p的边界说明 | **范围外（2026-11-08 按"现代主流"口径剔除；保留历史证据）****未实现**：`HI_VDEC_MJPEG_SUPPORT` 未定义（链接缺 `VDEC_MJPEG_Codec` 等）。round52 量化：硬件 JPEG 解码 5.4ms/帧，但用户态 HAL 每帧 create/destroy 固定成本 ≈64ms（>25ms@40fps 预算），同 handle 不能重复解码 → 需句柄复用/输入游标重置或内核 MJPEG 通路|
| D11 | PNG | 最大6400万像素 | 小图/1080p/64MP；颜色类型及位深按实际支持范围逐项记录 | **内核驱动就绪 + 硬件实测可解出正确局部像素（整幅受 vendor 私有流控语义限制）**：硬件存在（`drv/png`+`api/png/png-hal`，round124 已撤回"无硬件"）；`port/png` 已可 **`insmod` 成功并创建 `/dev/hi_png`（major 247）**（round135）；关键修复：调用 `port_stubs_init`、MMZ 页分配器、复用 jpeg DT virq 38 + `IRQF_SHARED`/dev_id。**已达成**：内核驱动全部就绪（`/dev/hi_png`、IRQ→virq 39、CRG210 时钟、SMMU、寄存器、MMZ→DMA 一致性）、用户态 HAL+`png_test` 全链路、**IDAT 帧流下干净会话首次解码 head 像素与 ffmpeg 逐字节一致**（round159/161）、寄存器快照 `Type=0x208` 证明硬件接受 8bit/RGB（round169）。**未达成**：整幅完成（硬件第一段内静默停止、`Int=0`、无错误码）→ 受 vendor 私有流控语义限制；已排除 SMMU/cache/时钟/中断/stride/transform/分段大小/链式续传/filter 大小（round168/170）。软件路径可解 64MP（round100）。round12/96/99/124–170 |
| E01 | HEVC编码 | MP@Level5 Main Tier，最大单路1080p@30fps | Main Profile；CBR、VBR分别测试 | **部分（Level5 不可演示，平台边界）**：Main Profile ✅、Main Tier ✅（`tier_flag=0`）、1080p30 吞吐 ✅（CBR 32.3fps / VBR 30.5fps）；level 实测 L4（120）且 SDK 明确 level 不可更改；**4K 编码创建失败 rc=0x801d0002（缓冲按 4K 修正后仍失败）→ 平台编码上限 1080p，L5 无触发场景**。round10/11/20–22/29/35/66/98/101–105 |
| E02 | H.264编码 | BP/MP/HP@Level4.1，最大单路1080p@30fps | 3个Profile × CBR/VBR，共6个基本组合 | **通过（全矩阵覆盖）**：**BP/MP/HP × CBR/AVBR 六组合在 1080p30 复杂内容下均达标**（BP/CBR 33.4、BP/AVBR 34.7、MP/CBR 30.9、MP/AVBR 34.4、HP/CBR 33.2、HP/AVBR 34.4 fps）；3 Profile 均正确声明且 **level 全为 41（L4.1）**；CBR 位率精度约 3%；AVBR=驱动 Variable（VBR）。round10/11/20/21/29/35/66/97/104 |
| U01 | VC-1及概述中的其他能力 | 概述提到VC-1，本截图没有独立性能条款 | 先查完整规格/支持表；不得自行套用1080p60 | **范围外（2026-11-08 按"现代主流"口径剔除；保留历史证据）**待补充可量化依据|

解释边界：

- “4K×2K”截图没有给出精确像素尺寸。首先测试UHD 3840×2160；另列4096×2160能力测试。未确定完整规格对4K的定义前，不用UHD通过覆盖4096宽度。
- 64MP首先选8000×8000作为候选样本，但它仅是面积为6400万的一个形状；单边尺寸限制和支持的宽高组合另行核实。失败需区分单边限制、内存不足和解码能力。
- Level/Tier标记、实际码率、参考帧数和编码工具必须检查。仅改码流标签不能生成有效的规格样本。
- MPEG-4等条款可能同时列出标准level范围和设备扩展分辨率；遇到不一致时分别报告“合规子集”和“厂家宣称扩展上限”，不伪造标准符合性。
- 截图未给出JPEG/PNG fps，也未给出CBR误差、VBR峰值和质量阈值；这些项目报告实测值，工程阈值单列，不能称为规格书原文要求。

## 3. 统一测试方法

### 3.1 样本与正确性

每个样本保存SHA256、生成/来源、codec/profile/level/tier、分辨率、位深、色度格式、帧率、帧数、码率和GOP信息。用ffprobe和必要的语法解析确认，MVC/AVS+不能只依赖通用探测器的名称。

视频解码先做离线正确性：不丢帧、不重复、输出尺寸及格式正确，显示顺序和PTS对应参考。8bit路径尽可能逐字节比较；Main10必须保留10bit值及实际plane布局，不能降到NV21 8bit后当作10bit正确性。标准允许的舍入差异需要明确参考规则及数值，不自动豁免。

编码使用已知原始图像及逐帧ID/PTS，软件解码最终输出，核对帧数、顺序和合法性，并报告PSNR/SSIM、码率及GOP。编码是有损路径，不要求与输入bit-exact。JPEG允许的IDCT差异按明确误差规则记录；PNG须无损一致。

### 3.2 吞吐与稳定性

拟定执行协议（工程验收规则）：

1. 正确性测试与性能测试使用同一版本、同一已确认配置。性能模式关闭逐帧打印和落盘，不把大量复制/软件参考解码放在关键路径。
2. 用单调时钟记录输入提交、首帧输出、末帧输出、EOS/drain完成时间；同时报告端到端fps与稳定输出区间fps。
3. 每个目标组合先做短跑定位，再做至少60秒的有效测量，重复3次；通过吞吐后做10分钟持续测试。明确初始化、预热、排空时间，不从结果中任意剔除慢帧。
4. 既测无节流最大吞吐，也测按目标fps持续送流；不能通过输入提前停止、丢帧、只计算小窗口突发峰值通过验收。
5. 全程核对输入/输出总帧数、PTS或帧标识、队列积压、超时和内核错误。按规格要求的目标速率持续处理，无非预期丢帧及持续积压方可通过。
6. 记录CPU负载、频率、可用温度信息、内存/MMZ峰值及后台负载。单项规格先单路独占测试，并发能力另列。
7. 为同一码流建立软解/软编码参考；禁止用硬件目标输出反过来生成其正确性参考。

CBR/VBR除1080p30吞吐外，还须确认实际启用对应模式、码率配置生效、输出合法，记录实际码率随场景复杂度的变化。若无厂商精度要求，只报告误差和曲线，不自行宣称满足未定义误差指标。

### 3.3 现有测试器不能直接承担规格验收

对当前`/home/jason/bringup-7.3/port/vdec-m2diag-r2/usertest/vdec_test.c`（测试器源码）的审计已确认：

- 固定H.264和FULLHD能力，不能直接验证HEVC或4K。
- AU scanner按H.264组织，不能用于其他codec。
- 顺序模式上限60个AU；threaded模式默认每次送流等待20ms，理论送流上限约50AU/s，本身不足以验证60fps。
- 帧采集固定最多50帧、640×368×1.5字节，不适合4K/Main10。
- 轮询、逐帧打印、首帧dump及固定排空时间会影响汇总fps；GetBuffer失败会停止送流，必须实现有界背压重试并记录失败。
- 现有完整性比较器以PTS=参考帧索引为基础，需要扩展B帧/实际时间戳映射。

因此保留原50帧验证器作为回归基准，新增独立规格测试路径：codec/capability显式配置、codec正确的packet边界或带索引的packet输入、无节流供流、可观测背压、正确EOS、格式感知的校验与机器可读统计。

## 4. 当前执行进度（滚动更新）

| 轮次 | 内容 | 结果 |
|---|---|---|
| round01 | 工具/样本/能力审计 | 完成；确认现有解码器与编码器均不能直接用于规格验收 |
| round02 | 新解码测试器、清理映射泄漏、修正生命周期 | 完成；H.264 基线 50/50 复现 |
| round03 | HEVC 真实失败点定位；撤回一次消息同步试验 | 完成；D01 失败点收敛到首个 VDH 任务超时 |
| round04 | 1080p Main 对照 + 钩子位置核查 | 完成；确认 HEVC 失败与分辨率/位深无关，现有消息钩子不在 HEVC 路径上 |
| round05 | 在 HEVC HAL 内部加消息发布钩子 | 完成；**1080p Main 89/90、1080p Main10 28/30 出帧且 PTS 无重复**，关闭时 0 帧；4K 仅 2 帧；像素未验证 |
| round06 | 加只读 MMZ 用量计数，证实 4K 容量上限 | 完成；4K 峰值 95.65MiB 撞满 96MiB 区、3.1 万次分配失败；640×360 仅需 23.9MiB |
| round07 | MMZ 满时回退 CMA | 完成；**4K Main10 从 4/113 提升到 111/113**（mmz_cma=8、fail=0），H.264 基线 50/50 不受影响 |
| round08 | MPEG-2/MPEG-4/MJPEG 首次实测；HAL 整体 uncached 负结果 | 完成；MPEG-2 0–2/21、MPEG-4 0/21、MJPEG 通道属性被拒（支持未编译） |
| round09 | 验证 MPEG-2 是否缺消息发布 | 完成；**负结果**：MPEG-2 确实走共享提交钩子，但发布 picture 槽后仍 0 帧；未证明代码已撤回，H.264 基线 50/50 |
| round10 | 编码首次实测（H.264 BP/MP/HP 与 HEVC 1080p30） | 完成；四配置均出可解析码流，H.264 为 level 4.1；HEVC level=0，不计通过 |
| round11 | RC 二分 + 高熵码率实测 | 完成；**撤回** round10 的「RC 导致停摆」（实为单缓冲死锁）；CBR 超目标 8 倍、AVBR 超 3–4 倍、BP+CBR 停摆 |
| round12 | H.264 4K 解码 + JPEG 1080p/64MP | 完成；H.264 Baseline L5.1 4K 16/18；JPEG 64MP rc=0（162.63ms/帧）；PNG 无路径 |
| round13 | HEVC 1080p 像素校验；4K 抓帧受阻原因；MJPEG 依赖核查 | 完成；**HEVC 1080p 逐像素一致（mean 0.0、max 0）**；4K 输出为 NV21_TILE_CMP，需解压才能校验；MJPEG 缺 codec/demux |
| round14 | 4K 输出格式控制 + 反 tile 抓帧 | 完成；新增 `vdec_no_vcmp` 使 4K 输出变为 NV21_TILE，反 tile 后可抓帧 18/18；但比对 mean 1.18/max 135，**未逐位一致**，4K 像素仍未通过 |
| round15 | 用块常量流验证反 tile 布局 | 完成；**8100/8100 块精确、抽样 mean 0.0**，反 tile 正确；故 round14 的 4K 差异归因于**解码保真度**而非抓帧，4K 像素仍未通过 |
| round16 | MPEG-1 实测；AVS/AVS+/MVC 条件核查 | 完成；MPEG-1 0/21（与 MPEG-2 同路径失败）；AVS/AVS+/MVC 无样本无编码器，记为未具备测试条件 |
| round17 | 解码节拍实测 + 瓶颈排除 | 完成；1080p HEVC 69.1ms/帧(≈14.5fps)、640×360 143ms/帧；flush/DFS/task-sleep 均非原因；**4K+16MB 环导致重启**（稳定性缺陷） |
| round18 | 拆分每帧 69ms：硬件 vs 软件 | 完成；默认 `vdec_own_isr=0` 时端口 ISR 不注册、计时钩子不触发；`own_isr=1` 下实测 **硬件 ~12ms、软件 ~54ms/帧**，瓶颈在软件出帧路径 |
| round19 | VFMw 中断耗时 + 中断接入方式对比 | 完成；ISR 后处理均值 2.2–4.3ms（max 52ms）；**端口自管中断使吞吐从 14.5 降到 9.3fps**；确认还需在默认路径找观测点 |
| round20 | 编码 RC 默认值缺陷定位与验证 | 完成；`u32DriftRateThr` 默认 `0xFFFFFFFF` 导致 RC 失效（47Mbps vs 6Mbps 目标）；设为 20 后码率受控；正常内容四档 PASS 59/60；高熵内容仍停摆 |
| round21 | 编码 RC 正式测量（drift 默认 + 实时喂帧 + 中等运动内容） | 完成；8 组合全 PASS 59/60，**CBR 误差 3–7% 达标**；H.264 为 level 4.1；**VBR 无 API 模式**、HEVC `level_idc=0` 仍不满足 |
| round22 | HEVC `level_idc=0` 根因修复 | 完成；`H265e_MakeVPS/SPS` 写死 0 → 按亮度样本率计算；板上实测 level 120(4.0)、59/60 帧、H.264 回归正常 |
| round23 | JPEG 色度校验 | 完成；色度为 NV21 顺序，1080p 与 64MP 的 Y/色度均与软件参考一致；**D09 判定通过（首个通过项）** |
| round24 | MPEG 系失败点定位 | 完成；失败在 `FSP_ConfigFrameBuf`（MPEG-2 分区 Num=3 vs imgNum=7，与分辨率无关）；排除帧存参数与内存容量；顺带实现 MMZ 对齐（提交 e0f72f9），H.264/HEVC 像素回归 0.0 |
| round25 | fsp.S 静态定位 + 插桩风险评估 | 完成；早期校验为"实例容量像素 > 通道需求像素即失败"；在 fsp.S 插桩会致板子重启（两次复现），已撤回；H.264 复验正常 |
| round26 | 检验"通道最大尺寸"修复假设 | 完成；**否证**——把 `s32MaxWidth/Height` 改为 1920×1080 后 MPEG-2 仍 0 帧（H.264 50/50 正常），该字段不是 FSP 比较项；新增 `vdec_force_maxw/h` 探针 |
| round27 | 4K High profile 解码与像素；汇总验收报告 | 完成；4K High L5.1 10/12 帧、mean 1.14（与 Baseline 同特征）；产出**汇总验收报告** `CODEC-SPEC-ACCEPTANCE-REPORT-2026-11-07.md` |
| round28 | 4K 解码"保真差异"根因 | 完成；**根因是抓帧反 tile 表错误**（SDK 表与硬件布局不符且方向相反）。实测原始布局后修正，4K H.264 Baseline/High 像素完全一致；新增 4 条回归测试 |
| round29 | 解码吞吐根因 | 完成；**每包/每 ioctl 的 pr_err 打串口控制台**是 ~50ms/帧主因；改为默认关闭后 1080p 250–289fps、4K 80–84fps、4K+16MB 无重启；并补测编码吞吐 24–28fps（<30，实时性不足） |
| round30 | MPEG 失败点再定位 + 10-bit 抓帧 | 完成；C 侧读数推翻"最大分辨率"判断；实现 10-bit 抓帧，1080p Main10 30/30、Y 偏差 max 3/1023 |
| round31 | MPEG 根因改写（**已被 round32 部分撤回**） | "分区失败"确为非致命（随后分区成功）；但"切片从未写入"是**插桩破坏寄存器**所致，已在 round32 撤回 |
| round32 | MPEG-2 真实状态 | 完成；修正钩子后 VDH 任务已提交（68 切片），但 err_mbs=48% → 无输出；记录插桩时序影响与一次 oops 事故 |
| round33 | MPEG-2 描述符 flush | 完成；`StartDec` 返回前 flush DownMsg/slice 描述符后 **首次解出并交付 1 帧**、出现 `err_mbs=0` 的正确任务；但重跑多为 0 帧，仍时序敏感、判定失败 |
| round34 | MPEG-2 竞态收窄 | 完成；端口计数显示 `ActivateVDH` 6666 次、`noparam` 6604 次、VDH 统计为 0 → 卡在 SCD→VDM 参数交付；A/B 排除喂流速率与 ISR 归属 |
| round35 | 编码吞吐精测（稳态） | 完成；用首帧→末帧间隔重算：HEVC **33.2/32.2fps**（简单/复杂）、H.264 **33.6/26.7fps**；此前 24–28fps 含建链开销，结论修正 |
| round36 | MPEG-2 交付路径定位 | 完成；通道 `open=1/run=1/f632=3`，`noparam` 来自 SCD 参数区未就绪；但计数显示 SCD/VDH/图像均执行（+20/+6/+9），图像经"占用帧"路径被**释放**（RLSIMG/RLSOCC）而未进入用户队列 → 丢失点在帧交付 |
| round37 | MPEG-2 交付复核 + 10-bit 低位分析 | 完成；`imgout=1` 正常（排除图像输出开关假设，MPEG-2 仍偶发 1 帧）；10-bit 低 2 位对所有行列偏移匹配率均 ~54%，判定低 2 位平面也是 **tile 重排**、当前线性读法错误 |
| round38 | 10-bit 2-bit 平面布局实测 | 完成；块签名搜索解出 16 行组/4 块分组的布局，修正实现后 **1080p Main10 逐位一致（mean 0.0/max 0，渐变与噪声流）**；4K 因宽度变化布局不同，仍 mean 1.23/max 3 |
| round39 | 4K Main10 逐位一致 | 完成；块签名搜索证明只有"16 行组大小"随宽度变化（块组步长 1024、块步长 128 为常量），修正后 **1080p 与 4K Main10 均 mean 0.0/max 0**；High-tier 仍无样本 |
| round40 | 稳定性 soak + High-tier 结论 | 完成；4K Main10 4K 解码 150 轮/16,950 帧 0 失败、无内核故障；High-tier 样本在本环境不可得（x265 参数无效），该项维持"未具备条件" |
| round41 | 编码尾帧 | 完成；尾帧为流水线延迟（约 3–4 帧），`--pad-tail`+4 垫帧后 H.264/HEVC 各 3/3 次 **120/120 帧**、tail_unflushed=0 |
| round43 | H.264 多 slice 修复（D02→通过） | 完成；`m2_sync_msgs` 原来对多 slice 直接跳过，改为遍历切片消息链后 2/4 slice 均 10/10、`err_mbs=0`、Y 像素 0.0；补齐 4K Main/1080p Main/High/B 帧覆盖，4K 吞吐 48–75fps |
| round42 | 高熵内容停摆刻画 | 完成；纯噪声输入先正常编码数帧后停摆（CBR/AVBR、drift 20/60/100、宽 QP、360p–1080p 均复现），dmesg 无 VENC 错误；判定为编码器能力边界、非规格验收条件 |
| round44 | MPEG-2 描述符发布实验 | 完成；per-slice 发布后宏块错误率 48%→14–21%，但仍 0–1 帧且强时序依赖；排除"仅缺描述符 flush"假说 |
| round45 | MPEG-2 切片消息布局 | 完成；解出 32B/条、w7=next 链、w5/w6=首/末宏块；切片流地址疑似比起始码晚 1 字节（待窗口验证） |
| round46 | MPEG-2 地址窗口验证 | 完成；a3 与切片起始码相对位置随调用变化（-1/+3），**撤回 round45"系统性偏移 1 字节"假设**；另查明 SSH 拒绝实为 sshd inactive（可串口重启） |
| round47 | MPEG-1/4 真实样本补测 | 完成；1080p 自产样本：MPEG-1 偶发 1 帧、MPEG-4 0 帧（且连 VDH 任务都未提交）；D04/D06 失败结论以真实样本确认 |
| round48 | MPEG-4 失败链路 | 完成；定位到 `MP4_Combine_HdPacket`（头包/VOP 合并失败，SCD 小段被当完整包）；EOP 注入实验排除；下一步按帧合并 SCD 段 |
| round49 | MPEG-4 真 ES 复测 | 完成；更正此前样本为 MP4 容器；真 ES 下仍 combine 失败（56 次），`eStd=2` 正确；EOP/整段单包均无效 |
| round50 | 综合回归验证 | 完成；H.264 多 slice 仍 30/30、4K BP 18/18 74.6fps、4K Main+B 12/12；HEVC 1080p 90/90、4K Main10 112/113 @86.7fps；1080p Main10 像素仍 **0.0**；JPEG 复验因工具缺失去留待下轮 |
| round51 | D09 JPEG 复验 | 完成；工具已纳入仓库（`a440f2e`）；1080p 5.39ms、64MP 162.63ms、Y/UV 与参考一致（max 1）；pixel 色度确认 NV21 顺序；`loops>1` 重复解码失败（D10 需解决） |
| round52 | JPEG 重复解码/MJPEG 可行性 | 完成；实测同 handle 重复解码受 HAL 输入游标限制；每帧全流程 1080p≈199ms（create 固定≈64ms + 未缓存 memset），远超 40fps 的 25ms 预算 → D10 需句柄复用/内核通路 |
| round53 | MPEG-4 LastPack 分析 | 完成；端口递交字段正常；根因锁定为 SCD 段 IsLastSeg 恒 1（LastPack=ctx+22168 未填充）；下一步对比 SCD 通道类型寄存器 |
| round54 | 撤回 IsLastSeg 推断 + 拆包实验 | 完成（部分）；H.264 同样 IsLastSeg=1 → 撤回 round53 推断；端口标非末段的拆包实验导致 VFMW 不结束、板端卡死（串口复位恢复），假设未证实 |
| round55 | MPEG-4 LastPack 写入路径 | 完成；LastPack(ctx+22168) 唯一写入者 `MP4_Record_HeadPacketInfo`（在 `Mp4_Syntax_Vos` 成功后调用）→ LastPack=NULL 说明 VOS 解析未执行或失败；下一步给 `Mp4_Syntax_Vos` 加钩子 |
| round56 | MPEG-4 重复头部 | 完成；VOS/Record 钩子证实解析与 LastPack 正常、Clean 每帧清空；重复头部流使 VDH 任务可提交且 `err_mbs=0`；交付仍 0–2 帧 |
| round57 | MPEG 交付层卡点 | 完成；事件计数对比证实 MPEG 全族在**显示序**下 VFMW 不发 `EVNT_NEW_IMAGE`（H.264 正常发）；切换解码序可出现 1 次但用户态读取阻塞。round56 的重复头部使 MPEG-4 可解出 err_mbs=0 帧 |
| round58 | NEW_IMAGE 发射点 | 完成；包装 `g_event_report` 捕获调用者 → H.264 的 NEW_IMAGE 来自 `InsertImgToVoQueue+0x400`；端口旧钩子（VCTRL 调用点）计数 0，说明生效路径不同；下一步在函数本体加钩子对比 MPEG |
| round59 | 内核越界读修复 + MPEG-4 链路 | 完成；修复 `RecvStrmBuf` 短段越界读（此前触发 `+0x1b8` oops）；MPEG-4 探针下 9/10 帧、postproc 10 次、入队返回全 1 → **全链路已通**，干净运行仍 0–1 帧（时序敏感竞态）；MPEG-2/1 重复头部仍 0 帧（宏块错误层） |
| round60 | MPEG-4 随机性刻画 | 完成；H.264 计数异常澄清（样本 30 包，无回归）；MPEG-4 交付对喂流速度/同步开关/read_seg 延迟/探针矩阵均无稳定依赖，9/10 帧成功为低概率事件；无内核 fault；判断为 VFMW 内部时序竞态 |
| round61 | D01 High-tier/4K60 | 完成；`hevc_tier_tool.py` 解析/改写 SPS tier 位；High-tier L5.1 4K60 20/20、73–74fps、前 8 帧逐位一致；High-tier 1080p 18/18 逐位一致 |
| round62 | D01 Main10+High-tier | 完成；4K60 Main10 High-tier 8/8 帧、71.55fps、8/8 帧 sha1 逐位一致；澄清"0 帧"为 tile 模式慢交付+短超时 |
| round63 | MPEG-4 再刻画 + E02 逐帧 | 完成（部分）；MPEG-4：`m2_sync_downmsg=0` 略改善（2/2/1），`m2_sync_msgs` 对 MPEG 有害、`VDEC_SPLIT_VOP` 修复后不再挂板；trace 显示 116 次 Combine 失败 vs 1 次 VDH；E02：`--motion` 稳态 27.8fps（36ms/帧），默认 33.9fps，噪声内容 RC 卡顿 |
| round64 | E02 归因 | 完成（部分）；aarch64 fake 后端测出测试器下限：默认 19.8ms/50.6fps、motion 28.8ms/34.7fps；去掉逐帧生成后 real 仍有 ≈28ms/帧固定地板 → 27.8fps 不是编码器能力结论，瓶颈在提交/MMZ 写回路径 |
| round213 | 环境对照（CMA/WiFi 排除） | 完成（环境清单化）；当前 boot 环境含 **rtw88 WiFi 栈 + samba/fwupd 等服务**，**CmaFree 仅 64MB**（历史期 137MB）；卸载全部 WiFi 模块后 **CmaFree 110MB**，但解码仍 **recv 0/2/0** → **CMA 紧张非主因（或非唯一因素）**，环境差异不止内存（模块集合/服务/内存布局）；建议：恢复历史 rootfs 或构造精简环境复测，否则在报告中标注"历史通过、当前环境不可复现"并记录本环境快照 |
| round212 | **环境差异确认（历史模块复刻失败）** | 完成（**归因收敛**）；用历史验收模块 **`hi_vdec_acc.ko` sha1 `6d33babbec7d`** + 历史参数 + 预热协议复刻：**warmup recv=3、随后 5 次测量全部 recv=0**；对照 round116 历史"预热后 10 次全部 10/10、64.5–75.6fps" → **模块/工具/流/内核均已尝试且排除，唯一剩余变量=板上运行环境**（rootfs/依赖模块/服务/boot 参数）；验收报告已补"复现性说明"：D01/D02 数据为历史证据、当前现场不可复现（非改判 FAIL，属可复现性缺口）；建议：找回历史 rootfs 快照/对比 lsmod 与 boot 参数 |
| round211 | 预热协议无效 | 完成（负结果）；按历史配方"预热一次后测量"：**warmup recv=0、测量轮次 recv=1**，第 2–4 次运行**未产出 RESULT**（工具失败） → **历史"预热即可稳定"在当前环境不成立**；与 round210 的 15/60 帧对照波动 0–15 帧，说明**间歇性故障且会累积**，非冷启动瞬态；下一步：用历史验收模块 `6d33babbec` 完整复刻预热+10 次测量、收集失败运行 dmesg、对比历史 boot 环境；在稳定复现前验收报告保持"历史证据+当前不可复现"如实表述 |
| round210 | 事件 payload 埋点 + 15/60 帧 | 完成（观测增强）；在 `VDEC_EventHandle` 加 `vdec_dbg` 门控的 payload 打印（模块 sha1 **`b00aa3ed0b`**）；1080p 本次运行 **received=15/60**（first_ms=662.9、last_ms=20533、0.7fps，此前为 0–3 帧）→ **解码链路可工作但高度依赖运行状态**；`type=113` payload 全 0 → `pArgs` 是结构体指针而非整型数组，需按类型解析；事件序列 `113→113→112→20→5→112…`；下一步：按结构体解析 113/114、统计 121/112 与帧数对比、测"预热后测量"、查帧交付节奏 |
| round209 | 事件链路验证（错误事件） | 完成（**链路排除+错误定位**）；`vdec_dbg=1` 解码 17 条事件：**112=EVNT_MEET_NEWFRM ×3、20=FIND_IFRAME、121=ARRANGE_FRAME_BUF** 均出现 → **事件分发正常（r208 的事件假设不成立）**；但同时出现 **113=EVNT_DECSYNTAX_ERR、114=EVNT_RATIO_NOTZERO** → **解码报错致帧被拒**，与历史 HANDOFF 的"repair 信息过期/err_mbs 误报"一致；下一步：打印 `ErrRatio`/`err_mbs`、复核 `u32ErrCover`(100 vs 原厂 25)、检查 `UpdateHardwareInfo/ClearIntState` 顺序 |
| round208 | **受控矩阵：推翻"分辨率分界"** | 完成（**最终更正**）；1-run-per-boot 受控实验（每次重启后只跑一次，`vdec_dfs=1 vdec_sed_only=0`）：**A fullhd+1080p60帧 → recv 0**、**B 4k+4k30 → recv 3**（first_ms=1364）、**C 4k+4k60hevc(120) → recv 0**、**D fullhd+gen3 → recv 1** → **分辨率不是分界（4K 反而解出帧，1080p 全 0）**，**"VDEC 回归"实质=解码稳定性/可靠性问题**（能解但大多数运行拿不到帧），与流格式/分辨率/工具/索引/缓冲均无关；最可疑：①事件回调 stub（EVNT_ARRANGE_FRAME_BUF/NEW_IMAGE 分发）②通道状态复位 ③时序/空闲等待；下一步：验证事件回调链路计数、固定预热协议 5 次统计、查帧交付队列 |
| round207 | ffmpeg 校验/生成 4K 流 + 稳定性暴露 | 完成；本机装好 ffmpeg：①`ffprobe` 校验板上 4K 流**合规**（H.264 Constrained Baseline L5.1 4K60、HEVC Main L5.1 4K60）；②新生成 `gen4k30.h264`(L5.0)/`gen4k60.hevc`(L5.1) + 正确索引 → **4K 仍 0 帧**；③交叉测试出现 **0/1/5 帧随机**、连续 4 次运行甚至无输出 → **"运行间不稳定"为当前主导因素**，round203–206 的"分辨率唯一分界"结论**需收紧**（单次运行不足以归因）；下一步：受控实验（每实验前重启、1-run-per-boot）：A fullhd+1080p / B 4k+4k30 / C 4k+4k60hevc / D fullhd+gen3 |
| round206 | **工具可用性验证：1080p 可解、4K 双编码 0 帧** | 完成（**分辨率唯一分界**）；①`vdec_spec h264 fullhd gen3`（1080p 单包索引）→ **received=5**（工具/索引/解码正常）；②`vdec_spec hevc 4k 4k60-20m.hevc 4k60-20m.index`（历史带索引的 4K 流）→ **0 帧**；③4K H.264 同 0 帧；对照通道参数：1080p `scdbuf=3063808` vs 4K `scdbuf=16695296` → **工具/索引/码流封装/驱动框架均正常，唯一分界是 4K 分辨率**；下一步：4K MMZ 分配清单（scdbuf 16.7MB）、4K SCD 读流、4K VDH 配置、重新生成 4K 基线流对照 |
| round205 | 4K 连 VTSTAT 都不打印 | 完成（差异定位）；4K 运行（`cap=18 max=4096x2304` 正确）期间 dmesg **只有 CHANOPT、完全没有 VTSTAT**，最终 submitted=20/received=0/idle_polls=3426；对照 1080p（gen3）**有 VTSTAT 且 img=12** → **4K 在"tick/统计打印"之前就停住**（SCD 读流或 4K SPS 解析前置失败）；下一步：C 侧计数差值、把同内容降为 1080p 对照、查 4K scdbuf 分配、4K SPS 解析约束 |
| round204 | **更正 r203：1080p 正常、4K 仍失败** | 完成（**混杂更正**）；dmesg `CHANOPT` 显示 **`vdec_test` 固定开 1080p 通道（`cap=4 max=1920x1088`）**，gen3 本就是 1080p → 正常；**4K 流在 1080p 通道下必然失败**，故 **r203"4K 经 vdec_test 也失败"被污染，需更正**；4K 用正确 harness（`vdec_spec`，`cap=18 max=4096x2304`）在历史参数下补测：**BUF_MB=8/16/32 全部 recv=0** → **1080p 完好、4K 路径失效且与缓冲无关**；下一步：抓 4K 运行 VTSTAT（read/img/vdh 增量）、查 4K SPS 解析与 scdbuf、4K HEVC 复测、原厂 ground truth |
| round203 | 4K 路径失效（gen3 正常） | 完成（范围精确定位）；历史配方 + `vdec_test` 对比：**`gen3_idr.h264` → img=12/vdh=17（正常）**；`4k-baseline.h264`（3840×2160）**无 VTSTAT 增量**（GetStreamBuf 持续）；`4k60-100m.hevc` → **`frames=0 time=6956ms`、`SetEosFlag rc=0x0`** → **4K（H.264/HEVC）经历史工具同样 0 帧，问题在 4K 解码路径本身，非工具选择**；与历史 D01/D02 的 4K PASS 对照 → **4K 解码能力回退**；下一步：确认 gen3 分辨率、4K 失败点（read/vdh 计数）、4K 缓冲/参数组合、原厂内核 ground truth |
| round202 | **突破：历史配方下 VDEC 正常** | 完成（**决定性反转**）；检索 `HANDOFF-M2-vdec-2026-11-05.md` §0 发现历史用 **`vdec_test` + `gen3_idr.h264`** 且加载参数 **`vdec_dfs=1 vdec_sed_only=0`**；按此配方实测：**`VTSTAT: put=26 read=538 img=12 ack=2 \| vdh=17 scd=24`** → **VDEC 硬件解码当前正常工作**；而 `vdec_spec` + `4k-baseline.h264/4k60-100m.hevc` 路径 0–3 帧，且板上 **`4k60-100m.index` 已缺失** → **"VDEC 回归"实为验收 harness（工具+流+索引）无法复现，非驱动/硬件回归**；下一步：用 `vdec_test` 对 4K 验收流独立复核、重生成索引、把历史可用配方写入可复现性章节 |
| round201 | git 首提交回放 | 完成（负向）；检出**首个验收提交 `1ad1764`（11-07 00:24）**，同提交重建模块 `d4337a6455` + 工具 `25abbfdf86`，成对部署后 H.264 三次 **recv 1/0/3** → **仍无法复现 10/10**；同时复核输入流 `4k-baseline.h264` 结构完整（**SPS/PPS/SEI + 1×IDR + 19×P**）；至此**代码/工具/输入/内核四维全部排除**，剩余差异指向**板上运行环境**（模块集合与顺序、MMZ/CMA 提供者版本、boot 参数）；下一步：查历史轮次是否留有 `lsmod`/`dmesg` 开头、复刻完整依赖链、两版 `hi_mmz_shim` 交叉测试 |
| round200 | **git 历史回放 A/B** | 完成（**全表对比**）；按建议用 git 回放：仓库 `vdec-m2diag-r2`（85 commits），定位 H.264 验收时点 **`64d45c5`（11-07 13:21, fixes multi-slice decode）**，`git worktree` 检出后**同提交重建模块+工具**（模块 `2835224c60` / 工具 `8265456945`）→ H.264 4K **recv 0/0/1/0**、HEVC 4K60 **0** → **同提交配对仍无法复现历史 OK**；A/B 全表：6 种模块×工具组合全部 ≤2 帧（Nov5 `6d33babbec`、7-28 `a905bdd5`、当前 `02786eee`、git `2835224c60` × 工具 当前/r10/r12/同提交）vs 历史 OK **10/10 帧 68–77fps**；结论：**模块版本非决定性变量**，历史配方未留档，差异在环境/参数/输入；下一步：`git bisect` 逐提交回放 + 找到后固化完整配方 |
| round199 | VDEC 首包拆分（负结果） | 完成（**证伪 header 分离假设**）；把首包 323,133B 拆为 "SPS/PPS(667B) + VCL 数据" 两包（21 包、PTS 顺序修正）；`vdec_spec` 提交 21 包 → **received=0**、idle_polls=2185 → 首包拆分**未恢复解码**；已排除：输入格式/工具版本/汇编埋点/包头分离/中断/MMZ/时钟/safe 线；**剩余唯一方向=当前 `hi_vdec.ko` 的 C 侧移植改动**（`drv_vdec_intf_k.c` 大量 diag 补丁/事件声明），建议以 SDK 原始 `vdec_v2.0`+`vfmw_v5.0` 为基线做**最小改动重建**（仅叠加 `VDEC_OpenModule`、IRQ 映射/翻译、port_stubs），再二分加回 diag 补丁 |
| round198 | 汇编埋点移除（负结果） | 完成（**证伪 r197**）；脚本删除三文件 **全部 48 处** `hi_vdec_dbg_tag` 埋点（h264.S 22 / vdm_drv.S 22 / vfmw_ctrl.S 4，left 0），构建 `02786eee68…` 部署后连续三次 **recv 0** → **移除埋点未恢复解码，"埋点破坏 flags/分支"假设证伪**；副作用：SPIC/VTSTAT（依赖 `g_spi_tag`）归零→失去解析层可观测性；下一步（不再改 `.S`）：C 侧加 NAL type 打印、检查 `drv_vdec_intf_k.c` 事件回调 stub、对照 Android 同源旧版 C 逻辑 |
| round197 | VDEC 汇编埋点疑点 | 完成（高概率根因）；diff 梳理：`drv_vdec_intf_k.c` 有大量移植补丁、**`h264.S` 22 处 / `vdm_drv.S` 22 处 / `vfmw_ctrl.S` 4 处 `hi_vdec_dbg_tag` 汇编埋点**；埋点形如 `stp…; mov x0,#N; bl hi_vdec_dbg_tag`，**`bl` 会破坏 NZCV 标志与 x30** → 若插在 `cmp`/`b.cond` 之间会使分支走错，与观测"参数分支从未进入（setdecparam=0/spspps=0/noparam=887）"高度吻合；验证方案：先移除 `h264.S` 埋点重建测 `setdecparam/img`，不行再依次移除 `vdm_drv.S`/`vfmw_ctrl.S`；保留驱动必需修复（OpenModule、IRQ 映射/翻译） |
| round196 | VDEC 历史工具同样失败 | 完成（更正 r195 部分推断）；默认参数下用 **`vdec_spec_r10`** 跑同一 index：`VTSTAT: put=20 read=703 img=0 ack=1 \| vdh=1 scd=17`、**`setdecparam=0`** → **历史工具同样失败**；`vdec_spec_r11` 触发连接重置（疑 oops）；结合 r195 输入格式正确 → **问题不在测试工具，而在当前 `hi_vdec.ko` 构建/移植改动**（m2-diag 埋点或桩改动破坏参数路径）；下一步：diff port/vdec 与 SDK 原始源、按最小改动原则重建（仅保留必要桩）后验证 `setdecparam/img` |
| round195 | VDEC 输入格式验证 | 完成；板上核对：index 20 包、偏移连续、总长一致（2,669,288）；**首包 `00 00 00 01 67` = Annex-B + NAL 7(SPS)**，后续 NAL 1 → **输入格式正确**；但驱动仍 `spspps=0/setdecparam=0` → 疑点转向**驱动期望的"包粒度/封装"**：首包（SPS+PPS+IDR 混合 323KB）可能需**拆分为参数集包头与帧数据**（`vdec_hdr_meta` 很可能即"头分离"语义）；下一步：①用历史工具 `vdec_spec_r10/r11/r12` 跑同 index ②手工拆分首包验证 |
| round194 | VDEC hdr_meta 实验 | 完成（对比）；`vdec_hdr_meta=0`：**nalerr=7、noparamflag=6、vdh=1**（默认 hdr_meta=1 时为 0/0/0），但 **`setdecparam` 两种模式都为 0** → `hdr_meta` 确实影响解析但参数集仍未交付；强提示**用户态喂包封装格式与解析器预期不匹配**（测试工具/index 来自 m2diag 分支，与历史 PASS 轮不同）；下一步：打印驱动收到的 NAL type 序列与码流实际（SPS7/PPS8/IDR5）对照、检查 index/喂包格式、用旧版工具重试 |
| round193 | VDEC 参数分支定位 | 完成（最后软件分支）；tag52=`**H264DEC_SetDecParam**`（`h264.S:20458`，**0 次**）、调用者在 **`H264DEC_DecodePacket`**（24501 起，24652/24754 两处 `bl`）、decpkt=18 → **DecodePacket 执行了 18 次，但 SPS/PPS 参数分支从未进入**；可能原因：①NAL 类型解析不符（nalerr=0 但可能被归类错误）②码流封装格式与解析器预期不符（`vdec_hdr_meta=1`、喂原始 Annex-B）③上层过滤；下一步：`vdec_hdr_meta=0` 单步实验、在 NAL 类型判定分支加计数打印实际 NAL type 序列 |
| round192 | VDEC 未就绪链定位 | 完成（链路映射）；把 SPIC 计数映射到 `vdm_drv.S` 埋点：**tag49=887 命中 `VDMDRV_ChnDecReady`（无参数）**、**tag51=888 命中 `VDMDRV_ActivateVDH`（全部 skip）**、**tag52/53=`SetDecParam`=0 / chkdecparam=906** → 调用链：SCD 读流→chkdecparam 反复→ChnDecReady 判无参数→ActivateVDH 全跳过→SetDecParam 从未执行→无 VDH 任务；问题集中在**参数集解析→SetDecParam**（汇编层 `vdm_drv.S` + `VCTRL_*`）；下一步：查 `syntax/h264.c` 解析结果与 `VDMDRV_ChnDecReady/ActivateVDH` 检查的参数标志位 |
| round191 | **VDEC 决定性诊断** | 完成（**根因层**）；`SPITAG` 门控后暴露模块诊断计数：`VTSTAT: put=20 read=902 **img=0** ack=0 \| **vdh=0** scd=20`、**`setdecparam=0`**、**`spspps=0`**、`noparam=887`、`chkdecparam=906`、`slice/decvdm/done=0` → **码流被 SCD 正常读取，但参数集（SPS/PPS）从未被接受 → `SetDecParam` 从未调用 → VDH 任务从未启动**；与 PNG 的"局部后静默"不同性质（VDEC 卡在解析前置阶段）；下一步：查 `noparam/skip` 路径源码、`vdec_dbg=1` 抓参数解析日志、对比历史计数、补齐可疑桩 |
| round190 | VDEC MMZ 排除 + SPITAG 噪音 | 完成（排除+诊断）；**CMA 262MB/137MB free、解码前后无变化、无分配失败** → **MMZ/CMA 非 VDEC 回归原因**；本轮 20 帧全程 0 完成（同 r186）；新发现 dmesg 被**自加埋点 `SPITAG`** 刷屏（`port_stubs.c:709`，tag 43/44/45/49/51/53 高频），**淹没 VDH/超时日志**；下一步：定位 tag 对应调用点、关/限频 SPITAG、首帧完成时读 VDH 状态寄存器 |
| round189 | safe 中断假设否定 | 完成（结论）；修正 `dev_id` 后 safe 探针注册成功（`SPI105→41`/`SPI106→42`，`/proc` 显示 `GIC-0 137/138 vdh-safe/scd-safe probe`），但解码期间 **`SAFEISR`=0** → **硬件不使用 safe 中断线（105/106）**，假设否定；同轮解码 **received=1**（first_ms=1352.8）→ **VDH 完成中断至少偶发触发**；剩余问题=**硬件只完成首帧（或极少数帧）后停止产生完成事件**（与 PNG"局部后静默"模式相似，也可能与 MMZ/参考帧容量有关）；下一步：读 VDH 状态/错误寄存器、抓首帧后 dmesg、核查 MMZ 余量与 ref 帧参数 |
| round188 | safe 中断探针 | 完成（负结果+已知坑复现）；新增 `vd_safe_irq_probe()` 映射并注册 **SPI 105（vdec_vdh_safe）/106（vdec_scd_safe）** 探针；结果两路 **`request_irq` 均 rc=-22**、`SAFEISR`=0、解码仍 0 帧；原因=**`IRQF_SHARED` + `dev_id=NULL` 违反内核要求**（与 round145/146 的 PNG 同类坑一致）；修正：探针传唯一 `dev_id`（或不用 SHARED）后重跑，判断硬件是否走 safe 线 |
| round187 | VDH 中断使能排查 | 完成（定位缺口）；`port_stubs.c` **无任何 `HI_DRV_IRQ_*`/中断使能实现**、`HI_DRV_SYS_*` 桩不含中断使能、VDH HAL 中亦无 int mask 写入引用 → 高度怀疑 vendor 的 **VDH 中断使能路径在 mainline 移植中缺失/被桩短路**；也可能实际用 **safe SPI 105/106**；下一步：反汇编 `VDMHAL_V5R2C1_OpenHAL`/`VDEC_InitHardware` 找中断屏蔽寄存器写、对照 vendor 4.4 调用链、试验注册 SPI 105/106 |
| round186 | VDEC VDH 中断缺失 | 完成（精确定位）；默认参数下解码中采样：**`vdec_scd`=20（流就绪正常）、`vdec_vdh`=0（完成中断从未触发）**、`received=0`、`idle_polls=2139` → **SCD 链路正常但 VDH 完成事件从未产生**；round184 曾见 vdh=11 → 非确定性；可能原因：①VDH 中断在硬件侧被屏蔽（中断使能/清除寄存器未正确设置）②VDH 解码任务未启动 ③硬件仍等码流 ④参数组合；下一步：读 VDH 状态/中断屏蔽寄存器、查移植中断使能路径 |
| round185 | VDEC 参数调优负结果 | 完成（负向）；怀疑 diag 参数影响帧完成，以 **`EnVcmp=0 vdec_maskdfs=0 vdec_dfs=0`** 加载 → **`HI_MPI_VDEC_ChanStart rc=0xffffffff`（通道启动失败，比默认更差）** → **参数关闭方向无效**，默认参数是当前更可用组合；失败点下移到**通道启动后的帧完成/出队**（默认参数下 received 0–7、vdh 中断 11<20）；历史 PASS 的完整加载参数未留档 → 建议固化"模块 sha1+完整 insmod 参数+工具版本"配方随证据保存 |
| round184 | **更正：VDEC 中断在触发** | 完成（**重要更正**）；round183 的"无中断"结论**撤回**——原因是**采样时机错误**（测试退出后 handler 已释放，行消失）；改为**解码进行中**采样：`38: 11 GIC-0 127 vdec_vdh`、`39: 71 GIC-0 136 vdec_scd`、`40: 0 GIC-0 181 mmu_vdh` → **厂商 virq 转换+显式 SPI 映射+trampoline 全部工作，VDEC 中断正常到达**；剩余问题=**帧完成/吞吐**（20 帧请求中 vdh 仅 11 次、用户态收 0–7 帧、多轮不稳定）；下一步：查 ISR 帧完成/出队是否被 wrapper 重复处理、SCD:VDH 比例、超时日志 |
| round183 | VDEC 中断不计数 | 完成（诊断）；同构建解码期间中断增量仅 timer/eth/usb/mmc，**无 VDEC 中断**；`/proc/interrupts` 中 **38/39/40 无对应行**（无 handler）；dmesg 显示 trampoline 注册被调用（127/136/181→38/39/40）但最终未生效；对照 round182 同构建曾收 7 帧 → **非确定性**（注册时序/复用冲突/残留）；下一步：打印 `request_irq` 返回值与映射表、查 38-40 占用、确认 `VCTRL_OpenVfmw` 结果 |
| round182 | VDEC 厂商 virq 转换 | 完成（修复+进展）；Android 源码佐证 **`VDH_IRQ_NUM (95+32)`** → vendor virq=SPI+32（127/136/181 = 95/104/149+32）；本轮：①`vd_hwirq` 改 SPI {95,104,149} 并用 **`irq_create_fwspec_mapping`** 显式映射（`/proc` 显示 GIC-0 127/136/181 = SPI 95/104/149，映射正确）②`vd_irq_translate()` 同时接受 SPI 与 vendor virq → **vfmw 自注册不再失败**（此前 `VCTRL_OpenVfmw ret=-1`→`HI_MPI_VDEC_Init rc=0x80120001`）；构建 `bc5eaf8fca…` 默认参数下 **run1 收 7 帧（3.2fps）**、run2/3 为 0 → **帧回流但稳定性待解**；下一步：按 vfmw 中断名统计增量、查通道释放/状态残留、多轮预热+BUF_MB 扫描 |
| round180 | VDEC OSAL 修复生效 | 完成（**修复验证**）；在 `drv_vdec_intf_k.c` 中于 `pfnVfmwInit` 前调用 **`VDEC_OpenModule()`**（填充 `vfmw_Osal_Func_Ptr_S`），构建 sha1 `8fd2a65019…`；dmesg 显示 **oops 消失**、`VCTRL_OpenVfmw ret=0`/`VDEC_InitHardware ret=0`/`vfmw init rc=0`/`VDEC_OpenDev ok`；4K H.264 连续三次：received 0/0/**5**（fps 13.8，first_ms=316）→ **帧开始回流**，但仍不稳定且有 `pts_errors=5`（未达历史 20/20、48–75fps）；下一步：查 pts_errors、多轮预热复测、对比历史构建事件/中断差异 |
| round179 | CabacTab oops 精确根因 | 完成（**根因确认**）；汇编分析 `vdm_hal_h264.S`：`Write_V5R2C1_CabacTab` 经 `MEM_Phy2Vir` 取 virt 后，用 **`vfmw_Osal_Func_Ptr_S[104]`**（OSAL 函数指针表）调用 memcpy（源 `g_CabacMN`，5120B），oops 的 `lr=+0x34` 正是 `blr x3` 返回地址 → **该函数指针为 NULL**（移植版未初始化 OSAL 函数表）→ `VDEC_DRV_Open` 失败 → `AllocChan=CREATECH_FAILED`；修复：定位 `vfmw_Osal_Func_Ptr_S` 定义/字段（offset 104 成员名）并在移植初始化中填充（或调用 vendor OSAL init）后重建部署验证 |
| round178 | 回归根因=HAL 初始化 oops | 完成（**决定性**）；dmesg 调用栈：**`Write_V5R2C1_CabacTab` ← `H264HAL_V5R2C1_InitHal` ← `VDMHAL_V5R2C1_OpenHAL` ← `OpenDrivers` ← `VCTRL_OpenVfmw` ← `VDEC_Init` ← `VFMW_Init` ← `VDEC_DRV_Open`** → 当前模块在 **驱动初始化期内核 oops**，通道资源未建立 → `AllocChan` 返回 `CREATECH_FAILED`；round173–177 的 0 帧现象**全部由此解释**（ABI/缓冲/MMZ/同步假设均排除）；历史 PASS 轮次所用构建在该路径未崩溃 → 回归需**特定模块构建**；下一步：对比 `Write_V5R2C1_CabacTab` 实现差异、取历史模块文件重验 |
| round177 | CREATECH_FAILED 与尺寸无关 | 完成；错误码定位 **`0x80120047 = HI_ERR_VDEC_CREATECH_FAILED`**；`VDEC_BUF_MB` 取 2/4/8/16 **全部失败**，系统内存充足（821MB/571MB available）→ 非用户态缓冲问题，指向**内核侧通道创建资源/构建配套**（`lsmod` 引用计数 2、diag 与验收构建混用、`hi_mmz_shim` CMA 大块分配限制）；下一步：失败时 `dmesg -w` 抓内核打印、查 `/proc/vfmw/info`、与 round108/116/119 的确切加载命令逐字比对 |
| round176 | 回归直接原因=AllocChan 失败 | 完成（**关键定位，更正 r174**）；按修正规程（scp→sync→复位→串口重启 ssh）加载验收构建 + `vdec_uncached_mmz=1`（`insmod=0`、sha1 匹配）；`vdec_spec` 输出 **`HI_MPI_VDEC_AllocChan rc=0x80120047`**、无 RESULT → **0 帧的直接原因=通道分配失败**（非 ABI 不匹配）；dmesg 另见启动早期内核 trace 残留；下一步：查 0x80120047 错误码（MMZ 不足/参数非法）、`dmesg -w` 抓完整栈、按需降 `VDEC_BUF_MB` 或换用 round119 成对构件 |
| round175 | 部署规程修正 | 完成（**重要更正**）；核对板端 `/` 为 ext4 持久挂载、重启后文件均在 → 此前"重启丢文件"实为 **scp 后未 `sync` 即复位**（数据滞留 page cache）；**部署规程修正：scp → sync → 复位**；回归仍受阻：验收构建+当前工具/历史 r10/r11/r12 均 0–1 帧，模块初始化正常（`VDEC_InitHardware ret=0`/`VDEC_OpenDev ok`）但 `VFMW_Chan_Ctx cached=1`；下一步按修正规程 + `vdec_uncached_mmz=1` 重试，或取当时成对构件 |
| round174 | 回归 ABI 匹配 | 完成（环境诊断深化）；部署**验收构建** `out/deploy/hi_vdec.ko`（1,954,400B、sha1 `6d33babbec`、无 SPITAG）后仍 **H264 仅 1 帧 / HEVC 0 帧**、`transport_ok=false` → 回归需**成对匹配的（验收模块 + 对应 `vdec_spec` 工具）**，当前工具来自 m2diag 分支存在 ABI/结构体差异；**交付建议**：在验收文档注明该复现前提；D01/D02 历史证据保持有效 |
| round173 | 回归环境前提 | 完成（环境诊断）；尝试回归 D01/D02 时 **0 帧**（`transport_ok=false`；`VDEC_BUF_MB=8` 仅 2 帧、1.76fps）；根因=**板上 `hi_vdec.ko` 为 1.68MB diag 构建**（含 `SPITAG` 调试、参数无 `vdec_no_vcmp`/`VDEC_BUF_MB`），非验收构建 → 属**环境前提不满足**，非 PASS 结论推翻；文档中 D01/D02 证据（sha1/err_mbs/fps）保持有效；建议文档补注"环境前提：验收构建 hi_vdec" |
| round172 | PNG IDAT 帧对齐 | 完成（负结果）；发现测试 PNG 有 **53 个 4096B IDAT 块**；按**每节点=一个完整 IDAT 帧**（4108B）提交后结果与 32KB/1600B/单缓冲**完全一致**（head 正确、goodrows 15/1080、`Int=0`、`Type=0x208`）→ **停止点与分段方式无关**，属 **vendor 私有解码器状态机语义**（需 vendor 文档/用户态栈）；PNG 维持"部分可用"定档，已排除清单补入 IDAT 帧对齐 |
| round171 | 文档一致性清扫 | 完成；系统扫描四份文档中"PNG 硬件缺口/无硬件路径"过期表述并**全部修正**：矩阵状态头与 D11 行、路线图 §1 完成度/PNG 章节/§5 表 K 行/P1.4/P0.1/P0 建议项（报告与一页摘要在 round170 已同步）；历史轮次行（round100/113/114）按审计纪律保留；四份文档链接校验 **4× ok**；PNG 口径现完全一致=**部分可用（硬件已证实）** |
| round170 | PNG filter 加倍 | 完成（负结果）；将 `PNG_FilterBuf` 按 **2×rowBytes(11520B)** 分配后结果**完全一致**（`match 0.49301`、`goodrows 14`、`Int=0`、流地址未推进）→ **filter 缓冲大小不是根因**，已回退至 vendor 语义；PNG 维持 round169 定档：**硬件解出正确局部像素、整幅受 vendor 私有流控语义限制**；剩余路径需 vendor 文档/用户态栈或二进制逆向 |
| round169 | PNG 停顿寄存器快照 | 完成（定档依据）；超时 dump：`Int=0`、`EMode=0xffff0000`、`Type=0x208`（**BitDepth=8、ColorFmt=RGB 被硬件正确接受**）、`bufSt/strSt` 仍为第一段（**未推进**）、`rdc=0x18028000`/`fltSt=0x18030000` 正常 → 硬件**配置接受、解出正确头部像素后在第一段内静默停止**（无中断/无错误码）；**PNG 定档**：硬件解码已实测可用（部分输出），整幅受 vendor 私有流控语义限制；已排除 SMMU/cache/时钟/中断/stride/transform/分段大小/链式续传 |
| round168 | PNG DMA 一致性实施 | 完成（负结果）；实现 `platform_device` + **`dma_alloc_coherent`**（RDC 缓冲 phys=`0x18028000` 落入 CMA），确认生效；但解码结果与修复前**完全一致**（head 正确、goodrows 15/1080、无 ISR/无状态位）→ **cache 一致性假设证伪**（该修改作为正确实现保留）；PNG 现状定档：**内核驱动就绪 + 硬件实测可解出正确局部像素**，整幅完成受 **vendor 私有流控/状态机语义**限制 |
| round167 | PNG 缓冲一致性假设 | 完成（关键新根因）；实现 10ms 分片+进程上下文轮询兜底后，**整个 2s 内 `uInt` 始终为 0**（无中断也无状态可轮询），但 head 像素正确（`7e00fd…`）→ **硬件解出开头若干行后静默停止**；根因假设：内核侧 **filter(5760B)/RDC(32KB) 缓冲由 `__get_free_pages(GFP_KERNEL\|__GFP_ZERO)` 分配，是 cacheable 内存**（`__GFP_ZERO` 脏化 cache 行，回写可能覆盖硬件写入；硬件读到污染行缓冲后静默停顿）；修复：改用**有效 device 的 `dma_alloc_coherent`**（或去 `__GFP_ZERO` + `dma_sync_*`） |
| round166 | PNG 中断交付不稳定 | 完成（新线索）；resume 埋点已就位（`resume#/switch to next/no next`）但**本轮干净 boot 全程无 ISR**（dmesg 无 `png_isr`），而寄存器/时钟/地址均正确（`StartDecode regs` 正常、`CRG33=1`）；对照 round147/149 ISR 曾正常触发 → **中断交付不稳定**，此前的"只发 resume 不发 finish"可能部分是**中断丢失假象**；下一步：①对照 `/proc/interrupts` 计数 ②ISR 计数 + 轮询 `uInt` 判断是否丢失 ③实现**内核轮询兜底**（workqueue 读 `uInt` → `PngOsiIntHandle`）验证硬件行为 |
| round165 | PNG vendor 库依赖梳理 | 完成；`libhigo_png.so` 导出 **`HIGO_ADP_*`**、导入 `HIGO_ADP_Malloc/Free/IOCreate/IORead/HIGO_SyncSurface`（由 **`nca_lib/libhigo.so`** 提供，已核对 687 导出）+ **libpng** 符号；`DT_NEEDED` 仅 libc → 需 libhigo+libhigoadp+libhigo_png+aarch64 libpng+适配层应用，工程量大于继续修 HAL；**优先路径**：内核 resume 分支打印节点序号/`u32HwUseBufPhyAddr`/`u32StreamLen`/ISR 次数，定位硬件在第几段停止（已有证据：7 节点链 ISR 只前进约 4 次 → 约上半幅正确）|
| round164 | PNG vendor 库捷径 | 完成；按 vendor 分段大小（**`PNG_INFLEXION_SIZE=40×40=1600`**）提交后结果与 32KB/单缓冲**完全一致**（head 正确、goodrows 15/1080、match 0.4935）→ **分段大小非决定因素**；已排除项汇总：硬件存在/时钟/SMMU/IRQ/寄存器/IDAT 帧/stride 对齐/transform/状态污染；**下一轮首选捷径**：直接使用 SDK 预编译 **`libhigo_png.so`**（vendor 用户态实现）在板上解 PNG——驱动已就绪，可快速判定"驱动+硬件整体是否可用" |
| round163 | PNG vendor 参数对齐 | 完成（分析）；读 vendor `hipng_decode()` 发现两处我们未对齐：①**`u32Stride` 需 16 字节对齐**（`(TmpStride+0xf)&~0xf`）②**`stTransform` 由 `hipng_set_transform()` 统一计算**（测试一直传 0）；流程确认=**IDAT 预填链 + 单次 Decode**（非每段一次 Decode）；下一步：读 `hipng_set_transform` 确定 RGB/RGBA 默认 transform 与输出 bpp，按同规则改测试后干净会话重测 |
| round162 | PNG 链式首解码 | 完成；干净会话首个解码用 **IDAT 分段链**（7×32KB）：`head=7e00fd7e00fd` 正确但 **仅 15/1080 行完全匹配、字节匹配 49.35%** → **链式续提不被硬件接受为流续传**；结论：整幅完成需**应用驱动式循环**（对标 `hipng_push_stream`：每段 `AllocBuf/SetStreamLen/Decode(nonblock)` 后等 resume 再提交下一段）+ 驱动 **resume 状态可观测** + `ReleaseBuf/DestroyDecoder` 状态重置 |
| round161 | PNG 干净会话验证 | 完成（证实）；reboot+单次解码：**decode#1 head=`7e00fd7e00fd` 与 ffmpeg rgb24 一致、match 49.6%**（≈上半幅正确），**decode#2 全零（match 48.6%≈随机）** → ①硬件干净状态下确实解码 ②**失败解码后状态污染**已证实 ③整幅未完成=流式续提问题；下一步：①干净会话首解码即用 IDAT 分段链 ②修复 `PngOsiReleaseBuf/DestroyDecoder` 状态重置 |
| round160 | PNG 复现性问题 | 完成（诊断）；在**同一模块会话内**依次尝试 链/单缓冲 × stride(5760/7680) × IEND(有/无) 共 7 组合，**全部输出全零**；对照 round159 的首次成功（head `7e00fd…`）→ 假设：**失败解码后解码器/缓冲链状态未清理**（`u32StartBufPhyAddr` 指向已消费节点或 eState 残留）；验证方案：每次实验前 reboot+insmod、只做一次解码、再测同进程二次解码；修复方向：`PngOsiReleaseBuf`/`DestroyDecoder` 完整重置状态 |
| round159 | **PNG 硬件首次解出像素** | 完成（**突破**）；从 vendor HAL `hipng_push_stream()` 发现硬件流格式=**仅 IDAT 块自组帧**（len+`"IDAT"`+data+CRC），此前整文件提交是"永远 resume/输出全零"的根因；改为提取 IDAT 流单缓冲提交后，**输出 head=`7e00fd7e00fd` 与 ffmpeg 参考一致**（RGB888 3Bpp）→ **硬件确实解码成功**；剩余：①只写出部分像素（约 48% 抽样匹配）需**IDAT 帧 + 分段链/应用式分段提交** ②完成状态（timeout）③64MP 验证 |
| round158 | PNG 非阻塞已可用 | 完成；删除 `PngOsrDecode` 强制 `bSync=TRUE` 后，**`Decode(nonblock) rc=0` 立即返回**，`GetResult` 轮询持续 `state=1(DECING)` 4s、ISR 仅 1 次 `Int=0x2`、输出全零 → 非阻塞流程打通；剩余：**应用侧逐段提交码流**（每段 `AllocBuf/SetStreamLen/Decode`）与**内核 filter/RDC 缓冲 cache 一致性**（`__get_free_pages` 为 cacheable，硬件会写 filter 缓冲） |
| round157 | PNG 非阻塞不可用 | 完成；`png_test` 用 `bSync=HI_FALSE`+`GetResult` 轮询 → `Decode` **仍阻塞 2.3s 后返回超时**；根因：内核 **`PngOsrDecode` 强制 `stCmd.stDecInfo.bSync = HI_TRUE`**（忽略用户态）→ 该版本不支持非阻塞解码；下一步补丁：删除该强制赋值、保留用户态 bSync，再测轮询/续提；若仍只 resume → 定档"硬件可用、流结束语义未对齐" |
| round156 | PNG 灰图+续跑实验 | 完成（负结果）；**8-bit 灰度 640×480 单块**同样 `DecResume` 后超时、输出全零 → 与输入格式无关；在 resume 分支加**仅一次** `PngHalResumeDecode()`（静态标志限制）→ **板端 panic 重启**（uptime 2min、dmesg 无记录）→ **ISR 内续跑路线彻底排除**；已回退；剩余方向：**非阻塞 API（`bSync=FALSE`+`GetResult` 轮询+应用侧 `SetStreamLen`/`Decode` 续提）** |
| round155 | PNG 寄存器全部接受 | 完成；`PngHalOpen` 读回全部一致（`AXI=0x20441 TMO=0x80008 IMask=0xffff0003 EMode=0xffff0000 RDC=0x0ccf8000`）、StartDecode 流寄存器按块正确（首块 32760B：`start`→`start+0x7ff7`）→ **SMMU/时钟/寄存器层全部排除**；ISR 逐段 resume（cnt 2–7）；剩余：**最后一段后的完成语义**（需结束标记/`eOutFmt` 明确设置/vendor 语义） |
| round154 | PNG SMMU 探测 | 完成；对 5 个候选基址探测：**只有 JPEG SMMU（0xf8c4f000）响应**（d0=1/d1=0x00280028/d3=0x2d，写 bit0 读回 1），VDEC/VENC/PNG 的 base+0xf000 均全 0 且写不进；盲探 0xf8a2f000 导致 insmod 崩溃 → 已回退探测代码（sha1 `9061789505c6`），保留 CRG210 时钟修复；结论：**SMMU 不是输出全零的根因**（唯一活动 SMMU 已 bypass）→ 回到 PNG 自身初始化：读回 AXIConfig/TimeOut/IntMask/ErrMode/RDC 地址、核对是否需 AXI 独立时钟、比对 vendor 4.4 初始化序列 |
| round153 | PNG SMMU 时钟修复、基址待查 | 完成；根因之一=**`PngHalSetSmmuClock()` 在未定义 `CONFIG_GFX_MMU_CLOCK` 时为空函数** → 在 `port_stubs_init` 直接写 **CRG210(0x348) bit0**，成功（`0x10→0x11`）；但 `0xf8c7f000` 的 `SMMU_SCR` **仍读回 0、写不进**（JPEG 0xf8c4f000 正常）→ **PNG SMMU 基址待确认**；下一步：探测候选基址（0xf8c7f000/0xf8c8f000/0xf8c3f000/全局 SMMU）与 SDK 库中常量 |
| round152 | PNG SMMU 写入无效 | 完成；为 PNG SMMU（0xf8c7f000）写 `glb_bypass=1` 后**读回仍 0**（JPEG 对照 CRG205=1/SMMU_SCR=1 正常）→ PNG 的 **SMMU 时钟未使能或基址不对**；输出仍全零；下一步：查 `PngHalSetSmmuClock` 的 CRG 偏移/位是否适配本板、核对 PNG SMMU 基址 |
| round151 | PNG 输出全零→SMMU 疑点 | 完成（新方向）；末段 8 字节零结束码**无效**（仍 resume）；**输出全零**（vs ffmpeg 参考 head `7e00fdff…`，out 全 0）→ 硬件未读到/未解码码流；根因指向：①**PNG SMMU 未 bypass**（`HI_GFX_InitSmmu(0xf8c7f000)`，而移植代码只调了 jpeg 的 `jpeg_smmu_bypass()`）②**cache 一致性**（`libmmz_shim.c` 的 `HI_MPI_MMZ_Flush` 为空实现，`/dev/hi_mmz` mmap 属性待查）；下一步：为 PNG SMMU 写 bypass 并读回、检查 mmap cache 属性 |
| round150 | PNG resume 回退 | 完成（安全回退）；尝试"resume 无下一块时也无条件 `PngHalResumeDecode()`"→ **板端内核 panic 重启**（事后 uptime≈2min、dmesg 无 png、/proc/interrupts 无 png 行）；已**回退**，重建 sha1 `5fecc34f688a` 与 round147 完全一致（确定性重建）；结论：结束标记必须由数据/链语义表达；下一步候选：①链尾加空节点（`AllocBuf` 不 `SetStreamLen`）②末段追加结束码 ③查 vendor 示例 ④比对 vendor 4.4 PNG resume 分支 |
| round149 | PNG 多段链生效 | 完成（部分）；`png_test` 改按 **32KB 分段**逐段 `AllocBuf`+`SetStreamLen`（共 7 段）→ **ISR 逐段触发**（`png_isr cnt=6..9 Int=0x2`，`/proc/interrupts` 计数 9），证明**流式缓冲链语义已生效**；但 7 段全部消费后硬件仍上报 `DecResume`、无下一节点 → 仍超时；缺**"码流结束"标记**；候选：①链尾加空节点(`StreamLen=0`) ②末段 `SetStreamLen=0` ③末段追加结束码（多段场景重试填充）④查 SDK PNG 示例 |
| round148 | PNG 单缓冲不足 | 完成（负结果）；把尾部填 `0xFF` 且 `SetStreamLen` 传缓冲全长（215,696）后**仍触发 resume**（`png_isr cnt=2 Int=0x2`）→ 排除"结束标记/长度不足"假设；确认 PNG 解码器按**码流缓冲链**分段消费，单节点时 `u32NextPhyaddr=0` 链断 → 需**多段 AllocBuf + SetStreamLen**；下一步：测试程序按 32KB 切段循环分配，观察 resume 次数与是否 FINISH |
| round147 | PNG 中断已通、根因=resume | 完成（关键）；ISR 已触发（`png_isr cnt=1 Int=0x2`）、`/proc/interrupts` 计数 1、`CRG33` 终值 `0x1`（时钟开+复位释放）；`Int=0x2` = **`PNG_INT_U.u32DecResume`（bit1，需下一段码流）而非 DecFinish(bit0)**；`PngOsiIntHandle` 的 resume 分支需取**链表下一块缓冲**，而我们只 `AllocBuf` 一次（`u32NextPhyaddr=0`）→ 不重启 → 超时。下一步候选：①`SetStreamLen` 传缓冲全长（215,696）②按流式语义分配多块缓冲链 ③确认"最后一块/结束标记"语义 |
| round146 | PNG 中断注册成功 | 完成（突破）；用 **`irq_create_fwspec_mapping(GIC SPI 96, LEVEL_HIGH)`**（DT 等价完整分配）→ **`request_irq(39) ret=0`**、`/dev/hi_png` 创建、`init OK`（insmod=0），解决了 round145 的 -38；剩余：**硬件完成信号未唤醒**——启动后 3ms 轮询 `Int=0`（round144 曾见 0x2）、Decode 2s 超时；下一步在 `png_isr` 加计数与 `Int` 打印、`PngHalSetClock` 末尾打印 CRG33 终值、核对 `/proc/interrupts` 的 png 行计数 |
| round145 | PNG 中断需走 DT | 完成（结论）；三种映射来源实测：jpeg virq38 注册成功但收不到 PNG 中断（hwirq 96）；`irq_find_host` + `irq_create_mapping(96)` 与"jpeg 节点 parent 域 + mapping(96)"均得 virq 39 但 **request_irq → -38 ENOSYS**；对照 `kernel/irq/irqdomain.c` 的 `irq_domain_alloc_irqs_hierarchy`（`ops->alloc==NULL` → -ENOSYS）→ **驱动自建映射缺完整域分配路径，正规解法是 DT 声明**；下一步：板级 DTS 加 `png@f8c70000` 节点（`interrupts=<GIC_SPI 96 LEVEL_HIGH>`）重建 dtb 部署 |
| round144 | PNG 硬件确实工作 | 完成（关键）；启动后轮询显示 **`uInt` 由 0 变 0x2**（硬件产生中断信号），`u32DecStart` 读回 0 属自清零正常 → **硬件已实际工作**；但 Linux 侧无 ISR（注册的是 jpeg virq 38，而 PNG 是 hwirq 96）→ 2s 超时；`CRG33=0x10` 打印位置在 enable 之前（不代表终值），需移到函数末尾复核。下一步：①中断路由（DTS 加 png 节点 `GIC_SPI 96` 重建 dtb，或核对 `irq_create_mapping(96)` 的有效性）②`png_isr` 加计数 ③CRG33 终值确认 |
| round143 | PNG 已启动无中断 | 完成；`PngHalStartDecode` 入口寄存器快照全部正确（`bufSt=18080000 bufEnd=180b4a8f strSt=18080000 strEnd=180b4a87 tgt=19100000 flt=3283f67f`）→ **硬件已正确配置并启动**；但 2s 内无中断、无 `png_isr` 输出、`GetResult`=ERR；剩余方向：①**PNG 模块时钟是否真使能**（`PERI_CRG33` 读回）②**中断线**（现复用 jpeg virq 38，vendor 为 hwirq 96）③复位释放；下一步：打印 CRG33 读回值 + StartDecode 后轮询中断状态寄存器 |
| round142 | PNG 错误码更正 | 完成（**重要更正**）；核对 `hi_png_errcode.h` 枚举：**`0x8000000D` 是 `HI_ERR_PNG_INTERRUPT`（不是 NOSTREAM，NOSTREAM=0x80000007）** → round139–141 的"NOSTREAM/码流未生效"表述**全部撤回**；dmesg 时间线显示 Decode(49.303s)→输出映射(51.332s) 间隔 **2.03s**，与 `PngOsiDecode` 的 **2 秒等待超时**完全吻合 → 根因是**解码完成中断未到达**；方向：①中断线（当前复用 jpeg virq 38，而 PNG 是 hwirq 96）②PNG 时钟/复位未使能（vendor 4.4 CRG 偏移）③SMMU/RDC 配置；下一步加 DTS png 节点或核对 virq 接管、打印 CRG 值、在 `png_isr` 加计数 |
| round141 | PNG 越过 NOSTREAM 检查 | 完成（撤回 round140 推断）；内核埋点显示 **`u32StartBufPhyAddr` 已正确置为 0x18080000**（AllocBuf→SetStreamLen 均正常），Decode 入口 `start=18080000` 非 0 → **已通过 NOSTREAM 检查**，随后分配 5760B filter 缓冲；最终仍返回 0x8000000D（同数值来自后续路径或 HAL 映射）→ 下一步读 `PngOsiDecode` 后半段并埋点 `PngHalOpen/StartDecode/GetResult` 状态机 |
| round140 | PNG NOSTREAM 根因 | 完成（定位）；改用 `AllocBuf` 回填的 `pVir` 写码流后仍 **NOSTREAM**；内核 `PngOsiDecode` 的判定为 **`pstInstance->u32StartBufPhyAddr == 0`** → `SetStreamLen` 未成功设置该字段（用户态返回 0 但内核未更新）；线索：内核 AllocBuf 期间自建 `5760B` 内部缓冲；下一步在 `PngOsiSetStreamLen` 加埋点（入参/匹配/设置结果）并核对 ioctl 命令号与结构体一致性 |
| round139 | PNG 用户态链路打通 | 完成；`open` 失败根因=**`PngOsiOpen` 依赖 TDE 模块导出表**（`HI_DRV_MODULE_GetFunction(HI_ID_TDE)` 桩返回 NULL）→ 改为返回占位表后，**Open/CreateDecoder/AllocBuf/SetStreamLen 全部 rc=0**，输出缓冲 8,294,400B 正确写出；但 **`Decode rc=0x8000000D`（HI_ERR_PNG_NOSTREAM）、state=ERR**——驱动认为码流缓冲无数据（userspace `HI_MPI_MMZ_Map` 未映射到内核侧缓冲）；下一步改用 `HI_PNG_BUF_S.pVir` 或 `HI_PNG_GetReadPtr` 提交码流 |
| round138 | PNG 测试程序构建+首跑 | 完成；`port/png-user/png_test.c`（IHDR 解析+MMZ+Decode/GetResult）用 histbv100 静态编译成功（778KB，部署 sha1 一致）；板上首跑：**IHDR 解析正常**（1920×1080 depth=8 fmt=2），但 **`HI_PNG_Open` 返回 0x80000001（DEV_NOEXIST）**——`/dev/hi_png` 节点存在（247,0）→ 实为内核 `png_open→PngOsiOpen()` 返回错误；下一步在 `PngOsiOpen` 加埋点排查（疑 `HI_GFX_Sem/Lock` 等同步原语或调试接口） |
| round137 | PNG API 流程确认 | 完成；逐函数核对 `hi_png_api.h` 后确认调用链：`Open → CreateDecoder → AllocBuf(码流缓冲) → Map/memcpy/Flush → SetStreamLen → Decode(输出phy/stride+stPngInfo+stTransform) → GetResult(阻塞) → Release/Destroy/Close`；**无 ParseHeader 接口** → 测试需自解析 PNG IHDR；下一步写 `png_test.c`（MMZ 码流/输出缓冲、IHDR 解析、ARGB8888 输出）并用 histbv100 工具链静态编译后板上验证 1080p/64MP |
| round136 | PNG 用户态骨架 | 完成；`port/png-user/` 已建（HAL `hi_png_api.c`/`png_accelerate.c`、`include/`、GFX 头、`libmmz_shim.c`）；PNG API 为**回调式读取 + 状态查询**（Open/CreateDecoder/AllocBuf/SetStreamLen/Decode/GetResult），与 JPEG 的 ParseHeader 模型不同，且未见 Parse 接口 → 测试程序可能需自行解析 PNG IHDR；下一步实现 `png_test`（MMZ 缓冲→Decode→GetResult→输出）并做 1080p/64MP 像素比对 |
| round135 | PNG 内核侧移植完成 | 完成**里程碑**；改用**复用 jpeg DT 节点的 virq 38**（vendor DTS 96=png/97=jpeg）→ `request_irq(38) ret=0`；随后 `PNGPM` 创建 **`/dev/hi_png`（major 247）**、`PNGDBG: init OK`、**`insmod` rc=0**；内核侧移植完成（关键改动：port_stubs_init 调用、MMZ 页分配器、IRQ 复用、IRQF_SHARED+dev_id）；下一步：用户态 HAL（`api/png/png-hal`）+ 1080p/64MP 解码验证 |
| round134 | PNG 中断调查 | 完成（部分）；vendor DTS 确认 **hwirq 96="png"（97="jpeg"）**、`PNG_INTNUM=128`；实现显式映射（`irq_find_host(arm,gic-400)`+`irq_create_mapping(dom,96)`）得到 **virq 39**，并补 `IRQF_SHARED`/非 NULL dev_id；但 `request_irq(39)` 依次返回 **-22 → -38(ENOSYS)**（该 virq 未绑定可用 irq_chip，疑多级中断控制器/安全划分）。下一步：查 mainline GIC 层级并在板级 DTS 加 png 节点（`interrupts=<0 96 4>`）重建 dtb，或复用 jpeg 的 virq=38（若硬件共享），或先用轮询模式验证解码 |
| round133 | PNG MMZ+OsiInit 通过 | 完成；改用**页分配器**（`__get_free_pages`+`virt_to_phys`）实现 MMZ：`mmz alloc size=32768 phys=102f0000`、**`PngOsiInit ok`**，初始化链推进到最后一个内核步骤；仅剩 **`osal_request_irq failed irq=128`**（`PngHalGetIrqNum()` 硬编码 128，mainline DTS 无 png 节点；jpeg 走 DT 得 virq=38）；下一步从 vendor DTS/中断表查 PNG 中断号或加模块参数逐个试 |
| round132 | PNG oops 真因 | 完成（决定性）；埋点+oops 回溯显示崩溃为 **`pc : dma_alloc_attrs+0x8` ← `lr : HI_DRV_MMZ_Alloc+0x40 [hi_png]`**（`ESR=0x96000004`）→ 根因是 **现代内核不允许 `dma_alloc_coherent(NULL,…)`**；且 `panic_on_oops=1` 导致板端重启、掩盖了日志。修复方案：**改用 DT 预留的 `mmz@28000000`（96 MiB）自建线性分配器**（推荐），或给 `dma_alloc_coherent` 传有效 device |
| round131 | PngHalInit 通过 | 完成；逐行埋点显示 **`PngHalInit` 全流程正常**：`base=f8c70000`、`ioremap` 成功（`db340177`）、`SetClock` OK、`MapSmmuReg` OK；崩溃点前移到 **`PngOsiResInitHandle`**（`png_osires.c`，疑涉及 `HI_GFX_KMALLOC`/osal 同步原语等未实现的桩）；下一步在该函数内逐行埋点 |
| round130 | 撤回 round128 + 重新定位 | 完成**更正**；round128 的"init 成功"实为**旧模块残留**（内存中 hi_png 非当前构建、无任何埋点日志、无节点；printk 已单独验证正常）→ **撤回**；**干净启动 + 当前构建：`insmod` 段错误（rc=139），dmesg 仅 `PNGDBG: init start`** → 崩溃在 `PngHalInit` 内（`ioremap_nocache(0xf8c70000)`/`PngHalSetClock`/`HI_GFX_MapSmmuReg`）；下一步在该函数内逐行埋点定位 |
| round129 | PNG 节点路径确认 | 完成；发现 port_stubs 的 **`HI_DRV_PM_Register` 本身就是字符设备/节点创建实现**（`alloc_chrdev_region`+`cdev_add`+`device_create`，日志 `PM_Register created /dev/%s`）；PNG init 的 `HI_GFX_PM_Register()` 应调用到它，但板上无节点/无日志 → 需用当前构建清 dmesg 重载确认（或直接在 init 显式调用 `HI_DRV_PM_Register` 创建 `/dev/hi_png`） |
| round128 | PNG init 成功 | 完成；**根因=PNG 端口未调用 `port_stubs_init()`，`g_pstRegCrg` 为 NULL 导致 `PngHalSetClock` 空指针崩溃**（round127 段错误）；修复后 **`insmod` 成功、模块稳定驻留**（对比 rc=139）；但 `/proc/devices`、`/proc/misc`、`/dev/hi_png*` 均无节点 → GFX 设备注册在桩函数中被跳过，下一步需在 port_stubs 实现最小 `misc_register` 设备节点并转发到 `s_PngExportFuncs` |
| round127 | PNG init 定位与 MMZ 实现 | 完成（部分）；埋点定位失败步=**`PngOsiInit` 的 MMZ 分配**（经 `HI_GFX_AllocMem`→`HI_DRV_MMZ_Alloc`）；已用 **`dma_alloc_coherent`** 实现 `HI_DRV_MMZ_Alloc/Release`（含 32 项 phys↔virt 表）；重新加载**越过 MMZ 步骤**但随后段错误（rc=139，dmesg 仅 `init start`）→ 崩溃点在 `PngHalInit` 的寄存器映射（`g_pstRegCrg` 仅覆盖 CRG，PNG 寄存器基址待查）；下一步查 `png_hal.h` 基址宏并在 `PngHalInit` 内逐行埋点 |
| round126 | PNG 模块构建成功 | 完成；补齐 10 个垫片符号后 **`hi_png.ko` 构建成功（42,968 字节，modpost 全解析）**；板上 sha1 一致但 `insmod` 返回 **EPERM**、无 dmesg（init 错误宏依赖 `CONFIG_GFX_DBG_ENABLE` 未开）→ 下一步开调试日志定位失败步（疑 `PngHalInit` 寄存器映射或 `osal_request_irq` IRQ 不匹配），并实现真实 `HI_DRV_MMZ_Alloc` |
| round125 | PNG 移植符号清单 | 完成；modpost 缺 10 个符号：`g_pstRegCrg/PM_*/MODULE_*/PROC_AddModule/MMZ_Alloc/MMZ_Release/SYS_SetIrqAffinity/osal_request_irq`；其中 7 个可直接复用 `port/jpeg/src2/port_stubs.c`，需新写 `HI_DRV_PROC_AddModule` 与 `HI_DRV_MMZ_Alloc/Release`（mmz 端口当前仅导出 `hi_mmz_phys2va`，或退化为 `dma_alloc_coherent`）；另注意 `HI_DRV_MODULE_Register` 与 hi_vdec/hi_jpeg 重复导出风险，png 应不导出 |
| round124 | PNG 硬件存在（更正） | 完成**重大更正**；用户提示"JPEG 与 PNG 同一解码器"后重查发现 `source/msp/drv/png/` 与 `api/png/png-hal` 存在（含 `PngHalGetIrqNum`、`HIGFX_PNG_ID`、独立 IRQ、预编译 `libhigo_png.so`）→ **撤回 round99"无硬件"结论**，正确表述为"**未移植**"；新建 `port/png`（src2/include/shim/Kbuild），C 代码编译通过，modpost 缺 8 个 vendor 符号（`g_pstRegCrg`、`HI_DRV_MMZ_Alloc`、`HI_DRV_MODULE_Register`…）→ 下一步写 port_stubs 并完成移植 |
| round123 | D09 64MP 回归 | 完成；8000×8000 JPEG 解码 **rc=0**、Y 平面采样 **mean 0.00053/max 1**；**全周期 4,188ms**（输出 160MB，memset 主导 ~38MB/s），与历史 **162.63ms 纯解码**口径不同、不矛盾 → D09 的 64MP 子项回归通过；用途上需注意"纯解码 vs 全周期"口径差异 |
| round122 | 最终回归 B 组 | 完成；**H.264 4K30 Baseline 预热后 20/20 ×2**（确认 round121 的 0 帧为新流冷启动）；**JPEG 独立 boot 回归：四类颜色 rc=0、整周期 208–215ms、输出 5,222,400B、模块哈希一致** → A+B 两组回归完成，**无通过项被推翻**；固化流程：逐流预热 / 4K解码8MB、抓帧16MB / JPEG与VDEC分boot / .ko校验sha1 / 无trace测量取中位数 |
| round121 | 最终回归 A 组 | 完成；干净启动一次性重跑：HEVC 4K60/100M 10/10、70.7fps；H.264 4K30 Main/High 20/20（**Baseline 首跑 0 帧=新流冷启动瞬态**）；H.264 编码六组合 26.5–35.0fps（BP/AVBR 26.5、HEVC CBR 28.4 本轮偏低）；结论：**短窗口(40 帧)方差大，判定仍取 N 次中位数**；新发现：冷启动瞬态也作用于"每条新流/Profile 的首次解码"，流程上应逐流预热 |
| round120 | BUF_MB=8 性能验证 | 完成；`VDEC_BUF_MB=8` 下 4K60/100Mbps **三次 66.8–75.2fps（全 ≥60）、10/10 帧**，与 16MB 相比无吞吐损失且更稳（16MB 两次 57.8/75.7）→ **建议 4K 解码默认 8MB**（抓帧仍用 16MB，两者分开配置）；D01 通过证据不受影响 |
| round119 | 交替 0 帧根因=MMZ 压力 | 完成（根因确认）；同一交替负载下 **`VDEC_BUF_MB=8` 四轮解码全部 10/10；`VDEC_BUF_MB=16` 三轮 0 帧** → 0 帧根因是 **VENC 占用 MMZ 后 4K 解码 16MB/帧缓冲分配失败**（容量问题，非时序/通道状态）；工程结论：4K 解码+编码并存时用 8MB 缓冲或确保 MMZ 余量，并先预热一次；不影响验收判定 |
| round118 | 交替失败与间隔无关 | 完成；在解码/编码间各插入 1 秒休眠仍出现 0 帧（10/0/0/10/10，5 轮 2 次），与无间隔版本（10/0/10/0/10）一致 → **排除"释放后立即使用"的简单时序竞争**，指向 MMZ/通道状态残留；需内核侧 MMZ 统计与通道创建日志才能定位；不影响单功能验收，建议避免高频交替并在切换后重开通道/预热 |
| round117 | VDEC+VENC 交替压测 | 完成（新发现）；5 轮交替（解码 4K60/100Mbps + 编码 1080p30）：**编码每轮正常 ≈35fps；解码隔次 0 帧（第 2、4 轮）**，其余 10/10 且 70–75fps；无 oops/重启/内存异常；对照"编码→解码"单向 3/3 均 10/10 → 属**解码-编码高频交替时的通道/MMZ 复用时序问题**，不影响单功能验收，工程上建议避免高频交替或切换后预热 |
| round116 | 4K 预热规避验证 | 完成；模块加载后先跑 1 次预热，随后 10 次测量**全部 10/10 帧**、吞吐 64.5–75.6fps（中位约 70.5，预热后首测仍可能低至 6.2fps 但帧完整）→ **预热可消除 round115 的 0 帧瞬态**；建议"加载后预热一次再测量/使用" |
| round115 | 4K 长稳复测 | 完成；`vdec_no_vcmp`+`VDEC_BUF_MB=16` 连续 10 次 4K60/100Mbps 解码：**未重启、无 oops**（uptime 单调 55→167s；dmesg 的 oops 匹配均为启动文本）；8/10 次 10/10 帧、稳定后 62.6–75.5fps；**前 4 次出现 2 次 0 帧 + 1 次极低 fps → 冷启动瞬态**（与 MPEG-2 首跑模式相似）；G 项"4K 重启"本轮未复现 |
| round114 | 路线图章节对齐 | 完成；重写路线图 §5"未解决问题"（11 行 A–K，MPEG/AVS/MVC 标范围外、B/C/D 标已解决、E 标平台边界、F 增补 JPEG/VDEC 符号互斥与 sha1 校验、K 新增 PNG 硬件缺口）；§6 P0 改为"保留范围收尾"（PNG 口径、HEVC L5 定性、稳定性长稳复测），P1 三项标已澄清/已定性/范围外 |
| round113 | 文档一致性收尾 | 完成；修正验收报告总览缺失的 D01 行；重写路线图"一页结论"为收窄后状态（4 通过/1 部分/1 硬件缺口）；更新路线图 VDEC/VENC/JPEG/PNG 各节（HEVC、H.264 转通过；MPEG/MVC/AVS/MJPEG 标范围外；JPEG 加颜色矩阵；PNG 定性硬件缺口）；三份文档链接/表格校验通过 |
| round112 | D09 颜色类型矩阵 | 完成；用 HAL 直连工具（哈希校验一致）单帧测试 4:2:0/4:2:2/4:4:4/gray：**四类全部解码成功**，输出统一 NV12（5,222,400B），整周期 197.25/199.93/203.57/202.78 ms；4:2:0 与 4:4:4 的 Y 平面 **mean 0.00122 / max 1**（与软件参考舍入级一致）→ D09 颜色类型与位深子项完成，**D09 恢复"通过"** |
| round111 | JPEG 模块回归修复 | 完成；`Invalid module format` 根因=板上 .ko **文件损坏**（同尺寸不同 sha1），校验重传后 insmod 成功（rc=0）；四类颜色 JPEG 均可解出数据但 `jpeg_test_v` 单帧约 5s、`rc=-1`（与历史 5.39ms 差 3 个数量级）→ 颜色类型性能/语义待 HAL 直连工具复测；记录"JPEG 与 VDEC 模块重复符号互斥"约束 |
| round110 | JPEG 颜色类型阻塞 | 完成（负结果）；生成 4:2:0/4:2:2/4:4:4/gray 四类 1080p JPEG 样本，解码全部 `CreateDecompress failed`（含此前通过的 4:2:0）；定位为 **`hi_jpeg` 模块无法加载**（旧文件与按当前内核重建版均 `Invalid module format`）→ D09 的"颜色类型逐项记录"子项被环境回归阻塞，待模块恢复后补测 |
| round109 | D02 4K30 三 Profile 位精确 | 完成；`vdec_no_vcmp=1`+`VDEC_BUF_MB=16` 下 4K30 三 Profile 均 20/20 帧、20 抓帧；**首帧 Y 平面 sha1 与 ffmpeg 参考逐字节一致**（baseline 23a2ba01…/main 2ceb8e4b…/high 5d7d450f…）→ D02 的 Profile 维度与位精确维度全覆盖 |
| round108 | D01 100Mbps 复测 | 完成；**100Mbps 4K60：10/10 帧、全任务 err_mbs=0；无 trace 吞吐 68.3/54.8/75.1/77.6/72.6 → 中位 72.6fps（≥60）**；20Mbps 对照 90.3fps；trace 开时降至 37–52fps（仪器开销，不作吞吐结论）→ **round107 的 47.17fps 判为冷跑异常值，D01 恢复"通过"** |
| round107 | D01 100Mbps 压测 | 完成（发现子项缺口）；x265 生成 **100.1 Mbps** 4K60 样本（2.08MB/10 帧）：解码 **9 次任务全部 err_mbs=0**（正确）但 **output_fps=47.17、received=9/10** → **4K60@100Mbps 组合吞吐未达 60fps**；按子项完整覆盖原则 **D01 下调为"部分"**；下轮需区分硬件上限 vs 逐包喂帧开销 |
| round106 | D02 4K30 三 Profile | 完成；板端 x264 生成 4K30 三 Profile 样本，解码 **BP/MP/HP 各 received=20、20 次任务全部 `err_mbs=0`** → D02 的 Profile 维度在 4K30 下全覆盖；位精确证据仍以 High 4K30 sha1 为准（4K 抓帧需 no_vcmp 配置，未在本轮启用） |
| round105 | 4K 编码确认不支持 | 完成；修正流缓冲按分辨率计算（4K=16.6MB）后 `HI_UNF_VENC_Create` **仍返回 0x801d0002** → 4K 编码确属不支持（非缓冲配置问题）；E01 Level5 因此无触发场景，维持"部分"；副产品：测试器缓冲改为按分辨率计算 |
| round104 | E02 全矩阵实测 | 完成；BP/MP/HP × CBR/AVBR 六组合 1080p30 复杂内容 **33.4/34.7/30.9/34.4/33.2/34.4 fps 全部达标**；profile/level 均正确（Baseline/Main/High, L4.1）→ E02 判定恢复为**通过（全矩阵）** |
| round103 | 4K 编码能力探测 | 完成；新增 `VENC_ALLOW_4K` 开关；**4K HEVC 编码 submitted=0/packets=0 → VENC 不支持 4K**（与规格 1080p30 一致）；结合 L4 实测 + level 不可更改 → E01 的 Level5 子项在本平台**不可演示**，维持"部分（Level5 不可达）" |
| round102 | E01 level 能力定性 | 完成；SDK 头文件原文明确 **"can't change the attributes of encoder level"** → level 由驱动/硬件固定，无法经 API 提升到 L5；1080p30 实测声明 L4。4K 自动声明 L5 的尝试被测试器 RC 校验拦截（未完成）→ E01 维持"部分（Level5 不可达）" |
| round101 | E01 level 子项核查 | 完成；HEVC 输出 **profile=Main（1）、tier_flag=0（Main Tier）** 正确，但 **level_idc=120（L4）≠ 规格 L5**；H.264 输出 level=41 ✅ → 按子项完整覆盖原则 **E01 从"通过"下调为"部分"**（仅 level 声明未达）；SDK VENC 头文件无 level 属性字段，需查私有 attr 结构 |
| round100 | PNG 软件逐像素验证 | 完成；生成"像素可预测"的 8000×8000 RGB PNG（7.46MB），ffmpeg 解码 16×16 裁剪窗口 **0/256 不匹配** → 64MP PNG 软件解码逐像素正确（全图 8.13s）；硬件仍无 PNG 能力（round99）→ D11 记为"软件可解/硬件缺口" |
| round99 | PNG 硬件能力结论 | 完成；SDK 证据链：`HI_UNF_VCODEC_TYPE_E` **无 PNG**；`HI_CODEC_ID_VIDEO_PNG` 全 SDK 零引用；VFMW/port 无模块 → **SoC 无 PNG 硬件解码能力**（非移植缺失）；软件可解 64MP/8.13s。收窄范围后除 PNG 外全部保留项通过 |
| round98 | E01 CBR 复测 | 完成；HEVC CBR 复杂内容 **5 次全部 32.3fps**、默认 33.2fps → **修正旧值 23.8fps 为非稳态样本**；结合 VBR 30.5fps，E01 判定更新为**通过（1080p30）**；E02 同型更新为通过（中位 32.5，记录偶发 27.4） |
| round97 | E02 运动量扫描 + 重复性 | 完成；运动量 0–32 倍扫描 32.6–33.3fps（无系统性下降）；重复性：默认 33.7×3 稳定、motion 32.5/27.4/32.7 → **修正此前"复杂内容 26.9–27.8fps"为偶发低值**，中位 ≈32.5fps（达标但偶发跌破 30）；建议以 N 次中位数判定 |
| round96 | 范围收窄 + PNG 实测 | 完成；按"现代主流"口径剔除 MPEG-1/2/4、AVS/AVS+、MVC、MJPEG（保留历史证据）；保留 HEVC/H.264/JPEG/**PNG** 解码与 HEVC/H.264 编码、CBR/VBR；**PNG 64MP 软件解码实测 8.13s（无硬件路径）**；paced 试验因串行化不可用于吞吐判定 |
| round95 | MPEG-2 消息清零实验 | 完成（负结果）；`m2_mp2_clear_msgs`（每帧写消息前清零）在 iso2I 上无改善（0/0/1 → 0/0/0），且大范围清零可能破坏其他结构 → **"消息残留"假设不被支持**；下一步精确清零 2176B 或转向帧缓冲/参考帧状态 |
| round94 | MPEG-2 帧间状态 | 完成；热身对多帧无效（3749/4384/154/8158）；**两个连续 I 帧中第二帧同样出错**（361/240/4942）→ 缺陷不在 P 帧语法，而在**帧间任务状态/缓冲复用**；下一步对比 H.264 每帧清理项，测试"任务前清零消息区" |
| round93 | MPEG-2 冷启动竞态 | 完成（根因质变）；结构对比显示两样本扩展头完全相同；**同一隔离帧 4 次解码：240 / 0 / 0 / 0** → 错误为**冷启动/状态切换竞态**，非数据/语法问题；修复方向收敛为"首任务前消息同步与状态复位"，并可评估"热身"缓解策略 |
| round92 | MPEG-2 slice 规模对比 | 完成；两码流 frame0 slice 统计相同（480/2699/1214），但 `m2-1slice` frame0 隔离解码 err=0 而 `m2all-i` frame0 在全序列 err=1782；两文件首帧字节数不同（82620/82650）不可直接对比 → 需把 `m2all-i` frame0 隔离解码以区分"帧本身问题"与"帧间/时序问题" |
| round91 | MPEG-2 全 I 帧对照 | 完成（否定 round90 建议）；全 I 帧 1080p 样本 10 帧**全部**提交 VDH 且全部带宏块错误（1782–6747/8160），而 `m2-1slice` 首帧 I 帧 err=0/像素级正确 → 失败与**切片规模/段边界**相关，不是 I/P 之分；下一步统计两码流 slice 大小分布并检查跨段 |
| round90 | MPEG-2 安全窗口观测 | 完成；改用 StartDec 入口打印链：**I 帧链值与 SlcStr 逐条一致**（12905/6345/8561）；**P 帧 SlcStr 正确、消息已写入，但未进入 StartDec** → 失败点精确到 `WriteSliceMsg`→`StartDec` 之间的 VFMW 分支；可另用全 I 帧码流单独证明 MPEG-2 解码通路 |
| round89 | MPEG-2 返回后 hook 回退 | 完成（负结果）；在 WriteSliceMsg 唯一返回点插入 dump hook 后板端重启（uptime 3min），实验未完成；已回退该 hook 并重建干净；替代方案：在 StartDec 入口（写入后/启动前安全窗口）打印链 |
| round88 | MPEG-2 入口 hook 伪影 | 完成；**撤回 round84"P 帧消息链未重写"**：hook 位于 `WriteSliceMsg` 入口，第二次调用入口处的链仍是上次（I 帧）内容 → "两次链相同"是测量伪影；同运行 SlcStr 数据显示 P 帧参数正确（12689/5881/6905）；下一步把链 dump 移到写入返回后即可判定 |
| round87 | MPEG-2 SlcStr 正确性 | 完成；同运行两次 WriteSliceMsg：P 帧 SlcStr 地址（28ae82f0）与比特长度（12689/5881/6905 = 码流−7）**全部正确** → **撤回 round85"语法层未刷新"推断**；round84 的"链相同"疑为同一任务重复写入，需同运行同时 dump 消息链与 SlcStr 复测 |
| round86 | MPEG-2 SlcStr dump | 完成（部分）；`MP2HAL_WriteSliceMsg` 入口可打印 `SlcStr[0..2]`：I 帧样本 bits=12905/6345/8561、bitoff=7、使用第二缓冲槽；本次运行仅 1 次调用（P 未提交）→ 需循环捕捉 P 帧样本对比；`slice_start_mbn/quantiser` 打印为 0，偏移待核对 |
| round85 | MPEG-2 陈旧参数来源 | 完成；hook 位于 `MP2HAL_WriteSliceMsg` 入口（**每帧一次**）→ 两条链相同说明 **语法层 `SlcStr[]` 对 P 帧未刷新**；`SlcStr` 偏移 232+44k、`BsLenInBit` 在 +8/+12；下一步在 write_slice 打印 `SlcStr[0..2]` 确认并回溯语法分支 |
| round84 | MPEG-2 陈旧 slice 消息 | 完成；两次 slice dump 中**第二条链与第一条逐字段相同**（6345/8561/7489…），而码流 P 帧 slice 比特长度为 5888/6912/6392 → **P 帧消息未被重写（陈旧 I 帧数据）**，直接解释 err_mbs=8160；下一步确认 WriteSliceMsg 在 P 任务中是否被调用 |
| round83 | MPEG-2 字段级比对 | 完成；P 帧下发参数与码流 picture coding extension **逐字段一致**（fcode 3,3/15,15、struct=3、intra_dc=0、fpred_dct=1、qtype/ivlc/ascan=0、mpeg1=0）→ 参数填充无误；剩余唯一方向为 **P 帧 slice 消息/语法**（此前只在 I 帧核验过） |
| round82 | MPEG-2 P 帧参考地址验证 | 完成；命中 P 帧提交样本：`coding_type=2 fwd=2901c000`（正是 I 帧地址）、`cur=29700000` → **参考指针正确、未被覆盖**，排除参考地址问题；剩余范围为 P 帧 `Fcode[]/FramePredFrameDct/IntraDcPrecision` 等预测参数与码流是否一致 |
| round81 | MPEG-2 P 帧偶发提交 | 完成；`vdec_occfrm_rls=1`（默认）下曾观测到 P 帧提交（coding_type=2），但连续 3 次复测又只有 I 帧 → P 帧 VDH 提交为**偶发**，与 err_mbs/received 波动同源；指向"参考帧先释放后使用"竞态，下一步循环捕捉成功提交那次并对比 fwd/cur |
| round80 | MPEG-2 P 帧被拒 | 完成；StartDec dump 证实 10 帧序列仅 1 次 VDH 提交（I 帧），P 帧在语法/FSP 层被丢弃（未到硬件）；与此前 MPEG-4 的"任务不下发"同型；下一步定位 P 帧拒绝分支与 FSP 参考帧可用性 |
| round79 | MPEG-2 参数偏移推导 | 完成；`MP2_DEC_PARAM_S`（UADDR=4B）关键偏移：PicCodingType=0、BwdRef=180、**FwdRef=184**、CurPic=188、DispFrame=200、SlcNum=232+N×44；下一步在 `hi_vdec_diag_mp2_start_dec` 打印 I/P 帧差异 |
| round78 | MPEG-2 P 帧不可交付 | 完成；P 帧 err≠0 时被 VFMW 丢弃，50s 超时仍只交付 I 帧 → 用户态抓帧分析路线不可行；下一步改为 dump VDH P 帧任务参数（forward ref 地址、picture coding type、motion_type），对照 I/P 差异 |
| round77 | MPEG-2 I 帧像素级验证 | 完成；`RefFrameNum=16` 与默认无差异（排除 DPB 容量）；**I 帧抓帧比对 mean 0.0013/max 1（2664/2073600 像素差 1）→ I 帧与参考内容完全一致**；据此把 P 帧失败定位到**预测语法/MC 或 VDH P 帧任务参数** |
| round76 | MPEG-2 DPB 参数 | 完成；连续 4 次运行 I 帧恒 err=0、P 帧 err 波动 461–2102（8160 为最坏）→ 修正 round75"P 帧恒 8160"；`RefFrameNum/DispFrameNum` 只读（0444），DPB 深度实验需 insmod 传参 |
| round75 | MPEG-2 I/P 分离 | 完成；修正索引构造（首包须从 0 开始）；2/10 帧序列显示 **I 帧 err_mbs=0、P 帧 err_mbs=8160** → 此前"14–48%"系 I/P 混合平均；根因锁定 P 帧参考/DPB；下一步查 FSP 参考帧驻留与 VDM 参考地址 |
| round74 | MPEG-2 单帧成功 + 约定否定 | 完成；`m2_mp2_bitshift` 0/+7/−7 均 `err_mbs=0` → 否定比特长度约定方向；**iso0 单 I 帧连续 3/3 received**（sync_mp2 0/1 均可）→ I 帧解码/交付路径已通，剩余为帧间参考/DPB 或 ES 跨包拼接；短序列构造待修正 |
| round73 | MPEG-2 消息全量量化 | 完成；导出全部 67 条消息：MB 范围精确；`w0` 低 16 位 = 切片比特长度 − 7（**恒差**，长度精确）；`w1` 累计字节偏移与实测差 1–4 字节（比特→字节取整）；消息自洽 → 剩余疑点为"−7 约定"方向、ES 跨包拼接、VDH 描述符；下一步做 `w0+7` 实验 |
| round72 | MPEG-2 消息字段假设 | 完成；`w0` 低 16 位≈切片**比特长度**（12905/6345 vs 实测 12912/6352，差值为起始码前填充）、`w1`≈字节长度（1616 vs 1618）；消息与码流切片一致到 1–2 字节 → 否定"SCD 划分/长度错乱"，剩余疑点为 bit/byte 混用舍入与 ES 环跨包拼接；下一步全量 68 条比对 |
| round71 | MPEG-2 slice 消息对照 | 完成（首轮）；`m2_mp2_dbg` 抓到 68 条 slice 消息：MB 范围（0–119、120–239…）与 68 行结构吻合、链式指针正常，`a3` 指向 slice 起始码 numbering 字节；消息中 `0x650=1616` 与 slice0 长度 1618（含起始码）差 2 → 存在长度字段，需按 VFMW 消息结构核对单位/位置 |
| round70 | MPEG-2 单帧隔离 | 完成；隔离 I 帧（头+单帧）仍 `err_mbs=4851` → **撤回 round69"整帧二值→帧级状态丢失"**，改为"帧内 slice 级数据/消息不匹配"；P 帧无参考不提交（预期）；下一步导出 68 条 slice 消息与码流切片逐条比对 |
| round69 | MPEG-2 帧级二值性 | 完成；板端 mpeg2video 恒按行切分（68 slice/帧），无法造单 slice 样本；新样本 trace 显示 `err_mbs=0` 与 `err_mbs=8160` 二值出现 → 问题为帧级状态/段对齐丢失，非逐 slice 损坏 |
| round68 | 消息分流核对 + MJPEG 通路 | 完成；`hi_vdec_diag_submit` 已有 H.264 布局自检（MPEG 不被动改写），修正 round63 的"需分流"表述；MJPEG 在 VFMW 属 `VFMW_USER` 外部解码器路径、端口无接入实现，且 JPEG 每帧 ≈64ms > 25ms 预算 → D10 维持未实现且需两项前置能力 |
| round67 | 驱动直通码控实验 | 完成；`/dev/hi_venc` + `CMD_VENC_SET_RC_TYPE` 直通测试：`Constant(2)` 成功（CBR 26.9fps 与 API 一致），`VariableSkipFrames(3)`/`ConstantSkipFrames(4)` 返回 `0x801d0002` **驱动未实现** → 排除"可选码控模式"作为 CBR 优化手段，CBR 复杂内容 <30fps 为真实下限 |
| round66 | VBR 语义更正 + CBR/VBR 实测 | 完成；API `AVBR` 实为驱动 `ControlRateVariable`（VBR），**撤回"VBR 无 API"**；VBR 复杂内容 H.264 33.8fps / HEVC 30.5fps 达标，CBR 复杂内容 26.8/23.8fps 不达标 → E01/E02 未满足项更正为"CBR 复杂内容" |
| round65 | E02 地板更正 | 完成；`VENC_PHASE_LOG` 显示提交/取流为**微秒级** → **撤回 round64"28ms 来自提交/MMZ 写回"的推断**；28–32ms 帧节拍来自编码器本身，`--motion` 的 61ms 尖峰来自码控 → E02 复杂内容 27.8fps 是真实能力，维持"部分" |
| 待办 | MPEG-4 竞态；MPEG-2/1 宏块错误；VBR；E02 复杂内容码控调优评估 | 未开始 |

详见 [round01](artifacts/spec-acceptance/round01-tooling-audit.md)、[round02](artifacts/spec-acceptance/round02-tooling-hevc-firstrun.md)、[round03](artifacts/spec-acceptance/round03-hevc-real-failure.md)、[round04](artifacts/spec-acceptance/round04-hevc-hook-location.md)、[round05](artifacts/spec-acceptance/round05-hevc-decode-breakthrough.md)、[round06](artifacts/spec-acceptance/round06-4k-mmz-capacity.md)、[round07](artifacts/spec-acceptance/round07-4k-cma-fallback.md)、[round08](artifacts/spec-acceptance/round08-mpeg-mjpeg-first-look.md)、[round09](artifacts/spec-acceptance/round09-mpeg2-negative-result.md)、[round10](artifacts/spec-acceptance/round10-encoder-first-results.md)、[round11](artifacts/spec-acceptance/round11-rate-control-measured.md)、[round12](artifacts/spec-acceptance/round12-h264-4k-and-jpeg-64mp.md)、[round13](artifacts/spec-acceptance/round13-hevc-pixel-exact-and-4k-tilecmp.md)、[round14](artifacts/spec-acceptance/round14-4k-tile-capture-and-gap.md)、[round15](artifacts/spec-acceptance/round15-detile-verified-4k-fidelity.md)、[round16](artifacts/spec-acceptance/round16-mpeg1-and-unavailable-formats.md)、[round17](artifacts/spec-acceptance/round17-decode-cadence-measured.md)、[round18](artifacts/spec-acceptance/round18-decode-time-split.md)、[round19](artifacts/spec-acceptance/round19-isr-cost-and-path-choice.md)、[round20](artifacts/spec-acceptance/round20-rate-control-default-defect.md)、[round21](artifacts/spec-acceptance/round21-cbr-verified-vbr-missing.md)、[round22](artifacts/spec-acceptance/round22-hevc-level-fixed.md)、[round23](artifacts/spec-acceptance/round23-jpeg-passed.md)、[round24](artifacts/spec-acceptance/round24-mpeg-fsp-partition.md)、[round25](artifacts/spec-acceptance/round25-mpeg-fsp-static-and-instrument-risk.md)、[round26](artifacts/spec-acceptance/round26-mpeg-maxdims-hypothesis-rejected.md)、[汇总验收报告](CODEC-SPEC-ACCEPTANCE-REPORT-2026-11-07.md)。

已知测量干扰：已验收模块在 SCD 中断路径对前 400 个 segment 打印 `M2SEG`，吞吐因此被压到 6–15fps；该数字不得用于规格判定，需先移除打印再测。

## 5. 执行顺序与证据目录


1. 保持M2已通过模块及参数，建立规格测试器；先用已知640×360流校准其正确性和计时。
2. H.264逐级720p/1080p/4K，分别验证BP/MP/HP及30fps上限。
3. HEVC Main 4K60，再Main10；确认内存容量和10bit输出路径，独立处理多slice消息同步。
4. MPEG-1/2/4、MJPEG，以及JPEG/PNG面积上限。
5. MVC、AVS、AVS+在样本和参考工具就绪后逐项验证，不用其他协议替代。
6. H.264编码3×2组合，再HEVC编码2种码控；纠正已有尾帧完整性问题。
7. 对通过组合执行持续测试，最终汇总通过/失败/缺测及每项证据。

证据目录：[spec-acceptance](artifacts/spec-acceptance/)。当前已保存规格截图；各测试原始日志、样本元数据、配置、模块hash、boot ID和结果随执行追加。

原M2的[50帧验收](artifacts/venc-reverse/m2-diag/round51-downmsg-fix-acceptance-20261106.md)仅作为基础回归，不占用本规格矩阵的“通过”状态。实际开发/板端实验继续记录，不把此文档本身当作完成验收。