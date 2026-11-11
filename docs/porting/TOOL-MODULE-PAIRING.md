# 工具-模块配对登记（TOOL-MODULE-PAIRING）

- 版本：2026-11-11（**R8 正式**：TDE v16p `211bb47a…`（GIC-only IRQ 映射 + 延迟映射 + 关闭轮询，真实 IRQ 达成）；发布包 `dist/hi-accel-r8-20261111.tar.gz` `7443c865…`；2026-11-11（**R6 正式**：TDE v16l `cd6b1b7e…`（active 内核公共路径）+ PNG v15/工具 v1.9；发布包 `dist/hi-accel-r6-20261111.tar.gz` `dbab333d…`（r6 板端最终确认全绿）；A1 子字节 CLUT 硬件化 negative（bd1/2/4 保持 CPU LUT）；2026-11-11（**R5 正式**：TDE v16k `9f1347fb…`（poll 期间强制保持 TDE 时钟 + 完整 cmd active 门控，task-8 闭环）；发布包 `dist/hi-accel-r5-20261111.tar.gz` `4c846a8d…`；2026-11-11（**R5d**：TDE v16e `7227d8a1…`（recover=2 安全寄存器清理 + load_seq + 记账修正，针对 reload 第 6 轮挂死）；发布包 `dist/hi-accel-r5d-20261111.tar.gz` `04af2817…`；2026-11-11（**R5c**：TDE v16c 修复 reload 路径 poll worker/cleanup UAF 竞态（v16b 的 insmod 总线错误修复保留）；发布包 `dist/hi-accel-r5c-20261111.tar.gz` `002ce823…`；2026-11-11（**R5b**：R5 的 TDE 模块升级为 v16b `14fd8bbd…`——修复 v16 在时钟未使能时读 TDE 寄存器导致的 insmod 总线错误（`tde_recover`/`tde_regs_dbg` 默认 0、`tde_poll_ms` 生效）；发布包 `dist/hi-accel-r5b-20261111.tar.gz` `e44933ba…`（取代 r5 `c0b813c0…`）；2026-11-11（**R5**：修复 `hi-accel.service` ExecStop 漏卸 `hi_tde` 导致的 restart 后 TDE 旧实例挂死（task-8），TDE 模块升级 v16 `1efdaba4…`；发布包 `dist/hi-accel-r5-20261111.tar.gz` `c0b813c0…`，取代 r4）；2026-11-11（**R4**：PNG v15（TDE CLUT 接线）+ 工具 v1.9 + **TDE 完整驱动 `hi_tde.ko` 纳入 hi-accel（6 模块同 boot）**；发布包 `dist/hi-accel-r4-20261111.tar.gz` `06c91ffc…`）；2026-11-09（R2：PNG reload 模块、`vdec_hdr_meta=0`、hi-accel 部署）；2026-11-10（R3：VDEC-02D 实验模块 `hi_vdec_02d`、D01 高码率/10-bit 结论、DRM-02 #183 RAM 启动 → **同日晚 DRM-02 闭环：#188 内核（驱动 patch 0002 + HIGH_RES_TIMERS）已刷 eMMC**；续：INF-04 编排器 SSH 韧性修复 `run_phase.sh` `f85a56d9`、VDEC-02D 预分配帧存候选排除）；2026-11-08（task-13 / 路线图 INF-03 初版；task-28 / DOC-06 修复阶段更新 + Round 7 闭环同步；task-39 / DOC-VDEC-02h 验收对更新到 reloadfix，执行：docs-fixer）
- 适用范围：Hi3798MV300 PoC（mainline Linux 7.3.0 #182，Ubuntu 26.04.1）上的 VDEC / VENC / JPEG / PNG 验收与诊断。
- **2026-11-08 修复阶段新增**：§1.5 VDEC HEVC 修复对（VDEC-01 根因；head_w1 `047cad9b` 7/7 为**历史记录**）、§1.6 VENC 模块演进、§1.7 VDEC 实验模块（非验收）、§1.8 VDEC 抓帧配对（VDEC-03，**4K 抓帧已闭环**）、**§1.9 VDEC-02 panic/exit 修复链（当前验收模块 `hi_vdec_reloadfix.ko` `e8859791`）**。
- 一句话：**"哪个模块"必须和"哪个用户态工具 + 哪条输入流 + 哪套参数"一起记账**；只记模块版本、不记工具版本的历史结论，不能拿来复现，也不能当作当前保证。
- 证据根：`docs/porting/artifacts/hwtest-2026-11-07/`（下表"证据"列均相对此根）；历史轮次见 `docs/porting/artifacts/spec-acceptance/roundNN*/`。

> 依据：[`REPORT.md` §4.1](artifacts/hwtest-2026-11-07/REPORT.md)、[`matrix/harnesses.csv`](artifacts/hwtest-2026-11-07/matrix/harnesses.csv)、
> [`matrix/streams.csv`](artifacts/hwtest-2026-11-07/matrix/streams.csv)、[`matrix/gaps.md`](artifacts/hwtest-2026-11-07/matrix/gaps.md)、
> [`round174`](artifacts/spec-acceptance/round174-regression-abi-mismatch.md)、[`round200`](artifacts/spec-acceptance/round200-git-history-ab.md)。

> **当前验收配对（2026-11-09 更新：R2 产品配置，5 模块同 boot，由 `hi-accel.service` 开机加载）**
> - VDEC：`hi_vdec_reloadfix.ko`（`e8859791…`）+ `vdec_spec_hevc_head`（`6ada1250…`），参数追加 **`vdec_hdr_meta=0`**（VDEC-02B：HDR 元数据 buffer 只分配不释放，每次解码泄漏约 48 KB）。完整参数：`m2_sync_downmsg=1 m2_sync_msgs=1 m2_sync_scd=1 m2_sync_hevc_msgs=1 vdec_dfs=1 vdec_sed_only=0 vdec_hdr_meta=0`；抓帧时在 insmod 阶段再加 `vdec_no_vcmp=1`（运行时写 sysfs 无效）。
> - VENC：`hi_venc_venc06b.ko`（`0d95a512…`）+ `encoder_accept10`（`a0458c90…`）。
> - JPEG：`hi_jpeg_noext.ko`（`8f39ceb0…`）+ **`jpeg_test_d09`（`d9959e17c0dc4cad2e8bc8e9634af1aff21006e9`，2026-11-09 晚起，入口 `hi_jpeg` 使用）**；`jpeg_test_jpeg01`（`d3c64680…`）仅保留给 `jpeg_smoke` 阶段的 4:2:0 loops=100 回归。`jpeg_test_d09` 构建：`-DCHIP_TYPE_hi3798mv300`，源码 `port/jpeg-user/{jpeg_test.c,jpeg_sof_guard.c,jpeg-hal/src_comm/jpeg_hdec_parse.c}`；gray 需 `JPEG_ALLOW_GRAY=1`；`JPEG_DUMP=raw` 写盘不算 hash。
> - **PNG（2026-11-11 R4 起）：`hi_png_reload.ko`（`d1975921b0f0ac9e04cfe9f1e965dc297481f5e6` = v15：v2–v7 全修复 + Adam7 交错 + TDE CLUT 接线 + 16bit LE 工具配合）** + **`hi_png_hw`（`4d4ed71ab0954e611a8379148470c1a825afefb7` v1.9，HW-only 生产工具；`--clut-hw` 仅 bd8 走 TDE，bd1/2/4 自动回退 CPU LUT）**；入口 `hi_png`（`auto/hw`=硬件，无软件兜底；`sw` 仅诊断）。v15 含 AXI=0 根因修复、`png_wait_ms`(10000)、ISR 错误分类、同 boot 多次解码修复、**Adam7 硬件 7-pass + 内核拼图**、TDE CLUT 硬件颜色扩展（pal8 逐字节 MATCH）、`png_dbg`(默认 0)。旧 v5（`a47b509a`）仅作回滚。根因报告 [`ref-png/PNG-HW-FULLFRAME-ROOTCAUSE-2026-11-10.md`](ref-png/PNG-HW-FULLFRAME-ROOTCAUSE-2026-11-10.md)、交错 [`ref-png/BOARD-EXPERIMENTS.md`](ref-png/BOARD-EXPERIMENTS.md)。**注意：旧结论"PNG 每 boot 只能解一次"已作废。**
> - **TDE（2026-11-10 移植，R4 起纳入 hi-accel 开机加载；R5d 起为 `hi_tde.ko` **v16e `7227d8a1c7e44952c1e3095a54a6d1fab0796a5c`**（v16c 的 poll/cleanup UAF 修复 + `tde_recover=2`：CRG37 复位脉冲 + 时钟窗口内只写清 INTCLR/CTRL/AQ_NADDR + load_seq/MMZ 记账）：默认不碰 clock-gated TDE 寄存器；`tde_recover`/`tde_regs_dbg` 默认 0；`tde_poll_ms`（默认 2））** + `tde_test`（`49c9abb4…`）。完整 TDE 2D 驱动（v2_0 HAL，base `0xf8c10000`，SPI91），`/dev/hi_tde` + 全套 ioctl，导出 `g_tde_export_funcs`（GPL）供 PNG CLUT 使用；完成链：DT 节点优先 IRQ，无节点时 2ms 轮询兜底。SolidDraw 纯色 fill 不做 dst α 混合（vendor 限制）；文档/证据 `work/tde/`。**加载顺序：hi_tde → hi_png（PNG 可选使用 TDE CLUT）；不带 TDE 时 PNG 走 CPU LUT 不受影响。**
> - **PNG v15（TDE CLUT 硬件化，R4 定稿）**：`hi_png_final_v15.ko`（`d1975921…`）+ `hi_png_hw`（`4d4ed71a…`，v1.9）——**pal8 `--clut-hw` 与 CPU LUT 逐字节 MATCH**（v15 修掉 job2 二次 CLUT 映射）；bd1/2/4 自动回退 CPU LUT（子字节 TDE 路径有挂板风险，列为 r4 后增强）；rmmod/10×/PNG 回归全绿。
> - MMZ：`hi_mmz_shim.ko`（`1ad0d7c7…`）。
> - 清单与发布包：`tools/deploy/hi-accel/hi-accel.manifest`、`dist/hi-accel-r2-20261109.tar.gz`。执行记录：[`fixes/R2-EXECUTION-2026-11-09.md`](artifacts/hwtest-2026-11-07/fixes/R2-EXECUTION-2026-11-09.md)。
> - 已退役：`hi_png_cls.ko`（`ebb0064d`，同 boot 重载失败）、`hi_png_nb.ko`、`hi_jpeg.ko`（`224eea81`）、`hi-imgdec`（已拆分为 `hi_jpeg` / `hi_png`）。

