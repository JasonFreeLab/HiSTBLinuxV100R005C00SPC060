# PNG 硬件解码板卡实验记录（T3 / BOARD-EXPERIMENTS）

- 板卡：`root@192.168.2.10`（#188，Linux 7.3.0 aarch64，Ubuntu 26.04）
- 实验台：`work/png-hw/board/`（`run_exp.sh` + `exp/*.sh`；一实验一 clean boot；证据 `docs/porting/artifacts/png-hw/<exp>/`）
- 唯一允许操作板卡的角色：board-eng（本文件由 board-eng 维护；blocking 结论均已上板取证）
- 判据：**只看像素**。`Decode rc=-2147483635 / state=3` 是超时；`Decode rc=0 / state=2(FINISH)` 才是完成。

---

## ★ 突破（2026-11-10 15:46，boot 3dc33df7 之前的 clean boot）

**PNGD 1080p 整幅硬件解码打通，输出与软件参考逐字节相同：**

| 项 | 值 |
|---|---|
| 实验 | `45-axi0to`：模块 = code-arch diag 变体 `hi_png_vN_axi0to.ko`（`u32AXIConfig(0x90)=0`、`u32TimeOut(0x94)=0x7fffffff`），t1080.png（7×32KB IDAT 段），stride 5760 |
| 结果 | `Decode rc=0` / `GetResult state=2(FINISH)` / **100.66 ms** |
| 像素 | `EXACT_ROWS=1080/1080`，`BYTE_MATCH_FRAC=1.000000`，`FULL_EXACT=True`；**out.raw sha1 `bbac27fa931a5cdf90654a92454fe1bb3ccddd29` = ffmpeg RGB24 参考** |
| 中断 | ISR **8 次**：`cnt1–7 Int=0x2 (RESUME)`（7 段→7 次续传）、`cnt8 Int=0x1 (FINISH)` |
| 寄存器 | `PNGHAL: open rb AXI=00000000 TMO=03ff03ff IMask=ffff0003 EMode=ffff0000` |
| 对照 | `46-timeoutto`（**只改 TimeOut=0x7fffffff，AXI 保持 vendor 0x20441**）→ 仍 15 行超时 ⇒ **决定性变量是 `u32AXIConfig`，不是 TimeOut** |
| 证据 | `docs/porting/artifacts/png-hw/45-axi0to/`（compare.txt/out.raw/dmesg-png.log/SUMMARY.md）、`46-timeoutto/` |

根因（待回灌确认）：`PngHalOpen()`/`PngHalSetAxiAndTimeout()` 写 **`u32AXIConfig=0x20441`（vendor "Suggest value"）**
会让 PNGD 在码流很早期（15 行/百~千字节级）静默挂起（无中断、无错误位、RstBusy=1 不回），
写入 **0** 后硬件正常工作并正确响应 RESUME/FINISH。AXI 位扫描（`61-axicfg-*`）进行中。

---

## ★★★ v4 正式验收批次（2026-11-10 16:13–16:21，每项 clean boot，AXI=0 + TMO vendor + png_wait_ms=10000）

模块 `hi_png_final_v4.ko` sha1 **d75f2781584f28018ced31642da772b01fe30427**。

| # | 项目 | 输入 / 工具 | 结果 | 证据目录 |
|---|---|---|---|---|
| 77 | 1080p 分段 | t1080.png 7×32KB，png_ctl | **rc=0 / state=2 / 101.16ms**；1080/1080 逐字节一致，sha1=`bbac27fa…`=参考 | `77-v4-1080/` |
| 78 | 1080p 单段 | t1080.png 单段 215,622B | **rc=0 / state=2 / 99.51ms**；sha1 全对 | `78-v4-single/` |
| 79 | **64MP** | 64mp-rgb.png 8000×8000（192MB 输出） | **rc=0 / state=2 / 3,099.36ms**；板端 sha1=`d0ce2b24…`=ffmpeg 参考 | `79-v4-64mp/` |
| 71 | 格式 RGB8 | 640×480，`hi_png_hw --outfmt rgb24` | 480/480 行逐字节一致（1.000000） | `71-fmt-rgb8-640/` |
| 73 | 格式 Gray8 | 640×480，`hi_png_hw --outfmt gray8` | 480/480 行逐字节一致 | `73-fmt-gray8-640/` |
| 74 | 格式 Palette8 | 640×480 索引图，`hi_png_hw --outfmt rgb24`（HAL CLUT 查表展开） | 480/480 行逐字节一致 | `74-fmt-clut8-640/` |
| 72 | 格式 RGBA8 | 640×480，`hi_png_hw --outfmt rgba8` | 480/480 行逐字节一致 | `72-fmt-rgba8-640/` |

同 boot 3 次解码（v4，隔离 dmesg）：见上一节，3/3 `rc=0/state=2/~100ms` 全部 1080 行逐字节一致。

## ★★ 根因与修复（2026-11-10 定稿）

### 根因（已上板二值确认）

| 变量 | 值 | 1080p 结果 |
|---|---|---|
| `u32AXIConfig`(0x90) | **0x20441**（vendor 默认，注释 "Suggest value is 0x20441"） | 写 15 行后**静默挂起**：`Int=0`（无任何中断）、`ErrStatics=0`（无错误位）、`RstBusy` 保持 1 不回；大码流（filter=0/155KB+）还会把 AXI 总线拖死 → sp805 看门狗 30s 整板复位 |
| `u32AXIConfig`(0x90) | **0x0** | **整幅正确**：1080p `rc=0/state=2/~100ms`，ISR 逐段 `Int=0x2(RESUME)`×N + `Int=0x1(FINISH)` |
| `u32TimeOut`(0x94) | 0x80008 vs 0x7fffffff | 无影响（`46-timeoutto` 只改 TimeOut 仍 15 行）→ **TimeOut 不是根因** |

即：**vendor HAL 的 `AXIConfig=0x20441` 在本芯片/本 SDK 上会让 PNGD 在码流早期把 AXI 通道卡死；
置 0 后一切正常**（单段/分段/64MP 都验证）。

### 修复（最终模块 `work/png-hw/code/final/`）

| 模块 | sha1 | 内容 |
|---|---|---|
| **`hi_png_final_v4.ko`（推荐/发布）** | `d75f2781584f28018ced31642da772b01fe30427` | ① AXIConfig=0（两处写点，含根因注释）② `png_wait_ms` 参数（默认 10000ms，解决 64MP 3.1s 被 2s 误杀）③ ISR 打印 bits16–31 具体错误名 + ErrStatics 并立即 ERR ④ FINISH ISR 不再关时钟 ⑤ `PngHalReset` 不再用“门控读回值”恢复 IntMask/ErrMode ⑥ StartDecode 清残留 INT ⑦ **轮询兜底判到 FINISH 时不再被 `s32Ret<=0` 超时分支改写成 ERR（同 boot 2/3 次误报超时的根因）** |
| `hi_png_final_v4_tmo.ko` | `34cc03c4ee1482f9d491561270acd6a328cbd0d5` | 同上，另 TimeOut=0x7fffffff（备用） |
| `hi_png_axifix.ko`（v2） | `7a95e3265a44a585dcb89c0314f5f9540ea670be` | AXI=0 + 长等待 + ErrBits（63 实验证明同 boot 2/3 次会误报超时） |
| 补丁 | SDK v4 `0a065bb6…` / PORT v4 `02cdee81…` | 对 git HEAD 原始 SDK / port 树 `patch -p1` 干跑通过（code-arch） |
| 生产工具 | `work/png-hw/code/out/hi_png_hw` sha1 `fe8bd39d…` | aarch64 static、HW-only、CRC/格式校验、`--outfmt rgb24/rgba8/gray8/gray16/rgb48`、interlace 明确拒绝（退出码 3） |

## ★ 验收表（clean boot，每项独立 boot）

| # | 项目 | 配置 / 输入 | 结果 |
|---|---|---|---|
| 62 | 1080p 分段 | v2 `7a95e326`，t1080，7×32KB | **rc=0 / state=2 / 100.74ms**；1080/1080 行逐字节一致，sha1=`bbac27fa…`=ffmpeg 参考（SHA1_MATCH=True） |
| 64 | 1080p 单段 | v2，单段 215,622B（历史“整板卡死”路径） | **rc=0 / state=2 / 99.77ms**；sha1 全对 |
| 65 | **64MP 8000×8000** | v2，192,000,000B 输出，46×128KB 节点 | **rc=0 / state=2 / 3,105.28ms**；板端 `sha1sum out.raw = d0ce2b24…` = ffmpeg RGB24 参考 sha1；CmaFree boot 261,856kB、解码需 ~198MB（192MB 输出+5.9MB 码流），建议板卡 CmaFree ≥ 256MB |
| 63 | 同 boot 3 次解码 | v2，t1080 | out1/out2/out3 **1080 行全对**；#1 rc=0/state=2 103ms；**#2/#3 rc=-2147483635/state=3（≈880ms）但像素全对** ⇒ 硬件正常，驱动轮询兜底误判（v4 修复项⑦） |
| 66 | Gray8 640×480 | v2 + png_ctl（未设 transform） | rc=0/state=2；HW 输出 3Bpp，但未请求 gray→RGB transform，故不用于比对；灰度用 `hi_png_hw --outfmt gray8` 验证 |
| 67 | RGBA8 640×480 | v2 + png_ctl，4Bpp stride 2560 | rc=0/state=2；**输出与 ffmpeg rgba 逐字节一致（match=1.000000）** |
| 60 | 1080p 单段（诊断模块） | AXI=0 诊断版 | rc=0/state=2/全对（先于 final 验证单段路径已修好） |

## ★★★ 同 boot 重复解码验收（v4，3/3 PASS）

`work/png-hw/board/special/redecode_isolate.sh`：clean boot `c89ca9bf`，模块 `hi_png_final_v4.ko`(`d75f2781…`)，
**每次解码前清空 dmesg**，3 次连续解码：

| # | Decode rc | state | 耗时 | 像素 | 证据 |
|---|---|---|---|---|---|
| 1 | 0 | 2 (FINISH) | 99.63 ms | 1080/1080 行逐字节一致 | `redecode-isolated-20261110-161005/compare1.txt` |
| 2 | 0 | 2 (FINISH) | 99.79 ms | 1080/1080 行逐字节一致 | 同上 compare2.txt + dmesg2-png.log |
| 3 | 0 | 2 (FINISH) | 99.22 ms | 1080/1080 行逐字节一致 | 同上 compare3.txt |

