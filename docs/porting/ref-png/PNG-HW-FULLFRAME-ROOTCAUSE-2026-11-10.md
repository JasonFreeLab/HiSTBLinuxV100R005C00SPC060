# PNG 全硬件整幅解码：根因与修复（Hi3798MV300 / #188，2026-11-10）

> 结论先行：**PNG 全硬件整幅解码已打通**。根因是驱动把 `u32AXIConfig`(0x90) 写成 vendor 的"建议值" `0x20441`；
> 在 Hi3798MV300 mainline 移植环境下该值使 PNGD 在约 15 行输出后**静默挂起**（无中断、无错误位）。
> 改为 `0x0` 后 1920×1080 PNG 整幅输出与 ffmpeg RGB24 **逐字节完全一致**（`FULL_EXACT=True`），
> 100–106 ms，`Decode rc=0 / state=FINISH`，中断序列 = 7×RESUME（逐段续传）+ 1×FINISH。
> 不需要任何软件解码兜底。
>
> 关联：`BOARD-EXPERIMENTS.md`（实验矩阵）、`CODE-ANALYSIS.md`（代码考古/§11 根因）、
> `REF-ARCHAEOLOGY.md`（原厂固件/SDK 交叉验证）、`work/png-hw/code/final/`（最终补丁与模块）。

## 1. 症状（修复前）

| 项 | 值 |
|---|---|
| 输入 | 1920×1080 RGB8 PNG（t1080.png，215,688 B；IDAT-only 组帧 215,622 B） |
| 现象 | 输出前 **15 行**逐字节正确，第 15 行起全 0；`Decode rc=-2147483635`（2 s 等待超时）、`state=3(ERR)` |
| 中断 | **全程 0 次**（无 FINISH/RESUME/ERR）；`Int`、`IntMask`、`ErrMode`、`ErrStatics` 均无变化 |
| 寄存器 | StartDecode 与 timeout 快照逐 word 比对：**已定义寄存器 0 变化**；`RstBusy(0x110)=1`（正常忙） |
| 数据 | FLT(0x88) 缓冲内容 = 参考图第 14 行（5760/5760 字节），即硬件完成第 15 行后停在第 16 行入口 |
| 码流 | 停点仅消耗约 898–991 B 压缩数据（deflate 首块边界在 compressed_in=12,216，排除块边界触发） |
| 边界 | 停点行数随内容变化：照片 15 行、纯色(filter=up) 23 行、渐变(filter=2) 26 行 ⇒ 不是固定行数/固定字节数，而是 AXI 事务侧的挂起 |
| 风险 | 单段大窗口（215 KB）解码会把整板总线拖死（WDT 30 s 复位）；分段（32 KB）只静默停住 |

历史结论 PNG-08（硬件整幅 = NA）因此**作废**：当时把"15 行静默停止"归因为 vendor 私有流控不可突破，
实际是 AXI 端口配置错误。

## 2. 根因

- `source/msp/drv/png/src/png_hal.c` 的 `PngHalOpen()` / `PngHalSetAxiAndTimeout()` 写：
  `u32AXIConfig = 0x20441`（头文件注释 "Suggest value is 0x20441"）。
- `ref/` 下全部历史 SDK（V100R005C00SPC050、V100R006C00SPC050、Android V600R001C00SPC065、本地 SPC060）
  都是同一常量、无 per-chip 变体 ⇒ 它是**调优建议值，不是硬件必需值**。
- 该值在 vendor 参考 NoC/QoS 配置下调出；本 mainline 移植（SMMU 全 bypass、mainline 7.3）不适用，
  PNGD 的 AXI 主口在 ~1 KB 码流后挂在未完成 AXI 事务上：无中断、无错误位、`RstBusy` 保持 1。
- 决定性对照（同一模块、同一图、同一分段）：
  - `u32AXIConfig=0x20441` + `TimeOut=0x7fffffff` → 仍 15 行（`46-timeoutto`）⇒ **不是 TimeOut**；
  - `u32AXIConfig=0x0` + `TimeOut=0x80008`（vendor 默认）→ **整幅 1080/1080 bit-exact**（`57-axi0-tmo8`）。