> **历史验收配对（2026-11-08 06:25 更新：reloadfix）**
> - **VDEC（HEVC+H.264）当前验收对**：`hi_vdec_reloadfix.ko`（`e8859791…`，2,008,888 B）+ `vdec_spec_hevc_head`（`6ada1250…`），参数
>   `m2_sync_downmsg=1 m2_sync_msgs=1 m2_sync_scd=1 m2_sync_hevc_msgs=1 vdec_dfs=1 vdec_sed_only=0`，`VDEC_BUF_MB=8`；
>   抓帧再加 `vdec_no_vcmp=1` + `VDEC_BUF_MB=16`。= head_w1(`047cad9b`) + `0005` SCD 防 panic/4K + `0006` class 名生命周期 + `0007` exit inverse。
>   上板：rmmod/insmod ×10 PASS（taint 4096、0 WARN/Oops/EEXIST、`/dev/hi_vdec` 每次重建）；reload 后 4K/1080p 解码全 PASS（4K 冷启动偶发重试）；7 用例矩阵两 boot 4/7、5/7（失败为 VDEC-02 已知间歇，按重试规则判定，非回归）；SCD kill-race 100 次 0 panic。见 **§1.9**。
> - **VDEC 历史验收对（Round 7，保留证据）**：`hi_vdec_hevc_head_w1.ko`（`047cad9b…`）7/7 PASS + 抓帧 bit-exact；被 reloadfix 取代，仅作历史/回滚。见 §1.5 / §1.8。
> - **VENC**：`hi_venc.ko`（`0d95a512…`）+ `encoder_accept10`（`a0458c90…`）。见 §1.6。
> - **旧验收对降级**：`hi_vdec_downmsg_r51_final.ko`（`d4337a64…`）+ `vdec_spec`（`25abbfdf…`）**缺 HEVC message-publish 补丁**
>   （源码 `1ad1764` 恰为 HEVC 使能 `6a2b5f5` 的父提交）→ HEVC 全 0 帧；只作"历史对照/回滚"，不得再作为验收对（§1.5 V-H1-old）。
> 证据：[`fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md)、[`fixes/vdec-01/BOARD-VERIFY-H1.md`](artifacts/hwtest-2026-11-07/fixes/vdec-01/BOARD-VERIFY-H1.md) §3/§4、[`fixes/PROGRESS.md`](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md) VDEC-01/VDEC-02 行。

---

## 0. 使用方法（三步）

1. **选配对**：在下表按"用途"找到一行（§1.9 **当前验收对** / 历史对照 / 诊断 / 实验），照抄该行的模块 sha1、工具 sha1、输入流 sha1、insmod 参数/env 变量，不要跨行混搭。
2. **上板前校验**：模块与工具落板后 `sha1sum` 对照 §2/§3 清单，并核对源码 commit（§4.4 R11）；不一致即停止（见 §4.4 R6）。
3. **证据写全 ENV 块**：每条日志头部必须含 `boot_id`、模块 sha1、工具 sha1、insmod 参数、输入流 sha1；缺任何一项的结论只能算"观察"，不能进验收报告（见 §4.4 R8）。

---

## 1. 本次实测用到的配对总表

> 说明：sha1 为前 12 位缩写，完整值见 §3；"期望"= 规格/历史验收期望，不是本次实测结果；"本次"列为 2026-11-07 全量实测结果，
> 详细数字与判定见 [`REPORT.md`](artifacts/hwtest-2026-11-07/REPORT.md) 对应小节。"—"表示本次未测/不适用。

### 1.1 VDEC（模块 = `hi_vdec*` + `hi_mmz_shim`）

| 配对 ID | 模块（板上路径 / sha1 / 大小 / 参数） | 工具（板上路径 / sha1 / 大小） | 输入流（sha1 / 规格） | 用途 | 期望结果 | 本次实测 / 证据 |
|---|---|---|---|---|---|---|
| **V-A**（Pair A，主验收） | `/root/m2/hi_vdec_downmsg_r51_final.ko` = `/root/m2/hi_vdec.ko`<br>`d4337a64…` / 1,970,408 B<br>`m2_sync_downmsg=1 m2_sync_msgs=1 m2_sync_scd=1 vdec_dfs=1 vdec_sed_only=0`，`VDEC_BUF_MB=8` | `/root/m2/vdec_spec`<br>`25abbfdf…` / 922,432 B | `h264-1080p-bp.h264`<br>`8110aa2d…` / 1080p BP 30 帧 | D02 规格解码 | 30/30、`pts_errors=0`、吞吐 ≥30fps | 矩阵首跑 29/30（pts 28，❌）；独立单跑 **30/30 @14.4fps**；`p1b-logs/h264-1080p-bp*.log`、`p1-h264-1080p-bp.log` |
| V-A | 同上 | 同上 | `h264-1080p-mp-b.h264`<br>`6618eb77…` / 1080p Main+B 30 帧 | D02 规格解码 | 30/30、像素一致 | **0, 0**；`p1b-logs/h264-1080p-mp*.log` |
| V-A | 同上 | 同上 | `h264-1080p-hp-bs.h264`<br>`5a0f9ff8…` / 1080p High 30 帧 | D02 规格解码 | 30/30、像素一致 | 0, 1；`p1b-logs/h264-1080p-hp*.log` |
| V-A | 同上 | 同上 | `hp-slice-nob.h264`<br>`152b3c04…` / 多 slice 10 帧 | D02 多 slice | 10/10、逐像素一致 | 0, 1；`p1b-logs/h264-1080p-multislice*.log` |
| V-A | 同上 | 同上 | `4k-baseline.h264`<br>`e6df0bf7…` / 4K BP 20 帧 | D02 4K30 | 20/20、`err_mbs=0` | **20/20 @16.1fps**（唯一稳定完全通过）；重跑 2/20、2/20；`p1b-logs/h264-4k-bp-a1.log` |
| V-A | 同上 | 同上 | `4k-main.h264` `86f7de84…` / `4k-high.h264` `7afa0730…`（各 20 帧） | D02 4K30 三 Profile | 各 20/20 | 3/20、3/20；`p1b-logs/h264-4k-main*/h264-4k-high*` |
| V-A | 同上 | 同上 | `ht1080b.hevc`<br>`38bbbce8…` / 1080p Main 20 帧 | D01 HEVC 1080p | 20/20、逐位一致 | 0, 0；`p1b-logs/hevc-1080p*.log` |
| V-A | 同上 | 同上 | `4k60.hevc`<br>`44dca79c…` / 4K60 Main L5.1 20 帧 | D01 HEVC 4K60 | 20/20、73–74fps、前 8 帧 sha1 | 0/20 ×3；`p1b-logs/hevc-4k60-8bit*.log` |
| V-A | 同上 | 同上 | `4k60-10b.hevc`<br>`9a41d9e8…` / 4K60 Main10 8 帧 | D01 HEVC Main10 | 8/8、逐位一致 | 0, 0；`p1b-logs/hevc-4k60-main10-a1/a2.log` |
| V-A | 同上 | 同上 | `4k60-100m.hevc` `1dfac16a…` / `4k60-20m.hevc` `7fe805d2…`（各 10 帧） | D01 HEVC 码率 | 各 10/10、`err_mbs=0` | 0/10、0/10；`p1b-logs/hevc-4k60-100m-*.log`、`hevc-4k60-20m-*.log` |
| **V-A-smoke**（历史 smoke 配方） | 同 V-A | `/root/m2/vdec_test`<br>`0bdf305a…` / 854,736 B | `gen3_idr.h264`<br>`9287998f…` / 640×360 50 帧 | H.264 健康检查（不能测 HEVC/4K） | 50/50、`img=50 vdh=50` | **50/50 ×2**；`p1b-logs/smoke.log`、`summary-v2.txt` |
| **V-R36**（r36 工具，交叉对照） | 同 V-A（`d4337a64…`） | `/root/m2/vdec_spec_r36`<br>`38b64af0…` / 922,848 B | `h264-1080p-bp.h264` `8110aa2d…` | D02 交叉 | 与 Pair A 一致 30/30 | 冷启 **0/30**；预热后 **30/30**；`summary-v1.txt`、`p1-h264-1080p-bp.log`、`p0-baseline/SUMMARY.md` §5 |
| V-R36 | 同上 | 同上 | `h264-1080p-mp-b.h264` `6618eb77…` | D02 交叉 | 与 Pair A 一致 | **30/30**（同模块下与 Pair A 的 0,0 相反，见 §4.1）；`summary-v1.txt` |
| V-R36 | 同上 | 同上 | `4k-baseline.h264` `e6df0bf7…` | D02 交叉 | 20/20 | 18/20；`summary-v1.txt` |
| **V-B**（验收模块对照，codec-first） | `/root/m2/hi_vdec_acc.ko`<br>`6d33babb…` / 1,954,400 B<br>`vdec_dfs=1 vdec_sed_only=0`（无 `m2_*`） | `/root/m2/vdec_spec`<br>`25abbfdf…` | `4k60.hevc` `44dca79c…`（**开机后第一个用例**） | D01 排除"H.264 预热污染" | 20/20 | **0/20**，VTSTAT `img=0 vdh=0 scd=20`；`p1c-logs/hevc-4k60-first-acc.log` |
| V-B | 同上 | 同上 | `4k-baseline.h264` `e6df0bf7…` | D02 对照 | 20/20 | 0/20（该模块无 `m2_*` 修复）；`p1c-logs/h264-4k-acc.log` |
| V-B-R36 | 同上 | `vdec_spec_r36` `38b64af0…` | `4k60.hevc` `44dca79c…` | D01 交叉对照 | 20/20 | **1/20**（仅 1 帧）；`p1c-logs/hevc-4k60-r36.log` |
| **V-P0**（旧构建，**仅对照，不作验收**） | `/root/hi_vdec.ko`<br>`a905bdd5…` / 1,906,664 B<br>无参数（旧 diag，常开 SPITAG/FILEDBG/PUTBM） + `/root/hi_mmz_shim.ko` `0bfd830f…` | `vdec_spec_r36` `38b64af0…`；`vdec_test` | `h264-1080p-bp.h264` `8110aa2d…`；`gen3_idr.h264` `9287998f…` | 污染态对照（证明旧构建≠验收构建） | 不作期望（对照） | 冷启 0/30；预热后 30/30；`vdec_test` 仅 `img=2 vdh=4`；`p0-baseline/SUMMARY.md` §3/§5、`old-module-runtime.log` |

### 1.2 VENC（模块 = `hi_venc_m4pass` + `hi_mmz_shim`）

> `encoder_accept` 的输入不是外部码流，而是**工具内部生成的运动图案**（`--motion`，`VENC_MOTION_PX=8`）；因此"输入流"列记为"内部图案"，
> 可核验的输入侧参数是 1920×1080@30 / 5.8 Mbps 目标 / 90 帧。

| 配对 ID | 模块（板上路径 / sha1 / 大小 / 参数） | 工具（板上路径 / sha1 / 大小） | 输入流 | 用途 | 期望结果 | 本次实测 / 证据 |
|---|---|---|---|---|---|---|
| **E-M4** | `/root/m2/hi_venc_m4pass.ko`<br>`7cfb0c0a…` / 198,984 B<br>无模块参数；+ `hi_mmz_shim.ko` `1ad0d7c7…` | `/root/m2/encoder_accept10`<br>`a0458c90…` / 3,631,592 B | 内部运动图案；输出 `h264-HP-CBR.h264` `7205de7a…`（2,145,391 B） | E02 H.264 六组合 1080p30 | 六组合 30.9–34.7fps、level 41、码流合法 | 4/6 ≥30fps（27.27–34.29fps）、level 41、8 码流 `ffmpeg rc=0`；`raw/p2-venc/SUMMARY.md` |
| E-M4 | 同上 | 同上 | 内部运动图案；输出 `hevc-CBR.hevc` `8ba6eea4…`（2,084,158 B） | E01 HEVC 1080p30 | level 120(L4)、CBR 32.3fps | CBR 30.62 / AVBR 33.32fps；码流合法但 **SPS `level=0`（未设置）**；`logs/hevc-*.log` |
| E-M4 | 同上 | 同上 | 内部图案（3840×2160 探测） | 4K 编码 | 平台边界（Create 失败） | `Create rc=0x801d0002`；`logs/h264-4k.log` |

### 1.3 JPEG（模块 = `hi_jpeg` + `hi_mmz_shim`）

| 配对 ID | 模块（板上路径 / sha1 / 大小 / 参数） | 工具（板上路径 / sha1 / 大小） | 输入流（sha1 / 规格） | 用途 | 期望结果 | 本次实测 / 证据 |
|---|---|---|---|---|---|---|
| **J-JPEG** | `/root/m2/hi_jpeg.ko`<br>`224eea81…` / 31,048 B<br>无参数；+ `hi_mmz_shim.ko` `1ad0d7c7…`；**必须独立 boot**（与 `hi_vdec` 重复符号） | `/root/jpeg_test`<br>`cc957cd2…` / 781,120 B | `j1080.jpg` `a81cd997…` / 1080p 4:2:0，`loops=5` | D09 重复解码 | 每次 rc=0、~5.4ms/帧 | `rc=-1`、~2008ms/帧（同 handle 重复 Start 限制）；`raw/p3-jpeg/SUMMARY.md` §2 |
| J-JPEG | 同上 | 同上 | `j64mp.jpg` `e9cc93c1…` / 8000×8000，`loops=1` | D09 64MP | rc=0、~162.6ms | **rc=0 @162.63ms**；`logs/j64mp.log` |
| J-JPEG | 同上 | 同上 | `b-yuvj420p.jpg` `ff37e161…`<br>`b-yuvj422p.jpg` `85c58ea2…`<br>`b-yuvj444p.jpg` `b1375882…`<br>`gray.jpg`（ffmpeg 现场重生成，127,912 B，sha1 未落盘） | D09 颜色矩阵 | 四类均 rc=0、~5.4–10.5ms | 420/422/444/gray 均 rc=0（5.31/7.04/10.51/10.53 ms）；`logs/c420.log`…`cgray.log` |

### 1.4 PNG（模块 = `hi_png` + `hi_mmz_shim`）

| 配对 ID | 模块（板上路径 / sha1 / 大小 / 参数） | 工具（板上路径 / sha1 / 大小） | 输入流（sha1 / 规格） | 用途 | 期望结果 | 本次实测 / 证据 |
|---|---|---|---|---|---|---|
| **P-PNG** | `/root/m2/hi_png.ko`<br>`1dfac9e0…` / 53,416 B<br>无参数；+ `hi_mmz_shim.ko` `1ad0d7c7…` | `/root/m2/png_test`<br>`c90dc820…` / 778,008 B | `t1080.png` `1252aba8…` / 1920×1080 rgb24 | D11 1080p 硬件 | 整幅完成（或至少 head 像素逐字节一致） | **无像素输出**：ISR 1 次后静默、输出全 0（8,294,400 B）、超时；`logs/hw1080.log` |
| P-PNG | 同上 | 同上 | `tg2.png` `6167a768…` / 640×480 gray | D11 小分辨率 | 同上 | 同上：全 0（1,228,800 B）、~2195ms；`logs/hw480.log` |
| P-PNG | 同上 | 同上（软件路径用板上 ffmpeg） | `t1080.png` `1252aba8…`；64MP PNG **无样本** | 软件兜底 | 软件可解 | 1080p **729ms**；64MP **NA（无样本）**；`raw/p4-png/SUMMARY.md` §3 |

> 依据：上表所有模块/工具/流 sha1 与大小来自 [`matrix/harnesses.csv`](artifacts/hwtest-2026-11-07/matrix/harnesses.csv)、
> [`matrix/streams.csv`](artifacts/hwtest-2026-11-07/matrix/streams.csv) 与各阶段 `logs/summary.txt` 的 ENV 块；
> 本次结果数字引自 [`REPORT.md`](artifacts/hwtest-2026-11-07/REPORT.md) §4.1–§4.4 及各 `SUMMARY.md`。

### 1.5 VDEC HEVC 修复对（VDEC-01 根因；head_w1 7/7 为历史记录）

> **根因（一句话）**：板上验收模块 `d4337a64` 的源码 = commit **`1ad1764`**，恰是 HEVC 使能 commit **`6a2b5f5` 的父提交**。
> `6a2b5f5` 在 HEVC HAL 增加 picture/slice 槽 cache 发布（`hi_vdec_diag_hevc_slice()`，仅 `m2_sync_hevc_msgs=1` 时生效）；
> 旧对缺该补丁 → VDH 收到 start 脉冲但不启动 → `img=0 vdh=0 scd=N`、HEVC 全部 0 帧（**不是硬件/HEVC 能力回归**）。
> 同 boot 对照：`m2_sync_hevc_msgs=1` → HEVC 1080p **20/20（vdh=40）**；`=0` → **0/20**。
> 依据：[`fixes/vdec-01/HEVC-0FRAMES-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/vdec-01/HEVC-0FRAMES-REPORT.md)、
> [`BOARD-VERIFY-H1.md`](artifacts/hwtest-2026-11-07/fixes/vdec-01/BOARD-VERIFY-H1.md)、[`module-tool-verification.txt`](artifacts/hwtest-2026-11-07/fixes/vdec-01/module-tool-verification.txt)。