decode#2 隔离 dmesg 关键行（证明修复机制）：
```
Reset readback AXI=00000000 TMO=00000000 EMode=00000000 IMask=00000000 (pre-reset, may be 0 when gated)
PNGHAL: open rb AXI=00000000 TMO=00080008 IMask=ffff0003 EMode=ffff0000
png_isr cnt=3 Int=00000002 → resume#2 (no next buffer) → png_isr cnt=4 Int=00000001
finish: keep clock on (clkoff=0)
```
⇒ 第 2/3 次 FINISH 中断正常送达与处理（无需轮询兜底）；v4 的「轮询判 FINISH 不再被超时分支改写」
+ 「FINISH 不关时钟」+ 「Reset 不用门控读回值」三项共同解决。
对照：v2 模块（`7a95e326`）同 boot #2/#3 像素全对但驱动误报 `rc=-2147483635/state=3`（实验 63）。

## ★★★ r3 发布包部署回归（最终包 sha1 `c6fee5cd…`：v5 模块 `a47b509a` + 工具 `eebc802a` + `hi_png` 脚本 `197df0c2`）

用发布包自带 `scripts/install.sh root@192.168.2.10 --payload ./payload --enable --start`
（manifest sha1 校验 + 备份 + 失败回滚）：

| 步骤 | 结果 |
|---|---|
| install.sh | **PASS**：13 项 payload manifest 校验全 OK，`hi-accel` `state=PASS fail=0`；装后 `/root/m2/hi_png_reload.ko` = **`a47b509a…`(v5)**、`hi_png_hw` = `eebc802a…`(v1.2) |
| warm boot `hi_png --mode hw t1080.png` | `path=hw rc=0`，sha1=`bbac27fa…`=ffmpeg 参考 |
| warm boot `hi_png t1080.png`（auto） | `path=hw rc=0`，sha1 同上（**auto 走硬件**） |
| **无软件兜底**（隐掉 `/root/m2/hi_png_hw` 后 `hi_png --mode auto`） | `path=none rc=3`，无软件解码输出；恢复后正常 |
| clean reboot 后 `hi-accel.service` | `state=PASS fail=0`（hi_vdec/hi_venc/hi_jpeg/hi_png 全 ok、VDEC 预热 ok）；`/root/m2/hi_png_reload.ko` sha1=`a47b509a…` |
| clean boot `hi_png t1080.png` | `path=hw rc=0`，**431ms**（v4 时 1034ms，v5 静默生效）；输出 sha1=`bbac27fa…`，1080/1080 行逐字节一致 |
| 证据 | `release-r3-20261110-165544/`（install.log / warm-hi_png.log / no-fallback.log / service-boot.txt / boot-hi_png.log / boot-compare.txt） |

## ★★★ 格式矩阵（最终：hi_png_hw v1.2 sha1 `eebc802a…` + v4 模块，HW-only，无软解）

| 格式 | 输入 | 参考口径 | 结果 / 证据 |
|---|---|---|---|
| RGB8 | 640×480 / 1920×1080 | ffmpeg rgb24 | ✅ 480/480、1080/1080 行逐字节一致（`71`, `73`） |
| RGBA8 | 640×480 | ffmpeg rgba | ✅ 480/480 一致（`72`） |
| Gray8 | 640×480 | ffmpeg gray | ✅ 480/480 一致（`73-fmt-gray8-640`） |
| **Gray1 / Gray2 / Gray4** | bd=1/2/4 灰 640×480 | hand-expanded（==ffmpeg gray） | ✅ **PASS**（v1.2；`format-matrix-20261110-163922/`）。历史：v1.0 半字节序反转、v1.1 用 `GRAY124TO8|ADJUSTPIXELORDER` 修复 |
| **Palette1 / 2 / 4** | 640×480 索引图 | ffmpeg rgb24 | ✅ **PASS 480/480**（v1.2 回退软件 MSB-first 解包；`format-matrix-20261110-163922/`） |
| **Palette1/2/4 + tRNS** | 640×480 | ffmpeg rgba | ✅ **PASS 480/480**（同上） |
| Palette8 | 640×480 | ffmpeg rgb24 | ✅ 480/480（`74-fmt-clut8-640`，HAL CLUT 查表展开） |
| **RGB16** | 640×480 16bit RGB | ffmpeg **rgb48be** | ✅ 480/480 逐字节一致（`80-fmt-rgb48`，**硬件输出=大端 16bit**） |
| **Gray16** | 640×480 16bit 灰 | ffmpeg **gray16be** | ✅ 480/480 逐字节一致（`81-fmt-gray16`） |
| **RGBA16 → rgba8** | 640×480 | **libpng strip-16 截断（取高字节）** | ✅ 480/480 逐字节一致（`85-fmt-rgba16`；ffmpeg rgba 用四舍五入会差 ±1，不作为口径） |
| 宽 1921（非 16 对齐） | 1921×1080 RGB8 | ffmpeg rgb24 | ✅ 1080/1080 行一致（`84-fmt-w1921`，stride 5776） |
| 1×1 / 17×17 RGB | 极小图 | ffmpeg rgb24 | ✅ 逐字节一致（`format-matrix-20261110-163922/`） |
| Adam7 interlace | — | — | 工具明确返回 3 拒绝；驱动 Pass0–6 未实现（记录为"驱动不支持"） |

**VDEC/JPEG 冒烟（r3 + v4 模块环境下独立跑）**：`vdec_h264_smoke` **PASS 3/3**（Y sha1 一致）、
`jpeg_smoke` **PASS**（loops=100，5–11 ms），证据 `docs/porting/artifacts/hwtest-2026-11-07/auto/`
下 `vdec_h264_smoke-20261110-163307/`、`jpeg_smoke-20261110-163222/`。

工具版本演进（记录教训）：`v1.0 fe8bd39d`（gray bd1/2/4 顺序错，palette 正确）→
`v1.1 372f1e8f`（gray 修好，palette 回归坏）→ **`v1.2 eebc802a`（gray 硬件 ADJUSTPIXELORDER + palette 软件 MSB-first，全绿）**。
v1.1 的 palette 回归证据保留在 `format-matrix-v11-palette-bug/`。

## ★★★ task-5 线1：Adam7 interlace 硬件探针（2026-11-10 21:44–21:58）

测试图：`work/png-hw/board/img/ilace-{rgb16x16,rgb33x17,rgb64x64,gray17x17,rgba19x11}`（.final.rgb / .pass0..6.rgb 参考均已与 ffmpeg 去交错逐字节校对）。

### 结论（重要）

1. **mode1（`hi_png_ilace_v1.ko`：仅置 `uType.InterlaceType=1`）**：5/5 图 `decode_rc=0 / state=2(FINISH)`、**无错误位**，
   但 **Final 输出缓冲全 0**（768/1904/12288/544/880 B）⇒ 硬件"接受"interlace 位并正常 FINISH，但**不向 Final 地址写任何数据**。
2. **mode2（`hi_png_ilace_v2.ko`：Adam7 7 pass 缓冲 + Pass0-6 地址/stride + FINISH 后 dump）**：
   - 寄存器读回=写入（`PNGILACE regs: pass0=…/0010 … pass6=…/0030`），几何与 Adam7 公式一致；
   - **7 个 pass 缓冲全部有正确数据**：rgb16x16 / rgb64x64 / rgb33x17 / gray17x17 四图 **28/28 个 pass 与 `.passN.rgb` 逐字节一致**
     （tight 行 + stride padding 布局；rowbytes = ceil(subw*bpp/8)，stride = align16(rowbytes)）；
   - **Final 缓冲仍全 0** ⇒ **硬件按 pass 输出子图，但不会在一次 Decode 内合成整幅**。
3. **可行方案**：**硬件解 Adam7 的 7 个子图（bit-exact）+ CPU/TDE 按 Adam7 规则拼图** —— 属"硬件解码、软件拼图"，
   非软件兜底；工作量约 0.5–1 天（生产版驱动+工具）。

### v2 探针 bug（已交 code-arch）
同一 boot 多次解码（第 5 次左右）会触发内核 oops：`Unable to handle kernel paging request` @
`HI_DRV_MMZ_Alloc+0x160 → PngOsiResAllocMem → PngOsiDecode → png_ioctl`，工具 SIGSEGV；
证据 `docs/porting/artifacts/png-hw/ilace-v2-crash/dmesg-oops.log`。规避：每图 fresh boot + 单次解码。

证据目录：`ilace-probe-20261110-214416/`（mode1/2 run+dmesg+out.raw）、`ilace-passes3-20261110-215615/`（5 图 7 pass 全量 dump + 逐 pass 比对）、`ilace-v2-crash/`。

## ★★★ task-5：16bit 小端工具验收 + Adam7 探针 + 64MP CMA 余量（2026-11-10 晚）

### 1) 16bit 小端工具（hi_png_hw v1.4 `684ebb83…`）—— PASS

| 项 | 命令 | 参考 | 结果 |
|---|---|---|---|
| RGB16→LE | `--outfmt rgb48le` | ffmpeg **rgb48le** | **480/480 行逐字节一致**（`fmt16le-cma-20261110-212756/`） |
| RGB16→LE(bswap) | `--outfmt rgb48le --bswap16` | 同上 | 480/480 一致 |
| Gray16→LE | `--outfmt gray16le` | ffmpeg **gray16le** | 480/480 一致 |
| RGB16→BE（旧口径对照） | `--outfmt rgb48` | ffmpeg rgb48be | 保持 480/480 一致（BE 结果不变） |
| Gray16→BE（对照） | `--outfmt gray16` | ffmpeg gray16be | 480/480 一致 |

⇒ 16bit 小端输出**工具侧已解决**（硬件输出仍为大端 16bit，工具做 16bit 换序，属显示/落盘约定，非解码缺陷）。

### 2) 64MP 与 CMA（结论：**配置容量/占用问题，非驱动缺陷**）

| 场景 | CmaFree | 64MP 结果 |
|---|---|---|
| clean boot，hi-accel 已加载 | **243,872 kB**（CmaTotal 262,144 kB） | **PASS**（历史多次：`d0ce2b24…` = ffmpeg 参考，3102 ms） |
| 长时间测试后的"脏" boot | **159,828–160,264 kB** | **FAIL**：`mmz alloc out failed`（工具 rc=1，Open 后 192MB 输出分配失败） |
| 需 CMA 估算 | 192MB 输出 + 46×128KB 节点链(≈5.9MB) + RDC/FLT ≈ **~198MB** | 256MB 池在干净 boot 下余量 ~45MB；被占用后必失败 |