- 旁证：同族 JPEGD 有专门的 4K/16M DDR 边界计数器（`JPGD_REG_AXI4KCNT 0x11C` / `AXI16MCNT 0x120`），
  说明该 GFX 家族 AXI 主口对 DDR 边界/突发敏感；AXI 配置寄存器无公开位定义，结论以实测为准。

## 3. 修复（v4 最终补丁）

补丁（均对 git HEAD 原始源码生成，`patch -p1` 可复现）：
- SDK：`work/png-hw/code/final/SDK-FINAL-FIX-v4.patch`（已应用到本仓库 `source/msp/drv/png`）
- 板上构建树：`work/png-hw/code/final/PORT-FINAL-FIX-v4.patch`（`/home/jason/bringup-7.3/port/png`）

| # | 文件 | 改动 | 归类 |
|---|---|---|---|
| 1 | `png_hal.c` | **`u32AXIConfig` 0x20441 → 0x0**（`PngHalOpen()` 与 `PngHalSetAxiAndTimeout()`），含根因注释 | 根因修复（必需） |
| 2 | `png_hal.c/h` | 新增 `PngHalGetIntRaw/PngHalGetErrStatics/PngHalErrNames` 只读辅助 | 诊断 |
| 3 | `png_osi.c` | ISR 处理 `Int bits16..31` 具体错误位（FmtBuf/FltBuf/RdcBuf/FltType/DecCpy/HuffDec/Zlib*/Adler/Crc）：打印错误名+`ErrStatics` 并立即置 ERR，不再"静默超时" | 通用健壮性 |
| 4 | `png_osi.c`（SDK） | 同步等待 2 s → 模块参数 `png_wait_ms`（默认 10000 ms；64MP 需 ~3.1 s） | 通用健壮性 |
| 5 | port 树 `png_osi.c` | 轮询兜底判 FINISH 后不再误判超时（`s32Ret<=0 && FINISH!=eState` 才走超时分支）；打印 `poll finish` | mainline 适配 bugfix（v4 关键） |
| 6 | port 树 `png_osi.c` | ISR FINISH 默认不再拆除时钟/复位（`png_clkoff_on_finish=1` 可 A/B 旧行为） | mainline 适配 |
| 7 | `png_hal.c` | `PngHalReset()` 不再用门控期间读回的 0 值恢复 `IntMask/ErrMode/AXI/TMO`（Open 随后显式写全） | 通用健壮性 |
| 8 | `png_hal.c` | `PngHalStartDecode()` 启动前清残留 INT（非 0 打印）；SetClock(TRUE) RstBusy 超时告警 | 诊断/健壮性 |

> 最终模块：`hi_png_final_v5.ko`（sha1 `a47b509a8200cb4e2b915f347e2f799cf2409759`；干净 `port/png` + v5 补丁可逐字节复现）。
> `u32TimeOut` 保持 vendor 默认 `0x80008` 不变（根因对照已证明 TimeOut 不是主因）。

## 4. 验证（关键用例，板上 #188，最终模块 `hi_png_final_v5.ko` sha1 `a47b509a…`）