| 配对 ID | 模块（板上路径 / sha1 / 大小 / 参数） | 工具（板上路径 / sha1 / 大小） | 输入流（sha1 / 规格） | 用途 | 期望结果 | 板上验证 / 证据 |
|---|---|---|---|---|---|---|
| **V-H1-min**（最小修复，**已上板确认**） | `/root/m2/hi_vdec_hevc_min.ko`<br>`18c3ca6b…` / 1,971,776 B<br>`m2_sync_downmsg=1 m2_sync_msgs=1 m2_sync_scd=1 m2_sync_hevc_msgs=1 vdec_dfs=1 vdec_sed_only=0`，`VDEC_BUF_MB=8`（= `1ad1764` + `6a2b5f5` 补丁；**无** `vdec_no_vcmp`） | `/root/m2/vdec_spec_hevc_head`<br>`6ada1250…` / 922,848 B | `ht1080b.hevc` `38bbbce8…` / 1080p Main 20 帧 | D01 HEVC 1080p 恢复 | `received==expected`、`vdh>0`、`M2HEVCSYNC>0` | **20/20（vdh=40）**；同 boot sync=0 → **0/20**；`fixes/vdec-01/BOARD-VERIFY-H1.md` |
| V-H1-min | 同上 | 同上 | `4k60.hevc` `44dca79c…` / 4K60 Main 20 帧 | D01 HEVC 4K 恢复 | 20/20 | min 模块 4K 首轮 **1/20**（已启动未完成）；**4K 全矩阵由 V-H1-head-w1 闭环（20/20）**；同上 §1/§3 |
| V-H1-min | 同上 | `vdec_spec_hevc_min`<br>`a9cc2b63…` / 922,544 B（6a2b5f5 工具） | `ht1080b.hevc` `38bbbce8…` | 工具独立性对照（Arm D） | HEVC 仍 PASS ⇒ 解码修复只在模块侧 | 未单独上板（HEAD 工具已验证；min 工具仅作对照） |
| **V-H1-head**（HEAD 构建参考） | `/root/m2/hi_vdec_hevc_head.ko`<br>`b443d88b…` / 2,000,840 B<br>同 V-H1-min 参数 + `vdec_no_vcmp=1`，抓帧时 `VDEC_BUF_MB=16` | `vdec_spec_hevc_head` `6ada1250…` | `ht1080b.hevc` `38bbbce8…`、`4k60-10b.hevc` `9a41d9e8…`（4K Main10 8 帧） | HEVC/10-bit 像素验证（Arm B） | `capture_errors=0`、Y 平面 sha1 与 ffmpeg 参考一致 | 能力已由同族 **V-H1-head-w1** 上板验证（§3/§4）；本行为 HEAD 单构建参考 |
| **V-H1-w1**（HEVC + W1 退出同步，decode-only） | `/root/m2/hi_vdec_hevc_w1.ko`<br>`ce811774…` / 1,975,720 B<br>同 V-H1-min 参数 + `vdh_exit_sync` | 同上 | `hevc-1080p` / `4k60` | HEVC + mode-A 防护（Arm C） | 20/20 且 W1 不回归 | 组件参考；验收采用同族 head_w1（含抓帧） |
| **V-H1-head-w1（历史验收对，Round 7）** | `/root/m2/hi_vdec_hevc_head_w1.ko`<br>`047cad9b…` / 2,004,408 B<br>HEVC + W1 + `vdec_no_vcmp`；参数同 V-H1-min，抓帧 `VDEC_BUF_MB=16` | `vdec_spec_hevc_head` `6ada1250…` | `ht1080b.hevc`、`4k60.hevc`、`4k60-10b.hevc`、`4k60-20m.hevc`、`4k60-100m.hevc` | 历史验收对（HEVC + 抓帧 + mode-A；**已被 §1.9 reloadfix 取代**） | 全矩阵 PASS + 抓帧像素一致 | **Round 7 全矩阵 7/7 PASS**（boot `20a1ce86`）：HEVC 1080p 20/20、4K60 8bit 20/20、Main10 8/8、20M/100M 10/10、H.264 1080p 30/30、4K 20/20；抓帧 1080p/4K 20/20、抽样 Y+全帧 sha1 bit-exact；`fixes/vdec-01/BOARD-VERIFY-H1.md` §3/§4。**历史记录保留，不再作为当前验收对** |
| **V-H1-old**（旧对，0 帧根因对照；**已降级**） | 旧 V-A：`d4337a64…` / 1,970,408 B（源码 `1ad1764`，无 `m2_sync_hevc_msgs` 参数） | `/root/m2/vdec_spec` `25abbfdf…` / 922,432 B | `ht1080b.hevc` `38bbbce8…` | 根因对照（**已知 0 帧**） | 0/20、`img=0 vdh=0` | **0/20**；仅历史对照/回滚，不得作验收对；`fixes/vdec-01/BOARD-VERIFY-H1.md`、`raw/p1-vdec/` |

> **配对规则补充（VDEC-01 教训）**：验收对必须能映射到**同一 git commit**；`d4337a64`/`25abbfdf` = `1ad1764`，
> 与 HEVC 使能 `6a2b5f5` 差一个 commit ⇒ 属于"看似成对、实则落后"的隐蔽错配，用 sha1 互校验也发现不了，必须记录 commit 溯源。
> 依据：[`HEVC-0FRAMES-REPORT.md` §2](artifacts/hwtest-2026-11-07/fixes/vdec-01/HEVC-0FRAMES-REPORT.md)、[`PROGRESS.md`](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md) VDEC-01 行。

### 1.6 VENC 模块演进（2026-11-08 修复阶段）

> 主机产物均为 `/home/jason/bringup-7.3/port/venc/hi_venc.ko`，逐版可复现；板上部署名按轮次区分（`hi_venc_venc05.ko`、`hi_venc_levelfix.ko` 等）。
> 共同工具：`encoder_accept10`（`a0458c90…`，3,631,592 B）；VENC-07 新增诊断工具 `encoder_entropy`（`802fb464…`，非验收）。