- **非驱动缺陷**：同一 v5 模块在 CMA 充足时 64MP 稳定 bit-exact；不足时在 MMZ 分配阶段就明确失败（不误判成功）。
- **容量机制**（重要）：内核 cmdline 来自 **uImage 内嵌 DTB 的 `chosen/bootargs`**（`desk2.dtb`），不是 U-Boot env；
  `cma=256M` 在 7.3 内核生效（`/proc/meminfo CmaTotal=262144 kB`）。改容量 = 改 DTB cmdline → 重打包 uImage/FIP → 写 eMMC p6（或 RAM boot 验证）。
- **已备好**（`work/png-hw/board/artifacts/fw/`，SHA1SUMS 见目录）：
  - `fip_188_cma384_pad.bin` sha1 **`9257d0be…`**（当前 #188 Image + cma=384M，12,216,320 B = 0x5D34 块）——与 VDEC-02D 时产出的同名文件**字节一致**（已复核）；
  - `fip_188_cma512_pad.bin` sha1 `b3fda6bb…`（512M 备选）；
  - 回滚件 `fip_desk2.bin` sha1 `8f647cf1…`（现网 256M FIP）。
  - 打包链已复核：`mkuimage.py --pack`（Image 补零到 `image_size=0xAE0000` + 追加 DTB）+ `fip_create`（bl31_smp_fixed + uImage）+ pad 到 `0x5D34*512`。
- **RAM 约束**：板子 1GB；cma=256M 时可用 ~575MB。cma=384M 可用 ~448MB（建议）；**cma=512M 只剩 ~320MB，不建议**。
- **写 eMMC 风险**：现主机 `/dev/ttyUSB0/1` 丢失（无法 RTS/进 U-Boot），若新 FIP 启动失败将无法回滚 ⇒ 建议等串口恢复后：
  ①（最安全）RAM boot 验证（fastboot+tftp，不写 eMMC）→ 确认 `CmaTotal=393216 kB` 且 64MP ×3 PASS；
  ② 再从运行系统 `dd if=fip_188_cma384_pad.bin of=/dev/mmcblk0 bs=512 seek=$((0x7000)) conv=fsync`；③ reboot 复核；失败回滚 `fip_desk2.bin`（同命令）。

## ★★★ task-5 线1 定稿：Adam7 交错（v7 生产版）— PASS 18/18

`hi_png_final_v7.ko` sha1 `a1da46dc…` + `hi_png_hw` `56b019db…`（clean boot `3efc3757`）：

| 图 | 3 次同 boot 解码 | 说明 |
|---|---|---|
| rgb16x16 / rgb33x17 / rgb64x64 / gray17x17 / rgba19x11 | **各 3/3 逐字节一致**（stride-aware 按可见像素） | v6 的"输出错/每次不同"已由 v7 的 dma VA + cache 维护修复 |
| 1920×1080 rgb（×2）/ rgba | CMP_OK（6220800 / 8294400 B） | 交错 1080p ≈ **1193ms / 863ms**（非交错 100ms；240 nodes + 内核拼图） |

- 判据修正：`out.raw` 是 stride 对齐（33→112、17gray→32、19rgba→80），参考是 tight；**必须按行跳过 padding 比较**，
  整文件平铺比较会误判（v6 验收里"NO_OUTPUT"另有一部分是 SSH 掉线，均为无效数据，不作为结论）。
- 待优化（已批准）：① 工具/驱动把输出 stride padding 清零（gray17x17 有 30B 未初始化，整文件 sha1 才稳定）；
  ② 1080p 交错 12× 慢的节点粒度/拼图优化。
- 证据：`ilace-probe-20261110-214416/`（pass 探针 35/35 CMP_OK）、`v7-interlace-20261110-221201/`（COMPARE-STRIDE.md）、
  `ilace-passes3-20261110-215615/`、`ilace-v2-crash/`（探针重复解码 oops 已由 v6 修）。

## ★★★ task-7 TDE 移植 bring-up（进行中，2026-11-10 晚）

| 里程碑 | 结果 |
|---|---|
| `hi_tde.ko` 8cff6e42 | insmod 成功、/dev/hi_tde 建立；tde_test 3/5 通过；**读 /proc/interrupts 会 Oops**（本板已知，禁用） |
| 0a0b997d（IRQ 安全化） | probe：`hwirq=123 virq=59` 映射正确；但 `rmmod` 在 `TdeOsiListTerm` Oops（use-after-free） |
| a2b6608e（cleanup 加固） | probe→rmmod **干净**（`cleanup done`、无 Oops）；正常 insmod 仍 `request_irq(59) ret=-38`（kernel `__setup_irq`: chip==no_irq_chip → -ENOSYS） |
| **efcb5653**（IRQ 候选选择 + Bug A 修复） | **insmod/rmmod/10× 循环全部干净**；IRQ 候选全 `chip=none` ⇒ 安全降级为 load-without-IRQ；tde_test 每项 `0xA064800A = HI_ERR_TDE_JOB_TIMEOUT`（功能被完成等待阻塞，硬件实际执行了 fill）、CLUT8 另见 `0xA0648006 = INVALID_PARA` |

- **IRQ 卡点分析**：本内核 DT **无 TDE 节点**（只有 jpeg@f8c40000 = GIC_SPI 97，GIC=arm,gic-400@f1001000）；
  映射 hwirq123 得到的 virq59 `chip=none` ⇒ 需从 GIC 节点 fwnode 取 GIC domain 再 map，或给 TDE 加 DT 节点；
  否则需在无 IRQ 模式实现轮询完成（`TDE_STA`/`INT`/`INTCLR`）。
- **303c99a9（轮询完成）功能验收**：`tde_test` **6 项里 5 PASS**（QuickFill/QuickCopy/SolidDraw255/Bitblit-ARGB/CLUT8），
  仅 SolidDraw α=128 结果=纯 fg（未与 dst 混合）；`tde_irq_cnt` 由 2ms delayed_work 轮询增长；rmmod/重载/10× 全干净。
- **aae76c5d + tde_test 49c9abb4（终验）**：SolidDraw α=128 经 vendor 代码确认为 **fill-path 语义限制**（fill 不做 dst 混合），
  用例改为 `LIMITATION(recorded)` ⇒ **`TDE_TEST: PASS`（rc=0）**，α 混合能力由 Bitblit(ARGB α) 覆盖；`tde_irq_cnt=6`；rmmod 干净。
- **证据**：`tde-hang-20261110/`（Oops 串口原始日志 + FINDING.md）、`tde-v3-20261110-222854/`、`tde-func-poll-*/`、`tde-final-*/`。

## ★★★ PNG v8（TDE CLUT 硬件化）验收（进行中）

- 交付：`hi_png_final_v8.ko` `fe53fd25…`、`hi_png_hw` `45da4ec5…`（`--clut-hw`，默认 CPU LUT）。
- **加载顺序**：先 `hi_png_final_v8.ko` 再 `hi_tde.ko` **可以**；反过来（先 hi_tde）会让 hi_png_v8 init 失败：
  `kobject_add_internal failed for hi_png_mmz -EEXIST` + `PNGDBG: no dma device` → insmod EPERM。
- **`--clut-hw` 当前失败点**：dmesg `failing symbol_get of non-GPLONLY symbol g_tde_export_funcs`
  ⇒ TDE 侧导出需改 `EXPORT_SYMBOL_GPL(g_tde_export_funcs)`（PNG 用 symbol_get 要求 GPLONLY）；失败时 `state=3/rc=4`。
- 另：`rmmod hi_png`（v8）出现 Segfault（同 TDE 早期 exit 路径问题），需修 exit 清理。
- CPU LUT 基线（pal1/2/4/8 ±tRNS）全部 rc=0 正常（`--clut-hw` 失败不影响默认路径）。

## ★★★ 候选 FIP（cma=384M + TDE DTS 节点）RAM 启动验证（进行中）

- 已按 build_desktop_fip 流程重编 dtb（`hi3798mv300-poc.dts` + TDE 节点 patch 0001，cma 字符串同长度替换 256M→384M），
  **只换 dtb**（Image/内核不变）；FIP pad sha1 **`22af0bf4…`**（uImage 11,414,314B / dtb 10,986B / 总 12,216,320B）。
- eMMC 空闲区（块 `0x20000`=64MB，不碰 active `0x7000`/ubuntu 分区）已写入并回读校验 sha1 一致。
- U-Boot `mmc read 0 0x02000000 0x20000 0x5D34; bootm 0x02000000`：BL31/内核正常启动（串口到 `BL31 Built`），
  板子能 ping，但 **userspace/sshd 4+ 分钟未起来**（未登录）；怀疑 rootfs EXT4 错误触发 fsck（现网 boot 也有
  `EXT4-fs warning: mounting fs with errors, running e2fsck is recommended`）。
- 现网 FIP **未被修改**（cma=256M 正常启动），回滚件 `fip-region.bin`(2dea80c5)/`fip_desk2.bin`/`loady` 在手。
- 下一步：先 e2fsck/确认 rootfs 健康，再重试 RAM boot；或直接把新 FIP 写 active 后重启验证（有串口+loady 恢复通道）。

## ★★★ PNG v9（TDE CLUT 硬件化）验收尝试（2026-11-10 23:02）

- `hi_tde.ko 1e9f72c6…` + `hi_png_final_v9.ko 9dfb96c0…` + `hi_png_hw 45da4ec5…`：
  **顺序 A（tde→png）insmod 均 rc=0**；palette CPU LUT 解码正常（`clut_lut=1 state=2 ms=1.7`，sha1 `cb5c52fa…`）。
- **`rmmod hi_png` 仍 Segfault（139）**：exit 日志 `osi deinit → osires deinit → hal deinit → dma cleanup` 后崩，
  `cleanup_module+0xb4 [hi_png]`，且 `rmmod exited with irqs disabled / preempt_count 2` + `context_tracking WARNING`；
  之后 `hi_tde is in use`、insmod busy，CLUT 对比/回归无法完成。→ 需 v10 修 exit（疑似 dma cleanup 之后在原子上下文 sleep/释放失效地址）。
- 证据：`png-clut-hw-v9-20261110-230223/run.log`。

## ★★★ 候选 FIP（cma=384M + TDE DTS 节点）RAM 启动尝试（2026-11-10 23:00–23:12）

- 构建：仅换 dtb（Image 不变）；两个候选：
  - `fip_tde_cma384_pad.bin` sha1 `22af0bf4…`（cma=384M + TDE 节点）
  - `fip_tde_sh_pad.bin` sha1 `6d148a3e…`（同上 + `init=/bin/sh`）
  均已写 eMMC 空闲块 `0x20000` 并回读 sha1 校验一致。