| # | 用例 | 条件 | 结果 |
|---|---|---|---|
| 62 | **1080p RGB8 整幅** | AXI=0 + TMO=0x80008，7×32KB 节点链 | `rc=0` / `state=2(FINISH)` / **100.74 ms**；6,220,800 B 与 ffmpeg RGB24 逐字节一致（sha1 `bbac27fa…`，SHA1_MATCH=True）；1080/1080 行 EXACT；ISR = 7×RESUME + 1×FINISH |
| 64 | **1080p 单段 215,622 B**（修复前此路径会拖死整板/WDT） | 同上，单段 | `rc=0` / FINISH / 99.77 ms / 逐字节一致 |
| 65 | **64MP 8000×8000 RGB（192 MB 输出）** | 47×128 KB 节点链，`png_wait_ms=10000` | `rc=0` / FINISH / **3,105.28 ms**；板端 out.raw sha1 `d0ce2b24…` = 主机 ffmpeg RGB24 参考 sha1；47×RESUME + 1×FINISH |
| 46 | **根因对照**：vendor AXI 值 | AXI=0x20441 + TMO=0x7fffffff | 仅 15 行、2 s 超时、`Int=0` ⇒ 排除 TimeOut、锁定 AXI 配置 |
| 45/57/58 | AXI=0 复现性 | 多次 clean boot | 均 FINISH、逐字节一致（100–106 ms） |
| 15/16/17 | 小图回归（<8 KB 流） | 修复前后 | 均整幅 FINISH，修复不破坏小图路径 |
| 77/78/79/86/88 | **v4/v5 复跑** | 1080p chunked / 单段 / 64MP | 全部 `rc=0`/FINISH/bit-exact：**101.2 / 99.5 / 3,099–3,103 ms**（v5 1080p 104 ms） |
| 87/redecode-isolated | **同 boot 连续 3 次** | v4/v5 | **3/3 PASS**，每次 1080/1080 行逐字节一致（v5：101.8 / 276.2 / 280.4 ms） |
| 71 | 格式：RGB8 640×480 | `hi_png_hw --outfmt rgb24` | FULL_EXACT（480/480 行） |
| 72 | 格式：RGBA8 640×480 | `hi_png_hw --outfmt rgba8` | FULL_EXACT |
| 73 | 格式：Gray8 640×480 | `hi_png_hw --outfmt gray8` | FULL_EXACT |
| 74 | 格式：调色板 8bit 640×480 | `hi_png_hw --outfmt rgb24`（CLUT 查表） | FULL_EXACT |
| 66/67 | 早期 stride 探针（非规范输出格式） | — | 仅作探索；规范格式验收见 71–74 |

（完整矩阵：`BOARD-EXPERIMENTS.md` 与 `artifacts/png-hw/<exp>/`。）

### 4.0 发布包部署验收（r3，按 install.sh 安装 + clean boot）

| 项 | 结果 |
|---|---|
| `install.sh ... --payload ./payload --enable --start` | 载荷 13 项 sha1 全 OK；`/run/hi-accel/status` **state=PASS fail=0**；hi_mmz_shim/hi_vdec/hi_venc/hi_jpeg/hi_png 全部 loaded；节点 `/dev/hi_mmz /dev/hi_png /dev/hi_vdec /dev/hi_venc` |
| 服务开机加载 | clean boot 后 `hi_png_reload.ko` sha1 = `a47b509a…`（v5）；`hi_png t1080.png` → `path=hw rc=0`，输出 sha1 `bbac27fa…` = ffmpeg 参考 |
| 入口 `hi_png --mode hw` / `hi_png`(auto) | 均 `path=hw`、`rc=0`、输出与参考逐字节一致；端到端 **431 ms**（v5 静默后；驱动解码 98 ms、写回 136 ms、节点分配 ~7 ms） |
| **无软件兜底验证** | 移除硬件可用性（rmmod/hide hi_png_hw）后 `hi_png` → `path=none rc=3`，**不产生任何软件解码输出**；恢复后正常 |

### 4.1 修复前后对照（同一图/同一驱动栈）

| 项 | 修复前（AXI=0x20441） | 修复后（AXI=0） |
|---|---|---|
| Decode 返回 | `rc=0x8000000D`（超时） | **`rc=0`** |
| state | 3 (ERR) | **2 (FINISH)** |
| 输出 | 行 0–14 正确，其余全 0 | **整幅、逐字节 bit-exact** |
| 中断 | 0 次（静默挂起） | 7×RESUME + 1×FINISH |
| 单段 215 KB | 整板 AXI 挂死 → WDT 复位 | 正常 99.77 ms |
| 1080p 耗时 | 2 s 超时 | **~100 ms** |
| 64MP | 不可达 | **3.1 s，bit-exact** |

## 5. 覆盖范围与限制（最终口径）

硬件 PNGD（`/dev/hi_png`）寄存器能力：GRAY 1/2/4/8/16、RGB 8/16、AGRAY 8/16、ARGB 8/16、CLUT 1/2/4/8；
transform：1/2/4bit 像素序、PACKBYTE、GRAY→BGR、ADDALPHA、STRIPALPHA、BGR2RGB、SWAPALPHA、16→8、8→4、
tRNS 透明色、premultiply alpha；宽高 13 bit（≤8191）；Adam7 interlace 有 Pass0–6 地址/stride 寄存器。