| 版本 ID | sha1 / 大小 | 新增/保留修复 | 验证范围 | 证据 |
|---|---|---|---|---|
| `7cfb0c0a`（m4pass，基线） | `7cfb0c0ae150…` / 198,984 B | 无 level/PTS0/workqueue 修复 | E01 `level=0`；E02 六组合 27.27–34.29fps | `raw/p2-venc/SUMMARY.md` |
| `339c04da`（VENC-01） | `339c04dafbd8…` / 199,248 B | **HEVC level 修复**（`level_idc=120`） | HEVC CBR/AVBR `level=120`；H.264 六组合字节与旧模块完全一致（零回归） | `fixes/venc-01/FIX-REPORT.md`、`BOARD-VERIFY.md` |
| `eab8d6cd`（VENC-05） | `eab8d6cd0e52…` / 199,192 B | + **首帧 PTS0 修复**（`PTS0=0xFFFFFFFF`，纠正"尾帧丢失"误判） | 90 帧 7/8 用例 PASS 90/90、ffprobe 90 帧、level 41/120 | `fixes/venc-05/FIX-REPORT.md`、`board-verify/BOARD-VERIFY.md` |
| `569f13d5`（VENC-04/06） | `569f13d53aea…` / 199,688 B | + **die-notifier exit 注销**（保留 level+PTS0） | rmmod→insmod 的 `notifier_chain_register` duplicate WARNING 消失 | `fixes/venc-04/FIX-REPORT.md` |
| **`0d95a512`（当前验收）** | `0d95a512bff7…` / 199,744 B | + **workqueue cancel guard**（`venc_probe_work` 未 INIT 时不再 `cancel_delayed_work_sync`，保留以上全部） | rmmod/insmod ×10 无 WARNING、taint 全程 4096；编码回归 90/90、level 41、ffmpeg rc=0 | `fixes/venc-06/FIX-REPORT.md`、`BOARD-VERIFY-06b.md` |

> 依据：[`PROGRESS.md`](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md) VENC-01/05/06 行；各 `FIX-REPORT.md` 的 sha1/大小/vermagic 记录。

### 1.7 VDEC 实验模块（**非验收**，仅用于 VDEC-02 追因）

| 配对 ID | 模块（板上路径 / sha1 / 大小 / 参数） | 新增参数 | 用途 | 结论 | 证据 |
|---|---|---|---|---|---|
| **V-X-p1**（实验） | `/root/m2/hi_vdec_p1_settle.ko`<br>`0b80fe85…` / 1,971,344 B（基线 `d4337a64` + settle 补丁；保留 `m2_sync_*`） | `vdec_open_settle_ms`、`vdec_close_settle_ms` | VDEC-02 Open/Close 复位时序实验 | settle close200 合并 p=0.0075，但交错实验不显著 ⇒ 不足以定论 | `fixes/vdec-02/module-p1-verification.txt`、`FINDINGS.md` |
| **V-X-w1**（实验） | `/root/m2/hi_vdec_w1fix.ko`<br>`ec3f792f…` / 1,974,344 B（与 `hi_vdec_w1_exitsync.ko` **同 sha1**；P1 + W1 `VDH_Quiesce` 退出同步） | 同上 + `vdh_exit_sync`、`vdh_exit_wait_ms`、`vdh_exit_legacy_wait_ms` | VDEC-02 W1 原型 A/B | A/B 无效（off 6/20 vs on 8/20，p=0.84）；稳定期方向有利但 ns | `fixes/vdec-02/module-w1-verification.txt`、`W1FIX-REPORT.md` |

> **禁止**把这两个模块写进验收结论：它们是为 VDEC-02 追因构建的实验件；验收仍用 V-H1-head-w1（HEVC）或 V-A/新对（H.264）。

### 1.8 VDEC 抓帧配对（VDEC-03，**4K 抓帧已闭环**）

> **Round 7 结论**：4K 抓帧不再依赖 `hi_vdec_ok64.ko`（其在本次两个 boot 均 0 帧，属 VDEC-02 族交付问题）；
> 用 `hi_vdec_hevc_head_w1.ko`（`047cad9b…`）+ `vdec_spec_hevc_head`（`6ada1250…`），
> `vdec_no_vcmp=1`、`VDEC_BUF_MB=16`（HEVC 走 kernel vdec_no_vcmp；抓帧输出 format=99 de-tile）⇒ 1080p/4K 抓帧均被闭环。
> **2026-11-08 更新**：当前验收模块已换为 §1.9 的 `hi_vdec_reloadfix.ko`（`e8859791…`，数据面与 head_w1 同族、未改解码路径）；
> reloadfix 的抓帧像素复核**待补**（`RMMOD-RELOADFIX-VERIFY.md` §5），在补测前抓帧证据仍以 head_w1 记录为准。

| 配对 ID | 模块 | 工具 | 输入流 | 用途 | 状态 / 证据 |
|---|---|---|---|---|---|
| **V-CAP-H1**（抓帧验证配对；Round 7） | `/root/m2/hi_vdec_hevc_head_w1.ko`<br>`047cad9b…` / 2,004,408 B<br>参数同 §1.5 + `vdec_no_vcmp=1`，`VDEC_BUF_MB=16` | `/root/m2/vdec_spec_hevc_head`<br>`6ada1250…` / 922,848 B（第 8 参数 capture_dir，**目录须预建**） | `ht1080b.hevc` `38bbbce8…`（1080p 20 帧）、`4k60.hevc` `44dca79c…`（4K 20 帧） | HEVC 1080p/4K 抓帧 + 像素验证 | ✅ **已闭环**：1080p 20/20、4K 20/20，`capture_errors=0`；抽样 pts 0/5/10（1080p）/0/5（4K）Y+全帧 sha1 与 ffmpeg 参考 **bit-exact**；4K ~37 s/20 帧（eMMC I/O 开销）。`fixes/vdec-01/BOARD-VERIFY-H1.md` §4、`fixes/vdec-03/FIX-REPORT.md` §7 |
| **V-CAP-1080**（H.264 抓帧） | 验收对 `d4337a64…`（V-A） | `vdec_spec` `25abbfdf…`（capture_dir 须 `mkdir`） | `h264-1080p-bp.h264` `8110aa2d…` | 1080p H.264 抓帧/像素验证 | ✅ **已恢复**：30/30、`capture_errors=0`、30/30 帧 Y 平面 bit-exact。`fixes/vdec-03/FIX-REPORT.md` §3 |
| V-CAP-ok64（**历史尝试，已弃用**） | `/root/m2/hi_vdec_ok64.ko`<br>`2835224c60…` / 1,989,008 B（含 `vdec_no_vcmp`） | `/root/m2/vdec_spec_r32`<br>`82654569…` / 922,832 B | `4k60.hevc` `44dca79c…` | 4K 抓帧（旧路径） | **0/20（两个 boot）**，已由 V-CAP-H1 取代；仅存档。`fixes/vdec-03/FIX-REPORT.md` §2 |

> 依据：[`fixes/vdec-03/FIX-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/vdec-03/FIX-REPORT.md) §7、[`fixes/vdec-01/BOARD-VERIFY-H1.md`](artifacts/hwtest-2026-11-07/fixes/vdec-01/BOARD-VERIFY-H1.md) §4、[`PROGRESS.md`](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md) VDEC-03 行。

### 1.9 VDEC-02 panic/exit 修复链（**当前验收模块 `hi_vdec_reloadfix.ko`**，2026-11-08）

> **背景**：VDEC-02 的"交付不稳定/boot 状态依赖/板卡失联"根因之一 = **SCD ISR 在 stream/channel 失效（close/exit 竞态）时解引用 NULL**
> （`SM_SCDIntServeProc→VCTRL_Scd_Isr→CheckStream→InsertStreamSeg`，进程被 SIGKILL/退出时 Comm=ip 正在 exit_mmap）；
> 另有 `rmmod` 的 device class 名生命周期与 module exit 顺序缺陷。修复链 = **4 个迭代模块（v1→v2→devfix→reloadfix）**；
> 最终 `reloadfix` = head_w1 基线（`0001`+`0003`）+ **`0005`**（SCD v2）+ **`0006`**（class 名生命周期）+ **`0007`**（exit inverse），为当前验收模块。

**修复链（模块 / sha1 / 大小 / 变更 / 上板结论）**

| 版本 | 模块 / sha1 / 大小 | 叠加补丁与修复 | 上板结论 | 证据 |
|---|---|---|---|---|
| head_w1（基线，历史） | `hi_vdec_hevc_head_w1.ko`<br>`047cad9b…` / 2,004,408 B | HEAD + `0001` settle + `0003` VDH exit sync | Round 7 **7/7 PASS**、抓帧 bit-exact（**历史记录，保留**） | `fixes/vdec-01/BOARD-VERIFY-H1.md` §3/§4 |
| v1（已退回） | `hi_vdec_scdguard.ko`<br>`9005a9d5…` / 2,006,928 B | + `0004` SCD ISR NULL 初版（quiesce + `cbz` 检查） | panic 未复现（串口 1100s 0 panic），但 **4K 全 0/20 回归 + rmmod Oops**（`HI_DRV_DEV_UnRegister→device_del→kobject_uevent`）⇒ 退回 | [`SCD-ISR-NULL-FIX.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/SCD-ISR-NULL-FIX.md)、[`SCD-V1-REGRESSION.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/SCD-V1-REGRESSION.md)、`RMMOD-OOPS.log` |
| v2（SCD 验收通过） | `hi_vdec_scdguard2.ko`<br>`b62e5504…` / 2,007,672 B | + **`0005` SCD ISR 修复 v2**：未映射段只跳过 `CheckStream` 解析、继续正常记账（修 4K 回归）；新增只读 `scd_seg_unmapped` | 4K **24/27 = nofix baseline**（3 个失败与 baseline 相同）；1080p 10/15（小样本差）；**kill-race 100 次 0 panic**；原 SIGKILL 主竞态未复现 | [`SCD-ISR-NULL-FIX-v2.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/SCD-ISR-NULL-FIX-v2.md)、[`SCD-V1-REGRESSION.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/SCD-V1-REGRESSION.md)、`SCD-V2-KILL-RUN.log` |
| devfix（中间产物） | `hi_vdec_scdguard2_devfix.ko`<br>`079b733f…` / 2,007,712 B | v2 + **`0006` class 名生命周期**（栈 buffer→静态 class 名，修 `device_del/kobject_uevent` Oops） | `rmmod rc=0`、device_del Oops 消失；但 **reload 第 1 次即暴露下一层**：`hi_vdec_mmz` platform_device `-EEXIST` + `proc_register` WARN + Oops ⇒ 未进验收 | [`RMMOD-UNLOAD-FIX.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-UNLOAD-FIX.md)、`RMMOD-DEVFIX-RUN.log` |
| **reloadfix（当前验收）** | `hi_vdec_reloadfix.ko`<br>`e8859791…` / **2,008,888 B** | v2 + `0006` + **`0007` module exit inverse**：`hi_vdec_mmz` platform_device / VFMW proc / IRQ / MMZ / DMA / iounmap 按创建逆序注销 + `mmz_init` 幂等 | **rmmod/insmod ×10 PASS**（taint 4096 不变、0 WARN/Oops/EEXIST、`/dev/hi_vdec` 每次重建）；reload 后 4K/1080p 解码全 PASS（4K 冷启动偶发重试）；7 用例矩阵两 boot **4/7、5/7**（失败为 VDEC-02 已知间歇，**按重试规则判定，非回归**）；SCD kill-race 100 次 0 panic | [`RMMOD-RELOAD-FIX.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOAD-FIX.md)、[`RMMOD-RELOADFIX-VERIFY.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md) |

**补丁清单（`fixes/vdec-02/patches/`）**