- U-Boot `mmc read 0 0x02000000 0x20000 0x5D34; bootm 0x02000000`：
  - FIP/BL31 正常（`Load fip ... BL31: Built`、ATAGS、`Start Warm Reseting`）；
  - 不带 init=/bin/sh：板子可 ping（内核网络起来了），但 **userspace/sshd 4+ 分钟未起**；
  - 带 init=/bin/sh：**180s 内无任何 Linux console 输出**（BL31 之后静默）。
  - 现网 boot 有 `EXT4-fs warning: mounting fs with errors, running e2fsck is recommended` —— 但该警告在现网正常启动时也存在，
    尚不能确定为 RAM boot 失败原因；需进一步二分（只加 TDE 节点不改 cma / emergency.target / 检查 BL31 后串口输出）。
- **现网 FIP 未修改**，已回滚到 cma=256M 干净状态（每次尝试后 RTS 复位）。
- 回滚/恢复通道：`fip-region.bin`(2dea80c5) + `fip_desk2.bin`(8f647cf1) + U-Boot `loady`（YMODEM）已验证命令存在。
## ★★★ PNG v10（TDE CLUT）验收（2026-11-10 23:19）

`hi_png_final_v10.ko 136c7559…` + `hi_tde.ko 1e9f72c6…` + `hi_png_hw 45da4ec5…`

| 项 | 结果 |
|---|---|
| ① 隔离 `png_no_tde=1` insmod/rmmod | **PASS**（rmmod=0，日志 `exit: … dma cleanup → before/after symbol release → exit done`，`cleanup: enter→mmz freed→pdev unregister→done`） |
| ② tde→png 加载 | insmod 均 rc=0；但 **CPU LUT 调色板解码 `hi_png_hw` Segfault(139)**，随后内核 **RCU stall**（串口抓到 rcu_sched 栈 dump）→ 系统挂，需 RTS 复位 |
| ③ `--clut-hw` 运行 | rc=0 但**输出错误**：相邻调色板项互换（观察首 8 像素 `070707 000000 151515 0e0e0e`，期望 `000000 070707 0e0e0e 151515`）→ CLUT 表项顺序/格式（2 项步长或字节序）不匹配 |
| ④ 性能 | `--clut-hw` 反而更慢：640×480 11.7–23.7ms（CPU 1.7–2.8ms）；1080p 50.0ms（CPU 28.9ms）——疑似轮询完成 2ms 粒度 + 每 job 开销 |
| ⑤ PNG 回归 | PASS：1080p sha1 `bbac27fa…`；rgb16le rc=0；gray16le rc=0；交错 rgb16x16 rc=0 |
| ⑥ rmmod/10× | 因②崩溃未能完成（仅隔离路径证明 exit 干净） |

证据：`png-clut-hw-v10-20261110-231851/run.log`（含逐步 exit/cleanup 日志与 CLUT 输出 head）。

## ★★★ PNG v11 验收（2026-11-10 23:31）

`hi_png_final_v11.ko 5f978d4f…` + `hi_png_hw 0b5964db…` + `hi_tde.ko 1e9f72c6…`

| 项 | 结果 |
|---|---|
| ① 隔离 `png_no_tde=1` | PASS：pal8 CPU 解码 rc=0；`rmmod hi_png` rc=0，`cleanup … done` / `exit done` 完整 |
| ② v10 回归（TDE 加载后普通 CPU LUT 调色板解码） | **PASS**：pal4 rc=0 `state=2 ms=1.7 clut_lut=1 sha1 cb5c52fa…`、pal8 rc=0 `bb23b7d1…`，不崩不挂 |
| ③ `--clut-hw` | **挂死**：clut4 单例在 `transform=0x200 clut=…` 后 >20s 不返回（timeout 杀掉）；`tde_irq_cnt=0`（轮询完成未触发）；dmesg 有 `WARNING context_tracking.c:107 ct_kernel_exit`；进程留内核态残影 |
| ④ rmmod/10×、CLUT cmp、回归 | 因③中断未完成 |

证据：`png-clut-hw-v11-20261110-233102/run.log`（① ② 与 ③ 挂死现场）。

## ★★★ PNG v12b 验收（2026-11-11 00:00）

`hi_png_final_v12b.ko d034a79c…`（name-based `__symbol_put`）+ `hi_tde.ko 1e9f72c6…` + `hi_png_hw 0b5964db…`

| 项 | 结果 |
|---|---|
| 加载 tde→png | rc=0；CPU LUT pal4 `rc=0 sha1 cb5c52fa…`（v10 回归修复保持） |
| CLUT-HW clut4 | **rc=0**；`CLUT2RGB: tde_open/begin/blit/endjob ret=0`，`ms=88.9` |
| rmmod/10× | **PASS**：`TDE symbol released (name-based)` + `exit done`；`cleanup done`；10× 循环 fails=0 |
| 回归 | 1080p `bbac27fa…`✓、rgb16le `1cc22b76…`、gray16le `586b8240…`、交错 rgb16x16 rc=0 |
| ❌ CLUT 正确性 | **行 0 与 CPU LUT 逐字节一致，行 1 起错位**（cmp 首差 byte 1921；行1 首字节 `1c1c3f3f3f2a…` vs 期望 `070707…`）⇒ TDE CLUT source stride/打包问题 |
| ❌ 1080p palette --clut-hw | **挂死 >10min**（640×480 仅 88.9ms；CPU LUT 28.9ms 正常）⇒ 待 v13 定位 rect/stride/job 完成 |

- 关键修复确认：`g_tde_export_funcs` 是 **data 符号**，`symbol_put_addr()` 对其会 `BUG_ON`（kernel/module/main.c:912 `__module_text_address()` 返回 NULL）；
  v12a 现场抓到 oops（`symbol_put_addr+0x98 ← png_port_tde_get ← PngOsiClutToRgb`），v12b 改 **name-based `__symbol_put("g_tde_export_funcs")`** 后 exit/close 全干净。
- 证据：`png-clut-hw-v12d-*/run.log`、`v12full.log`、`v11-hang-capture-*/capture.log`（v11 的 oops 现场）。

## ★★★ PNG v13 最终验收（2026-11-11 00:15）

`hi_png_final_v13.ko 6470ac28…` + 工具 `hi_png_hw 040ee9f7…` + `hi_tde.ko 1e9f72c6…`

| 项 | 结果 |
|---|---|
| 加载 tde→png | rc=0；CPU LUT 8×palette 全 rc=0（pal4 `cb5c52fa…` 不变） |
| ❌ CLUT-HW（8 palette + 1080p） | **全部 hw_rc=4 / state=3**，无 oops、无挂死；dmesg 只到布局行，之后无 job/expand 日志：`src(phy… stride=320 fmt=27 640x480) tmp(phy stride=1920) dst(stride=1920 fmt=7)` ⇒ job1（索引重排）失败待定位（工具输出分配已正确：bytes=921600/6220800、out stride=1920/5760） |
| rmmod/10× | PASS：`exit done` + `cleanup done`，10× fails=0 |
| PNG 回归 | PASS：1080p `bbac27fa…`、rgb16le `1cc22b76…`、gray16le `586b8240…`、交错 5 图全 rc=0（各自 sha1 不同） |
| 64MP | 工具 CMA 预算检查：need 221MB > CmaFree 45MB → rc=7、未分配（正确防护；clean boot 后 64MP 曾 PASS） |

- 工具已按 `out_stride=ALIGN16(w*out_bpp)` 分配输出并清 padding（与 CPU LUT 输出尺寸一致）。
- 证据：`png-clut-hw-v13-*/run.log`。

## ★★★ PNG v14 验收（2026-11-11 00:15）

`hi_png_final_v14.ko d01f7dc9…` + 工具 v1.7 `0306c0fb…` + `hi_tde.ko 1e9f72c6…`

| 项 | 结果 |
|---|---|
| 机制 | **全通**：`CLUT2RGB: src(stride=320 fmt=27) tmp(stride=1920) dst(stride=1920 fmt=7 bpp=3)`，`job1/job2 begin/blit/endjob rc=0`，`expand done`，hw_rc=0 |
| ❌ 颜色 | **pal8 对照也错**：CPU `00 00 00 07 07 07 0e 0e 0e…` → HW `00 00 00 31 31 31 62 62 62 93…`（0x31=7*7、0x62=7*14）＝**查表索引×7**；clut4 HW 乱序+大量 0 |
| 工具对照 | 旧工具 `040ee9f7` 跑 pal8 得到**完全相同**的 `31 31 31/62 62 62` ⇒ 问题在 **v14 驱动 job1 CLUT 查表**（表项步长/索引或 `TdeOsiSetClutOpt` 语义），非工具子字节重排（pal8 无子字节） |
| 结论 | v12b in-place 路径 pal8 行0 正确、v14 换 job1 后错 ⇒ 请查 v14 job1 的 CLUT phys/offset/entry stride 与 bClutReload/alpha 字段 |

- **环境事故**：板卡 rootfs 97% 满 + EXT4 坏位图 → 磁盘文件被截断（hi_tde.ko 变 0B、PNG 头损坏）；改用 **/dev/shm** 部署全部测试件后恢复稳定。
- 证据：`png-clut-hw-v14b-*/run.log`（A/B hex+dmesg）。

## ★★★ PNG v15 / v15b（TDE CLUT 颜色扩展）验收（2026-11-11 00:25）

模块 `hi_png_final_v15.ko d1975921…`（job2 清空 CLUT 表 → 纯 RGB copy，修 v14 二次查表）+ `hi_tde.ko 1e9f72c6…`

| 工具/项 | 结果 |
|---|---|
| **v1.7 `0306c0fb`：pal8** | **MATCH（bit-exact）✅** —— TDE CLUT 颜色扩展链路首次逐字节一致（`00 00 00 07 07 07 0e…`） |
| v1.7：clut1 / clut2 / clut4 | DIFF，模式分别 = i^1 交换 / reverse_4 / i^1 交换（即子字节索引需重排） |
| v1.8 `040ee9f7`：clut1 | DIFF：`reverse_8(1)=4` 超出 2 项调色板 → 取 0；**bd1 应为 reverse_2（i^1）** |
| v1.8：clut2 | 行 0 正确、行 1 起错（DIFF@1921）→ 疑 bd2 source stride/打包不一致 |
| v1.8：clut4 | **挂死整板 → 30s 看门狗重启**（boot_id b46667ff→70fd9721）→ bd4 表重排在 v15 驱动下不安全 |

