# Hi3798MV300 移植验收最终状态（2026-11-10，#188）

> 本文件汇总 2026-11-08 ~ 11-10 的全部验收条目最终判定、证据入口与残留限制；权威细节见 [`ROADMAP-CLOSURE-MATRIX-2026-11-08.md`](ROADMAP-CLOSURE-MATRIX-2026-11-08.md)、[`HARDWARE-ACCELERATION-FIXLIST-ROADMAP-2026-11-08.md`](HARDWARE-ACCELERATION-FIXLIST-ROADMAP-2026-11-08.md)、[`artifacts/hwtest-2026-11-07/fixes/PROGRESS.md`](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md)。

## 0. 平台基线

| 项 | 值 |
|---|---|
| SoC / 板卡 | Hi3798MV300（4×A53），Ubuntu 26.04.1 |
| 内核 | mainline Linux 7.3.0 **#188**（eMMC 启动；FIP sha1 `2dea80c52b4aee1c4be4c644c20f5fac4b5ce844`） |
| 验收模块 | `hi_vdec_reloadfix.ko`（`e8859791`）+ `vdec_spec_hevc_head`（`6ada1250`）；其余见 [`TOOL-MODULE-PAIRING.md`](TOOL-MODULE-PAIRING.md) |
| 服务 | `hi-accel.service`（5 模块 + 预热 + 自检；`/run/hi-accel/status`） |

## 1. 条目统计

| 口径 | ✅ | 🟡 | ⚪NA | ⏳ |
|---|---|---|---|---|
| R1 46 条（闭环矩阵） | 31 | 5（VDEC-02/04/05、GPU-01/03） | 9 | 0 |
| **R2 追加 24 条** | **17** | **6**（OPS-02、VDEC-02A/02D/04、GPU-01/03） | **1**（DRM-06；PNG-08 已由硬件整幅闭环，旧 NA 作废） | **0** |

**已无未开工条目**；剩余 🟡 全部为**硬件/厂商限制**（有完整证据与最终判定），非软件待修项。

## 2. 关键能力与最终判定（摘要）