| 补丁 | 内容 | 进入版本 |
|---|---|---|
| `0001-vdec-open-close-settle-params.patch` | open/close settle 参数（`vdec_open_settle_ms`/`vdec_close_settle_ms`） | head_w1 起全部 |
| `0003-vdh-distributor-exit-sync.patch` | VDH/distributor 退出同步（`vdh_exit_sync`/`VDH_Quiesce`） | head_w1 起全部 |
| `0004-scd-isr-null-fix.patch` | SCD ISR NULL 初版（v1，**已退回**） | 仅 v1 |
| **`0005-scd-isr-fix-v2.patch`** | SCD ISR 修复 v2：只跳过 CheckStream、继续记账；`hi_vdec_scd_seg_unmapped` 计数 | v2 / devfix / reloadfix |
| **`0006-dev-classname-lifetime.patch`** | device class 名生命周期（静态名，修 rmmod `device_del` Oops） | devfix / reloadfix |
| **`0007-module-exit-inverse.patch`** | module exit 逆序注销 + `mmz_init` 幂等（修 reload EEXIST/proc WARN/Oops） | reloadfix |

**当前验收配对的模块参数集合**（reloadfix；在既有基础上新增）：
`m2_sync_downmsg=1 m2_sync_msgs=1 m2_sync_scd=1 m2_sync_hevc_msgs=1 vdec_dfs=1 vdec_sed_only=0`（+ `vdec_no_vcmp=1`/`VDEC_BUF_MB=16` 按抓帧用例），
新增 **`vdec_scd_isr_quiesce`**（参数，1=SCD IRQ quiesce 使能）、**`scd_isr_skipped`**（只读计数 0444）、**`scd_seg_unmapped`**（只读计数 0444）。
构建可复现：`git archive HEAD` + `0001+0003+0005+0006+0007` → sha1 = `e8859791…`（vermagic `7.3.0 SMP preempt mod_unload aarch64`）。

> 依据：[`fixes/vdec-02/SCD-V1-REGRESSION.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/SCD-V1-REGRESSION.md)、
> [`RMMOD-UNLOAD-FIX.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-UNLOAD-FIX.md)、
> [`RMMOD-RELOAD-FIX.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOAD-FIX.md)、
> [`RMMOD-RELOADFIX-VERIFY.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md)、
> [`SCD-V2-KILL-RUN.log`](artifacts/hwtest-2026-11-07/fixes/vdec-02/SCD-V2-KILL-RUN.log)、
> [`BOARD-VERIFY-H1.md`](artifacts/hwtest-2026-11-07/fixes/vdec-01/BOARD-VERIFY-H1.md) §6（reloadfix 复核记录）。

---

### 1.10 VDEC-02D 实验对（2026-11-10，**实验/非验收**）

| 项 | 路径 / sha1 / 大小 | 说明 |
|---|---|---|
| `hi_vdec_02d.ko` | `/home/jason/bringup-7.3/port/...` 重建于 reloadfix 源（`ebaa7dd`+`0001`+`0003`+`0005`+`0006`+`0007`）+ 两个诊断参数；`ca7a74b3544da13e11516f2c62fb27f6ea632df0` / 2,010,560 B | 新增 `vdec_ctrl_toggle`（0=不做 VCTRT 状态切换）、`vdec_sync_ack`（1=事件内同步回执，**实测挂死，禁用**）；**实验件，不得作为验收结论依据** |
| 历史对照模块 | `hi_vdec_hevc_head_w1.ko` `047cad9b…` / 2,004,408 B（§1.5 历史验收对） | VDEC-02D 同条件对照（2/4、1/4），用于排除 reloadfix 回归 |
| 工具 | `vdec_spec_hevc_head` `6ada12501cd1225665ebe827db18728d00eb2228` / 922,848 B | 与上面两个模块配对 |
| 流 | `4k60-100m.hevc` `1dfac16a4ff063f07eedfd0beb6e5149f06a70b4`（10 帧）；`4k60-10b.hevc` `9a41d9e8dfaa05c767891a3fbcf7b8f84fbea12a`（8 帧）；`4k60.hevc` `44dca79c2f98fd51730d9841038e4091fdbc75f3`（20 帧） | 100 Mbps / Main10 / 8-bit 对照 |
| 参数 | `m2_sync_downmsg=1 m2_sync_msgs=1 m2_sync_scd=1 m2_sync_hevc_msgs=1 vdec_dfs=1 vdec_sed_only=0 vdec_hdr_meta=0`；`VDEC_BUF_MB=8` | 与当前验收配方一致；实验只加 `vdec_ctrl_toggle`/`vdec_sync_ack` |
| 结论 | **DP8=否**（ctrl 无差异；sync ack 挂死；head_w1 同故障；坏 boot 首次调用 3/3 失败、再次调用第 3 次尝试才 PASS） | 证据：[`fixes/vdec-02d/R2-EXPERIMENTS-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02d/R2-EXPERIMENTS-2026-11-10.md) |

> DRM-02 **最终交付内核 #188**：Image `deaa3146`（10,887,176 B）、uImage `6d841e47`（11,414,162 B）、FIP pad `2dea80c5`（12,216,320 B）、config `38eacf2d`、DRM driver `379a09ba`；驱动修复 patch `/home/jason/bringup-7.3/port/0002-drm02-vblank-on-symmetry.patch`（`6a24aad2`）。已验证写入 eMMC（read-back sha1 一致），板卡从 eMMC 启动 #188，eMMC FIP sha1 = `2dea80c5…`。详见 [`fixes/drm-02/FIX-REPORT-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/drm-02/FIX-REPORT-2026-11-10.md)。
>
> DRM-02 中间工件（保留可复现）：#183 RAM 启动 `Image 5b3dd3e6 / FIP pad 2c329fa8`（vblank 不达标，失败基线）；#187（仅驱动修复、p99 3.334 ms 受 4 ms tick 限制）`Image 839de290 / pad 4dc3eb9a`；诊断内核 #184/#185/#186（插桩，源码已还原）。归档目录：`/home/jason/bringup-7.3/out/backup-drm02-20261110/artifacts-{183,187,188}/`。
>
> INF-04 #188 回归（2026-11-10，最终 8/8 PASS）：`board_ctl.py` 现 sha1 **`327e903fb502bc6d5fc19a1d3d731435f794afa1`**（旧 `db357697`；INF-01：`reboot` 改 sync+RTS 快路径，184s→25s）；编排器 `tools/hwtest/run_phase.sh` 现 sha1 **`74f771a1b3fb283647f236c0e4171ce153cd39e1`**（旧 `a44052ef`；ssh keepalive/rc=255 重试 + boot 后磁盘预检 `MIN_FREE_MB=300` + 失败也清理板卡 workdir）；mock 自检 137/137 PASS ×2。8 阶段 clean-boot 结果：**8/8 PASS**（vdec_hevc_4k 清盘后复跑：decode 20/20、抓帧 20/20、像素 bit-exact），详见 [`fixes/inf-04/INF-04-188-REGRESSION-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/inf-04/INF-04-188-REGRESSION-2026-11-10.md)、[`fixes/inf-01/INF-01-REBOOT-FIX-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/inf-01/INF-01-REBOOT-FIX-2026-11-10.md)。
>
> VDEC-02D E8 预分配帧存候选（2026-11-10，RAM boot，未写 eMMC）：`desk2.dtb` 原地改 `cma=384M`（sha1 `26ee7116…`）→ `uImage_vdec_cma384`（`85ef4908…`，配 #188 Image `deaa3146`）→ FIP pad `9257d0be…`（12,216,320 B）；结论：`cma=384M` 无改善、`vdec_dfs=0` 建流失败（`HI_MPI_VDEC_ChanStart rc=0xffffffff`）⇒ 候选排除。工具 `vdec_spec_hevc_head` `6ada1250`、流/索引同 VDEC-02D 基线。

### 1.11 DRM-05 实验/工具（2026-11-10，**bring-up/实验，非产品交付**）

| 项 | 路径 / sha1 | 说明 |
|---|---|---|
| `drmplay` | `fixes/drm-05/src/drmplay.c`（`d0081844…`，源码）；二进制 `921d83d9…`（git 未入库二进制） | 直接 DRM ioctl（无 libdrm）：dumb buffer + SETCRTC + `WAIT_VBLANK`（绝对序列）+ `PAGE_FLIP`；显示路径 30min soak 用（54000 帧、0 drops、抖动 max 0.047ms） |
| `drmdec` | `fixes/drm-05/src/drmdec.c`（`23f23a15…`）；二进制 `f218e112…` | 由 `vdec_spec` 派生：同进程 VDEC 解码 + DRM 显示；`DEC_LOOPS` 流循环；`/dev/mem` 一次映射保留 MMZ 窗口（`0x28000000`，96MB）后 `map=0ms`；紧耦合 HEVC 30min soak（53677/54000、29.82fps、drops 1.19%）；**H.264 30min 紧耦合 soak（53549/54000=99.17%、29.75fps、drops 0.6%、抖动 mean 0.385ms、oops/lima=0）** |
| 构建 | `aarch64-linux-gnu-gcc -static -O2 -pthread -DCHIP_TYPE_hi3798mv300 -I<toolchain>/usr/aarch64-linux-gnu/include ... port/vdec-m2diag-r2/{usertest/*.c}`（详见报告 §1/§6） | `drmdec` 复用 vdec_spec 的 usertest 链接集 |
| ⚠️ 注意 | `/dev/mem` 映射保留 MMZ 窗口是 **bring-up hack**（需 root、依赖未开 STRICT_DEVMEM），**不可作为产品方案** | 产品化应改为 shim 持久映射 ioctl 或 dma-buf；见 [`fixes/drm-05/DRM-05-STAGE3-COUPLED-2026-11-10.md`](artifacts/hwtest-2026-11-07/fixes/drm-05/DRM-05-STAGE3-COUPLED-2026-11-10.md) §6.3 |

## 2. 模块清单（完整 sha1）