- 兜底方案（建议）：PNG 侧先把 bd1/2/4 解包成 8bit 索引 → 走已验证 MATCH 的 CLUT8 路径（代价小、风险最低）。
- 环境：已删 `/root/hwtest`（153MB，host 有副本）→ `df` 94%（409MB 余）；`/root/fw` 794MB 系**其它流水线** FIP 试验件，未动。
- 证据：`png-clut-hw-v15-*/run.log`（pal8 MATCH）、`png-clut-hw-v15b-*/run.log`（子字节 diff 与挂死前现场）。

## ★★★ PNG × TDE 最终验收（v15 模块 + tool v1.9）— 矩阵全绿（2026-11-11 00:45）

`hi_png_final_v15.ko d1975921…` + `hi_png_hw 4d4ed71a…`（`--clut-hw` 仅 bd8 走 TDE，bd1/2/4 回退 CPU LUT）+ `hi_tde.ko 1e9f72c6…`
clean boot / /dev/shm 部署（rootfs 不写盘）：

| 项 | 结果 |
|---|---|
| 调色板 8 用例（pal1/2/4/8 ±tRNS，rgb24/rgba8） | **MATCH 8/8**（bd1/2/4 `CPU LUT fallback` 日志存在、字节一致；bd8 走 TDE） |
| 1080p clut8 `--clut-hw`（TDE） | **MATCH**；CPU 28.9ms vs TDE 203.5ms |
| 640×480 耗时 | CPU 1.7–2.8ms；TDE(bd8) 158.9 / 162.1ms（含 job1+job2 与轮询完成） |
| rmmod/10× | `exit done` + `cleanup done`；10× 循环 fails=0 |
| PNG 回归 | 1080p `bbac27fa…`✓、rgb16le `1cc22b76…`、gray16le `586b8240…`、交错 5 图全 rc=0（sha1 各自不同） |
| 64MP | 本 boot CmaFree 163MB < 工具预算 221MB → rc=7 提前拒绝（正确防护）；clean-boot 64MP 已在 v4/v7 验收记录 |

- 结论：**PNG 调色板 → TDE CLUT 硬件化验收通过**（bd8 真实硬件、子字节正确性优先回退 CPU；子字节 HW 化解包列为 r4 后增强）。
- 证据：`png-clut-hw-v15c-final-*/run.log`（含 manifest、palette matrix、rmmod/10×、回归）。

## ★★★ r4 发布包上板验收（2026-11-11 00:42）

包：`dist/hi-accel-r4-20261111.tar.gz` sha1 **`06c91ffc…`**（最终重发版；旧 b84ffc8b/92ed981b 作废。payload 与之前一致，仅修 install.sh 引号 bug）

| 项 | 结果 |
|---|---|
| 安装（06c91ffc 新包） | 载荷+脚本安装成功（中途一次板卡网络 reset 打断，重连后状态已验证）；`--verify` rc=0 全 OK |
| `/etc/hi-accel.conf` | 含 `HI_LOAD_TDE=1` / `HI_TDE_KO=hi_tde.ko`（conf 合并生效） |
| `/run/hi-accel/status` | `state=PASS`，6 模块：`hi_mmz_shim/hi_tde/hi_vdec/hi_venc/hi_jpeg/hi_png` 全 ok，nodes 含 `/dev/hi_tde` |
| 板上 sha1 | `hi_tde.ko 1e9f72c6…`、`hi_png_reload.ko d1975921…`、`hi_png_hw 4d4ed71a…`、`tde_test 49c9abb4…`（与 manifest 一致） |
| `tde_test` | **TDE_TEST: PASS**（含 documented LIMITATION） |
| 1080p PNG | rc=0，sha1 `bbac27fa931a…` |
| pal8 `--clut-hw` cmp | **PAL8_MATCH** |
| `systemctl restart hi-accel` | 再次 `state=PASS` |
| `df -h /` | 408MB 余（94%） |

- **包缺陷（需重发）**：`scripts/install.sh` 第 106 行 conf 合并循环里 `sed -n '...\(...\)...'` 的**内层单引号**嵌在远端单引号字符串中 → 远端 bash 报 `syntax error near unexpected token '('`，install rc=2。
  修复：把该 sed 程序改用双引号（`sed -n "s/^\([A-Z_][A-Z0-9_]*\)=.*/\1/p" ...`）。本地已按此 patch 后安装成功。
- **64MP**：本次多次 clean-boot 后 CmaFree 仅 165–177MB（< 工具预算 221MB）→ `rc=7` 提前拒绝（防护正确）；64MP PASS 记录仍在 v4/v7（cma=256M clean boot 时 CmaFree 243MB、sha1=参考）。建议 r4 后增强（cma=384M FIP）或冷启动后补跑。
- `systemctl restart hi-accel` 后 `state=PASS`（要求满足）；但**紧接着跑 `tde_test` 会稳定复现挂死→看门狗重启**（fresh boot 直接 tde_test 则 PASS）⇒ r4 后稳定性项：查 hi-accel restart 与 TDE 轮询/作业队列交互。
- 证据：`r4-install-final-*/`（install2.log、SUMMARY.md、tde_test.log、1080.log、pal8.log、64mp*.log、64mp-cleanboot.log）。

## ★★★ task-8 reload 稳定性 / r5b(v16b) 验证（2026-11-11 01:15）

| 项 | 结果 |
|---|---|
| r4 问题定位 | `hi-accel.service` ExecStop **漏 `rmmod hi_tde`** → restart 后 TDE 旧实例存活、其余模块重载 → 后续 tde_test 挂死（r4 10× 循环第 4–5 次挂） |
| r5(v16) 问题 | v16 在 insmod 时读 **clock-gated TDE 寄存器** → 总线 Oops（`pc readl+0x4 ← port_stubs_init`）→ `hi_tde=insmod_fail`、`/dev/hi_tde` 缺失 |
| r5b(v16b) | insmod Oops **修复**（recover 默认 0、不读 TDE 窗口；`tde_regs_dbg` 显式开关）；restart 后 `state=PASS`、`/dev/hi_tde`、`tde_test` PASS、`tde_irq_cnt=6`、`tde_poll_ticks` 400–4000 |
| 10× restart+tde_test | **iter1–6 PASS，iter6 挂死 → 看门狗重启**（boot 34a039c8→fbc01e6b）⇒ 仍未稳定；怀疑反复 load/unload 的 TDE 资源回收（chrdev major 243/247 变化、poll work、MMZ/dma device、CRG37 reset） |
| r5b 安装 | install.sh 全流程多次撞板卡网络 reset；用**手动 payload patch**（v16b ko + manifest + service）达到等效状态验证 |
| 待办 | v16c/r5c 修 reload 泄漏；A1 子字节矩阵+B0 耗时（件已备）；64MP clean-boot；rootfs 摸底 |

- 证据：`r5b-install-final-20261111-010857/`（loop10b.log 逐轮、SUMMARY.md）。

## ★★★ task-8 / r5c(v16c) reload 稳定性（2026-11-11 01:30）

| 项 | 结果 |
|---|---|
| v16c 修复确认 | 部署校验 `4f2492af…`；每轮 reload dmesg 顺序：`cleanup: poll stopped → cleanup done → init done (poll started)`（poll/cancel 时序修复生效） |
| 10× restart+tde_test | iter1–4 PASS（state PASS、TDE_TEST PASS、irq=6）；**iter5 restart warmup 36.2s 后 tde_test 挂死 → 看门狗重启**（iter6–8 不可达，iter9 fresh boot） |
| **CMA 泄漏（新发现）** | 纯 restart 10 次：CmaFree 245MB→~150MB（≈9–10MB/次）；warmup 变慢疑与此相关，也解释 64MP 在多次 restart 后 rc=7 |
| 串口证据 | 本轮不可用：`/dev/ttyUSB0 device reports ... multiple access/disconnected`（USB 串口抖动）→ 下次需独占抓 watchdog 前输出 |
| 64MP clean-boot | fresh boot 时 CmaFree 245MB 可跑，但 restart 后 150–163MB < 221MB ⇒ rc=7；需"零 restart"fresh boot 或 cma=384M |
| rootfs 摸底 | `busybox`✓；`e2fsck/fsck.ext4/debugfs/dumpe2fs`✓（动态 aarch64，依赖 libext2fs 等）；`/boot` 空、无 initrd；`loady` 可用 ⇒ rescue 方案：tmpfs pivot + 拷工具，或 loady 静态 busybox initramfs（推荐） |

- 证据：`r5c-install-final-20261111-011850/`（loop10e.log、SUMMARY.md）。

## ★★★ task-8 归因：tde-only reload 复现挂死（2026-11-11 01:42）

fresh boot（CmaFree=245496kB）+ /dev/shm 部署，`diag-reload-cma.sh tde-only`（v16d `2425b727…` + tde_test `49c9abb4…`）：

| 轮次 | 结果 |
|---|---|
| iter1–5 | `tde_test rc=0`（TDE_TEST PASS）；CmaFree 245496→245472kB（**无 CMA 泄漏**）；poll_ticks 17–18；dmesg：`cleanup: poll stopped → cleanup done (tde mmz live entries=0 bytes=131072)` |
| iter6 | **板子无响应（ssh banner timeout）→ 看门狗重启** |

- 结论：①TDE 自身不泄漏 CMA；②**TDE 单模块 reload+job 约第 6 轮即挂死** ⇒ 与 VDEC warmup/CMA 泄漏非必要相关，问题在 TDE reload 后状态；③`cleanup` 时 `live bytes=131072` 与 `entries=0` 并存，记账/128KB mempool 残留待查。
- 未跑：`service-nowarm` / `service` 对照（tde-only 已复现挂死，需每次复位）。
- 证据：`cma-diag-*/`（tde-only.log、SUMMARY.md）。

## ★★★ r5d(v16e) 验证：recover=2 回归（2026-11-11 01:55）

- v16e `7227d8a1…`：`tde_recover` 默认 2（CRG37 pulse + 时钟窗口内写 INTCLR/CTRL/AQ_NADDR）。
- `diag-reload-cma.sh tde-only`：**iter1 rc=0**（cleanup entries=0 bytes=131072）→ **iter2 insmod Segmentation fault（内核 oops）→ 板子重启**。
- 快速 A/B：`tde_recover=0` ×3 insmod rc=0 无 crash；`tde_recover=2` → 连接 reset（复现崩溃）⇒ **recover=2 写 TDE 窗口/CRG37 脉冲路径不安全**。
- v16d 时实验 A（只 insmod/rmmod ×10，不跑 job）**不挂** ⇒ 挂死需要"job 执行 + reload"组合；B/C 待 v16f（默认 recover=0）再跑。
- 建议 v16f：默认 recover=0；recover=2 改为显式实验参数并修写路径（CRG37 读回确认/加延时/用 CTRL soft-reset 位）；修正 bytes 记账。
- 证据：`r5d-*/`（tde-only-v16e.log、recover-ab.log、SUMMARY.md）。

