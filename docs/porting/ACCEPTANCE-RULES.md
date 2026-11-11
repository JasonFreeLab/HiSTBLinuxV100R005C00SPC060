# 硬件加速验收规则（DOC-06）

- 版本：v1，2026-11-09。适用于 Hi3798MV300（mainline Linux 7.3.0 #188，2026-11-10 起）上 VDEC / VENC / JPEG / PNG / DRM / GPU 的全部验收、回归与报告。
- 约束力：REPORT、闭环矩阵、PROGRESS、路线图及之后新增的报告一律引用本文，不得另定口径。
- 执行实现：`tools/hwtest/run_phase.sh`（阶段编排）、`tools/deploy/hi-accel/hi-vdec-run`（运行时自愈）。

## R1 重试与 clean boot

1. 每个阶段从 clean boot 开始（`phase_boot clean`，由 `board_ctl.py reboot` 执行，不回则 RTS 复位）。
2. VDEC 用例最多尝试 3 次（`phase_case … 3`）。只要有一次 `received==expected` 且 `capture_errors==0`，就判 PASS，并记录首次是否通过。
3. 3 次都失败时，reboot 一次再跑（`phase_retry_after_reboot 1`），仍失败才算 FAIL。
4. 每个阶段只允许出现一次单 boot 失败，再失败就开缺陷单（VDEC-02 间歇性问题按 VDEC-02A 追因）。
5. PNG 硬件每个 boot 只能解一次（会话状态会被污染），只能靠 reboot 重试，不能在同一 boot 内重试。
6. 板上不得跑无关负载（`stability-load.service` 等）。soak 阶段（OPS-02）例外，并需在报告中写明负载内容。

## R2 稳定性统计口径

| 指标 | 门限 | 统计方式 |
|---|---|---|
| VDEC 1080p HEVC 首次成功率 | ≥88% | 跨 ≥3 个 boot，`/var/log/hi-vdec-run/attempts.tsv` 中 attempt=1 的通过比例 |
| VDEC 4K HEVC 最终成功率（重试 ≤3 次） | ≥98% | 同上，按最终判定统计 |
| 内核 Oops / BUG / panic | 0 | 每个 boot 的 dmesg |
| CmaFree | 不得单调下降 | soak 期间每 5 min 采样 |

## R3 性能口径

- 至少跑 N≥3 次，取中位数，不取最好值。
- 每次的统计窗口 ≥90 帧，并剔除第一次冷启动（VDEC 冷启动吞吐约为稳态的 0.24×，由 hi-accel 开机预热消除）。
- 测性能时不得打开 trace、dbg 参数或抓帧（抓帧会显著拖慢）。

## R4 配对与证据

- 模块、工具、输入流三者的 sha1 必须与 [`TOOL-MODULE-PAIRING.md`](TOOL-MODULE-PAIRING.md) 当前验收对一致。`run_phase.sh` 的 `phase_expect_sha1` 和 `hi-accel.manifest` 会强制校验，不一致即拒绝运行或加载。
- 每条证据都必须有 ENV 块：`boot_id`、模块 sha1、工具 sha1、insmod 参数、输入流 sha1。缺任何一项，结论只算"观察"。
- 已加载模块的参数或 srcversion 与阶段要求不一致时，`run_phase.sh` 会先 rmmod，再按阶段配方重载。例如 4K 抓帧需要 `vdec_no_vcmp=1`，这个参数运行时写 sysfs 不生效。

## R5 表述规范

- "历史 PASS ≠ 当前保证"：只有用当前验收对、在当前内核上按 R1 复现的结果，才能写成"PASS"。历史结论要写"历史 PASS（日期 / 配对 / 证据）"。
- HEVC 工具的 `rc=1` 和 `transport_ok=false` 是既有语义，不作判据，判据只看 `received==expected`。
- 判定只允许以下四种：

| 判定 | 定义 | 举证要求 |
|---|---|---|
| ✅ PASS | 按 R1–R4 复现通过 | 阶段证据目录 + results.csv |
| 🟡 PARTIAL | 有可用路径，但存在限制（如需重试、软件兜底） | 写明限制与兜底路径 |
| ❌ FAIL | 按 R1 重试后仍失败 | 失败证据 + 缺陷单 |
| NA | 硬件或平台不支持，不可修 | SDK、手册或寄存器层面的证据（例：VENC 上限 1920×1088 → 4K 编码 NA） |

## R6 固定约束（已定稿）

- 图像解码入口按格式拆分（2026-11-09 用户决策，取代此前"PNG 与 JPEG 同栈/统一入口"约束）：JPEG 用 `hi_jpeg`，PNG 用 `hi_png`。两者命令行、退出码（0/2/3/4）和状态行格式（`HI_JPEG …` / `HI_PNG …`）保持一致。JPEGD 与 PNGD 本就是两块独立 IP，内核模块也是 `hi_jpeg.ko` / `hi_png.ko` 各自独立。
- 4K 编码：NA（硬件不支持）。
- 长稳测试：1h × 3 个 clean boot（OPS-02）。8h/24h 已取消。
- JPEG：Baseline **4:2:0 / 4:2:2 / 4:4:4 / gray 与 ≤64 MP 均走硬件**（2026-11-09 晚 D09 起，工具 `jpeg_test_d09` / 入口 `hi_jpeg`）；progressive / 4:4:0 / 4:1:1 走软件。gray 输出的色度平面固定填 0x80。此前"仅 4:2:0、64MP 硬解挂板"的结论对应缺 `CHIP_TYPE` 宏的旧工具，已作废（见 `fixes/d09-jpeg/`）。