| 模块 | 板上路径 | 主机路径（构建源） | sha1 | 大小 | 参数/角色 |
|---|---|---|---|---|---|
| `hi_vdec_downmsg_r51_final.ko`（= `hi_vdec.ko` Pair A） | `/root/m2/hi_vdec_downmsg_r51_final.ko`、`/root/m2/hi_vdec.ko` | `/home/jason/bringup-7.3/port/vdec-acc0/hi_vdec.ko` | `d4337a6455ea29c1662aeaa3628f14dda8956c70` | 1,970,408 B | round51 M2 验收构建；`m2_sync_*`、`vdec_dfs`、`vdec_sed_only`；**无 `vdec_no_vcmp`**（4K 不可抓帧） |
| `hi_vdec_acc.ko` | `/root/m2/hi_vdec_acc.ko` | 同板上路径 | `6d33babbec7d98bb7417160a6aebaf36d8c2c7c1` | 1,954,400 B | 2026-11-05 验收构建；无 `m2_*`；仅作对照 |
| `hi_vdec.ko`（7-28 旧 diag） | `/root/hi_vdec.ko` | 同板上路径 | `a905bdd5449b086453df775f6553607b4ffe4956` | 1,906,664 B | 常开 SPITAG/FILEDBG/PUTBM；**仅对照，禁止用于验收/压测** |
| `hi_mmz_shim.ko`（验收） | `/root/m2/hi_mmz_shim.ko` | `/home/jason/bringup-7.3/port/mmz/hi_mmz_shim.ko` | `1ad0d7c7d5e2ba7b9e74d5de50a2277407708a09` | 11,464 B | **必须先于所有编解码模块加载**（否则 `Create` 返回 `0x801d0008`） |
| `hi_mmz_shim.ko`（旧） | `/root/hi_mmz_shim.ko` | 同板上路径 | `0bfd830f06261499286d1b2bc99d4cac86b3a815` | 10,376 B | 仅与 P0 旧构建对照 |
| `hi_venc_m4pass.ko` | `/root/m2/hi_venc_m4pass.ko` | `/home/jason/bringup-7.3/port/venc/hi_venc.ko`（`339c04da…` 已部署为 `hi_venc_levelfix.ko`；此后演进见 §1.6） | `7cfb0c0ae1508fadfe790537f5c0daa4b049c406` | 198,984 B | 基线 VENC 模块；SPS `level=0`（未含 level 修复） |
| `hi_jpeg.ko` | `/root/m2/hi_jpeg.ko` | `/home/jason/bringup-7.3/port/jpeg/hi_jpeg.ko` | `224eea81e487540250521204451fe7f33054a556` | 31,048 B | `/dev/jpeg` major 247；**不可与 `hi_vdec` 同 boot** |
| `hi_png.ko` | `/root/m2/hi_png.ko` | `/home/jason/bringup-7.3/port/png/hi_png.ko`（主机 sha1 实为 `d8ade916…`，即 `hi_png_dmp.ko`，**不等同**） | `1dfac9e0befdb8695923d633499b851c193ecb51` | 53,416 B | `/dev/hi_png` major 247；配对以**板上** sha1 为准 |
| `hi_vdec_hevc_min.ko`（VDEC-01 最小修复） | `/root/m2/hi_vdec_hevc_min.ko`（归档 `fixes/vdec-01/bin/`） | `port/vdec-m2diag-r2` @ `1ad1764` + `patches/0001-hevc-publish-m2sync.patch` | `18c3ca6b1039fb98f7e21db659dc647e91e2ee98` | 1,971,776 B | = commit `6a2b5f5` 构建；含 `m2_sync_hevc_msgs`；**无** `vdec_no_vcmp`（不能抓帧）；HEVC 1080p 已上板 20/20 |
| `hi_vdec_hevc_head.ko`（HEVC+抓帧） | `/root/m2/hi_vdec_hevc_head.ko` | `port/vdec-m2diag-r2` HEAD（`ebaa7dd`）构建 | `b443d88bfd245d96167974f1f27a7b21f533463c` | 2,000,840 B | HEAD 构建：HEVC 修复 + `vdec_no_vcmp` + 10-bit/抓帧；含后续诊断改动（默认关） |
| `hi_vdec_hevc_w1.ko`（HEVC+W1） | `/root/m2/hi_vdec_hevc_w1.ko` | `6a2b5f5` + W1（task-23） | `ce811774e8f00f6ebeb253f32c1ae44fc230f0f4` | 1,975,720 B | HEVC + distributor 退出同步（`vdh_exit_sync`）；decode-only |
| `hi_vdec_hevc_head_w1.ko`（**历史验收模块（Round 7）**） | `/root/m2/hi_vdec_hevc_head_w1.ko` | HEAD + W1 | `047cad9b1a6d3bc76e4c4d91c72552ab2517cf58` | 2,004,408 B | HEVC + W1 + 抓帧/10-bit；Round 7 全矩阵 7/7 PASS（历史记录；已被 `hi_vdec_reloadfix.ko` 取代） |
| **`hi_vdec_reloadfix.ko`（当前验收模块）** | `/root/m2/hi_vdec_reloadfix.ko`（归档 `fixes/vdec-02/bin/`；同 sha1 副本 `hi_vdec_scdguard2_devfix2.ko`） | HEAD + `0001`+`0003`+`0005`+`0006`+`0007` | `e88597910e2fa7e00972a25bccd3024ef1fac2fa` | 2,008,888 B | = head_w1 + SCD 防 panic/4K(`0005`) + class 名(`0006`) + exit inverse(`0007`)；rmmod/insmod ×10 PASS；见 §1.9 |
| `hi_vdec_scdguard2_devfix.ko`（中间产物） | `/root/m2/hi_vdec_scdguard2_devfix.ko` | HEAD + `0001`+`0003`+`0005`+`0006` | `079b733ff366caf009792cb9f60fbd69fa93e482` | 2,007,712 B | rmmod Oops 已修，但 reload 仍 EEXIST/proc WARN/Oops ⇒ 未进验收（§1.9） |
| `hi_vdec_scdguard2.ko`（SCD v2） | `/root/m2/hi_vdec_scdguard2.ko` | HEAD + `0001`+`0003`+`0005` | `b62e550419adb028a3f5d4999cfa632a01eefd81` | 2,007,672 B | 4K 与 baseline 持平、kill-race 0 panic（§1.9） |
| `hi_vdec_scdguard.ko`（SCD v1，已退回） | `/root/m2/hi_vdec_scdguard.ko` | HEAD + `0001`+`0003`+`0004` | `9005a9d5894a33c31cbc0b36d3ad735585d34c57` | 2,006,928 B | **4K 全 0/20 回归 + rmmod Oops** ⇒ 退回，仅存档（§1.9） |
| `hi_vdec_unloadfix.ko`（隔离诊断，**非验收**） | `/root/m2/hi_vdec_unloadfix.ko` | HEAD + `0001`+`0003`+`0006`（不含 `0005`） | `a76a87e0…`（完整 sha1 见 `fixes/vdec-02/RMMOD-UNLOAD-FIX.md`） | 2,004,448 B | 隔离验证 rmmod 修复用，不用于验收 |
| `hi_vdec_p1_settle.ko`（**实验，非验收**） | `/root/m2/hi_vdec_p1_settle.ko` | `1ad1764` + settle 补丁 | `0b80fe8542d5ea6c38274bbc9ea9dd0405350fce` | 1,971,344 B | 新增 `vdec_open_settle_ms`/`vdec_close_settle_ms`；VDEC-02 追因 |
| `hi_vdec_w1fix.ko`（**实验，非验收**） | `/root/m2/hi_vdec_w1fix.ko`（= `hi_vdec_w1_exitsync.ko`，同 sha1） | `1ad1764` + P1 + W1 补丁 | `ec3f792f1b3e1e0692fa3ebf8eece448bf1ae2db` | 1,974,344 B | P1 + `VDH_Quiesce` 退出同步；VDEC-02 A/B |
| `hi_vdec_ok64.ko`（4K 抓帧旧路径，**已弃用**） | `/root/m2/hi_vdec_ok64.ko` | `/home/jason/bringup-7.3/port/vdec-ok64/hi_vdec.ko` | `2835224c60bb428f3275c5ec4f7e61238a3d105d` | 1,989,008 B | 含 `vdec_no_vcmp`；本次两个 boot 均 0 帧（VDEC-02 族），4K 抓帧已改用 `047cad9b`（§1.8） |
| `hi_venc.ko` `339c04da`（VENC-01） | `/root/m2/hi_venc_levelfix.ko` | `/home/jason/bringup-7.3/port/venc/hi_venc.ko` | `339c04dafbd827644d88e5ee1c3a363e2a8d7b24` | 199,248 B | HEVC level 修复（`level_idc=120`） |
| `hi_venc.ko` `eab8d6cd`（VENC-05） | `/root/m2/hi_venc_venc05.ko` | 同上 | `eab8d6cd0e5274bfc194dda911730812aca21a1f` | 199,192 B | + 首帧 PTS0 修复 |
| `hi_venc.ko` `569f13d5`（VENC-04/06） | `/root/m2/hi_venc_venc04.ko` | 同上 | `569f13d53aea1add221d12279a38682394738583` | 199,688 B | + die-notifier exit 注销 |
| `hi_venc.ko` `0d95a512`（**当前验收**） | `/root/m2/hi_venc_venc06b.ko`（按轮次部署） | 同上 | `0d95a512bff7ccbfc068f61aa99ca50b7e4dd7b8` | 199,744 B | + workqueue cancel guard（含以上全部修复） |
| **`hi_png_reload.ko`（当前验收）** | `/root/m2/hi_png_reload.ko`（归档 `fixes/png-07/bin/`） | `/home/jason/bringup-7.3/port/png/hi_png.ko`（src2 + mmz/irq 重载修复） | `4551b6e117a6d0b88c023c0cbbab87848ac25021` | 48,528 B | 独立 class `hi_png`、可同 boot 重载；`/dev/hi_png` |
| `hi_png_cls.ko`（已退役） | `/root/m2/hi_png_cls.ko` | 同上（修复前） | `ebb0064d729cb1c7562462baf609f60bb39a42e4` | 47,968 B | 修 class 冲突；同 boot 二次 insmod `-EEXIST` |

> 依据：[`matrix/harnesses.csv`](artifacts/hwtest-2026-11-07/matrix/harnesses.csv)、`raw/p0-baseline/SUMMARY.md` §4、各阶段 `summary.txt` ENV 块；
> 修复阶段模块 sha1/大小/参数来自 `fixes/vdec-01/module-tool-verification.txt`、`fixes/vdec-02/module-p1-verification.txt`、`fixes/vdec-02/module-w1-verification.txt`、
> `fixes/vdec-03/FIX-REPORT.md` 与各 VENC `FIX-REPORT.md`/`SHA1SUMS`；
> VDEC-02 修复链（scdguard/scdguard2/devfix/reloadfix/unloadfix）来自 `fixes/vdec-02/{SCD-ISR-NULL-FIX.md,SCD-ISR-NULL-FIX-v2.md,SCD-V1-REGRESSION.md,RMMOD-UNLOAD-FIX.md,RMMOD-RELOAD-FIX.md,RMMOD-RELOADFIX-VERIFY.md}` 与 `patches/0004–0007`。

## 3. 工具清单（完整 sha1）

