# Hi3798MV300 硬件加速能力矩阵与已知限制（DOC-07）

- 调色板 CLUT（TDE 颜色扩展）：bd8（pal8/clut8）`--clut-hw` 与 CPU LUT 逐字节 MATCH（640×480/1080p）；**bd1/2/4 可选 A2 路径**（PNG v17 `74f9c681…` + tool A2 `fd7b63cc…`，`--clut-hw` 触发：驱动 CPU 解包索引→TDE CLUT8 展开，8/8 MATCH）；A2 总耗时 ~250ms > CPU LUT 15ms ⇒ 默认仍 CPU LUT，`--clut-hw` 为显式可选（r7 能力件，不进 r6）。
- 版本：**r8-20261111（正式发布，TDE 真实 IRQ）**（发布包 `dist/hi-accel-r6-20261111.tar.gz` `dbab333d…`：6 模块同 boot = mmz_shim/vdec/venc/jpeg/PNG v15/**TDE v16k**；task-8 reload 稳定性闭环：单加载 tde_test ×10、reload ×10、service 10× restart 均 PASS）。2026-11-10 晚起：PNG 硬件整幅/交错、TDE 完整移植（功能 PASS）、16bit LE、CLUT-TDE 硬件路径（pal8 MATCH）。
- 平台：Hi3798MV300（4× Cortex-A53），mainline Linux 7.3.0 #188（2026-11-10 由 #182 升级；含 HIGH_RES_TIMERS），Ubuntu 26.04.1。
- 判定口径：见 [`ACCEPTANCE-RULES.md`](ACCEPTANCE-RULES.md)。表中"✅"仅指在当前验收配对（[`TOOL-MODULE-PAIRING.md`](TOOL-MODULE-PAIRING.md)）、当前内核上，按 R1 重试规则复现通过。
- 部署：`hi-accel.service` 开机加载 5 个模块并预热、自检，结果见 `/run/hi-accel/status`。安装与回滚使用 `install.sh`。

## 1. 能力矩阵

| 能力 | 格式 / 规格 | 分辨率上限 | 性能（中位，稳态） | 判定 | 限制 | 入口 |
|---|---|---|---|---|---|---|
| HEVC 解码 | Main / Main10，High-tier L5.1 | 3840×2160@60 | 4K60 约 72 fps（8-bit） | 🟡 | 交付间歇：1080p 首次成功率约 50–89%，重试 ≤3 次后 4K 8-bit ≥98%（VDEC-02A）；**4K 100 Mbps 与 Main10 随机 0 帧/部分交付（单次约 30–50%；坏 boot 重试 3 次也不保证）——VDEC-02D 已按 DP8 收口，记 PARTIAL** | `hi-vdec-run`（自动重试） |
| H.264 解码 | BP / MP / HP L5.1 | 3840×2160@30 | 1080p 30/30 | 🟡 | 同上（间歇），必须走 `hi-vdec-run` | `hi-vdec-run` |
| 解码抓帧 | NV21 输出，像素 bit-exact | 4K | 抓帧会降速 | ✅ | 需 `vdec_no_vcmp=1` 加载参数（运行时改无效）+ `VDEC_BUF_MB=16`；输出为解码序 | `vdec_spec_hevc_head … <dir>` |
| H.264 编码 | BP / MP / HP @L4.1，CBR / AVBR(VBR) | 1920×1088 | 1080p30 约 31–34 fps | ✅ | CBR 码率偏差约 ±5%；高熵内容会触发 RC 自动丢帧（设计行为） | `encoder_accept10` |
| HEVC 编码 | Main，CBR / AVBR | 1920×1088 | 1080p30 约 30–32 fps | ✅ | level 固定为 L4（SDK 不可改） | `encoder_accept10 --codec HEVC` |
| 4K 编码 | — | — | — | NA | 硬件上限 1920×1088，不可修 | — |
| JPEG 解码 | Baseline 4:2:0 / 4:2:2 / 4:4:4 / gray，输出 NV21 | 8000×8000（64 MP，硬件路径） | 1080p 纯解码 5.38 / 7.10 / 10.59 / 3.58 ms；64MP 162.6 ms；`hi_jpeg` 全流程 1080p 约 170 ms | ✅ | progressive / 4:4:0 / 4:1:1 走软件；gray 输出的色度平面固定 0x80（2026-11-09 晚起） | `hi_jpeg` |
| PNG 解码 | **PNGD 全硬件整幅**：GRAY 1/2/4/8/16、RGB 8/16、RGBA 8/16、GRAY+ALPHA 8/16、CLUT 1/2/4/8、**Adam7 交错（硬件 7-pass + 内核拼图）** | 8191×8191（13 bit）；64MP 已验证 | **1080p decode ~100 ms（入口 431 ms）/ 64MP 3.1 s / 1080p 交错 1193 ms**；均与 ffmpeg/libpng 参考逐字节一致 | ✅（**硬件整幅 + 硬件交错**；`hi_png_reload.ko` v7 `a1da46dc`；CLUT→TDE 路径待 v10） | 根因修复 `u32AXIConfig 0x20441→0`（见 [PNG-HW 根因报告](ref-png/PNG-HW-FULLFRAME-ROOTCAUSE-2026-11-10.md)）；**无软件兜底**；64MP 需 MMZ 余量≥256MB（cma=384M FIP 备好待验证）；CLUT 颜色展开：默认 CPU LUT（bit-exact 1.7ms/640×480）；TDE 硬件路径 `--clut-hw` pal8 已逐字节 MATCH（v15），子字节 bd1/2/4 收尾中 | `hi_png`（`hi_png_hw`） |
| VDEC+VENC+JPEG+PNG 共存 | 5 模块同 boot | — | 并发时 VDEC 吞吐约 −73% | ✅ | 并发会显著拖慢 VDEC，需降级策略（VDEC-08） | `hi-accel.service` |
| GPU（Mali450 / lima） | GLES2，EGL render node | — | 固定 200 MHz | 🟡 | 轻载 PASS；VBO 重载会触发 pp 复位；无 devfreq | `/dev/dri/renderD128` |
| 显示（DRM/HDMI） | 单 Primary plane，XR24/AR24/RG16 | 1920×1080@60 | — | ✅ | 无 EDID/HPD；无 4K 输出；weston 默认 pixman，客户端会回退 llvmpipe；**DRM-02 已闭环（#188 已刷 eMMC）**：`modetest -v` 60 s ≈3840 flips @60 Hz、0 flip/atomic 错误、`WAIT_VBLANK` p99 0.009 ms；vblank/page-flip/PTS 同步可用 | weston / modetest |
| **TDE 2D 引擎**（2026-11-10 新移植） | 作业/节点队列、fill/copy/blit(ARGB α)/CLUT8→ARGB8888；`/dev/hi_tde` + ioctl + 用户态 `tde_test` | 4096×4095（单矩形） | 作业 µs~ms 级；轮询完成 | 🟡（功能 PASS；IRQ 待 DTS/FIP） | 完整移植 17k 行驱动 + 491 行 port stubs，7.3 适配仅 1 文件；**完成链当前走 2ms 轮询**（本内核 DT 无 TDE 节点，SPI91 映射 `chip=no_irq_chip`），DT 节点方案已备好待 FIP 验证；SolidDraw 纯色 fill 不做 dst α 混合（vendor 语义限制，混合用 Bitblit 已验证） | `hi_tde.ko` + `tde_test`（`hi-accel` 待纳入） |
| VPSS / GFX2D / SEC / 音频 | — | — | — | NA | 未移植（范围外） | — |

## 2. 已知限制（集成方必读）

1. VDEC 交付间歇：单次解码可能少帧（19/20）或 0 帧。产品必须通过 `hi-vdec-run`（或同等的"关通道→重开→从 IDR 重喂"逻辑）调用，最多重试 3 次。
2. 冷启动：第一次解码吞吐只有稳态的约 0.24×。`hi-accel.service` 开机会预热一次，如果模块是手工重载的，需要自行预热。
3. VDEC 加载参数必须含 `vdec_hdr_meta=0`（否则每次解码泄漏约 48 KB MMZ，VDEC-02B）。抓帧参数必须在 insmod 时给出：`vdec_no_vcmp=1`。运行时写 `/sys/module/hi_vdec/parameters/vdec_no_vcmp` 不生效（2026-11-09 实测，0 帧）。
4. JPEG Baseline 四类采样都走硬件，但必须使用 `jpeg_test_d09`（d9959e17）或 `hi_jpeg` 入口。旧工具 `jpeg_test_jpeg01` / `jpeg_test` 编译时缺 `CHIP_TYPE_hi3798mv300` 宏，会拒绝 4:2:2/4:4:4，且 gray 和 64MP 会挂板（写物理地址 0）。不要绕过入口直接调用 `/dev/jpeg`。
5. PNG：入口 `hi_png`，**产品路径 = 硬件 PNGD（`hi_png_hw`，bit-exact，无软件兜底）**；`auto` 即硬件，失败返回非 0（不回落软件），`--mode sw` 仅保留给诊断/参考。根因修复：`u32AXIConfig` 0x20441→0（2026-11-10，见 [`ref-png/PNG-HW-FULLFRAME-ROOTCAUSE-2026-11-10.md`](ref-png/PNG-HW-FULLFRAME-ROOTCAUSE-2026-11-10.md)）。**Adam7 交错已解决**（硬件 7-pass + 内核拼图，v7 PASS 18/18）；调色板 CLUT→RGB 提供 TDE 硬件路径（`--clut-hw`，需先加载 `hi_tde.ko`；默认 CPU LUT 可回退）；64MP 需 ≥256MB 空闲 CMA（cma=384M FIP 备好待 RAM boot 验证）。
5.1 TDE：`hi_tde.ko` 完整移植（功能 PASS，`tde_test`）；完成链当前为 2ms 轮询（无 TDE DT 节点时），DT 节点 + 真实 IRQ 随 cma=384M 的 FIP 验证后启用；PNG 调色板可走 TDE CLUT（`--clut-hw`）。
6. 模块必须与 manifest 一致：`hi-accel` 在 sha1 不符时拒绝加载（`HI_STRICT_SHA1=1`），不要混用历史模块（如 `hi_vdec_hevc_head_w1`、`hi_jpeg.ko`、`hi_png_nb.ko`）。
7. 板卡 `reboot` 偶尔不生效，需要串口 RTS 复位兜底（`board_ctl.py`），根因未定位（INF-01）。
8. 无 RTC：开机后 NTP 会让墙钟大幅跳变，计时请用 `/proc/uptime` 或 `CLOCK_MONOTONIC`。
9. 长稳口径为 1h × 3 个 clean boot（OPS-02），不承诺 8h/24h。
10. 标准接口：本平台内核未启用 `CONFIG_MEDIA_SUPPORT`（无 V4L2 core/mem2mem/videobuf2），SDK 也无 hi3798 V4L2 解码驱动；**不支持 V4L2/ffmpeg hwaccel**（DRM-06=NA）。产品标准接口为 MPI（`HI_MPI_VDEC_*` / `hi-vdec-run` / hi-accel 服务）。
11. 播放/显示：当前 DRM 显示链路可用（DRM-02 闭环；1080p30 page-flip、PTS 同步已验证），"硬解→显示"紧耦合播放为 **bring-up 验证**（`drmdec`，依赖 `/dev/mem` 映射保留 MMZ 窗口），尚未产品化；产品化需 shim 持久映射 ioctl 或 dma-buf（DRM-05 遗留项）。

12. **TDE（r4 起开机加载）**：`hi_tde.ko` 完整 2D 驱动（/dev/hi_tde、fill/copy/blit-α/CLUT8）；本内核 DT 无 TDE 节点 → 完成链走 2ms 轮询（DTS 节点 + 真实 IRQ 随 cma=384M FIP 维护窗口启用）；SolidDraw 纯色 fill 不做 dst α 混合（vendor 限制）；**r5 已修**：`hi-accel.service` ExecStop 补 `rmmod hi_tde` + v16 init 寄存器恢复/CRG37 复位；restart 后立即跑 TDE job 正常（10× restart 验证）。

## 3. 证据索引

- 8 阶段回归（2026-11-09，当前配对，全 PASS）：`docs/porting/artifacts/hwtest-2026-11-07/auto/*-20261109-*`
- 开机加载与预热：`/var/log/hi-accel.log`、`/run/hi-accel/status`
- VDEC 重试统计：板上 `/var/log/hi-vdec-run/attempts.tsv`
- 长稳：`fixes/ops/ops02/runs/`（OPS-02）
- 历史与逐条闭环：[`ROADMAP-CLOSURE-MATRIX-2026-11-08.md`](ROADMAP-CLOSURE-MATRIX-2026-11-08.md)