实现/验收口径：
- **全硬件**：inflate + 反滤波 + 上述 transform 全部由 PNGD 完成；
- **调色板/CLUT**：PNGD 解出 packed 索引，软件按 PNG 规范 MSB-first 解包后查 PLTE/tRNS（1/2/4/8bit 全验证）
  （TDE 未移植；这属于格式转换，不是解码兜底）；
- **interlace**：驱动当前固定 `InterlaceType=0` 且从不配置 Pass0–6，硬件的 7 pass 是否自行合并未证实；
  interlace 输入按"不支持"显式失败（不做软件兜底），后续如需要单独立项；
- 64MP 级大图需放宽驱动 2 s 等待（`png_wait_ms`，默认已 10 s）并确认 MMZ 容量（≥256 MB 余量）。

### 5.1 格式覆盖（板上逐字节验证，`hi_png_hw` v1.1）

| 输入格式 | 验收输出 | 结果 |
|---|---|---|
| RGB8 | rgb24 | ✅ FULL_EXACT（640×480；1921×1080 非 16 对齐宽亦 PASS） |
| RGBA8 | rgba8 | ✅ FULL_EXACT |
| GRAY8 | gray8 | ✅ FULL_EXACT |
| RGB16 | rgb48（**大端字节序**） | ✅ 与 ffmpeg `rgb48be` 逐字节一致 |
| GRAY16 | gray16（**大端字节序**） | ✅ 与 ffmpeg `gray16be` 逐字节一致 |
| GRAY 1/2/4 | gray8 | ✅ FULL_EXACT（`GRAY124TO8+ADJUSTPIXELORDER`，`--expand accurate`；v1.1 修复半字节序） |
| PALETTE 8 / PALETTE2+tRNS | rgb24 / rgba8 | ✅ FULL_EXACT（硬件索引 + PLTE/tRNS 查表） |
| PALETTE 1/2/4 | rgb24 / rgba8 | ✅ FULL_EXACT（硬件解出 packed 索引，软件按 PNG 规范 MSB-first 解包 + PLTE/tRNS 查表；pal1/2/4/pal4_trns CMP_OK） |
| RGBA16 | rgba8 | ✅ 与 libpng `strip-16`（取高 8 位）逐字节一致；ffmpeg 用四舍五入会 ±1（口径差异，非失败） |
| 尺寸 1×1 / 17×17 / 640×480 / 1920×1080 / 1921×1080（非 16 对齐）/ 8000×8000 | — | ✅ |
| Adam7 interlace | — | ❌ 明确拒绝（退出码 3），不软件兜底 |

> 说明：16bit 输出为**大端**（硬件 PNGD 的字节序），与 ffmpeg `rgb48be/gray16be` 对齐；若产品要小端需调用方自行换序。

## 6. 复现与部署

```
# 主机：应用补丁到 SDK（或直接用 work/png-hw/code/final/sdk-src 覆盖后构建）
cd <SDK> && patch -p1 < work/png-hw/code/final/SDK-FINAL-FIX.patch
# 构建 hi_png_reload.ko（Kbuild 参考 /home/jason/bringup-7.3/port/png）
# 板卡：
insmod hi_mmz_shim.ko; insmod hi_png_reload.ko
/usr/local/bin/hi_png --mode hw in.png out.raw   # 无软件兜底
```

证据目录：`docs/porting/artifacts/png-hw/{45-axi0to,57-axi0-tmo8,46-timeoutto,01-baseline,...}/`
（`compare.txt`、`out.raw`、`dmesg*.log`、`SUMMARY.md`、`harness.log`、`boot_id.txt`）。

## 7. 同 boot 多次解码（v4）

修复 AXI 后，同 boot 第 2 次解码**硬件输出仍逐字节全对**，但驱动报 `rc=0x8000000D / state=3`。
根因是 port 构建树为 mainline "level IRQ 偶发丢失"加的 10 ms 分片轮询兜底：