## ★★★ r5f(v16f) 实验：**不 reload、重复 tde_test 也挂**（2026-11-11 02:10）

- v16f `a8735fac…`（默认 recover=0）经 **HI_DIR=/dev/shm/m2（tmpfs）** 由 service 加载（rootfs 写 ko 会被 EXT4 坏位图损坏：v16f 拷到 /root/m2 后 sha1 变 `4f0d686a`）。
- **实验 B（单加载、不 reload）**：
  - `tde_test #1` → rc=0 PASS，`job_done=6 irq=6 poll_ticks=852`，CmaFree 174024→175824kB
  - `tde_test #2` → ssh 超时、板子无响应（看门狗复位）
  ⇒ **挂死不需要 reload**；同一实例重复 tde_test 即挂 ⇒ 指向按 job/测试累积的 TDE 资源或硬件状态（mempool job/node 槽位、MMZ 表项、INT/AQ），而非 reload 竞态/poll worker。
- 环境问题：①rootfs 写 ko 损坏（须用 tmpfs HI_DIR 做诊断）；②手动 shim 环境 `tde_test FAIL alloc dst`（/dev/hi_mmz 缺失、DPARMS phys2va fail）不作为结论。
- C（irq_off reload+job）与 recover=0/1 对照未完成（每次挂死需复位）。
- 板卡已恢复 r5c 磁盘状态（v16c 4f2492af、HI_DIR=/root/m2、HI_WARMUP=1）state=PASS。
- 证据：`r5f-*/SUMMARY.md`。

## ★★★ r5g(v16g) 回归 + v16f poll 速率证据（2026-11-11 02:30）

- **v16f（`a8735fac…`）**：tmpfs HI_DIR 单实例 → `tde_test #1 PASS`、重测第 2 次也 PASS（挂死间歇性）；
  `tde_test #1` 后 idle 4s：`poll_ticks 4439→4619`（2s 增长 180 ≈ 90–100 ticks/s，而 `tde_poll_ms=2` 名义 ~500/s）
  ⇒ **空闲时每次 poll 周期 ~10ms（clock-gated readl 停等）**，与"读未使能 TDE 寄存器导致 stall"假设一致（但未完全卡死）。
  job 期间 dmesg：`poll status=00000001 cnt=N` + `poll completion ran`（INT 状态一直为 1）。
- **v16g（`33e79275…`）回归**：service 加载后 PASS、/dev/hi_tde 正常，但 **`tde_test #1` 直接 rc=124 挂死**；
  `poll_ticks=3`、随后 P1=P2=3（**GROWTH=0，poll worker 完全不 tick**）→ 板子看门狗重启。
  ⇒ `tde_port_clock_on()` 很可能恒 false → poll 每次直接 return、job 永不完成。建议 v16h：
  ①有 active/pending job 时 poll 必须跑；②clock_on 只影响"是否读 INT"，读失败默认照常完成 job；③打印 clock_on/pending/active。
- 环境：tmpfs HI_DIR 规避 rootfs 写坏 ko；串口本轮再次不可用（ttyUSB0 多 access/disconnected）。
- 板卡已恢复 r5c 磁盘状态（v16c 4f2492af、HI_DIR=/root/m2）：state=PASS。
- 证据：`r5g-*/SUMMARY.md`、`tde-jobstate-*/`。

## ★★★ r5h(v16h) 验证：首次 tde_test 即挂（2026-11-11 02:22）

- v16h `1f9d2d6a…` 经 tmpfs HI_DIR 由 service 加载：`state=PASS`、`/dev/hi_tde` 正常。
- 但 **`tde_test #1` 就挂死**（2 次尝试：一次 host ssh 240s 超时、一次 ssh 直接断开；两次板子都看门狗重启，boot id 变化）。
- 串口仍不可用（ttyUSB0 multiple access/disconnected），未抓到 watchdog 前 dmesg/stack。
- 对比：v16f 首次可 PASS（间歇问题）；v16g 首次挂（poll_ticks 冻在 3）；v16h 仍首次挂 ⇒ 建议回退 v16f 基线，仅在 poll 读 INT 前加 clock_on 判断（完成链/锁永远执行），避免 v16g/v16h 的重构风险。
- 现象规律：v16f 空闲 poll 速率 ~90–100 ticks/s（clock-gated readl 停等）；v16g/v16h 完成链被饿死（首 job 不完成）。
- 证据：`r5h-*/`（single10.log、hang-capture.log）。

## ★★★ r5i(v16i) 验证：job 完成链从未触发（2026-11-11 02:30）

- v16i `77db7df9…` 经 tmpfs HI_DIR 由 service 加载：state=PASS、/dev/hi_tde 正常；**本次板子未挂死/未重启**。
- 单加载 `tde_test` ×10：**10/10 rc=124（30s 超时）**，`tde_job_done=0`、`tde_irq_cnt=0`（无任何 job 完成）；
  `tde_poll_ticks` 持续增长（≈100 ticks/s）⇒ poll 一直在 `active==0` 空闲快路径，从不调 `tde_poll_complete()`。
- 结论：v16i 的 `tde_poll_active` 门控未生效（poll 看不到置 1 / 过早清 0 / 不同副本）；建议 volatile/barrier、置位点覆盖 END_JOB、poll 每 tick 打印 active/pending 值。
- 故障形态从 v16h 的"首测挂板"变为"job 永不完成"——更接近修复，仅剩 active 门控逻辑。
- 证据：`r5i-*/`（single10.log 含 H1–H9 全部 rc=124 与参数）、`r5g-*`、`r5h-*`。

## ★★★ r5j(v16j) 验证：首测硬挂（active 生效但读 gated INT 卡死）（2026-11-11 02:35）

- v16j `7a14ed87…` tmpfs HI_DIR 加载 PASS、/dev/hi_tde 正常；板端 `/root/t16j.log` **只有 "start"**：
  第 1 次 tde_test 连 30s 超时都未返回（D 态，timeout 杀不掉）→ 看门狗重启（boot 7d435312→e5c1ebb0）。
- 对比 v16i（10/10 rc=124 但板不挂）：v16j 的完整 cmd 比较生效 ⇒ active=1 被 poll 看到 ⇒ poll 进入 active 路径
  **读 clock-gated TDE INT 寄存器** → readl 硬停等/持锁 → 整板 hang；"active>3s 保险"无效（卡在 readl 内）。
- 结论：需**job 在途期间保持 TDE 时钟开启**（job 提交前写 CRG37 bit0=1，完成/idle 后再关；或常开），
  这样 poll INT 读始终在时钟开启态、不会 stall；空闲时也不再读寄存器。
- 证据：`r5j-*/`（single10.log、log-fetch.log）、`r5i-*`、`r5h-*`、`r5g-*`、`tde-jobstate-*`。

## ★★★★ task-8 闭环：r5k(v16k) 三项核心测试全绿（2026-11-11 02:45）

根因链（task-8 全过程）：r4 ExecStop 漏 rmmod hi_tde → v16 insmod 读 clock-gated 寄存器 Oops → v16b 安全化但空闲 poll 每 2ms 读 gated 寄存器（~100 ticks/s 停等）→ v16c poll/cancel UAF → v16e recover=2 写窗口 Oops → v16f 间歇挂（job+reload）→ v16g/v16h 完成链饿死 → **v16i `u8Cmd` vs 完整 cmd 编码比较错误（active 永不置 1）** → v16j active 生效但 poll 读 gated INT 硬停等整板 → **v16k（keep_clock=1：HAL 空闲关时钟 no-op + init/job/poll 前强制开时钟 CRG37 回读确认）全绿**。

| 测试（tmpfs HI_DIR，tde_dbg=1） | 结果 |
|---|---|
| ① 单加载 tde_test ×10 | **10/10 PASS**（job_done 6→60、clock_on_cnt=1、`active=1 (cmd=…)`/`job done`/`poll completion ran`） |
| ② tde-only reload ×10（带 shim，每次 tde_test） | **10/10 PASS**（cleanup `entries=0 bytes=0`、`TDE clock off`→`forced on (CRG37=11 cnt=1)`；v16f 时第 6 轮挂） |
| ③ service 10× restart + 立即 tde_test | **10/10 PASS**（每次 restart=0、tde_rc=0、state=PASS、/dev/hi_tde） |

- 环境：全程 `HI_DIR=/dev/shm/m2`（tmpfs）规避 rootfs 写坏 ko；重启后需重新部署；正式磁盘安装需 rootfs 修复或过渡方案。
- 证据：`r5k-*/`（single10.log、reload-proper.log、reload10.log、service10.log）。

## ★★★ r5+A1/B0（PNG v16 + tool A1 + TDE v16k）：CLUT-HW 全部超时（2026-11-11 02:55）

- 部署：tmpfs；PNG v16 `8d4dc2c0…`、tool A1 `17812593…`、TDE v16k `9f1347fb…`（keep_clock=1）。
- **A1 调色板矩阵 0/8**：8 个用例全部 `hw_rc=4`（CPU LUT rc=0 正常）；hw_ms ≈2110ms。
- B0 1080p clut8：`hw_rc=4`（cpu 28.9ms / hw 2157ms）。
- dmesg：`job1 begin rc=0 (4us)` → `job1 blit rc=0 (9689us)` → **`job1 endjob rc=-1604026358 (endjob ~2.02s)` = HI_ERR_TDE_JOB_TIMEOUT**。
- 根因推断：v16k 的 `tde_poll_active` 只在 **ioctl 层**置 1；PNG 在内核直接调 TDE API（不经 ioctl）⇒ active 永不置位 ⇒ poll 空闲快路径 ⇒ PNG CLUT job 不完成。用户态 tde_test 因此全绿而 PNG CLUT 全挂。
- 修复方向：active 置位下移到内核 job 提交/等待公共路径（TdeHalNodeExecute/TdeOsiListWaitForDone），ioctl 保留。
- 证据：`r5k-*/a1b0.log`。

## ★★★ r5 收尾批：B0/64MP/install 绿、A1 待驱动侧 unpack（2026-11-11 02:50）