| 能力 | 判定 | 证据入口 |
|---|---|---|
| HEVC/H.264 1080p/4K 解码 | 🟡 功能可用；**随机 0 帧/尾帧受 VDEC-02A/02D 限制（DP8=否）** | [`vdec-02a/`](artifacts/hwtest-2026-11-07/fixes/vdec-02a/)、[`vdec-02d/R2-EXPERIMENTS-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02d/R2-EXPERIMENTS-2026-11-10.md) |
| VDEC 多 slice / WPP / 4K-slice | ✅（31 用例矩阵 26 PASS） | [`vdec-04/VDEC-04-BOARD-MATRIX-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/vdec-04/VDEC-04-BOARD-MATRIX-2026-11-10.md) |
| VDEC 长序列（113 帧 4K Main10） | 🟡 采用重试协议 B（5 run ≥4 成功；实测 4/5）；5/5 需修 02A | [`vdec-04/VDEC-04-ACCEPTANCE-DECISION-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/vdec-04/VDEC-04-ACCEPTANCE-DECISION-2026-11-10.md) |
| 冷启动预热 | ✅ 首帧 30–44 ms（≤800ms） | [`vdec-05/VDEC-05-WARMUP-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/vdec-05/VDEC-05-WARMUP-2026-11-10.md) |
| VENC 1080p H.264/HEVC | ✅ 31–34 fps / 30–32 fps；4K/非 1080p Create = 平台限制 | [`e02-venc/`](artifacts/hwtest-2026-11-07/fixes/e02-venc/)、[`CAPABILITY-MATRIX.md`](CAPABILITY-MATRIX.md) |
| JPEG 四类采样 + 64MP | ✅ 硬件；稳态 5.39 ms/帧、64MP 233 ms | [`jpeg-06/JPEG-06-COST-TARGETS-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/jpeg-06/JPEG-06-COST-TARGETS-2026-11-10.md) |
| TDE（2026-11-10 新移植） | 🟡 完整驱动功能 PASS（fill/copy/solid255/blit-α/CLUT8；SolidDraw 纯色 fill 不做 dst α 混合=vendor 限制）；完成链当前 2ms 轮询（DT 无节点→`no_irq_chip`），DT 节点 + cma=384M 随 FIP 验证后启用真实 IRQ | [`BOARD-EXPERIMENTS.md`](ref-png/BOARD-EXPERIMENTS.md)、`work/tde/` |
| PNG | ✅ **硬件整幅（PNGD）bit-exact**：1080p decode ~100 ms（入口 431 ms）、64MP 3.1 s；同 boot 3/3 次；无软件兜底；根因 `u32AXIConfig` 0x20441→0（模块 `a47b509a`、工具 `eebc802a`、包 `c6fee5cd`） | [`ref-png/PNG-HW-FULLFRAME-ROOTCAUSE-2026-11-10.md`](ref-png/PNG-HW-FULLFRAME-ROOTCAUSE-2026-11-10.md)、`artifacts/png-hw/{62,64,65,...}` |
| DRM 显示/vblank | ✅ #188（60 Hz、0 丢事件、p99 0.009 ms） | [`drm-02/FIX-REPORT-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/drm-02/FIX-REPORT-2026-11-10.md) |
| 硬解播放闭环（1080p H.264 30min） | ✅ 29.75 fps、99.17% 交付、PTS 抖动 mean 0.385 ms | [`drm-05/DRM-05-STAGE3-COUPLED-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/drm-05/DRM-05-STAGE3-COUPLED-2026-11-10.md) |
| GPU（Mali450/lima） | 🟡 轻载 PASS；重载 pp 复位不可恢复（驱动/DT 无复位资源） | [`gpu-01/GPU-01-DRIVER-ASSESSMENT-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/gpu-01/GPU-01-DRIVER-ASSESSMENT-2026-11-10.md) |
| VDEC+VENC 并发 | ✅ 结论闭环（不支持全码率并发；策略已给） | [`vdec-08/VDEC-08-CONCURRENCY-POLICY-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/vdec-08/VDEC-08-CONCURRENCY-POLICY-2026-11-10.md) |
| 1h 长稳（3×1h） | 🟡 完成 3×1h（203 min/72 clean-boot step、0 oops）；整体首轮 89.4% ≥88%；VDEC-only 72.2%（VDEC-02A） | [`ops/OPS-02-1H-SOAK-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/ops/OPS-02-1H-SOAK-2026-11-10.md) |
| 标准接口 | NA（无 V4L2；产品用 MPI 后端） | [`drm-06/DRM-06-STANDARD-INTERFACE-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/drm-06/DRM-06-STANDARD-INTERFACE-2026-11-10.md) |

## 3. 残留限制（硬件/厂商，均有证据）

1. **VDEC 随机 0 帧/尾帧**（VDEC-02A/02D，DP8=否）：100 Mbps/Main10 单次约 30–50%；重试/重载/reboot 只能缓解；产品需重试/自愈协议；长序列验收用重试协议 B。
2. **GPU pp 复位不可恢复**（GPU-01/03）：lima 复位路径存在但 STOP_BUS 超时；DT 无 reset、SDK 无 CRG 复位位；生产用 pixman，GL 桌面不投产。
3. **并发**：VDEC+VENC 全速并发解码退化 73%（硬件带宽竞争）→ 默认串行/timeslice。
4. **PNG 硬件整幅（2026-11-10 已闭环，作废旧 NA）**：根因是驱动 `u32AXIConfig=0x20441`（vendor 建议值）在本 mainline 移植上让 AXI 主口静默挂起；改 0 后 1080p/单段/64MP 均整幅 bit-exact（见 [`ref-png/PNG-HW-FULLFRAME-ROOTCAUSE-2026-11-10.md`](ref-png/PNG-HW-FULLFRAME-ROOTCAUSE-2026-11-10.md)）。残留限制：interlace 未实现（显式拒绝）、CLUT 颜色展开为查表。
5. **V4L2/ffmpeg hwaccel**：内核无 MEDIA_SUPPORT、无 vendor 驱动 → NA，产品用 MPI。
6. **OPS-02**：3×1h soak 完成（0 oops、无泄漏）；整体首轮 89.4% ≥88%，但 VDEC-only 72.2% <88%/98%（归因 1）。

## 4. 产物与工具索引

- 报告：`docs/porting/artifacts/hwtest-2026-11-07/fixes/{vdec-*,jpeg-*,png-*,drm-*,gpu-*,ops,inf-*}/`
- 工具：`tools/hwtest/`（board_ctl/run_phase/phases）、`fixes/ops/soak.sh`、`fixes/drm-05/src/{drmplay.c,drmdec.c}`
- 发布：`dist/hi-accel-r2-20261109.tar.gz`（R2 包；#188 相关变更见 PROGRESS）
- 配对与口径：[`TOOL-MODULE-PAIRING.md`](TOOL-MODULE-PAIRING.md)、[`ACCEPTANCE-RULES.md`](ACCEPTANCE-RULES.md)、[`CAPABILITY-MATRIX.md`](CAPABILITY-MATRIX.md)

## 5. 结论

- 软件可修项已全部闭环（R2 无 ⏳；R1 无 ⏳）；关键能力（编解码、JPEG、PNG 软件、显示/播放、并发策略、长稳）均有上板证据；
- 剩余 🟡/NA 为**平台硬件或 vendor 限制**，已给出最终判定、量化数据与产品侧缓解/口径建议；
- #188 验收内核与验收模块组合已固化在 eMMC + 配对文档中。

## r4-20261111（2026-11-11 00:36 打包）

- 发布包：`dist/hi-accel-r4-20261111.tar.gz` sha1 `06c91ffc3390b01a9e8fe3675bdd1e8c9d047585`（16 个 payload；6 模块同 boot：mmz_shim/vdec/venc/jpeg/png_v15/tde）。
- PNG：`hi_png_reload.ko` = v15（`d1975921…`，含 Adam7 硬件交错 + TDE CLUT 接线），工具 `hi_png_hw` v1.9（`4d4ed71a…`，`--clut-hw` 仅 bd8，bd1/2/4 回退 CPU LUT）。
- TDE：`hi_tde.ko`（`1e9f72c6…`）+ `tde_test`（`49c9abb4…`）纳入 hi-accel（`HI_LOAD_TDE=1`；加载顺序 mmz_shim→tde→vdec/venc/jpeg/png）。
- **已上板验收通过**（clean boot `fd4cca44`，证据 `docs/porting/artifacts/png-hw/r4-install-final2-20261111-0047*/`）：install `--verify` rc=0；`/run/hi-accel/status` `state=PASS`、6 模块 ok、nodes 含 `/dev/hi_tde`；`systemctl restart` 后仍 PASS；fresh boot `tde_test` PASS；1080p PNG sha1 `bbac27fa…`；pal8 `--clut-hw` = PAL8_MATCH。执行记录 [`fixes/R4-EXECUTION-2026-11-11.md`](artifacts/hwtest-2026-11-07/fixes/R4-EXECUTION-2026-11-11.md)。
- 遗留：TDE 真实 IRQ/64MP CMA（cma=384M FIP 待 rootfs 维护窗口后 RAM 验证）；子字节调色板 TDE 颜色扩展（bd1/2/4，现走 CPU LUT，r4 后增强）；板卡 rootfs 坏位图需 e2fsck 维护窗口。

## r5-20261111（2026-11-11，取代 r4）

- 发布包：`dist/hi-accel-r5-20261111.tar.gz` sha1 `c0b813c059115ea016929780ee106a3c41c426df`
- 修复 task-8（restart 后 TDE 旧实例导致 tde_test 挂死）：`hi-accel.service` ExecStop 增加 `-/sbin/rmmod hi_tde`；`hi_tde.ko` 升级 v16 `1efdaba4…`（init：INT/INTCLR/CTRL/AQ_NADDR/STA 快照 + `tde_recover=1` 清 INT/CRG37 复位；poll worker 存活计数 `tde_poll_ticks` + `tde_dbg` 打印）。
- 其余内容同 r4（PNG v15 `d1975921…`、工具 v1.9 `4d4ed71a…`、vdec/venc/jpeg/mmz）。
- 验收（待 board 回执后补）：restart 后立刻 tde_test、10× restart、fresh boot 1080p/pal8、6 模块 install/verify。

## r5b-20261111（2026-11-11，取代 r5）

- 发布包：`dist/hi-accel-r5b-20261111.tar.gz` sha1 `e44933ba496df05cf47a49922f96c8851bd64dc0`
- 修复 r5 上板 FAIL：v16 在 insmod 时（TDE 时钟未使能）读 clock-gated TDE 寄存器 → 总线错误/insmod 失败；v16b `14fd8bbd…` 默认 `tde_recover=0`/`tde_regs_dbg=0`（不碰 TDE 窗口），`tde_poll_ms` 生效；其余同 r5。
- 验收：待 board 回执（fresh boot insmod/service PASS、restart 后 tde_test、10× restart、1080p/pal8、A1 子字节矩阵 + B0 耗时）。

> 注（2026-11-11 03:00）：**task-8 已闭环，r5 正式发布**（`dist/hi-accel-r5-20261111.tar.gz` `4c846a8d…`，TDE v16k `9f1347fb…`）。板端三项核心测试全绿：单加载 `tde_test` ×10 = 10/10、tde-only reload ×10 = 10/10、`service` 10× restart+tde_test = 10/10（`state=PASS`、6 模块、`/dev/hi_tde`）。根因链：service ExecStop 漏卸 hi_tde → poll/cleanup UAF → 空闲/active 读 clock-gated 寄存器 stall → active 门控编码比较 bug；v16k 以 `tde_keep_clock=1`（poll 期间强制保持 TDE 时钟）+ 完整 `cmd` active 门控根治。r5b–r5k 为中间候选（作废）。

## r5c-20261111（2026-11-11，取代 r5b）

- 发布包：`dist/hi-accel-r5c-20261111.tar.gz` sha1 `002ce823761805ab6137e182ea7f2be6e12a02c0`
- 修复 r5b 10× reload 中第 6 次偶发挂死：poll worker 与 cleanup 的 **UAF 竞态**（cleanup 先拆 List/HAL、最后才 cancel poll；init 时 poll 早于 ListInit 启动）。v16c `4f2492af…`：poll start 移到 `tde_init_module_k()` 末尾、cleanup 开头先 `cancel_delayed_work_sync`；v16b 安全项保留（recover/regs_dbg 默认 0、poll_ms）。
- 验收：待 board（fresh boot PASS、10× restart+tde_test、1080p/pal8、A1 矩阵 + B0）。

## r5d-20261111（2026-11-11，取代 r5c）

- 发布包：`dist/hi-accel-r5d-20261111.tar.gz` sha1 `04af28178ff7c36aed5ea5612a71c9b86394c0f7`
- 针对 tde-only 10× reload 第 6 轮挂死（CmaFree 稳定、无 CMA 泄漏；记账 bytes 残留为 v16d bug）：TDE **v16e `7227d8a1…`**：`tde_recover` 默认 2（CRG37 reset pulse + 时钟开启窗口内只写清 `INTCLR/CTRL/AQ_NADDR`，不读未使能寄存器）、`tde_load_seq`、MMZ live bytes 记账修正、init 失败中止。
- 验收：待 board（tde-only 10×、recover 0/1/2 对照、service 10×、A1/B0、64MP）。

## r5-20261111（正式发布，2026-11-11 03:00）

- 发布包：`dist/hi-accel-r5-20261111.tar.gz` sha1 `4c846a8dac59e5e1a6860167ec1ae8066dd02d62`（6.2MB；6 模块同 boot：mmz_shim/vdec/venc/jpeg/png_v15/**tde v16k**）
- 关键件：`hi_tde.ko` v16k `9f1347fb68dd0f2c1349d731bda079d0da0dce3a`；`hi_png_reload.ko` v15 `d1975921…`；`hi_png_hw` v1.9 `4d4ed71a…`；`tde_test` `49c9abb4…`
- 相对 r4 的修复：`hi-accel.service` ExecStop 补 `rmmod hi_tde`；TDE 驱动 v16k（poll/cleanup UAF、clock-gated 寄存器访问、active 门控编码比较、MMZ 记账、init 失败中止、load_seq 诊断）
- 验收（board，tmpfs HI_DIR）：单加载 tde_test ×10 PASS、tde-only reload ×10 PASS、service 10× restart+tde_test PASS（每次 state=PASS/6 模块//dev/hi_tde）
- 已知环境限制：板卡 rootfs 坏位图 → **写盘 ko 会损坏**，r5 上板安装需用 `HI_DIR=/dev/shm/m2`（tmpfs）或先修 rootfs；常开 TDE 时钟的功耗/温度影响待对照（`tde_keep_clock=0` 仅非 poll 模式）。

## r6-20261111（2026-11-11 03:10，正式 r6）

- 发布包：`dist/hi-accel-r6-20261111.tar.gz` sha1 `dbab333dc83cc8ade4204a833edf8d4fce27ca82`
- 内容 = r5（PNG v15 `d1975921…`、工具 v1.9 `4d4ed71a…`、vdec/venc/jpeg/mmz）+ **TDE v16l `cd6b1b7e…`**（active 置位下移到内核公共路径，覆盖 PNG 内核直调；`tde_test` ×10 与 service 10× 不回归）
- 验收（board）：B0 1080p clut8 `--clut-hw` **MATCH**（cpu 28.9ms / hw 185.9ms）；**64MP clean-boot 3/3 PASS**（sha1＝ffmpeg 参考、无泄漏）；r5/r6 install/verify（tmpfs HI_DIR 等效）rc=0、state=PASS、warmup=ok、6 模块、`/dev/hi_tde`、tde_test PASS、restart PASS；tde_test ×10 与 service 10× 不回归。
- **r6 最终板端确认（board，证据 `artifacts/png-hw/r6-final-*`）**：install（tmpfs 等效）rc=0、state=PASS、warmup=ok(3851ms)、6 模块、/dev/hi_tde、tde_test PASS；**pal8/clut8 `--clut-hw` 640×480 与 1080p 全 MATCH**（clut8t 首轮 DIFF 为 outfmt 用错，rgba8 重测 MATCH）；1080p PNG 解码 sha1 `bbac27fa…`（97.8ms）；tde_test ×10 与 service 10× restart 全 10/10；CLUT2RGB job1/job2 rc=0（v16l 对 PNG 内核直调生效）。
- **A1 子字节 CLUT 硬件化 = negative result**：bd1/2/4 保持 CPU PLUT 查表（bit-exact、非解码回退），`--clut-hw` 仅 bd8 走 TDE；B2 ABI 扩展不做（temp+job2 仅占 ~18%）。详见 `artifacts/png-hw/A1-SUBBYTE-CLUT-RESULT.md`。
- 环境：rootfs 坏位图 → 上板测试/安装用 `HI_DIR=/dev/shm/m2`（tmpfs）；磁盘安装与 e2fsck 待维护窗口。`warmup=skip` 原因：tmpfs 手工部署缺 `vdec_spec_hevc_head`/`ht1080b.hevc`，正式包安装后 warmup=ok。
## A2 子字节 TDE CLUT（2026-11-11 05:30，能力件，未进 r6）

- PNG v17 `74f9c681204e5588b854f0f49f789670ab97283f` + tool A2 `fd7b63cc4186f175eb33c556887772906bd8f03c` + TDE v16l `cd6b1b7e…`
- board：pal1/2/4 ±tRNS、pal8 ±tRNS **8/8 MATCH**（640×480）；`A2: unpack 51.4–52.0ms`、hw 总 ~250ms（CPU LUT 15.2ms）⇒ 默认 CPU LUT，`--clut-hw` 可选 A2
- 关键实现：MMZ(DRAM) 不能 ioremap → `phys_to_virt` + `dma_sync_single_for_device`（FROM_DEVICE/TO_DEVICE）+ `dma_wmb/mb`；无 ABI 变更
- 不回归：pal8 640/1080p MATCH、1080p PNG `bbac27fa…`、tde_test ×10、service 10×
- 结论：A1（HW unpack）negative、A2（CPU 解包+TDE 展开）可行但性能不优先 ⇒ 默认 CPU LUT；r7 作为能力可选件。
## 维护窗口结果（2026-11-11 夜间）

- **rootfs 坏位图已修复**：经 U-Boot 加载「内置 rescue initramfs 内核」执行 `e2fsck -f -y /dev/mmcblk0p1`（rescue init 内嵌原 U-Boot env 备份并自动恢复）→ 复检 `Filesystem state: clean`、dmesg 无 EXT4 bitmap 错误、250MB 落盘写测试通过、**r6 已磁盘安装**（HI_DIR=/root/m2，state=PASS/warmup ok/6 模块/tde_test PASS/restart PASS）。
- **FIP**：cma=384M + TDE 节点候选 FIP `22af0bf4…` 已实际刷入并启动（`CmaTotal=393216kB`、TDE 节点存在、state=PASS、tde_test ×5、restart ×5）；但 TDE 真实 IRQ 仍落回轮询（SPI91 映射到 no_irq_chip dummy domain），且 cma=384M 使 64MP CMA 预算不足（rc=7）⇒ **已恢复原生产 FIP `2dea80c5…`（cma=256M）**，保证 64MP 与稳定性。详见 `FIP-EXPERIMENT-2026-11-11.md`。
- **A2 子字节 CLUT**：PNG v17 `74f9c681…` + tool A2 `fd7b63cc…` + TDE v16l → pal1/2/4 ±tRNS 与 pal8 ±tRNS **8/8 MATCH**（性能不优先，默认 CPU LUT，`--clut-hw` 可选）。
- **r7**：`dist/hi-accel-r7-20261111.tar.gz` sha1 `b7f6d2bd5558acd80bf149c4ebe3037712567fe6`（r6 + PNG v17 `74f9c681…` + tool A2 `fd7b63cc…`；TDE v16l `cd6b1b7e…` 与其余不变）。已在板上磁盘安装（`/root/m2`，manifest/模块 sha1 全部匹配）：`state=PASS`、`warmup=ok(3879ms)`、6 模块、`tde_test PASS`、restart PASS。
- **TDE 真实 IRQ**：尝试 v16m（跳过 dummy-domain 的 jpeg-parent 映射、直接 GIC fwspec）→ 板端不稳定（疑 IRQ 风暴/未 ack），**已回滚 v16l，不发布**；轮询兜底为当前稳定方案，后续方向见 `FIP-EXPERIMENT-2026-11-11.md`。
- **64MP（恢复原 FIP 后 clean boot 复测）**：rc=0、3056.7ms、sha1 `d0ce2b24…` = ffmpeg 参考、CmaFree before 235MB ✓。
- **r7 最终板端验证（2026-11-11 07:55，恢复后实测）**：`/root/m2` = r7 载荷（TDE v16l `cd6b1b7e…`、PNG v17 `74f9c681…`、tool A2 `fd7b63cc…`）；`state=PASS`、`warmup=ok(5431ms)`、6 模块、`tde_test PASS`、**restart 5/5 PASS**；`CmaTotal=262144kB`（原生产 FIP）。
- **r7 A2 复测（2026-11-11 08:00，板端 r7 载荷）**：pal1/2/4 ±tRNS + pal8 `--clut-hw` vs CPU LUT **7/7 MATCH**（640×480，rgb24+rgba8；dmesg 见 `A2: unpack bd=… 51840us`、`hw_unpack=2`、job1/job2 endjob rc=0）。
- **最终板卡状态（ssh 实测）**：`/root/m2`=r7 载荷；`state=PASS`、`warmup=ok`、6 模块、`tde_test PASS`、restart 5/5 PASS、`CmaTotal=262144kB`（原生产 FIP）。
- **TDE 真实 IRQ（第二轮，2026-11-11 08:05）**：v16m 运行时重测仍映射到 `no_irq_chip` dummy 域（GIC 节点域在早期被固化为 dummy）；“TDE 延迟加载”对照因板卡 WiFi/串口反复失联未完成。已恢复 `HI_LOAD_TDE=1` + r7 载荷（TDE v16l），板端 `state=PASS`、6 模块、`tde_test PASS`、`cma_free 217MB`。修复方向（延迟映射/独立 domain）见 FIP 实验记录，属后续维护窗口。
## r8-20261111（2026-11-11 09:25，正式 r8：TDE 真实 IRQ）

- 发布包：`dist/hi-accel-r8-20261111.tar.gz` sha1 `7443c8656edfe35defcd86d6d656056e4c26281f`
- 内容 = r7（PNG v17 + tool A2 + 其余）+ **TDE v16p `211bb47a…`**：GIC-only IRQ 映射（跳过 jpeg-parent dummy 域）+ 域就绪前延迟映射（500ms×40）+ IRQ 成功后不启动轮询。
- 板端实测：启动/重启 `request_irq(39) ret=0`、`real IRQ active -> poll NOT started`；`tde_test` 10/10 PASS、`tde_irq_cnt` 按 job 增长、`tde_poll_ticks` 恒 0；`state=PASS`、6 模块；`install.sh --verify` 15/15 OK；64MP clean boot rc=0/sha 参考；pal8 `--clut-hw` MATCH。
- 无需修改 FIP（现网原生产 FIP `2dea80c5…` 即可；TDE DTS 节点非必需）。
## r9-20261111（2026-11-11 10:30，TDE 限制修复：SolidDraw α + CLUT 日志/性能）

- 发布包：`dist/hi-accel-r9-20261111.tar.gz` sha1 `2f594fcc83a483b4b7cc43197cdab30708812310`
- 变更 = r8（TDE 真实 IRQ v16p）+ **TDE v16q `d64bd263…`**（SolidDraw α 混合修复：1×1 预乘 CLUT8 Bitblit）
  + **PNG v18 `3bf910a9…`**（CLUT2RGB/A2 verbose 日志改走 `PNG_DBG`，默认关） + **tde_test `1e0dc073…`**（重写，含 α 混合断言）。
- 板端验证（clean boot + install --verify 15/15 OK）：
  - 启动 IRQ：`[12.68] using TDE irq virq=39 hwirq=123` → `init: real IRQ active -> poll NOT started`；`irq_cnt=0 poll=0`；
  - `state=PASS`、6 模块；`tde_test` PASS（含 `SolidDraw alpha=128 (blend over dst)`）；tde_test **10/10**、restart **3/3**；
  - `--clut-hw` 640×480 **5.6ms** / 1080p **44.2ms**（原 163/203.7ms），逐字节 MATCH；普通 1080p 解码 MATCH（94.9ms）；
  - **64MP clean boot**：rc=0、3056.1ms、sha1 `d0ce2b24aa81c4847bba3dc757738a76c2f7eb7c` = ffmpeg 参考，CmaFree 234680kB 前。
## r10-20261111（2026-11-11 11:45，TDE 限制修复：#4 大矩形分块 + #3 Rotate）

- 发布包：`dist/hi-accel-r10-20261111.tar.gz` sha1 `50ef94caec9f92ac88b1d3cafa07f76385d20336`
- 变更 = r9 + **TDE v16r `838adece…`**（大矩形自动分块：QuickCopy/SolidDraw/Bitblit；+ Rotate 实现）
  + **tde_test `6b32f2ac…`**（新增 5 项分块/旋转用例）。
- 板端 clean boot 验证（install --verify 15/15 OK）：
  - `tde_test` PASS：`Tiled SolidDraw >4096 width`、`Tiled Bitblit >4096 width`、
    `Rotate 180 (HW mirror)`、`Rotate 90/270 (CPU fallback)` 全 PASS；tde_test **10/10**、restart **3/3**；
  - 启动 IRQ：`real IRQ active -> poll NOT started`，`poll=0`；
  - 64MP clean boot：sha1 `d0ce2b24…`、3056.7ms、CmaFree 237652kB；
  - `--clut-hw` 640×480 **5.2ms MATCH** / 1080p **44.1ms**；普通 1080p MATCH（94.4ms）。
## r11-20261111（2026-11-11 12:15，--clut-hw 性能优化）

- 发布包：`dist/hi-accel-r11-20261111.tar.gz` sha1 `1109e29bad563c6b8f148bc8e7d6234ff8799917`
- 变更 = r10 + **PNG v21 `1a4bc54b…`**：
  - v18 日志门控（`PNG_DBG`，默认关）→ 640/1080 从 163/203.7ms 降至 5.3/45.1ms；
  - v19 temp 缓冲 grow-only 缓存 + job1/job2 合并单 job → warm 4.5/39.4ms；
  - v21 原地分块展开（同缓冲不同 stride，自底向上 y0=ceil(y1·src/dst) 分块，无 staging 拷贝）→ **3.8/34.4ms**。
- 板端 clean boot 验证（install --verify 15/15 OK）：state=PASS、IRQ poll=0、tde_test PASS（含分块/Rotate 5 项）、
  tde_test 10/10、restart 3/3；`--clut-hw` 640×480 **3.8ms MATCH**、1080p **34.4ms**；普通 1080p MATCH（94.1ms）；
  A2 子字节矩阵 **7/7 MATCH**。
- 说明：64MP 回归在 r10 clean boot 已通过（sha1 `d0ce2b24…`）；r11 的 PNG 改动仅 palette CLUT 路径，
  rgb8 64MP 走同一解码路径，本轮因该 boot CMA 仅 175MB（<204MB 预算）未重复执行。