| 工具 | 板上路径 | 主机路径 | sha1 | 大小 | 用法/角色 |
|---|---|---|---|---|---|
| `vdec_spec`（Pair A） | `/root/m2/vdec_spec` | `/home/jason/bringup-7.3/port/vdec-acc0/spec/decoder/vdec_spec` | `25abbfdf860d90507beff1a3f7c94142df81d7d5` | 922,432 B | `vdec_spec <codec> <cap> <stream> <index> <w> <h> <timeout_s>`；主验收工具 |
| `vdec_spec_r36` | `/root/m2/vdec_spec_r36` | （`matrix/harnesses.csv` 未登记主机路径；以板上 sha1 为准） | `38b64af06c01d45b6625bc20b899ef43f7fe8ed2` | 922,848 B | 交叉对照；**与验收模块配对时结果不稳定，只作对照** |
| `vdec_test` | `/root/m2/vdec_test` | `/home/jason/bringup-7.3/port/vdecuser/vdec_test` | `0bdf305a75f7c686d3de56f8974fc74864c246b1` | 854,736 B | `vdec_test <file.h264> [all\|au]`；固定 H.264+FULLHD，**不能测 HEVC/4K**；重定向须 `stdbuf -o0` |
| `encoder_accept10` | `/root/m2/encoder_accept10` | `/home/jason/bringup-7.3/port/vdec-m2diag-r2/spec/encoder/build/encoder_accept` | `a0458c9026e9ac7c748aed01b20fe8ea5fe12f07` | 3,631,592 B | `encoder_accept --codec H264\|HEVC --profile … --rc CBR\|AVBR …`；**不支持 `--rc VBR`**（见 §4.3） |
| `jpeg_test` | `/root/jpeg_test`（`/root/m2/jpeg_test_v` 同 sha1） | `/home/jason/bringup-7.3/port/jpeg-user/jpeg_test` | `cc957cd2ac438d98572ad077fb68500c276036dd` | 781,120 B | `jpeg_test in.jpg out.yuv [loops]`；`loops>1` 当前必失败 |
| `png_test` | `/root/m2/png_test` | `/home/jason/bringup-7.3/port/png-user/png_test` | `c90dc8203d412263d5e6cf7e2f83b189b50f1831` | 778,008 B | `png_test in.png out.raw [loops]`；**整文件提交**（`strings` 无 `idat stream`；`AllocBuf size=文件+8`）——P4 用它导致"全 0"，已由 PNG-01 判定为工具误用（见 §6 R1）。harnesses.csv 记录的 `png_testF`（`51a9ef94…`）才是"与当前源码一致"的 IDAT 组帧版 |
| `png_test8`（历史 head 成功配方） | `/root/m2/png_test8` | —（板上历史构建） | `723a011bb102ab818c032c7830fad12ad772cba1` | 778,160 B | **IDAT 组帧**（`idat stream 215622`）；round159/161 与 PNG-01 E0/E1 复现 head `7e00fd…`（HEAD_OK） |
| `vdec_spec_hevc_min` | `/root/m2/vdec_spec_hevc_min` | `fixes/vdec-01/bin/vdec_spec_hevc_min` | `a9cc2b63887fa8c62a75e6dfa316e725be4b5ed3` | 922,544 B | commit `6a2b5f5` 工具（PTSHEAD/order_breaks 统计；解码行为同旧工具）；用于 Arm D 工具独立性对照 |
| `vdec_spec_hevc_head`（**VDEC 当前验收工具**） | `/root/m2/vdec_spec_hevc_head` | `fixes/vdec-01/bin/vdec_spec_hevc_head` | `6ada12501cd1225665ebe827db18728d00eb2228` | 922,848 B | HEAD 工具（HEVC 抓帧/10-bit/统计）；与当前验收模块 `hi_vdec_reloadfix.ko`（`e8859791`）配对；V-H1 各 arm 与 reloadfix 矩阵均用 |
| `vdec_spec_r32`（Pair B，4K 抓帧旧路径） | `/root/m2/vdec_spec_r32` | `fixes/vdec-03/vdec_spec_r32` | `8265456945bb8d93ba44b83c7f82618c96a62d0c` | 922,832 B | 与 `hi_vdec_ok64.ko` 配对（旧 4K 抓帧路径）；当前抓帧改用 `vdec_spec_hevc_head`（+ `head_w1`/`reloadfix`，§1.8/§1.9） |
| `encoder_entropy`（VENC-07 诊断，非验收） | `/root/m2/encoder_entropy` | `fixes/venc-07/encoder_entropy` | `802fb464…`（完整 sha1 见 `fixes/venc-07/VENC-07-MATRIX.md`） | —（VENC-07 新增） | 熵梯度/进度/STAT 诊断；不替代 `encoder_accept10` |

> 依据：[`matrix/harnesses.csv`](artifacts/hwtest-2026-11-07/matrix/harnesses.csv) 与 `raw/p1-vdec/`、`raw/p2-venc/`、`raw/p3-jpeg/`、`raw/p4-png/` 的 `logs/summary.txt` ENV 块；
> 修复阶段工具 sha1/大小来自 `fixes/vdec-01/module-tool-verification.txt`、`fixes/vdec-03/FIX-REPORT.md`、`fixes/png-01/FIX-REPORT.md`、`fixes/venc-07/`。
> `png_test` 三版差异（`c90dc820` 整文件 / `723a011b` IDAT / `51a9ef94` 主机最新）**已由 PNG-01 澄清**：P4 的"PNG 全 0"是工具误用，非硬件回归（§6 R1）。

## 4. 配对规则与错配症状

### 4.1 本次实测：同一模块、r36 与 Pair A 结果不同

**前提**：模块同为 `d4337a64…`（Pair A 验收模块）、boot 同为 `2e31a1a2…` 阶段，仅用户态工具不同。
`summary-v1.txt` = `vdec_spec_r36`（矩阵 v1，无预热）；`summary-v2.txt` = `vdec_spec` `25abbfdf`（矩阵 v2，含预热）。

| 用例（同一输入流 sha1） | r36 `38b64af0…` | Pair A `25abbfdf…` | 差异 |
|---|---|---|---|
| `h264-1080p-bp` `8110aa2d…` | 0/30（冷启） | 29/30（另一次 30/30） | 一次预热后 r36 也能 30/30 → 不是工具独有 |
| `h264-1080p-mp` `6618eb77…` | **30/30 ✅** | **0, 0** | 同模块同流，相反结论 |
| `h264-4k-bp` `e6df0bf7…` | 18/20 | 20/20（重跑 2/20） | 帧数差异 |
| `hevc-4k60-8bit` `44dca79c…` | 0/20 | 0/20 | 一致（工具不改变 HEVC 失败） |

**解读（重要，勿过度归因）**：工具版本确实能改变结果，但两个矩阵的**预热状态与运行时刻不同**，因此不能把差异单独归因为"工具 ABI 不匹配"。
可下的结论只有两条：
1. **任何 0 帧结论必须写成"在该配对下"**（如"Pair A `25abbfdf` + `d4337a64` 下 H.264 1080p-mp 为 0 帧"），不能推断硬件失效；
2. **只看单一工具会误判**：只看 Pair A 会误判"H.264 规格解码不可用"，只看 r36 会误判"H.264 已稳定通过"。
> 依据：[`REPORT.md` §4.1](artifacts/hwtest-2026-11-07/REPORT.md)、`raw/p1-vdec/summary-v1.txt`、`raw/p1-vdec/summary-v2.txt`、`raw/p1-vdec/p1b-logs/summary.txt`。

### 4.2 历史误判案例（同类问题的前车之鉴）

| # | 案例 | 当时的判定 | 后来的纠正 | 教训 |
|---|---|---|---|---|
| M1 | [`round174`](artifacts/spec-acceptance/round174-regression-abi-mismatch.md) | 换验收模块 `6d33babb` 后仍 ~0 帧 → 判"`vdec_spec` 与模块 **ABI/结构体版本不匹配**" | [`round176`](artifacts/spec-acceptance/round176-vdec-allocchan-fail.md)：实为 **`VDEC_AllocChan` 失败**；ABI 只能解释"帧收到但解析异常"，不能解释 AllocChan 失败；[`round178`](artifacts/spec-acceptance/round178-vdec-hal-init-oops.md)–[`round180`](artifacts/spec-acceptance/round180-vdec-osal-fix-verified.md) 修 HAL init oops 后才恢复 | **0 帧先查 HAL/加载/初始化，不要先归因"工具模块不配对"** |
| M2 | [`round200`](artifacts/spec-acceptance/round200-git-history-ab.md) | 用 git worktree 同提交重建 **模块 + 工具**（`2835224c60` + `8265456945`，保证 ABI 配对）应能复现 | 同提交配对仍 **0/0/1/0（H.264）、0（HEVC）** | **配对是必要条件、不是充分条件**；缺"预热/参数/环境"配方同样 0 帧 |
| M3 | [`round111`](artifacts/spec-acceptance/round111-jpeg-module-fixed.md) | `insmod` 报 `Invalid module format` → 判该 `.ko` **文件损坏** | 实为**板上 .ko 与主机 sha1 不一致**（部署不同步） | 部署后必须 `sha1sum` 对照；不要把"部署错"误判成"文件坏"（[`gaps.md` R4](artifacts/hwtest-2026-11-07/matrix/gaps.md)） |
| M4 | [`round206`](artifacts/spec-acceptance/round206-tool-ok-1080p-4k-both-fail.md) 等 | 把 `gen3_idr.h264` 当 1080p 流，按 `1920 1080` 参数调用 `vdec_spec` | 实测该流是 **640×360** → 每帧 `geometry_errors`，数字只能证明"工具能出帧" | **工具参数（width/height/index）必须与流匹配**（[`gaps.md` §2 D2/D3](artifacts/hwtest-2026-11-07/matrix/gaps.md)） |
| M5 | `vdec_spec_r11`（`714277fc…`） | 当作普通对照工具上板 | [`round196`](artifacts/spec-acceptance/round196-tools-all-fail.md) 记录其曾**触发连接重置（疑 oops）** | 非验收/非受控工具不要上板；诊断工具单列清单 |
| M6 | 输入流身份 | 按文件名相信"规格样本" | `4k60-high.hevc` 与 `4k60.hevc` **字节相同**（`44dca79c…`，非 High-tier）；`j-gray.jpg` 是 4:4:4 副本（`b1375882…`） | **流身份错配 = 配对错配**；断言规格前先核 sha1/ffprobe（[`gaps.md` G03/G04](artifacts/hwtest-2026-11-07/matrix/gaps.md)） |
| **M7** | **VDEC-01（本次最重要的误判）** | 2026-11-07 实测 HEVC 全 0 帧 → 归因"SCD→VDH 参数集/消息交接"或"环境非确定性"；并曾按"模块/工具版本"做了排除（`d4337a64`/`6d33babb`、`vdec_spec`/r36/`vdec_test`） | 实为**部署对落后一个 commit**：模块/工具源码 = `1ad1764`，恰是 HEVC 使能 commit `6a2b5f5` 的父提交；补回 HEVC message-publish（`m2_sync_hevc_msgs=1`）后 1080p **20/20**，同 boot sync=0 → 0/20；Round 7 用 `047cad9b`+`6ada1250` **全矩阵 7/7 PASS**、抓帧 bit-exact（VDEC-01/03 闭环） | **sha1 成对 ≠ commit 对齐**；验收对必须记录源码 commit（见 R11）；"排除了模块/工具"不等于"排除了版本组合" |
| **M8** | VENC-05 尾帧误判 | REPORT §4.2 "completed=89/90、尾帧 1 帧未刷出"（历史同型） | 实为**首帧 PTS=0 被驱动"重复 PTS"逻辑吞掉**；1 行修复 `PTS0=0xFFFFFFFF` 后 90/90、ffprobe 90 帧 | **看 submitted/completed 差值不能定丢帧方向**；要用码流内容级 `fidx` 对齐判断（见 §1.6 `eab8d6cd`） |
| **M9** | PNG-01 "硬件无输出"误判 | P4 用 `/root/m2/png_test`（`c90dc820`）→ 输出全 0，判"PNG 硬件本次更差/无像素" | 实为**工具误用**：`c90dc820` 是整文件提交（无 IDAT 组帧）；换 `png_test8`（`723a011b`，IDAT 组帧）后同模块复现 head `7e00fd…`（HEAD_OK）；整幅仍受 vendor 流控限制 | **同一模块换工具结果可以相反**；工具行为（是否 IDAT 组帧）必须写进配对，不能只记 sha1 |
| **M10** | VDEC-02 "环境非确定性"误判链 | 交付不稳定/板卡失联长期归因"boot 状态/环境/WiFi 服务"，模块侧只做实验模块（settle/W1）且均未根治 | 串口捕获到 **SCD ISR NULL panic**（close/exit 竞态），根因在驱动侧；修复链 v1(9005a9d5)→v2(b62e5504)→devfix(079b733f)→**reloadfix(e8859791)** 后：kill-race 100 次 0 panic、rmmod/insmod ×10 干净；剩余交付率间歇属 VDEC-02 已知项（重试判定） | **先抓 panic 现场再归因环境**；"workaround 有效"不等于根因已修；修复模块必须同时验证 rmmod/reload（§1.9） |

### 4.3 VBR 口径（与配对登记的关系）

VENC 配对表的"码控"列不得笼统写 VBR：