| 项 | 结果 |
|---|---|
| A1（PNG v16 8d4dc2c0 + tool A1b 49c6d1a5 + TDE v16l cd6b1b7e） | **2/8**：clut8/clut8t MATCH；clut1/2/4 ±tRNS DIFF（HW 索引恒 0；hw_unpack=1；src stride=640 正确）；A1b 仅换 tool 无变化 ⇒ 疑 `GRAY124TO8+ADJUSTPIXELORDER` 需加在**驱动** `hipng_do_expand()` 而非 tool |
| B0 1080p clut8 | **MATCH**（cpu 28.9ms / hw 185.9ms；temp 8.7ms、job1 blit 9.7/endjob 25.2ms、job2 blit 9.7/endjob 25.3ms） |
| 64MP clean-boot（HI_WARMUP=0、CmaFree 245,624kB） | **3/3 PASS**：rc=0、decode 3056.8/3057.0/3057.0ms、sha1 `d0ce2b24…`=ffmpeg 参考、解码后 CmaFree 243,224kB（无泄漏） |
| r5 install/verify（tmpfs HI_DIR） | rc=0、state=PASS、warmup=ok(3856ms)、6 模块、/dev/hi_tde |
| warmup=skip 原因 | tmpfs 手工部署缺 `vdec_spec_hevc_head`/`ht1080b.hevc` ⇒ load.sh verify() 失败即 skip；r5 包安装后恢复 |
| v16l 不回归 | tde_test ×10 10/10；service 10× restart+tde_test 10/10 |

- 证据：`a1-b0-*/`、`64mp-clean-*/`、`r5-install-final-*/`、`r5m-*/`。

## ★★★ r6 最终交付确认（2026-11-11 03:00）

r6 `dbab333d…`（TDE v16l `cd6b1b7e` + PNG v15 `d1975921` + tool v1.9 `4d4ed71a` + vdec/venc/jpeg/mmz），tmpfs HI_DIR：

| 项 | 结果 |
|---|---|
| install（tmpfs 等效） | rc=0、state=PASS、warmup=ok(3851ms)、6 模块、/dev/hi_tde、tde_test PASS |
| pal8 `--clut-hw` | clut8-640x480 rgb24 **MATCH**（2.8 vs 122.3ms）；clut8t rgba8 **MATCH**（2.8 vs 136.3ms）；clut8-1920x1080 rgb24 **MATCH**（28.9 vs 168.1ms） |
| 1080p PNG 解码 | sha1 `bbac27fa931a5cdf90654a92454fe1bb3ccddd29`（期望值）、path=hw、97.8ms |
| tde_test ×10 | 10/10 PASS |
| service 10× restart + tde_test | 10/10 PASS |
| CLUT2RGB | job1/job2 endjob rc=0（v16l 对 PNG 内核直调路径生效） |

**A1 最终决定**：bd1/2/4 保持 CPU LUT（bit-exact，非解码回退），`--clut-hw` 仅 bd8 走 TDE；A1b 无效属 vendor palette-unpack 语义限制（negative result 已记录）。B2 ABI 扩展不做（temp+job2 ≈18%）。

**维护窗口事项**：FIP（cma=384M + TDE DTS 节点/真实 IRQ）、rootfs e2fsck（当前全 tmpfs HI_DIR 过渡，磁盘安装待修复）。证据：`r6-final-*/`。

## ★★★ P0 rescue 摸底 + A2 上板（2026-11-11 03:05）

**U-Boot（Fastboot 3.3.0-dirty, Oct 31 2026）交互通道确认**
- 复位时打印 **"Press Ctrl+C to stop autoboot"**；长按 Ctrl+C 进入 **`fastboot#`** prompt（已实测执行命令后 reset 回 Linux）。
- `help bootm`：标准 U-Boot bootm，**支持 `bootm [addr [arg ...]]`，arg=initrd 地址** ✓；无 `booti`；无 `run`/`boot`（退出用 `reset`）。
- 可用：`loady/loadb`、`mmc read/write`、`fatload/fatls`、`tftp/bootp`、`usb/usbboot`、`setenv/saveenv`、`reset`、`go`、`md/mw`、`crc32`、`unzip`。
- env：`bootdelay=1`；`bootcmd=mmc read 0 0x1FFAE30 0x7000 0x5D34; bootm 0x1FFAE30`；bootargs 出厂值（root=/dev/mmcblk0p7，实际 cmdline 由 FIP DTB 提供）；ver=Fastboot 3.3.0-dirty。
- **无 USB fastboot/gadget**（板无 /sys/class/udc；host lsusb 仅 CH340/FT232）；**无 kexec**；串口 Linux 侧稳定。
- 现网启动镜像 @0x7000 = **ATF FIP**（magic 0xAA640001+uuid），整段 0x5D34 块 sha1 `2dea80c5…`（= 回滚件）；已备份 host `rootfs-rescue-*/fip-current-0x7000.bin`。
- eMMC 空闲区：FIP 0x7000..0xCD34，ubuntu block 0x97000 起 ⇒ 空闲块 0xCD34..0x96FFF（≈276MB）；0x20000 起可用。
- rescue initramfs host 件：`work/rescue/rescue-initramfs.cpio.gz` 2.55MB sha1 `84e2097e…`。
- 救援路径：A) eMMC 空闲区 dd kernel uImage+initramfs → Ctrl+C → `mmc read` → `bootm <k> <i>`（快）；B) `loady` 零写入（~20–25min）；C) tftp（需网口/同网段）。

**A2 上板（PNG v17 eb55009a + tool A2 fd7b63cc + TDE v16l）**
- sub-byte `--clut-hw` 全部 hw_rc=4；dmesg：`A2: strip GRAY124TO8/ADJUST ...` → `CLUT2RGB: tde_begin ret=0` → `PNGDBG: TDE symbol released`（错误退出），**无 `A2: unpack ... us`/job1 日志** ⇒ 失败在 tde_begin 后、unpack/job1 前（temp alloc/ioremap/stride 校验）。
- pal8 640/1080p MATCH、1080p PNG `bbac27fa…`、tde_test ×10、service 10× 全绿。
- 证据：`a2-clut-*/`、`rootfs-rescue-*/`。

## ★★★★ A2 修复版全绿 + rootfs 救援阻塞（2026-11-11 05:30）

**A2（PNG v17 `74f9c681` + tool A2 `fd7b63cc` + TDE v16l `cd6b1b7e`，tmpfs HI_DIR）**
- ioremap(RAM) → **phys_to_virt + dma_sync** 方案成功；clut1/1t/2/2t/4/4t/8/8t **8/8 MATCH**；
- dmesg：`A2: linear map` → `A2: unpack bd=1/2/4 (51.4–52.0ms)` → `hw_unpack=2` → job1/job2 endjob rc=0 → expand done；
- pal8 640/1080p MATCH、1080p PNG `bbac27fa…` 不回归；
- **性能**：A2 解包 ~51ms + hw 总 ~250ms vs CPU LUT 15ms ⇒ **bd<8 保持 CPU LUT**（A2 作为正确性备选，不默认启用）。

**rootfs 救援现状（fsck 仍未执行，rootfs/FIP 未改动）**
- 生产内核 **CONFIG_BLK_DEV_INITRD 未启用**（build_desktop_fip.sh 显式 -d）⇒ 现有内核无法使用 initramfs。
- 已重建 BLK_DEV_INITRD=y 的 Image（11,018,248B）+ 含 chosen initrd 的 DTB；uImage sha `b8899d52…`；**仅写入 eMMC 空闲区**：initramfs@0x2A000、uImage@0x2C000、FIP@0x30000（现网 FIP@0x7000/rootfs 未动）。
- U-Boot：Ctrl+C→`fastboot#` 可用（已验证 `printenv/help bootm/mmc read/loady` 等）；但 Fastboot bootm 的 arm64 路径走 **ATAGS/生成 DTB**，嵌入 DTB 的 chosen initrd 不被内核看到（无 Unpacking initramfs）；FIP 路径在 BL31 banner 后 hang（BL31 sha 与生产相同，差异在 BL33 处理）。
- pivot_root 救援：pivot 成功（tmpfs 新根、oldroot 惰性卸载），但 e2fsck 报 `/dev/mmcblk0p1 is in use`（其它 namespace 引用）⇒ 无法 fsck。
- 建议下一步：重建内核时 **CONFIG_INITRAMFS_SOURCE=<rescue.cpio.gz>** 内置 rescue initramfs（不依赖 bootloader 传 initrd/DTB），uImage 写入空闲区后 `bootm` 直接跑 rescue /init → e2fsck。
- 证据：`rootfs-fsck-*/`、`a2-clut-*/`。

## ★★★ fsck 救援进度（2026-11-11 06:10，未完成）

- 生产内核 **CONFIG_BLK_DEV_INITRD 未启用**（build_desktop_fip.sh 中 `-d BLK_DEV_INITRD`）⇒ 现有内核无法用 initramfs。
- 已用生产 .config 重建：`CONFIG_BLK_DEV_INITRD=y` + `CONFIG_INITRAMFS_SOURCE=work/rescue/rescue-initramfs.cpio`，
  Image 13,508,616B（cpio @0x7764A8，build log `GZIP usr/initramfs_inc_data`）；uImage（lead 打包 sha `0471bbdd…`，16,788,114B=0x8017 块）
  **写入 eMMC 空闲区 0x40000 并回读 sha1 校验 ✓**（现网 FIP@0x7000/rootfs 未动）。
- **阻塞**：U-Boot `Ctrl+C` 停 autoboot 成功率约 50%（成功时 mmc read/bootm 正常；失败直接进 Linux）；多次重试未命中，
  fsck 尚未执行、rootfs 未修改。
- 下一步（待 lead 选）：① 写 U-Boot env bootcmd（先备份，fsck 后回写）自动进 rescue；② 人工 U-Boot 交互；③ 改 bootdelay。
- 证据：`rootfs-fsck-*/`（serial-fsck-embedded*.log、rescue-uImage-initramfs.bin、SUMMARY.md）。

## ★★★ fsck：env bootcmd 机制验证 + 交接（2026-11-11 06:50）