```c
while (wait_ms < png_wait_ms) {
    s32Ret = PNG_WAIT_EVENT_INTERRUPTIBLE_TIMEOUT(..., 10ms);
    if (s32Ret > 0) break;
    PngOsiPollStatus(pstInstance);          /* 可能在此把 eState 置 FINISH */
    if (HI_PNG_STATE_DECING != pstInstance->eState) break;
    wait_ms += 10;
}
if (s32Ret <= 0) { ... eState = ERR; return HI_ERR_PNG_INTERRUPT; }  /* BUG */
```

轮询先判定 FINISH 时 `s32Ret` 仍为 0 → 出口把 FINISH 改写成 ERR。v4 改为
`if ((s32Ret <= 0) && (HI_PNG_STATE_FINISH != eState))` 才走超时分支，并打印
`poll finish (FINISH seen by poll, irq missed)`；同时 v3 起 ISR FINISH 默认不再拆除时钟/复位
（`png_clkoff_on_finish=1` 可 A/B 旧行为），Reset 不再用门控期间的读回值恢复
`IntMask/ErrMode/AXI/TMO`，StartDecode 前清残留 INT。

该问题在 v4 修复（`hi_png_final_v4.ko` `d75f2781…`），最终 v5 模块（`a47b509a…`，含日志静默）沿用；
可用干净 `port/png` + `PORT-FINAL-FIX-v5.patch` 逐字节复现。

### 7.1 生产静默（v5）

调试打印（每解码 ~30 行 `PNGDBG`，115200 串口每行 5–10 ms）曾造成 150–250 ms 固定开销；
v5 增加 `png_dbg`（默认 0）gated 全部热路径打印、保留错误路径，`png_dbg=1` 可完整复现旧日志。
效果：1080p `decode` 98.2 ms（`--timing`）、1×1/17×17 decode 0.1 ms、`hi_png` 入口 1.0 s → **431 ms**。

## 8. 交付物与部署

| 产物 | 位置 / sha1 |
|---|---|
| SDK 源补丁（`source/msp/drv/png`，已应用） | `work/png-hw/code/final/SDK-FINAL-FIX-v5.patch`（与 v4 字节相同 `0a065bb6…`） |
| 板上构建树补丁（`/home/jason/bringup-7.3/port/png`） | `work/png-hw/code/final/PORT-FINAL-FIX-v5.patch`（`9af6bdc3…`，含 v5 日志静默） |
| 最终驱动模块 | `work/png-hw/code/final/hi_png_final_v5.ko` / `a47b509a8200cb4e2b915f347e2f799cf2409759` |
| 生产工具（HW-only，v1.2） | `work/png-hw/code/out/hi_png_hw` / `eebc802a87b5e688daf69b60cbbe65863a2ea7b9` |
| 发布包 | `dist/hi-accel-r3-20261110.tar.gz`（sha1 `c6fee5cdfa86a44795f9d867d4de9d77c354c69e`；payload：`hi_png_reload.ko`=v5 模块 `a47b509a…`、`hi_png_hw`=v1.2 `eebc802a…`；入口脚本 sha1 `197df0c2…`） |
| 入口脚本 | `tools/deploy/hi-accel/hi_png`（auto/hw=硬件、无软解兜底；sw 仅诊断） |

部署：按 `dist/hi-accel-r3-20261110` 的 `install.sh` 安装（或同步 `/root/m2` + `/etc/hi-accel.manifest` 后
`systemctl restart hi-accel`），`hi-accel.service` 开机加载 `hi_png_reload.ko`（v5，sha1 校验）；
调用 `hi_png in.png out.raw`（默认 `--mode auto` → 硬件）。

### 8.1 模块参数（诊断用）

| 参数 | 默认 | 说明 |
|---|---|---|
| `png_wait_ms` | 10000 | 同步解码等待预算（64MP 需 >3 s；2 s 会误杀 64MP） |
| `png_clkoff_on_finish` | 0 | 1 = 恢复旧行为（FINISH 时关时钟），仅 A/B 用 |
| `png_dbg` | 0 | 1 = 恢复全部调试打印（生产默认静默；调试打印曾造成 ~150–250 ms/次固定开销） |