| 口径 | 含义 | 结论 |
|---|---|---|
| **规格 VBR** | 公开 API `HI_UNF_VENC_RATECONTROL_TYPE_E` 中存在 VBR 枚举 | ❌ **不存在**（公开枚举只有 CBR/AVBR，`encoder_accept` 也只收 `CBR\|AVBR`） |
| **AVBR→驱动 VBR** | 用户态 `AVBR` 映射到驱动 `ControlRateVariable`（即 VBR 路径），可跑通 | ✅ 已实测可跑（历史 round66/104；本次 90 帧 AVBR 码流合法） |

⇒ 正确写法："**AVBR（=驱动 VBR）已测；规格 VBR API 不存在**"。不得写"VBR 通过"。
> 依据：[`REPORT.md` §4.2](artifacts/hwtest-2026-11-07/REPORT.md)、[`round66`](artifacts/spec-acceptance/round66-vbr-is-avbr.md)、[`matrix/harnesses.csv`](artifacts/hwtest-2026-11-07/matrix/harnesses.csv)（`encoder_accept` 的"VBR 非法"注）。

### 4.4 配对规则（R1–R12）

| # | 规则 | 反例/依据 |
|---|---|---|
| R1 | **模块与工具必须同源成对**：同一 commit/分支重建；验收模块配验收工具，诊断工具只配诊断模块 | M1/M2；[`matrix/gaps.md` G01](artifacts/hwtest-2026-11-07/matrix/gaps.md)、[`round174`](artifacts/spec-acceptance/round174-regression-abi-mismatch.md) 的"成对匹配的（验收模块 + 对应工具），缺一不可" |
| R2 | **加载顺序固定**：`hi_mmz_shim.ko` 先于所有编解码模块 | 否则 `Create` 返回 `0x801d0008`（[`ROADMAP` §2.6](HARDWARE-ACCELERATION-STATUS-ROADMAP-2026-11-07.md)）；[`REPORT.md` §4.2](artifacts/hwtest-2026-11-07/REPORT.md) |
| R3 | **模块生命周期隔离**：`hi_jpeg` 与 `hi_vdec` 不可同 boot；`hi_venc` 不可热重载 → 换模块必 reboot | 重复符号 `HI_DRV_MODULE_Register`；`rmmod` 段错误/`-EEXIST`（[`REPORT.md` §2.2/§6 R3–R4](artifacts/hwtest-2026-11-07/REPORT.md)） |
| R4 | **一 boot 一配方**：记录 `boot_id`，跨 boot 结果不合并为同一配置结论 | `REPORT.md` §2.2 注；本次 P1 两 boot（`2e31a1a2`/`dbebb982`） |
| R5 | **工具参数必须与输入流匹配**：`width/height/index` 取自流本身（ffprobe/`packet_index.py`） | M4；[`gaps.md` §2 D2/D3](artifacts/hwtest-2026-11-07/matrix/gaps.md) |
| R6 | **落板后校验 sha1 + 大小**，再 `sync`/reboot；不通过不测 | M3；[`gaps.md` R4](artifacts/hwtest-2026-11-07/matrix/gaps.md) |
| R7 | **ENV 块强制**：每条证据日志头部写 `boot_id`、模块 sha1、工具 sha1、insmod 参数、输入流 sha1 | `REPORT.md` §2.2 与各阶段 `summary.txt` 格式 |
| R8 | **历史 PASS 必须绑定"配方五元组"**：模块 sha1 + insmod 参数 + 工具 sha1 + 输入流 sha1 + 加载顺序/预热次数 | M2（round200：历史 OK 的配方未留档，无法复现） |
| R9 | **0 帧先查工具/参数/boot，不先判硬件** | M1；R8 |
| R10 | **不用文件名断言规格**：4K High-tier、gray JPEG 等以 sha1/ffprobe 为准 | M6；[`gaps.md` G03/G04](artifacts/hwtest-2026-11-07/matrix/gaps.md) |
| **R11** | **sha1 必须能映射到 git commit**：登记表除 sha1 外要写源码 commit / 构建源；"同源成对"以 commit 对齐为准 | **M7**：`d4337a64`/`25abbfdf` = `1ad1764`，与 HEVC 使能 `6a2b5f5` 只差一 commit，单看 sha1 互校验发现不了 |
| **R12** | **修复对更新后旧对降级**：新验收对登记后，旧只在"对照/回滚"用途出现，不得混入验收结论；新对须显式登记新增参数（如 `m2_sync_hevc_msgs`、`vdec_no_vcmp`） | M7；§1.5 的 V-H1-old 仅作 0 帧对照；§1.6 VENC 五版并存但只有 `0d95a512` 为当前验收 |

---

## 5. 开测前检查清单（6 步）

1. `sha1sum` 校验板上模块（§2）与工具（§3），与登记值一致；**并核对源码 commit（§4.4 R11，VDEC-01 教训）**；
2. `lsmod` 确认没有上一阶段的编解码模块残留；必要时 reboot 并记录新 `boot_id`；
3. 先 `insmod /root/m2/hi_mmz_shim.ko`，再 `insmod` 目标编解码模块；
4. 取流 sha1 与 `ffprobe` 分辨率/帧数，生成/校验索引（`packet_index.py`），确认与工具参数一致；
5. 按 §1 对应行照抄命令与 env（`VDEC_BUF_MB=8` 等），不要把诊断参数混进验收用例；
6. 日志头写全 `boot_id`/模块 sha1/工具 sha1/参数/流 sha1；结束后把结果回填 [`REPORT.md`](artifacts/hwtest-2026-11-07/REPORT.md) 与本登记表。

---

## 6. 引用与遗留风险

**引用**
- 本次实测总报告：[`REPORT.md`](artifacts/hwtest-2026-11-07/REPORT.md)（VDEC §4.1、VENC §4.2、JPEG §4.3、PNG §4.4）
- **修复进度（滚动）**：[`fixes/PROGRESS.md`](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md)（各条目状态/证据/下一轮建议）
- **修复阶段证据**：[`fixes/vdec-01/HEVC-0FRAMES-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/vdec-01/HEVC-0FRAMES-REPORT.md)、[`BOARD-VERIFY-H1.md`](artifacts/hwtest-2026-11-07/fixes/vdec-01/BOARD-VERIFY-H1.md)、[`fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md)、[`SCD-V1-REGRESSION.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/SCD-V1-REGRESSION.md)、[`RMMOD-UNLOAD-FIX.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-UNLOAD-FIX.md)、[`RMMOD-RELOAD-FIX.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOAD-FIX.md)、[`fixes/vdec-03/FIX-REPORT.md`](artifacts/hwtest-2026-11-07/fixes/vdec-03/FIX-REPORT.md)、[`fixes/png-01/`](artifacts/hwtest-2026-11-07/fixes/png-01/)、[`fixes/venc-01..07/`](artifacts/hwtest-2026-11-07/fixes/)
- 工具/流清单：[`matrix/harnesses.csv`](artifacts/hwtest-2026-11-07/matrix/harnesses.csv)、[`matrix/streams.csv`](artifacts/hwtest-2026-11-07/matrix/streams.csv)
- 资产缺口与纠错：[`matrix/gaps.md`](artifacts/hwtest-2026-11-07/matrix/gaps.md)（G01/G02/G03/G04/G05、D2/D3、R4）
- 历史配对相关轮次：[`round174`](artifacts/spec-acceptance/round174-regression-abi-mismatch.md)、[`round176`](artifacts/spec-acceptance/round176-vdec-allocchan-fail.md)、[`round196`](artifacts/spec-acceptance/round196-tools-all-fail.md)、[`round200`](artifacts/spec-acceptance/round200-git-history-ab.md)
- 文档口径：[`CODEC-SPEC-FINAL-SUMMARY-2026-11-08.md`](CODEC-SPEC-FINAL-SUMMARY-2026-11-08.md)、[`HARDWARE-ACCELERATION-STATUS-ROADMAP-2026-11-07.md`](HARDWARE-ACCELERATION-STATUS-ROADMAP-2026-11-07.md)、[`HARDWARE-ACCELERATION-FIXLIST-ROADMAP-2026-11-07.md`](HARDWARE-ACCELERATION-FIXLIST-ROADMAP-2026-11-07.md)

**遗留风险**
- **R1 PNG 工具登记（已由 PNG-01 澄清）**：P4 用的 `c90dc820` 是**整文件提交**工具（无 IDAT 组帧），历史 head 成功配方用的是 `png_test8`（`723a011b`，IDAT 组帧）；同一模块换工具后 HEAD_OK ⇒ **P4 的"PNG 全 0"是工具误用，非硬件回归**（`fixes/png-01/E0-VERIFY.md`）。整幅仍不可达（HEAD_OK 仅 goodrows 15/32，partial 级）。**不得把 head 复现写成"整幅可用"。**
- **R2 主机/板上 png 模块 sha1 不一致**：主机 `port/png/hi_png.ko` = `d8ade916…`（等同板上 `hi_png_dmp.ko`），板上验收用的是 `1dfac9e0…`；配对以板上为准，重建/部署时勿混记。
- **R3 像素抓帧能力（已闭环）**：1080p H.264 抓帧 30/30 bit-exact；**4K/HEVC 抓帧也已闭环**——用当前验收对 `047cad9b` + `vdec_spec_hevc_head` + `vdec_no_vcmp=1` + `VDEC_BUF_MB=16`，1080p 20/20、4K 20/20，抽样 Y+全帧 sha1 bit-exact（`fixes/vdec-03/FIX-REPORT.md` §7、`fixes/vdec-01/BOARD-VERIFY-H1.md` §4）。旧 `ok64 + vdec_spec_r32` 路径 0 帧，已弃用（仅存档）。
- **R4 历史配方缺失**：round200 已证明"同提交配对"仍 0 帧；本表只登记了本次/修复阶段用到的配对，历史 PASS 的完整配方（预热次数/服务集合/CMA 布局）仍无归档，不能据此复现历史数字。
- **R5 VENC level=0（已闭环）**：`7cfb0c0a…` 的 level=0 已由 `339c04da`（`level=120`，`fixes/venc-01/`）修复，当前验收模块 `0d95a512` 含 level+PTS0+notifier+workqueue 全部修复（§1.6）；换构建仍须重登 sha1。
- **R6 HEVC 修复对含 HEAD 后续改动**：`hi_vdec_hevc_head*.ko` = HEAD 构建，含后续诊断/MPEG 等改动（默认关）；跑 HEVC arm 时必须同 boot 跑 H.264 控制臂，区分"HEVC 修复"与"其它变化"（`fixes/vdec-01/HEVC-0FRAMES-REPORT.md` §8）。
- **R7 VDEC-02（panic/exit 已修，交付间歇仍在）**：SCD ISR NULL panic 与 rmmod/reload 缺陷已由修复链（v1→v2→devfix→**reloadfix `e8859791`**）闭环（kill-race 100 次 0 panic、rmmod/insmod ×10 干净，§1.9）；但**解码交付率仍有 boot 状态依赖的间歇**（reloadfix 两 boot 矩阵 4/7、5/7，失败集合随机），验收按"重试 3 次/预热/clean boot"规则判定，**不得据单次 0–3 帧或 <7/7 判硬件回归**。当前验收模块 = `hi_vdec_reloadfix.ko`（`e8859791`）+ `vdec_spec_hevc_head`（`6ada1250`）；head_w1（`047cad9b`）7/7 为历史记录（[`PROGRESS.md`](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md) VDEC-02 行、[`RMMOD-RELOADFIX-VERIFY.md`](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md)）。