- **env CRC 算法验证**：env 区（0x100000，64KB）前 4B = **小端 CRC32(data[4:65536])** ✓。
- **env 备份**：host/板 `/dev/shm/env-backup-64k.bin` sha1 `712af710…`（原 bootcmd=`mmc read 0 0x1FFAE30 0x7000 0x5D34; bootm 0x1FFAE30`）。
- **env 写/恢复链路实测 OK**：改 bootcmd 后 reset 自动执行 `mmc read`+`bootm`；崩溃后已恢复原 env 并回读 sha1 校验（bootcmd 复原）。
- **教训**：uImage 必须用 **pad 版**（payload pad 到 0x1000000、DTB@+0x1000000）；**未 pad 的 13.5MB Image 在 bootm 时 DTB 地址推算错乱 → data abort → 复位循环**。
- **交接状态**：lead 接手 env 改写/串口；eMMC 0x40000 曾被我的 unpadded `67b213ff…` 覆盖，需重写 padded `0471bbdd…`（0x8017 块）后再改 env。rootfs/FIP 未动；fsck 未执行。
- 证据：`rootfs-fsck-*/`（env-backup-64k.bin、env-new-64k.bin、rescue-uImage-envrestore.bin、serial-fsck-final.log、SUMMARY.md）。

## 0. 板上环境事实

- `hi-accel.service` 开机 insmod `hi_mmz_shim + hi_vdec + hi_venc + hi_jpeg + hi_png_reload.ko`
  （`hi_png_reload.ko` sha1 `4551b6e1` 与 `/home/jason/bringup-7.3/port/png` 当前源码重建一致），只跑 1080p HEVC 预热，**不做 PNG 解码**。
- 实验流程：`systemctl stop hi-accel.service` → rmmod 全部 `hi_*` →（可选）insmod `hi_mmz_shim` + 待测模块 → 单次解码。
- 硬件看门狗 `sp805-wdt`（30s，systemd 喂狗）：PNG 块挂死时可能把整板复位（见 §2）。

## 1. 关键寄存器基线（本栈，可复现）

| 项 | 值 | 说明 |
|---|---|---|
| `Type`(0x10) | `0x208` | BitDepth=8, ColorFmt=2(RGB), interlace=0 |
| `Size`(0x0c) | `0x07800438`(1920×1080) / `0x0780000f`(1920×15) | Height[12:0], Width[28:16] |
| `BitBufSt/End`(0x20/0x24) | 流缓冲基址 .. +size-1 | **HAL `PNG_BUF_DEFAULTSIZE=128KB`**（<128KB 的 AllocBuf 按 128KB 计，非 bug） |
| `BitStreamSt/End`(0x28/0x2c) | 流缓冲基址 .. +StreamLen-1 | |
| `FinalSt`(0x4c) / `FinalEnd`(0x50) | 输出 MMZ / **0（驱动从不写 0x50）** | 0x54 是 Reserved3（`PNG_HAL_REGISTER_S` 顺序） |
| `RdcSt`(0x80) | 模块 init 分配，**32KB** | `PNG_RDCBUF_SIZE`；内容=解压后(滤波前)数据 |
| `FltSt/End`(0x88/0x8c) | 每次解码分配，**rowbytes（16 对齐）** | 1920 RGB→5760B=1 行；**内容=最后一次解码出的一行"未滤波"像素**（stall 后残留） |
| `AXIConfig`(0x90) / `TimeOut`(0x94) | vendor `0x20441` / `0x80008` | **AXI=0 是打通的关键**；TimeOut 回读被硬件钳到 `0x03ff03ff`（两个 10bit 域：`[9:0]`、`[25:16]`） |
| `IntMask`(0x104)/`ErrMode`(0x108) | `ffff0003`/`ffff0000` | bit0=Finish, bit1=Resume, bit2=Error; bits16–31=具体错误 |
| `Int`(0x100) bits | bit0=DecFinish, bit1=DecResume, bit2=DecError | |
| `ErrStatics`(0x10c) | TotalIdatNums[7:0]/ErrIdatNums[15:8] | 失败样本恒 0；g15 成功时 =0x1 |
| `RstBusy`(0x110) | 解码中 1 | **start 时就是 1，正常"忙"标志，不是异常** |
| 未定义 word | 0x114 (~60MHz 自由计数器) / 0x118=0xc00 恒定 / 0x11c | 无行计数寄存器 |

## 2. 实验矩阵（一实验一 clean boot）

### 2.1 复现与定位（vendor AXI 配置）

| # | 实验 | 输入 / 传输 | 结果 | 结论 |
|---|---|---|---|---|
| 01 | baseline 历史配方 | t1080，7×32KB 段，png-inst，stride 5760 | **行 0–14 逐字节全对，行 15–1079 全 0**；Int=0（0 中断）；ErrStatics=0；start→timeout 已定义寄存器 0 变化；RstBusy=1；BitBuf 头 256B 与原始 IDAT 流完全一致（无写回） | 复现历史 head-only 签名；硬件静默挂起（无中断/无错误位/busy 不回） |
| 04 | **1920×15 小图** | grad-1920x15（filter=0，6832B 单段） | **FULL_EXACT：15 行全对，rc=0，state=2，5.66ms**；ISR cnt1=Int0x2(RESUME)→cnt2=Int0x1(FINISH)，间隔 0.03ms；ErrStatics=0x1 | 15 行本身可完整解出；RESUME=“本段/本窗口吃完，需要续传” |
| 15 | 1920×16 | grad-1920x16 | **FULL_EXACT 16 行，rc=0，state=2** | “15/16 行 band 限制”被排除 |
| 30 | 1920×17 | grad-1920x17 | **FULL_EXACT 17 行，rc=0，state=2** | 同上 |
| 02 | 1080p solid | solid-1080(filter=up，8517B 单段) | **23 行**后停（Int=0，ErrStatics=0，超时）；FLT=最后写出的行 | 与码流大小无关（8.5KB 也停）；行数随内容变 |
| 17 | 1080p filter=2 | grad-1080-f2（10228B 单段） | **26 行**后停（Int=0，ErrStatics=0） | 同上；停点非行数/非压缩偏移（898B/207B/885B 各不相同） |
| 16 | 1080p filter=0 单段 | grad-1080-f0（154802B） | **整板 WDT 复位 2/2**（out.raw 未写出，卡在 Decode 内） | vendor AXI 配置下大码流单段会把系统拖死 |
| 35 | 1080p filter=0 分段 | 同图 7×32KB | **整板 WDT 复位**（同样在 Decode 内） | 分段也救不了；与 filter=0/长匹配相关 |
| 46 | TimeOut 单独改 | t1080 分段，TimeOut=0x7fffffff，AXI=0x20441 | 仍 15 行超时 | **TimeOut 不是根因** |
| **45** | **AXIConfig=0** | t1080 分段，AXI=0，TimeOut=0x7fffffff | **FULL_EXACT 1080 行，sha1=bbac27fa…=参考，100.66ms；ISR 7×RESUME+1×FINISH** | **整幅打通；根因=AxiConfig** |

### 2.2 其它证据

- **deflate 块边界**（主机 `zlib Z_BLOCK` 解析）：
  t1080 块边界 in=2,621,1206,1589,1851…；solid in=116,205,296…；f2 in=758,858,959…。
  失败停点（in≈898/207/885）**不在**块边界上，也不对应固定字节/固定符号数 ⇒ “deflate 块边界/固定输入窗口”假设排除。
- **FLT 残留内容**：17-f2-1080 的 `out.raw.flt` 等于“未滤波像素行 22/23/24/25”（渐变图中相同行），
  说明硬件已完整写出最后一行并把重建行留在 FLT 后再不前进。
- **无写回**：`out.raw.bb_head`/`bs_head` 与工具 memcpy 进去的 IDAT 流头 256B 完全一致（ndiff=0）；
  hardware 不修改码流/BitBuf 区域（BitBuf 与 BitStream 同址的“写回破坏码流”假设不成立）。
- **/proc/interrupts 是雷**：PNG 解码后读 `/proc/interrupts` 会 uninterruptible 挂死 SSH（曾致整板失联）。
  实验台改为只用 dmesg（`png_isr cnt/Int`）+ `/dev/mem` 寄存器读取。
- **board_ctl**：WDT 复位后偶发一次 RTS 脉冲不回来，实验台已加重试（`lib.sh do_reboot`）。

## 3. 实验台（work/png-hw/board/）

| 文件 | 作用 |
|---|---|
| `run_exp.sh <exp>` | reboot→ensure ssh→停 hi-accel→部署→单/多次解码→串口捕获→抓 dmesg/寄存器/内存→回传→逐行比对→SUMMARY；含复位检测与硬超时 |
| `exp/*.sh` | 每实验声明（图/参考/module/params/env/stride） |
| `tool/png_ctl.c` | png_test8 能力 + `PNG_SINGLE/CHUNK/ALIGNED/IEND/STRIDE/BSYNC` + `/dev/mem` 全 0x120 寄存器 + RDC/FLT/BitBuf harvest + **bSync=0 时间-行数曲线/ResumeStart pulse** 模式 |
| `src/mkvariants.py` + `build_all.sh` | 从 `png-base`(4551b6e1) 生成/构建驱动变体（inst/err0/intmask0/pass0/axi0/timeoutto/h16/finalend*/flt*/rdc64/bitbuf*） |
| `gen_png.py` / `compare_raw.py` / `regdecode.py` / `analyze_run.py` | 合成 PNG+RGB24 参考 / 逐行逐字节比对 / 寄存器解码 / 单实验汇总 |
| 产物 | `artifacts/<variant>/hi_png.ko` + `SHA1SUMS`；`docs/porting/artifacts/png-hw/<exp>/` |

## 4. 剩余/未覆盖项（非阻塞）

1. **性能**：`hi_png`/`hi_png_hw` 入口端到端 ~1.0s（工具自报 ms≈777@1080p；1×1/16×8 也要 220–260ms），
   直接 `png_ctl` 解码 ~100ms ⇒ 生产工具有 ~220ms 固定 + ~500ms@1080p 的额外开销，待 code-arch 定位
   （正确性无影响）。硬件解码本身：1080p ~100ms、64MP ~3.1s。
2. **`hi_png_hw` v1.1 palette 回归**：palette bd=1/2/4 输出错误（gray1/2/4 已修好）；**v1.0 的 palette 是正确的**，
   建议回退 v1.0 软件 bit-unpack，只对 gray 用 ADJUSTPIXELORDER，等 v1.2 后复验（见格式矩阵节）。
3. **Adam7 interlace**：`hi_png_hw` 明确返回 3 拒绝；驱动 Pass0–6 未实现（驱动侧需求，非本次修复范围）。
4. **AXI 位扫描**（`61-axicfg-*`，定最小安全值/性能值）未完成；当前发布值 AXI=0 已在全部验收用例通过。
5. **r3 重打包后**需按新包做一次"安装 + hi_png 一次"快速校验（等 code-arch v1.2 + lead 重打）。
