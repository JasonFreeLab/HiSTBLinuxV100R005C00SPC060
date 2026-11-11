# PNGD（Hi3798MV300, `0xf8c70000`）整幅不可达的代码考古与可证伪根因清单

- 任务：T2（code-arch）；写范围：本文件 + `work/png-hw/code/**`
- 输入源码：`source/msp/drv/png/{src,include}`、`source/msp/api/png/{include,png-hal/src_hard}`、
  `source/component/png`（libpng 1.6.32 补丁版）、`sample/png/sample_png.c`（GBK）、
  `ref/HiSTBLinuxV100R005C00SPC050`（同代 SPC050 参考驱动）、`ref/HiSTBLinuxV100R006C00SPC050`（另一代芯片，仅参考）
- 输入证据：`docs/porting/artifacts/hwtest-2026-11-07/fixes/png-01/{FIX-REPORT.md,E0-BOARD.log,E0-VERIFY.md}`
  + `spec-acceptance/round143…round172` + `fixes/png-06/PNG-06-RELOAD-2026-11-10.md` + `fixes/png-08/PNG-08-SPIKE-2026-11-10.md`
- 板卡侧证据（本轮 Lead 复核）：IDAT-only 流、单缓冲 215,622 B、stride 7680、1920×1080 RGB8：
  **行 0–14 逐字节正确，行 15 起硬件未写（全 0）**；15 行 = 86,400 输出字节，只对应
  **约 898–991 B zlib 输入**（IDAT 全长 214,986 B，deflate 首块边界在 compressed_in=12,216/第 519 行）
  → 停止点不是 deflate 块边界、不是 IDAT 边界、不是缓冲链/段耗尽；`Decode rc=0x8000000D`
  （`HI_ERR_PNG_INTERRUPT`，2 s 等待超时）、`state=3`（`HI_PNG_STATE_ERR`）。
- 交付物：本文件 + `work/png-hw/code/out/`（6 个可上板 `.ko`、aarch64 静态工具 `png_hwprobe`、
  每个变体的独立 diff、sha1/ELF 校验）+ `work/png-hw/code/patches/`。

---

## 0. 结论摘要（先看这里）

> **2026-11-10 16:00 根因已确认（v3，最终）**：`u32AXIConfig(0x90)=0x20441` 这个 vendor "建议值"在
> 本 Hi3798MV300 mainline 移植环境会让 PNGD 在约 1 KB 码流/固定时长后**静默挂在未完成的 AXI 事务**上
> （无中断、无错误位、RstBusy=1）。改为 `u32AXIConfig=0` 后：1920×1080 **全幅硬件解码成功**
> （rc=0、state=FINISH、~100.66 ms、out.raw 与 ffmpeg RGB24 逐字节一致、ISR 7×RESUME+1×FINISH）。
> 只改 TimeOut（AXI 仍 0x20441）仍 15 行 ⇒ 决定因素是 AXIConfig。最终补丁与模块见
> `work/png-hw/code/final/`（`hi_png_axifix.ko` / `SDK-FINAL-FIX.patch` / `PORT-FINAL-FIX.patch`），
> 全格式覆盖矩阵见 `work/png-hw/code/final/COVERAGE-MATRIX.md`，根因/机理详见 **§11**。

1. **`head-only + 15 行` 与"码流分段/链式/末段/IEND"无关**：15 行只吃掉约 1 KB 压缩数据，
   而首段窗口是 32 KB（链式）或 215,622 B（单缓冲）——`BitStreamEnd` 远未到达。
   因此 `DecResume(Int=2)` 不是"本段消费完，请给下一段"，而是**更早的 re-arm 请求**（见 §4）。
2. 厂商驱动在 `RESUME` 分支只在"存在下一节点"时切节点 + `u32ResumeStart=1`；
   **没有下一节点时不做任何事**（不改寄存器、不 pulse）→ 硬件停等 → 2 s 超时。
   这是 `rc=0x8000000D / state=3` 的直接来源（`png_osi.c: PngOsiIntHandle`）。
3. 厂商 ISR **只判 bit2（`PNG_INT_ERR_MASK=0x4`）**，而 `PNG_INT_U` 的 bits16–31 才是
   具体错误状态（FmtBuf/FltBuf/RdcBuf/FltType/DecCpy/Huff/Zlib*/Adler/Crc）；
   `PngHalGetIntStatus()` 在 ISR 里已经把状态清掉 → 若硬件报的是 bits16–31，
   现象正是"**静默停止 + Int=0 + 无错误可见 + 超时 state=3**"。这是目前**信息量最大的未知**，
   已做成 P0 诊断件直接打印。
4. 数据通路/缓冲/寄存器时序、全部隐含假设与 off-by-one 见 §1/§2；候选根因（≥10，按可能性）
   与可证伪预测见 §3；`RESUME≈1 KB 内部 bit buffer` 假设的论证与反驳见 §4；
   Lead 指定的 a–f 代码疑点逐条结论见 §5；vendor 原生意图路径（libpng+`png_accelerate.c`）
   为什么**同样整幅不可达且会把失败掩盖成软解**见 §6。
5. 已产出可上板件（`work/png-hw/code/out/`）：P0 诊断基线 + P1 pulse + P2a 独立 BitBuf +
   P2b 码流窗口前移 + P3a `FinalEndAddr` + P3c FLT 多行，共 6 个 `.ko`；以及不依赖 vendor 库、
   无软解回退的 `png_hwprobe` aarch64 静态工具。**基线重建 sha1 = `4551b6e1…`，与板上
   `hi_png_reload.ko` 完全一致**，证明变体与基线同源。

> **2026-11-10 15:30 更新（v2，重要）**：board-eng 实测 **1920×15 图 rc=0/state=FINISH/5.66 ms/
> 86,400 B 整幅成功**；1080 行图停在"写完 15 行、FLT=第 14 行、无 IRQ、RstBusy=1、无错误位"。
> `15=16−1` 直接支持"**16 行 band**"：band 边界处硬件把 inflate 上下文存回 RDC(32 KB=zlib window)
> 与位残余(BitBuf) 并等待 `ResumeStart`。据此新增 **V1/V1a/V3/V8、V2 抓取工具**（共 10 个 `.ko`），
> 见 §10；§3/§8 的排序以 §10 为准。

---

## 1. 数据通路与调用/寄存器时序

### 1.1 分层与调用链（用户态 → 寄存器）

```
app / libpng(HIPNG_ACCELERATE) / png_test8
        │  HI_PNG_Open / CreateDecoder
        ▼
source/msp/api/png/png-hal/src_hard/hi_png_api.c   （用户态薄封装，只做 malloc/flush/ioctl）
        │  ioctl /dev/hi_png : PNG_CREATE_DECODER / PNG_ALLOC_BUF /
        │  PNG_SET_STREAMLEN / PNG_DECODE / PNG_GET_DECRESULT / PNG_DESTROY_DECODER
        ▼
source/msp/drv/png/src/png_osr.c      （file_ops + ioctl 分发；ISR png_isr）
        │  PngOsiCreateDecoder / PngOsiAllocBuf / PngOsiSetStreamLen /
        │  PngOsiDecode(阻塞 2s) / PngOsiIntHandle(ISR) / PngOsiGetResult
        ▼
source/msp/drv/png/src/png_osi.c      （实例/状态机/缓冲链表/中断处理）
        │  ↑ 每实例 PNG_INSTANCE_S + semaphore stInstanceLock；全局 g_DevMutex 串行化解码
        ▼
source/msp/drv/png/src/png_hal.c      （纯寄存器 R/W，volatile struct 映射 0xf8c70000, size 0x120）
        │
        ▼
PNGD @ 0xf8c70000（GIC SPI 96 / 主线上手工 fwspec 映射；CRG: PERI_CRG33/CRG210）
```

### 1.2 完整时序（以 `png_test8`/`png_hwprobe` 的 IDAT-only 单缓冲或分段链为例）

```
Open:        HI_PNG_Open()        → png_open → PngOsiOpen（仅取 TDE 导出函数 / 引用计数）
Create:      PNG_CREATE_DECODER   → PngOsiResAllocHandle（1..16，sema_init=1，eState=0 NOSTART）
AllocBuf ×N: PNG_ALLOC_BUF        → PngOsiAllocBuf
               · 对齐 (size+0xf)&~0xf；用户态 hi_png_api.c 强制最小 128 KB
               · 每个节点 = 内核 PNG_BUF_HEAD_S{u32NextPhyaddr,u32BufSize,u32StreamLen}
               · 首节点记 u32StartBufPhyAddr/pStartBufVir，其余串成单链表
SetStreamLen×N: PNG_SET_STREAMLEN → PngOsiSetStreamLen（要求 eState==NOSTART）
               · 只登记 u32StreamLen（≤u32BufSize），不碰硬件
（用户态 HI_PNG_Decode 前：HI_GFX_Flush 各节点或 kernel DMA 一致性缓冲；MMZ 桩下 Flush 为空）
Decode:      PNG_DECODE          → PngOsiDecode
               1) alloc FLT: rowBytes = PNG_GETROWBYTES(w, pixel_depth=ch*depth)，再 (x+0xf)&~0xf
                  例如 1920×1080 RGB8 → 5760 B（=1920*3，已 16 对齐）；**不含 PNG filter byte**
               2) down(g_DevMutex)；down(stInstanceLock)；eState = DECING(1)
               3) 保存 dec 参数（tgt/stride/info/transform/CLUT）
               4) PngHalOpen(): SetClock(1) → Reset(SRST pulse，保存/恢复 AXI/TimeOut/RDC/ErrMode/IntMask)
                  → SetRdcAddr(g_u32RdcBufPhyaddr 32KB) → AXIConfig=0x20441 → TimeOut=0x80008
                  → IntMask=0xffffffff → ErrMode=0xffff0000 → SMMU init
               5) PngHalSetImgInfo(): uSize{w,h}（各 13 bit）；uType{BitDepth,ColorFmt,InterlaceType=0,
                  FunSel=0,StreamType=0}
               6) PngHalSetTransform()（bit 位按 u32Transform 置位；tRNS/alpha 颜色字）
               7) PngHalSetFltAddr(flt, rowBytes)  → FltStAddr / FltEndAddr = flt+rowBytes-1
               8) PngHalSetTgt(tgt, stride)        → FinalStAddr = tgt；u32Stride = stride
                                                     （**u32FinalEndAddr 从不写**，见 §2/§3-a）
               9) PngHalSetStreamBuf(node0, node0.BufSize)   → BitBufSt/End
              10) PngHalSetStreamAddr(node0, node0.StreamLen)→ BitStreamSt/End
                  ★ 两者同址：BitBuf 窗口 = 整个节点(≥128KB)，BitStream 窗口 = 有效码流
              11) PngHalStartDecode(): uType.FunSel=0；写 u32DecStart=1
              12) bSync: wait_event_interruptible_timeout(2 s) 等 eState != DECING
                  （ioctl 层 png_osr.c 历史版本强制 bSync=TRUE；板卡 nb/poll 构建已删该行）
ISR:   RESUME(bit1): 取 pCur->u32NextPhyaddr / pHwUseBufVir 前进一个节点；
                     若 next 存在且 next->u32StreamLen≠0：
                        PngHalSetStreamBuf(next, next.BufSize)
                        PngHalSetStreamAddr(next, next.StreamLen)   ← BitStream 跳到下一节点起点
                        PngHalResumeDecode()                       ← 写 u32ResumeStart=1
                     否则：**什么都不做**（pulse 都没有）
       FINISH(bit0): eState=FINISH；PngHalSetClock(0)；唤醒等待队列
       ERR(bit2):    eState=ERR；唤醒（注意：只有 bit2；bits16–31 不处理）
       bits16–31:   被 PngHalGetIntStatus 的 RMW 写回清掉，ISR 不识别 → 静默
完成:  eState==FINISH → PngOsiDecode 返回；否则超时 → eState=ERR、返回 HI_ERR_PNG_INTERRUPT
GetResult: PNG_GET_DECRESULT → 返回 eState（NOSTART/DECING/FINISH/ERR）
Destroy:   PNG_DESTROY_DECODER → 释放 FLT、码流节点链表、handle
```

### 1.3 物理缓冲清单与语义（谁分配/大小/谁写/硬件假设）

| 缓冲 | 分配者 | 大小（1080p RGB8） | 寄存器（偏移） | 观察到的/推断的语义 |
|---|---|---|---|---|
| 码流节点 BitBuf | 用户态 MMZ → `PngOsiAllocBuf` | ≥128 KB/节点（驱动按申请，api 层最小 128 KB） | `BitBufStAddr`(0x20)/`BitBufEndAddr`(0x24) | 硬件**可预取**的物理码流窗口；驱动让它与 BitStream 指向同一节点（见 §3-#1） |
| 码流段 BitStream | 同上 | = `u32StreamLen`（首段可 215,622 / 32 KB / 4,108…） | `BitStreamStAddr`(0x28)/`EndAddr`(0x2c) | 当前"有效码流"窗口；RESUME 语义围绕它 |
| RDC "rle window" | 驱动 `PngOsiInit`，每模块一次 | 32 KB（注释：can't be changed） | `RdcStAddr`(0x80) | zlib/deflate 滑动窗口（32 KB 是 deflate window 上限；`ZlibCinfoErr`=窗口>32K）；驱动**从不调整大小** |
| FLT 滤波缓冲 | `PngOsiDecode` 每解码一次 | `(rowBytes+0xf)&~0xf` = 5760 B = **1 行**，不含 filter byte | `FltStAddr`(0x88)/`FltEndAddr`(0x8c) | PNG 反滤波上下文（Up/Average/Paeth 需上一行）；厂商只给 1 行（§5-b） |
| 目标输出 | 用户态 MMZ | stride×height（stride 必须 16 对齐，5760/7680 都试过） | `u32Stride`(0x08)/`FinalStAddr`(0x4c)/`FinalEndAddr`(0x50，**未写**) | 最终输出；非交错时 Pass0–6/FinalEnd 未配置（§3-a） |
| 交错 pass 缓冲 | 驱动**从不使用** | — | `Pass0..6StAddr`(0x30..0x48)、`Pass0..6Stride`(0x5c..0x74) | Adam7 的 7 个 pass 目标；`InterlaceType` 恒 0 → 非交错，推测不用 |
| CLUT/tRNS | 用户态（仅 CLUT） | ≤256×4 | `uTransColor0/1`(0x78/0x7c) | 调色板/透明色；`PngHalSetTransform` 有一处 Color0=Color1 的疑似笔误（§5-f） |
| 内核 MMZ 桩 | `port_stubs.c` | RDC/FLT | — | 基线以 DMA coherent 分配（round168），曾排除 cache 一致性 |

### 1.4 寄存器全表（`offsetof` 实测，`PNG_REG_SIZE=0x120`，实际结构 0x114）

| off | 字段 | 驱动是否写 | 说明 |
|---|---|---|---|
| 0x00 | u32DecStart | 写 1 | 启动（自清零） |
| 0x04 | u32ResumeStart | ISR 写 1 | 续流 re-arm |
| 0x08 | u32Stride | 写 | 输出行宽（16 对齐，否则 `HI_ERR_PNG_INVALID_PARAM`） |
| 0x0c | uSize | 写 | `height[12:0]`,`width[28:16]`；13 bit 上限 8191；厂商 HAL 又限 <4096 |
| 0x10 | uType | 写 | `BitDepth[4:0]`,`ColorFmt[10:8]`,`InterlaceType[13]`,`FunSel[14]`,`StreamType[15]`；`Type=0x208`=8bit+RGB2 被硬件接受 |
| 0x14 | uTransform | 写 | 格式变换位域；tRNS/alpha 相关 |
| 0x20/0x24 | BitBufSt/End | 写 | 码流窗口/预取窗口 |
| 0x28/0x2c | BitStreamSt/End | 写 | 当前有效码流窗口（RESUME 语义核心） |
| 0x30–0x48 | Pass0..6StAddr | **从不写** | 交错 7 pass 目标 |
| 0x4c | FinalStAddr | 写 | 输出物理地址 |
| 0x50 | **FinalEndAddr** | **从不写**（复位后 0） | 输出结束地址（§3-a 候选根因） |
| 0x5c–0x74 | Pass0..6Stride | **从不写** | 交错 pass 行宽 |
| 0x78/0x7c | TransColor0/1 | 写 | tRNS/alpha |
| 0x80 | RdcStAddr | 每次 Open 写 | 32 KB 窗口 |
| 0x88/0x8c | FltSt/End | 写 | 1 行 rowBytes |
| 0x90 | AXIConfig | 写 0x20441 | AXI 属性；历史未扫过其它值（§3-#12） |
| 0x94 | TimeOut | 写 0x80008 | 端口/解码超时；历史未扫过（§3-#12） |
| 0x98 | MmuBypass | 按 CONFIG_GFX_MMU_SUPPORT | 本基线未定义该宏 → 全部 bypass=1（物理地址直通） |
| 0x100 | uInt | 读/清（RMW） | 状态：bit0 FINISH/bit1 RESUME/bit2 DecError/bits16–31 具体错误 |
| 0x104 | uIntMask | 写 0xffffffff，读回 0xffff0003 | bit0/1 与 bits16–31 可屏蔽；bits2–15 恒 0 → **bit2 DecError 反而不可屏蔽** |
| 0x108 | uErrMode | 写 0xffff0000 | bits16–31 = "遇此类错误即停"（全开） |
| 0x10c | uErrStatics | **从不读** | `TotalIdatNums[7:0]`,`ErrIdatNums[15:8]`（P0 才打印） |
| 0x110 | RstBusy | 仅 SetClock 等 | bit0 复位忙 |

> 注：Lead 提到的"FinalEndAddr=0x54"应为 0x50（`offsetof` 实测；0x4c=FinalStAddr、0x50=FinalEndAddr）。
> 结构体对齐已被寄存器回读交叉验证：RDC(0x80)/FLT(0x88)/AXI(0x90)/IntMask(0x104) 的写入值都能原样读回，
> 因此不存在整体错位。**但 FinalEndAddr 确实从未被赋值**（这一点成立）。

### 1.5 状态/锁/中断/超时语义

- `eState`：0 NOSTART / 1 DECING / 2 FINISH / 3 ERR。只有 `PngOsiDecode` 置 DECING；
  FINISH 只由 ISR bit0 置；ERR 由 ISR bit2、超时、或部分错误路径置。
- 锁：`g_DevMutex`（整设备串行，`PngOsiDecode` 持有到解码结束/超时）、
  每实例 `stInstanceLock`（sema_init=1）、`g_HandleMutex`。ISR 路径通过 `PngOsiResGetInstance`
  取实例，不加实例锁（依赖 DECING 状态判断）。**bSync=FALSE 时驱动在 ISR 里 `PNG_UP(g_DevMutex)`**。
- 中断语义（`PNG_INT_U`）：
  - bit0 `DecFinish` → FINISH 并关模块时钟；
  - bit1 `DecResume` → 码流续传请求（厂商按"切下一节点"处理）；
  - bit2 `DecError` → 通用解码错；
  - bits16–31 `FmtBufErr/FltBufErr/RdcBufErr/FltTypeErr/DecCpyErr/HuffDecErr/ZlibHdis/Hlit/Len/Btype/Fcheck/Fdict/Cinfo/Cm/AdlerErr/CrcErr`
    → **ISR 完全不识别**，且 `PngHalGetIntStatus()` 用 `uInt &= u32Int` 的 RMW 写回已把状态清掉。
  - `IntMask=0xffff0003`（读回）：bit0/1 + bits16–31 使能；bit2 被硬件保留为 0 →
    **generic DecError 中断实际上不会被打开**，错误只能从 bits16–31 的逐个错误位出现。
- 超时：`PngOsiDecode` 同步等待 2000 ms；超时后置 `eState=ERR`、返回 `HI_ERR_PNG_INTERRUPT
  (0x8000000D)`；用户态 `HI_PNG_GetResult` 得到 `state=3`。**历史"成功 head"也是这个 rc/state**
  （round159/161）→ rc/state 不能作为成功判据，必须看像素。

### 1.6 驱动/HAL 的隐含假设与 off-by-one 汇总

1. `PNG_GETROWBYTES` 按 `width*pixel_depth` 计算，**不含 PNG 每行的 filter byte**；
   `pixel_depth` 由 `PngOsiGetPixelBitDepth()` 给出（RGB=bitdepth*3, ARGB=*4, AGRAY=*2）。
   非 8/16 bit 的 1/2/4 bit 图按位宽向上取整，然后 `(x+0xf)&~0xf`。
2. FLT 只分配 1 行 rowBytes（且 `PngHalSetFltAddr` 用 `phy+size-1`）。若硬件 FLT 语义是
   "滤波前/后行缓存"或需要"上一行 + 当前行"，1 行则偏小（§3-b）。16 bit 图 rowBytes 会翻倍，
   但"不含 filter byte"的 ±1 偏差对 16 对齐无害（因为对齐后 ≥+1）。
3. `u32FinalEndAddr` 未写（0x50），`Pass0..6*` 未写；`InterlaceType` 恒 0。
4. `PngHalSetStreamBuf()` 与 `PngHalSetStreamAddr()` 都写 `StreamMmuBypass`（重复无害）；
   BitBuf 与 BitStream 被设为**同一块内存**（§3-#1）。
5. `PngHalReset()` 只保存/恢复 AXI/TimeOut/RDC/ErrMode/IntMask；FinalEnd/Pass/TransColor/Stride
   在 SRST 后为 0（它们每次 Decode 都会重写，除 FinalEnd/Pass）。
6. `u32Size`/`u32Type` 是 RMW 写（先读回再改位域）；`u32Type.FunSel` 只在 StartDecode 清零。
7. 编解码地址/行宽必须 16 字节对齐（`CheckAddr/CheckStride`）；码流节点长度 ≤ BufSize。
8. `uErrMode=0xffff0000` 让任何错误位都**停止解码**；`uIntMask` 使能 bits16–31 中断。
9. 用户态 `hi_png_api.c` 的 `HI_PNG_AllocBuf` 最小 128 KB，因此"32 KB 分段"在驱动里其实
   每节点 BufSize≥128 KB；`HI_PNG_Decode` 会 flush 全部节点（MMZ 桩下为 no-op）。
10. `PngOsiDecode` 在超时路径**不调用 PngHalReset/SetClock(0)**，硬件可能仍处于时钟开、
    状态机停在半途；同 boot 第二次解码全 0（one-shot，PNG-03/06）与此一致。
11. `png_osr.c` 历史版本把 `stDecInfo.bSync` 强制为 TRUE（board nb/poll 构建已改为尊重用户值）。
12. `PngHalSetTransform` 第一行 `uTransColor0.u32All = g_pstPngReg->uTransColor1.u32All;`
    读的是 Color1（笔误，§5-f）；因为随后 ADDALPHA 分支会重写两者，只有"未开 ADDALPHA 且
    此前残留 tRNS"时才可能有影响。

---

## 2. "只出 head、15 行后静默"的证据复盘

| 观测 | 值 | 解读 |
|---|---|---|
| 输出 | 行 0–14 与 ffmpeg rgb24 逐字节一致；行 15 起全 0 | 硬件确实按正确算法解了 15 行 |
| 对应输入 | ≈898–991 B（zlib 二分），首段窗口 32 KB / 单缓冲 215,622 B | **不是段/链/IDAT/deflate 边界**；RESUME 发生在窗口远未耗尽处 |
| 寄存器（超时快照） | `Type=0x208`（8bit RGB 被接受）、`bufSt/strSt` 仍=首段起点、`Int=0`、`EMode=ffff0000`、`EStat` 未读 | 配置被接受；超时瞬间无挂起状态（可能已被 ISR 清掉，见 §3-#3） |
| 中断 | 有的 boot `ISR cnt=1 Int=00000002`（RESUME）；E0/E1 有的 boot **完全无 ISR**（Int 三次轮询=0） | ①中断交付不稳定（round166）；②RESUME 只在"需要 re-arm"时出现一次；③可能被误清 |
| rc/state | `-2147483635 = 0x8000000D` / `state=3` | 2 s 超时（`HI_ERR_PNG_INTERRUPT`）+ ERR；历史 head 成功同样如此 |
| 重复性 | 同 boot 第 2 次必全 0；模块重载无效；只有整机 reboot 首次有效 | 硬件/不可清状态 one-shot（PNG-03/06），与"停在半途未复位"一致 |
| 分段方式 | 单缓冲/32 KB/1600 B/IDAT 帧对齐（53 段）停止行都=15 | 与流组织无关（round172） |
| FLT 2 行 | 无变化（round170，但那是驱动只 alloc 2× 未改 FltEnd 的实验；本轮 P3c 两处都改） | 待 P3c 复验 |
| stride/transform | 5760/7680、transform=0 都得到同样 15 行 | 已排除 |

---

## 3. 候选根因清单（按可能性排序，每条给出可证伪预测 + 最小实验）

> "预测"=若该条为真，上板应观察到什么；"最小实验"=已封装好的变体/工具（`work/png-hw/code/out`）或寄存器操作。
> 现状：历史已排除 SMMU/cache/DMA 一致性/时钟/中断路由/stride/transform/分段大小/链式/IDAT 对齐/FLT 仅 2×alloc。
> 下面只列"未被排除或只有部分证据"的。

### #1. BitBuf 与 BitStream 同址 → 硬件预取窗口被"有效码流长度"截断（**中高**）
驱动把 `BitBufSt/End = 节点基址..基址+BufSize-1`，`BitStreamSt/End = 基址..基址+StreamLen-1`（同址）。
若硬件用 BitBuf 做"整块预取/回卷"，而用 BitStream 做"位流边界"，两者同址且 **BitBufEnd 只到
`StreamLen`** 时，硬件在把 BitBuf 预取窗口"读空"后会提前 RESUME——正好解释 ~1 KB 后即停
（若硬件内部预取粒度/水位与 1 KB 有关）。
- 预测：BitBuf 指向**独立、足够大的 MMZ 缓冲**（4 KB / 128 KB）后，第 1 次 RESUME 位置显著后移
  （>1 KB 输入、>15 行），或直接 FINISH。
- 最小实验：`hi_png_p2a_bitbuf.ko png_bitbuf_kb=4` / `=128`（BitStream 仍指码流节点）。
- 现状：**待板卡**（D3）。

### #2. RESUME = "内部 bit buffer 约 1 KB 耗尽，需要软件 re-arm"（**中高**，Lead 首选）
现象高度吻合：停止点≈1 KB 输入、每段 32 KB 窗口远未耗尽、只能看到一次 RESUME 后硬件静默。
厂商 RESUME 分支的"切下一节点"实现只有在"每节点刚好一段码流"时才是正确语义；单节点/任意切分时
`u32ResumeStart` 从未被写 → 硬件得不到 re-arm。
- 预测（弱）：仅 pulse `u32ResumeStart=1`（地址不变）可让解码继续到 1 KB 之后；
- 预测（强）：若硬件需要"消费位置"，则纯 pulse 会让它重新取同一窗口 → 立刻再次 RESUME →
  **ISR 风暴/soft lockup/panic**（round150/156 的 panic 正是这个模式）；或必须把
  `BitStreamStAddr` 前移已消费量后才 pulse。
- 最小实验：`hi_png_p1_pulse.ko`（限 3 次 pulse，防风暴）、`hi_png_p2b_step.ko
  png_step_kb=1 png_step_max=64`（每次 RESUME 前移 1 KB 再 pulse；用 step 扫描反推消费量）。
- 现状：**待板卡**（D4/D5），P1 限次是相对 round150/156 的安全化设计。

### #3. bits16–31 具体错误被 ISR 静默吞掉，错误停在"半途"（**中高**，且最能解释"无任何可见错误"）
`PngOsiIntHandle` 只处理 bit0/bit1/bit2；`PNG_INT_ERR_MASK=0x4` 只是 bit2。`uErrMode=0xffff0000`
让任何 bits16–31 错误都**停止解码**；而 `PngHalGetIntStatus()` 已把状态清掉，ISR 不打印不置 ERR
→ 现象=静默停止、超时后 `Int=0`、`EStat` 从不被读。
- 预测：P0 诊断件（`hi_png_diag0.ko`）会在 dmesg 打出 `ISR-HWERR stat=0x....` 或
  `poll-HWERR stat=0x....`，stat 的置位直接给出错误类型；同时 `state` 立刻变 3（无需等 2 s）。
- 最小实验：`hi_png_diag0.ko` + `png_hwprobe`（单缓冲先复刻 E0）。
- 现状：**待板卡**（D0，最高优先）。

### #4. 输出端 `u32FinalEndAddr` 未配置（**中**，Lead 的 (a)）
驱动 `PngHalSetTgt` 只写 `FinalStAddr(0x4c)` + `u32Stride(0x08)`，从不清 `FinalEndAddr(0x50)`
（SRST 后=0）。若硬件用它做写边界/写回卷/Final-DMA 结束判断，0 值可能在写了若干行后触发内部停止。
注：同代 SPC050 参考驱动与 R006C00 也不写它——但这两版是否在 MV300 上验证过未知。
- 预测：`png_finalend=1`（=tgt+stride*h-1）或 `=2`（=tgt+rowbytes*h-1）后 goodrows 从 15 明显增加，
  或 dmesg 出现/消失某错误位。
- 最小实验：`hi_png_p3a_finalend.ko png_finalend=1/2`；同时 P0 会在 `PNGDMP` 里回读 finalEnd。
- 现状：**待板卡**（D1）。

### #5. FLT 缓冲只有 1 行，反滤波上下文不足（**中**，Lead 的 (b)）
PNG 反滤波 Up/Average/Paeth 需要"上一行"；驱动只给 `rowBytes`（1 行，且**不含 filter byte**）。
厂商如此写，可能内部另有上一行缓存；但若 MV300 硬件确实把 FLT 当"上一行/两行"缓存，
1 行会在某处（15 行附近）触发 `FltBufErr` 或停止。15=16-1 也可能是"16 行内部行组"的暗示。
- 预测：FLT=2 行（`FltEnd` 同步放大）后 goodrows>15；或统计错误位变化。
- 最小实验：`hi_png_p3c_flt2.ko png_fltrows=2`（`=3` 备选）。注意历史 round170 只放大 alloc
  未改 `FltEndAddr`，本次两者都改，故不等价。
- 现状：**待板卡**（D2）。

### #6. RDC 32 KB 不够（**低-中**，Lead 的 (c)）
若 RDC 是 deflate 滑动窗口：32 KB 正确（deflate 上限，且 `ZlibCinfoErr` 定义"窗口>32K"）。
若 RDC 实际是"解压后原始数据窗口/环形缓冲"，1080p 一行 5760 B，32 KB≈5.7 行，
与 15 行无整数关系。历史未做 64 KB 实验。
- 预测：RDC=64 KB 若为真应改变停止行或错误位；若完全无变化 → RDC 是 deflate 窗口（32 KB 固定正确）。
- 最小实验：需再加一个变体（`PNG_RDCBUF_SIZE=64KB`，改 `png_osi.c` 宏 + 保证 16 对齐），
  当前 6 个变体未含；若 D0 出现 `RdcBufErr` 我立即补。
- 现状：**未做**，低优先。

### #7. 中断交付/清中断方式导致"状态被吞"（**中**，解释"有无 ISR 不一致"）
`PngHalGetIntStatus()`：`u32Int = uInt; uInt &= u32Int;` 是**对活跃 W1C 寄存器的 RMW**。
若两次读之间硬件置新位（如 RESUME 后紧跟 FINISH/错误），写回会把新位一起清掉（lost IRQ）。
另外主线无 PNG DTS，IRQ 是驱动手工 `irq_create_fwspec_mapping(GIC SPI 96, LEVEL_HIGH)`；
round166 观测到全程无 ISR。若有位被吞，现象就是"静默 + 超时 + Int=0"。
- 预测：P0 的 ISR/ poll 打印会在**同一位置**给出不同 boot 下不同的 Int（如 0x2 vs 0x20000），
  且 P0 对 bits16–31 置 ERR 后，超时不再发生（state 立即 3）。
- 最小实验：`hi_png_diag0.ko`（同时有 ISR 路径和进程上下文 poll 路径，两者都打全位）。
- 现状：**待板卡**（D0）。

### #8. 15 行 = 硬件内部"16 行行组/tile"边界，第 16 行需要软件重启动（**低-中**，Lead 的 (e)）
`Pass0..6StAddr`/`Pass*Stride` 从未配置。若硬件按"行组"工作、组结束要软件推进（类似交错的
pass 起点），非交错时也应给 Pass 地址/行偏移，则 15 行=第一组 16 行(减最后一行)是可能的。
- 预测：给 `Pass0StAddr=tgt`、`Pass0Stride=stride`（甚至 Pass1..）后停止行改变；或 RESUME 次数增加。
- 最小实验：需新增变体（"Pass0 起点=输出基址" 版）；若 D0 显示 RESUME 反复出现/寄存器 strSt 不前移，
  这条优先级上升。**当前未做**。
- 现状：**未做**，待 D0 数据。

### #9. `uErrMode/uIntMask` 组合语义理解反了（**低-中**）
若 `uErrMode` 的 1 位表示"忽略错误继续"，0xffff0000 反而全停；或 `uIntMask` 的 1 位表示"屏蔽"。
但 `IntMask` 写 0xffffffff 读回 0xffff0003 且历史上中断确实触发过 → "1=使能"成立；
`uErrMode` 未做对照实验。
- 预测：`uErrMode=0`（不因任何错误停）后，同样输入会继续解下去（若停在错误）或仍 15 行（若真卡死）。
- 最小实验：可用 `hi_png_diag0.ko` + 额外参数（需新增 `png_errmode` 参数；当前未暴露）。
- 现状：**未做**。

### #10. `PngHalSetTransform` 笔误 / tRNS/alpha 变换组合（**低**，Lead 的 (f)）
`uTransColor0.u32All = g_pstPngReg->uTransColor1.u32All;` 读 Color1 是笔误；但 ADDALPHA 分支随后会
重写 Color0/Color1，只有"不开 ADDALPHA 且寄存器残留"时有理论影响。测试样本 RGB8 无 tRNS，
transform=0，故对本症状**几乎不可能**是根因。
- 预测：transform=0 时无影响；开 `HI_PNG_TRANSFORM_ADDALPHA` 且 tRNS 图像才可能错色。
- 最小实验：`PNG_TRANSFORM=0x8`（工具 env）对比；不作为主线索。
- 现状：**已判低**（结论见 §5-f）。

### #11. `uType.InterlaceType` 恒 0 / `PNG_GETROWBYTES` 不含 filter byte（**低**）
前者对非交错样本是正确的；后者影响 FLT 大小 1 字节（再 16 对齐后被吞），对本症状无解释力。
- 预测：无论改与不改，1080p RGB8 行为不变（可用 FLT 多行变体间接验证）。
- 现状：**已判低**（§5）。

### #12. `AXIConfig=0x20441`/`TimeOut=0x80008` 在 MV300 上不适用（**低**）
这两个常量来自同代驱动（SPC050 相同），从未扫过其它值。若 MV300 的 PNGD AXI 端口属性/超时
配置不同，可能出现 AXI 读挂在 1 KB 处（无中断、无错误）——与"静默"吻合但无法从代码推断。
- 预测：改 AXI/TimeOut 后停止点改变；或 SMMU bypass/AXI 错误日志出现。
- 最小实验：需要"寄存器可写"的诊断接口（`/proc` poke），当前变体未含；建议在 D0–D5 之后按需加。
- 现状：**未做**。

### 其余已排除项（历史 + 本轮复核，勿重复）
SMMU/IOMMU 映射、cache/DMA 一致性（round168）、时钟/CRG（round147 终值 0x1）、
中断路由（round146/147 fwspec→virq 39，已触发过）、stride 16 对齐、transform=0 与 vendor 语义、
分段大小（32 KB/1600 B）、链式续传、IDAT 帧对齐、末段 0/0xFF 填充/IEND（round148/151/159/172）、
`bSync` 阻塞/非阻塞、FLT 2×alloc（round170，但与本次"2 行+FltEnd"不同，需 P3c 复验）、
模块重载（PNG-06）、vendor libpng 软件库（见 §6）。

---

## 4. 对"RESUME = ~1 KB 内部 bit buffer 耗尽，需要 re-arm"假设的论证

### 支持
1. 停止点 ≈898–991 B 输入，而 `BitStreamEnd` 距起点 32 KB（链）或 215,622 B（单缓冲）：
   **硬件不是"本段读完"才 RESUME**。
2. 只出现一次 RESUME 后硬件完全静默（不再发任何中断/状态位）：若 RESUME 是"请给下一段"，
   在无下一段时硬件也应继续等（正确）；但若是"请 re-arm 让我继续取同一窗口"，则没有 pulse 就永远不动。
3. 厂商 ISR 架构正是"RESUME → 换窗口 → 写 ResumeStart"：`ResumeStart` 是独立寄存器，
   说明硬件确实需要一次显式"继续"写；而厂商只在"有下一节点"时写它。
4. round149（整文件、7×32KB 链）曾观测 ISR 计数 6→9：说明每次切节点后硬件会再 RESUME，
   即"切到新窗口"不足以让它无中断地跑完一个 32 KB 窗口——**每次 re-arm 能推进的量很小**，
   与"1 KB 级内部缓冲"一致。

### 反驳/风险
1. 若 RESUME 只是"bit FIFO 空了，请 pulse"，硬件应**自己**知道继续从 `BitStreamStAddr` 哪里取
   （它有内部读指针），那纯 pulse 应有效；但 round150/156 在 ISR 中无条件 `PngHalResumeDecode()`
   导致 **panic**（疑似 IRQ 风暴），说明 pulse 后硬件可能立即再次 RESUME（无数据可推进）→
   更可能是"必须同时前移 `BitStreamStAddr` 到已消费位置"。
2. 硬件**没有把已消费位置写回** `BitStreamStAddr`（round169/172 超时快照 strSt 仍是起点），
   软件无法知道精确消费量 → 只能按"节点边界"或"估算步长"前移（P2b 用 `png_step_kb` 扫描）。
3. 若硬件实际需要"1 KB 对齐窗口"，则 P2b 的 step 扫描应能找到一个能让行数持续增长的 step；
   若所有 step 都只多解几行就再停/报错，说明需要精确消费量或另有根因。
4. 另一种等价解释：RESUME 是"内部 1 KB FIFO 空"的**电平**信号，软件必须在 ISR 里
   "填数据 + pulse" 才能消掉；厂商"换节点"在单节点场景下等于"没填数据"，故死锁。
   → 与 #1（BitBuf 独立）/ #2（前移窗口）本质相同，P2a/P2b 正是这两个方向。

### 判定设计（已交 board-eng）
- **D0**（`hi_png_diag0.ko`）先解决"是否有隐藏错误位"这一分叉：若 `ISR-HWERR stat≠0`，
  根因在缓冲尺寸/配置（按 stat 走 D1/D2/RDC）；若 stat=0 且 RESUME 只出现一次，则进入 re-arm 方向。
- **D5**（P1 pulse，限 3 次）：若行数继续增长 → re-arm 方向成立且纯 pulse 足够；
  若立刻再次 RESUME/风暴/panic → 必须前移窗口（P2b）或换独立 BitBuf（P2a）。
- **D4**（P2b step 扫描 1/2/4 KB）：用"行数 vs step"曲线反推硬件实际消费量（若 step≈1 KB 时
  行数持续增长，则消费量≈1 KB；若 step 太大导致花屏但行数更多，可用小 step 细化）。
- **D3**（P2a 独立 BitBuf 4/128 KB）：若 BitBuf 同址是根因，则独立后 RESUME 位置后移。

---

## 5. Lead 指定代码疑点的逐条结论

**a) `u32FinalEndAddr` 未赋值**：确认成立。`PngHalSetTgt()` 只写 `FinalStAddr(0x4c)` 与
`u32Stride(0x08)`；SRST 后 `FinalEndAddr(0x50)=0`，全代码库无任何写点（SPC050/R006C00 参考版同样没有）。
非交错时 `Pass0..6StAddr/Stride` 也从不配置。**但**：这两版参考驱动是否在 MV300 上验证过未知，
所以仍列为候选（§3-#4），已做 P3a 变体直接证伪。

**b) FLT 只有 1 行（不含 filter byte）**：确认。`u32RowBytes = PNG_GETROWBYTES(...)`（无 +1）再
`(x+0xf)&~0xf`；`PngHalSetFltAddr(flt, rowBytes)` → FltEnd=flt+rowBytes-1。若硬件 FLT 语义是
"上一行缓存"，理论上需要 ≥1 行（行宽可能含 filter byte → rowBytes+1）；若需"上一行+当前行"则 2 行。
"1 行也能正确出 15 行"说明 FLT 至少不是每行都越界；15=16-1 与"16 行行组/内部行缓存"吻合，
但也可能是巧合。历史 round170 只把 alloc 放大而 **FltEnd 仍=1 行**，等于没改 → 不能作为排除证据。
已做 P3c（alloc 与 FltEnd 同时放大）复验。

**c) RDC 32 KB**：注释明确 "rle window size, can't be changed"；若是 deflate 滑动窗口，32 KB 正好是
上限（PNG/zlib 规范）；若是"解压后原始数据窗口"则 32 KB≈5.7 行，与 15 无整数关系。未做 64 KB 实验
（低优先，除非 D0 报 `RdcBufErr`）。

**d) 错误位错位**：确认——这是**真 bug**。`PNG_INT_U` 的 bits16–31 是具体错误状态，
`uIntMask` 的 bits16–31 是它们的使能位；`uErrMode` 的 bits16–31 是"遇错即停"。
ISR 只判 `PNG_INT_ERR_MASK=0x4`（bit2 通用错误），而 `uIntMask` 读回 0xffff0003 表明 bit2 甚至
不参与屏蔽（bits2–15 恒 0）。因此任何 bits16–31 错误：①触发中断（已使能）→②`PngHalGetIntStatus`
读并清掉 →③ISR 不识别、不置 eState →④2 s 超时 `state=3`、超时快照 `Int=0`。
已用 P0 变体打印全 32 位 + `uErrStatics`，并在识别到 bits16–31 时立刻置 ERR（不再静默）。

**e) `PngHalSetTransform` 的 `uTransColor0 = uTransColor1`**：确认是笔误（应读 Color0 自身或保持原值）。
影响面：随后 `ADDALPHA` 分支会重写 Color0/Color1，故只有"未开 ADDALPHA 且寄存器残留旧值"时
理论上影响 tRNS/alpha；本症状是 RGB8、transform=0、无 tRNS → **不是根因**，但建议修复（一行）。

**f) `uType.InterlaceType` 恒 0 / `PNG_GETROWBYTES` 不含 filter byte**：
- InterlaceType=0 对非交错样本正确；且 `HIPNG_ACCELERATE_SUPPORT()` 在用户态已把 interlaced
  排除到软解，硬件路径本来就只处理非交错。
- 不含 filter byte 只影响 FLT 大小 1 字节，16 对齐后连边界都不变（5760 已对齐）；对 16 bit/窄图
  最多 ±16 B 级别，无法解释"15 行后停"。结论：都不是本症状根因。

---

## 6. vendor 原生意图路径分析（libpng 1.6.32 patch + `png_accelerate.c`）

### 6.1 构建事实（`source/component/png/Makefile`）

- 非 mini 芯片（含 hi3798mv300）加 `-DHIPNG_ACCELERATE` → `patch/patch/patch_include_files.c`
  直接 `#include "png_accelerate.c"`、`#include "hi_png_api.c"` 编进 libpng16；
- **`HIPNG_PUSH_DECODE` 从未在任何 Makefile/头/CFLAGS 中定义** → `hipng_push_*`（流式提交）
  是**死代码**；`pngpread.c` 里三处 `#ifdef HIPNG_PUSH_DECODE` 也不生效。
- hi3798mv300 在 `CONFIG_GFX_MEM_ION` 名单里 → `HI_GFX_AllocMem/Map/Flush` 走 ION 分支；
  但板卡 bring-up 用的是 MMZ 桩（`/dev/hi_mmz` + `hi_mmz_shim.ko`），所以**从未按产品配置跑过**
  这条路径（这也是无法直接复用的原因之一）。
- `HIPNG_ACCELERATE_SUPPORT()` 会把以下情况**排除出硬件**（返回 FALSE → 纯软解）：
  palette+MMU、`PNG_QUANTIZE/COMPOSE`、interlaced、`PNG_PACK/SHIFT/SWAP_BYTES/INVERT_MONO/
  BACKGROUND_EXPAND/GAMMA/INVERT_ALPHA/USER_TRANSFORM/RGB_TO_GRAY*`、`width>=4096`、
  `height>=4096` 或 `height<=1`、`read_row_fn`、非 AFTER 的 FILLER。
- `HIPNG_HWCOPY_DEC`：当用户行指针不是"连续物理+16 对齐"（`hipng_check_addr` 失败）时，
  硬件解到临时 MMZ 图，再由 `hipng_copy_rows()` 按行 `memcpy` 到用户行；
  `bSync=0` 走 `png_get_state`/`png_read_image_async` 的异步查询路径。

### 6.2 实际执行的硬件流程（非 push）= 与我们的 `png_test8` 等价

`png_read_image()`（`pngread.c`，HIPNG_ACCELERATE 钩子）→ `hipng_read_rows()`：
1. `hipng_read_stream()`：**一次性**把 PNG 的所有 IDAT 块按完整帧（len+"IDAT"+data+CRC）
   `AllocBuf + memcpy + SetStreamLen` 预填成**缓冲节点链**；每个节点 BufSize 至少 128 KB，
   `StreamLen` = 一个 IDAT 帧长；非 IDAT 块（IEND 等）只记 `idat_size/crc/chunk_name` 不提交；
2. `hipng_set_transform()`；`HI_PNG_Decode(bSync=pstHwStruct->bSyncDec, 默认 TRUE)`；
3. `bSync` 下等 FINISH；失败 `goto ERR` → `eState=ERR`：
   - 若 `u8DecMode` 不含 `HIPNG_SW_DEC` → `png_error("Internel err!")`（**应用可见的失败**）；
   - 否则（默认 `u8UserDecMode = SW|HW|HWCOPY`，一定含 SW）→ `hipng_prepare_switch()` 把
     libpng 的 buffer 状态回卷到硬件接管前，然后 `return HI_FAILURE`；
4. 回到 `png_read_image()`，**继续执行原生软件逐行解码循环**（同一份数据重新 zlib 解一遍），
   应用完全看不到"硬件失败"，只看到最终图像（软件解出来的）——**这就是"失败被掩盖成软解"的确切位置**：
   `pngread.c: png_read_image()`（约 732–742 行 `hipng_read_rows` 调用 + 其后的 `for(j..pass) for(i..height) png_read_row()`），
   配合 `png_accelerate.c: hipng_read_rows()` 的 `ERR:` 标签（约 1772–1782 行）。

### 6.3 结论：vendor 自己的逻辑也整幅不可达

- **非 push（唯一被编译的路径）** = 整段预填 + 单次 Decode + 轮询 FINISH，
  与板卡 `png_test8` 的 IDAT 单缓冲/链式流程**语义等价**；既然 `png_test8` 只到 15 行，
  vendor 这条路径同样只到 15 行，然后 **静默软解回退**。
- **push 路径（`hipng_push_stream/decode`）是死代码**，且即便打开，它只是"按 IDAT 帧 AllocBuf+
  SetStreamLen+Decode"，仍复刻同样的 RESUME 缺口（每帧 4,108 B 的窗口 >> 1 KB 停止点）。
- 所以"改用 vendor libpng 加速栈"**不会**得到硬件整幅；只会得到一个"看起来成功"的软件解码。
  若需证据，最小验证是：用 `png_set_swdec()` 关闭软解并让 `hipng_read_rows` 失败直接
  `png_error`，会立刻暴露同样的 15 行/超时（也已由我们的 `png_hwprobe` 路径等价覆盖，无需重编 libpng）。
- 这也解释了为什么 png-08 曾判"vendor HIGO PNG 插件是软件实现"：该 SDK 的用户态 PNG
  就是 libpng 软解（HIGO 插件连 `HIPNG_ACCELERATE` 都没有，`nm -D` 无任何 `HI_PNG_*`/MMZ 符号）。

> 因此：**要整幅，只能修驱动/HAL 的流控语义；vendor 栈不是替代路径。**

---

## 7. 构建与运行说明（可复现）

### 7.1 驱动变体（host 交叉编译，已验证可复现基线）

```sh
cd /home/jason/HiSTBLinuxV100R005C00SPC060/work/png-hw/code
# 基线补齐 + 诊断插桩（脚本幂等：tool_apply_diag.py 修改 mod/src2）
# 生成 6 个变体源码树 + 构建：
bash build_variants.sh
# 产物：out/modules/hi_png_{diag0,p1_pulse,p2b_step,p2a_bitbuf,p3a_finalend,p3c_flt2}.ko
```
构建环境（`build_variants.sh` 已内置）：
`PATH=/home/jason/bringup-7.3/toolchain/usr/bin:$PATH`、
`LD_LIBRARY_PATH=/home/jason/bringup-7.3/toolchain/usr/lib/x86_64-linux-gnu`、
`make -C /home/jason/bringup-7.3/src/linux-7.3 M=<variant> ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules`。
**不加任何插桩时重建 sha1 = `4551b6e1…` = 板上 `hi_png_reload.ko`**（构建一致性证明）。

补丁应用（相对 `/home/jason/bringup-7.3/port/png`）：
`patch -p1 -d /home/jason/bringup-7.3/port/png < patches/P3a-finalend.patch`。

每个变体的编译期/运行期开关：
| 变体 | 参数（默认） | 作用 |
|---|---|---|
| diag0 | — | 全 Int/ErrStatics/全寄存器打印；bits16–31 → 立即 ERR + dump |
| p1_pulse | — | RESUME 无下一节点：pulse `ResumeStart` 最多 3 次 |
| p2a_bitbuf | `png_bitbuf_kb=4/128` | BitBuf 指向独立 MMZ |
| p2b_step | `png_step_kb=1`, `png_step_max=64` | RESUME 时 `BitStreamStAddr += step` 后 pulse |
| p3a_finalend | `png_finalend=1/2` | 写 `FinalEndAddr = tgt+stride*h-1` / `tgt+rowbytes*h-1` |
| p3c_flt2 | `png_fltrows=2/3` | FLT 缓冲 = N×rowBytes，FltEnd 同步 |

> 所有变体都保留 `PNGDBG/PNGDMP` 全量日志；`PngHalDumpRegs("timeout")` 已扩展为
> `Int/IMask/EMode/EStat/AXI/TMO/MmuBypass/Stride/Size/Trans/Type/finalSt/finalEnd/p0..p6/pstride/tc0/tc1/rdc/fltSt/End/RstBusy`。

### 7.2 用户态工具（aarch64 静态、无软解回退）

```sh
cd /home/jason/HiSTBLinuxV100R005C00SPC060/work/png-hw/code
bash tool/build_tool.sh      # → tool/png_hwprobe
```
产出 `out/png_hwprobe`（sha1 见 `out/SHA1SUMS.txt`）。板上一行：
```sh
insmod /root/m2/png-diag/modules/<variant>.ko [params] && \
/root/m2/png-diag/png_hwprobe /root/m2/t1080.png /root/hwtest/png-diag/out.raw
```
常用 env：`PNG_MODE=single|chunk|aligned`、`PNG_CHUNK`、`PNG_STRIDE`、`PNG_TRANSFORM`、
`PNG_OUTFMT`、`PNG_BSYNC`、`PNG_IEND`、`PNG_PAD`、`PNG_REF`+`PNG_REF_BPP`（逐行严格比对）。
完整部署/判读见 `work/png-hw/code/out/README.md`。

### 7.3 vendor 原生 libpng 路径（结论：不构建）

按 §6 的静态证据，vendor 路径（libpng+`png_accelerate.c`，非 push）与 `png_test8` 语义等价，
且失败会静默回退软解；构建它需要 ION/MMZ 适配 + libpng 交叉编译 + HIGO 依赖，成本 3–5 人天
而结论可预期（head-only + 软解）。因此本轮**不做**该构建，以"驱动变体 + 裸 ioctl 工具"
作为独立、无回退的硬件整幅证据链（这也符合任务中"极简 ioctl 工具比完整 libpng 更有价值"）。

---

## 8. 最小可证伪实验清单（已发 board-eng；每个实验 = 1 次 fresh boot）

| ID | 变体/命令 | 若假设为真 | 若假设为假 |
|---|---|---|---|
| **D0** | `hi_png_diag0.ko`（`PNG_MODE=single`） | dmesg 出现 `ISR-HWERR stat=0x…`/`poll-HWERR` → 根因=错误位被吞（§3-#3），stat 指明类型 | 无 HWERR、`PNGDMP[timeout]` 的 strSt=首段起点且 EStat=0 → 静默卡死（转 D1/D2/D4） |
| D1 | `hi_png_p3a_finalend.ko png_finalend=1`（再 `=2`） | goodrows 明显 >15 → §3-#4 成立 | goodrows 仍=15 → 排除 FinalEnd |
| D2 | `hi_png_p3c_flt2.ko png_fltrows=2`（再 3） | goodrows >15 或错误位变化 → §3-#5 | 不变 → 排除 FLT 大小（本次 FltEnd 同步放大） |
| D3 | `hi_png_p2a_bitbuf.ko png_bitbuf_kb=4`（再 128） | 首 RESUME 位置后移/行数增加 → §3-#1 | 立即全 0/无进度 → 排除独立 BitBuf |
| D4 | `hi_png_p2b_step.ko png_step_kb=1 png_step_max=64` | 行数随 step 增长 → §3-#2（窗口需前移）；用 step 曲线反推消费量 | 仍 15 行 → re-arm 方向不成立或需精确消费量 |
| D5 | `hi_png_p1_pulse.ko` | 行数继续增长 → 纯 re-arm 足够 | 立刻再 RESUME/风暴/panic → 必须同时前移窗口/换 BitBuf（方向仍成立但需数据） |

D0 是所有分支的入口：它把"隐藏错误位"与"真静默卡死"分开，后续 D1–D5 才有确定判读。
若 D0 报 `RdcBufErr` → 立即补 64 KB RDC 变体；若报 `FltTypeErr` → 关注 FLT/filter 路径；
若报 `Zlib*`/`Adler`/`Crc` → 说明硬件对 IDAT 帧/末段语义仍有偏差，回头做"末段+CRC/Adler"专项。

---

## 9. 附录

### 9.1 关键常量/错误码
- `PNG_REG_BASEADDR=0xf8c70000`，`PNG_REG_SIZE=0x120`，GIC SPI 96（驱动手工 fwspec 映射）。
- `rc=-2147483635 = 0x8000000D = HI_ERR_PNG_INTERRUPT`；`state=3 = HI_PNG_STATE_ERR`。
- `PNG_RDCBUF_SIZE=32 KB`（"can't be changed"）；用户态 `PNG_BUF_DEFAULTSIZE=128 KB`。
- `AXIConfig=0x20441`，`TimeOut=0x80008`，`IntMask=0xffffffff`（读回 0xffff0003），`ErrMode=0xffff0000`。
- `Type=0x208` → BitDepth=8、ColorFmt=2(RGB)、Interlace/FunSel/StreamType=0。

### 9.2 本轮产出文件（`work/png-hw/code/`）
```
out/png_hwprobe                     aarch64 静态、HW-only、逐节点/逐行输出分析
out/modules/hi_png_diag0.ko         P0 诊断基线（全中断位/ErrStatics/全寄存器）
out/modules/hi_png_p1_pulse.ko      P1 纯 re-arm pulse（限 3 次）
out/modules/hi_png_p2a_bitbuf.ko    P2a 独立 BitBuf（png_bitbuf_kb=4/128）
out/modules/hi_png_p2b_step.ko      P2b 码流窗口前移（png_step_kb/max）
out/modules/hi_png_p3a_finalend.ko  P3a FinalEndAddr（png_finalend=1/2）
out/modules/hi_png_p3c_flt2.ko      P3c FLT 多行（png_fltrows=2/3）
out/patches/*.patch                 每个变体相对 vendor 基线的独立 unified diff
out/SHA1SUMS.txt out/FILE-TYPES.txt 校验（ELF64/AArch64/vermagic/params）
out/README.md                       部署、流程、判读矩阵
out/src/                            上述工具与构建脚本源码
mod/ src-utf8/ variants/            插桩源、GBK→UTF-8 阅读副本、6 个变体构建树
patches/                            同 out/patches（工作副本）
```

---

## 10. v2 更新（2026-11-10 15:30）：1920×15 整幅成功 → 16 行 band 假设

### 10.1 决定性新证据（board-eng 实测）

| 输入 | 结果 |
|---|---|
| **1920×15 RGB8（IDAT-only 单缓冲）** | **rc=0、state=2(FINISH)、5.66 ms、输出 86,400 B 正确** |
| 1920×1080（同编码器/同流组织） | 写完行 0–14，**FLT=第 14 行**、无 IRQ、`RstBusy=1`、无错误位；2 s 后 `rc=0x8000000D/state=3` |

这两条把问题从"任意静默卡死"收敛为**明确的 band 边界行为**：
- 单 band（高度 ≤15/16）→ 硬件能自行 FINISH，说明 inflate/filter/输出通路本身正确；
- 多 band → 第 1 个 band 结束处停下等软件动作；硬件没有丢弃数据，而是"**帧间上下文**"
  （32 KB zlib 滑窗 → RDC、位残余 → BitBuf）需要保存/恢复。

### 10.2 band 机制与 15 行的精确解释

- `RDC = 32 KB` 恰为 **deflate 窗口上限**（`ZlibCinfoErr` 定义"窗口>32K"）——band 之间要保存
  inflate 状态，最自然的落点就是 RDC；`BitBuf`（位级预取，按字节无意义）则是"未对齐位残余"的落点。
- 输出 15 行 + FLT=第 14 行 ⇒ 硬件处理到"第 16 行（index 15）之前/之中"：
  行 0–14 已写出（15 行），第 15 行的 filter 需要 FLT 里的第 14 行作为 Up 参考；
  这与"**16 行 band，输出流水线滞后 1 行**"一致：band 内解 16 行，写出 15 行，第 16 行还在
  输出/上下文保存阶段，此时到 band 边界要求软件 `ResumeStart`。
- 为何 15 行图能 FINISH：只有一个 band、且流在 band 内自然结束（zlib final + Adler），无需恢复上下文。
- 为何历史"ISR cnt=1 Int=2"有时出现、有时完全没有：band 边界很可能确实产生 `DecResume`，
  但①主线上 IRQ 交付不稳定（round166/167）；②一旦软件不动作，硬件不重复触发，超时后状态已被清；
  ③`RstBusy=1` 可能是"等待 re-arm"的另一种可轮询指示（P0 会把它打印出来）。

### 10.3 由此升级的候选根因（覆盖 §3 排序）

**#0（新增，最高）band 边界上下文保存/恢复缺失——软件未在 band 边界写 `ResumeStart`**
- 机制：硬件把"下一 band 需要的状态"写回 RDC/BitBuf 后自停；驱动 ISR 只在"有下一码流节点"时
  写 `ResumeStart`，单节点/最后一节点时什么都不做 ⇒ 永远停在第 1 个 band。
- 预测：V1（每 1 ms 无条件 pulse `ResumeStart`，见 §10.4）应让行 16/64/256 的采样值变化，
  最终 FINISH；pulse 次数 ≈ 1080/16 ≈ 68 量级（1 ms 周期下 <0.1 s）。
- 已交付：`hi_png_v1_bandpulse.ko`（V1）。

**#0b（新增，中，与 #0 并列验证）`BitBuf` 与 `BitStream` 同址是否影响 band 续接**
- 原机制假设：若硬件把位残余/预取状态**写回 BitBuf**，而 BitBuf 与码流节点同址，band 边界写回会
  覆盖未消费码流 → 下一 band 从污染码流继续。
- **反证（board-eng 实测）**：本样本 stall 后 BitBuf 头 256 B 与输入码流**逐字节相同**、尾 128 B 全 0
  ⇒ **本样本硬件没有写回 BitBuf**。因此 #0b 不能作为既定因果；V1a 的主要变量只是
  "**独立 BitBuf 是否改变硬件行为**"（例如硬件对 BitBuf/BitStream 同址有额外的窗口重叠判断）。
- 预测：V1a（=V1 + 独立 BitBuf 128 KB）与 V1 的差异直接给出答案；若两者行为一致，则同址无害。
- 已交付：`hi_png_v1a_pulse_bitbuf.ko`（V1a，默认 `png_bitbuf_kb=128`；`=4` 可缩小验证）。

**#0c（新增，中）`RstBusy=1` 的含义**：驱动只在 SetClock 里把它当"复位忙"。band 停顿处它=1，
说明该位可能是"解码状态机忙/等 re-arm"的通用 busy。P0 在 ISR/超时都会打印 `RstBusy`；
若 V1 每 pulse 后 `RstBusy` 短暂变化，则 pulse 确实被硬件接受。

其余 §3 的 #1–#12 保留（按上面三条之后排序）：P3a FinalEnd、P3c FLT 2 行、V8 RDC 64 KB、
P2b 码流窗口前移、P2a、V3 TimeOut/AXIConfig 均为对 band 假设的边界/旁证实验。

### 10.4 V1/V1a 的精确设计（为什么这样能验证 band 假设）

`hi_png_v1_bandpulse.ko`（`png_osi.c` 中 `#if PNG_EXP_MODE == 6`）把驱动 2 s 同步等待改成：
1. 1 ms 粒度的 `wait_event_interruptible_timeout` 循环（仍走原 `PngOsiPollStatus` 处理真实 Int）；
2. 每 tick 读 `PngHalGetIntRaw()`（不清状态）；若连续 2 tick 无中断且 `eState==DECING`，
   写 `u32ResumeStart=1`（`png_pulse_ms`/`png_pulse_always` 可调；`png_pulse_max` 上限）；
3. 每 100 ms 用 `memremap(target, stride*height)` 采样第 16/64/256 行首字，变化即打印
   `V1 progress ... row16=... row64=... row256=...`；
4. 结束打印 `V1 done pulses=N wait=Mms state=S`，并把 `RstBusy` 打进每次 pulse 日志。
- 若 band 假设成立：`pulses` 随解码推进增长（≈ band 数），progress 行号不断增加，最后 `state=2`；
- 若硬件需要"不仅 pulse、还要重设 BitStream/RDC 指针"：progress 会停在 row16 附近 →
  转 V1a（独立 BitBuf）与 P2b（窗口前移），并结合 V2 抓 RDC/FLT 判断上下文落在哪。
- 定时无上限 pulse 相对 round150/156 的安全性：所有 pulse 都在**进程上下文**（ioctl 内循环）
  完成，不在 ISR 里；有 `png_pulse_max`/`png_wait_ms` 双上限，不会形成中断风暴。

### 10.5 V2（band 停顿现场抓取）与 V3/V8

- **V2**：`png_hwprobe` 新增 `--dump <phys> <size> <out>`（mmap 任意 MMZ 物理窗口）与
  `PNG_KEEP=1`（不 ReleaseBuf/DestroyDecoder，保留 FLT/链）。P0 在超时 dump 打印 `rdc/fltSt/
  bufSt/strSt` 等于给出抓取地址；`out/src/bandstate_check.py` 用 zlib 重解 + 参考图判断
  RDC 装的是**未滤波行/压缩窗口**、FLT 装的是**滤波后行**。这是"RDC 是否真为 zlib 窗口"的直接证据。
- **V3**（`hi_png_v3_timeout.ko`）：`u32TimeOut=0x7fffffff`（`png_timeout` 可调），排除
  "AXI 端口超时误判"；若结果完全不变，说明 0x80008 不是停止原因。
- **V8**（`hi_png_v8_rdc64.ko`，或任意变体 `png_rdckb=64`）：RDC 分配 64 KB。注意 RDC **只有起始
  地址寄存器、没有 size 寄存器** ⇒ 硬件仍按 32 KB 用；但 RDC 与 FLT/其它 MMZ 相邻，
  64 KB 可排除"硬件实际写到 32 KB 之外踩邻接缓冲"这一可能（历史布局 RDC 0x18028000、
  FLT 0x18030000 正好相邻）。

### 10.6 后续判定树（board-eng 执行，v2）

```
V1a（pulse+独立BitBuf） → state=2 & goodrows≈1080  ──► 根因=band边界缺re-arm + BitBuf同址，修驱动即可
   │ 失败
V1（仅pulse） → progress 是否 >row16? ── 是 ──► 需独立BitBuf（与V1a交叉验证）
   │ 否
V2 抓 RDC/FLT/BitBuf → RDC=zlib窗口? FLT=row14? ── 是 ──► band机制确认，需精确恢复序列
   │                                        └── 否 ──► 重新审视 RstBusy=1 与 AXI 配置（V3/寄存器poke）
P3a/P3c/V8/D0-HWERR → 按 §5 位表定位缓冲/配置错误
```

### 10.7 本轮新增文件（v2 增量）

```
out/modules/hi_png_v1_bandpulse.ko     V1  1ms 轮询 + 无限(上限10万) ResumeStart pulse + 行进度采样
out/modules/hi_png_v1a_pulse_bitbuf.ko V1a = V1 + 独立 BitBuf(默认128KB, png_bitbuf_kb=4/128)
out/modules/hi_png_v3_timeout.ko       V3  TimeOut=0x7fffffff（可调）, AXIConfig 可调
out/modules/hi_png_v8_rdc64.ko         V8  RDC 64KB（可调 png_rdckb）
out/src/bandstate_check.py             V2  RDC/FLT 内容判读脚本
out/png_hwprobe                        + --dump / PNG_KEEP
out/README.md                          v2 矩阵、D0 的 bits16–31 判读表、V2 抓取命令
patches/V1-bandpulse.patch 等 10 个    每变体独立 diff（基线 /home/jason/bringup-7.3/port/png）
```

### 10.8 v2.1 增补（Lead 指定）：寄存器策略变体 err0/int0/pass0/pass0i/axi0to

在 `PngHalOpen/PngHalSetImgInfo/PngHalSetTgt` 三处寄存器策略上各做一个最小变体，用于直接命中
"15 行处是否有被静默的错误停机、是否 pass0/AXI 相关"：

| 变体 | 改动 | 预期（假设成立时） | 失败含义 |
|---|---|---|---|
| `hi_png_vN_err0.ko` | `uErrMode=0`（**所有错误不停机**） | 若 15 行处本有具体错误：硬件继续跑，`poll-HWERR/ISR-HWERR stat=0x…` 直接给出错误位（FmtBuf/FltBuf/RdcBuf/FltType/DecCpy/Huff/Zlib*/Adler/Crc），行数>15 或 FINISH | stat=0 且仍 15 行 ⇒ 不是错误停机，回到 band/re-arm 主线 |
| `hi_png_vN_int0.ko` | `uIntMask=0`（关中断） | 行数仍 15 但 poll 能读到 pending 位 ⇒ 中断投递问题；Int 恒 0 ⇒ 中断不在关键路径 | — |
| `hi_png_vN_pass0.ko` | 额外写 `Pass0StAddr=tgt`、`Pass0Stride=stride` | 行数变化 ⇒ 非交错也使用 pass0 通道 | 不变 ⇒ pass0 与主输出无关 |
| `hi_png_vN_pass0i.ko` | pass0 + `uType.InterlaceType=1` | 输出/停止点明显变化（可能多报错）⇒ interlace 位有效；不变 ⇒ 被忽略/语义不同 | — |
| `hi_png_vN_axi0to.ko` | `AXIConfig=0`、`TimeOut=0x7fffffff` | 行数变化 ⇒ AXI 配置/超时相关 | 不变 ⇒ 两者都不是停止原因 |

> err0 实现细节：`PngHalOpen()` 写 `uErrMode=0`；同时 P0 的 HWERR 处理在 err0 变体里**只打印不置 ERR**
> （ISR 与 poll 两条路径），保证硬件继续跑、能被后续 dump/输出比对观察，而不是被软件提前结束。

> 注意 err0 与 band 假设并不互斥：band 边界若要保存 inflate 上下文，也可能同时置某个错误位；
> 先看 err0 是否让行数增长/stat 是否出现，再决定是"错误停机"还是"缺 ResumeStart"。

---

## 11. v3 最终根因（2026-11-10 16:00，已由板上实验确认）

### 11.1 结论

**`PngHalOpen()`/`PngHalSetAxiAndTimeout()` 里写的 `u32AXIConfig = 0x20441`（寄存器 0x90）是
vendor 的"建议/调优值"（`ref/HiSTBLinuxV100R005C00SPC050` 与 R006 的 `png_hal.h` 原文：
`/*Suggest value is 0x20441*/  /*CNcomment:0x90 建议配置成0x20441*/`），在本 mainline/MV300 移植
环境不适用：它会让 PNGD 的 AXI 主口在读取约 1 KB 码流后停在一个未完成的事务上 → 解码状态机挂起
（表现为写出 15 行后不再推进、**不产生任何中断/错误位**、RstBusy=1），2 s 后驱动超时 → `state=3`。

**修复：`u32AXIConfig = 0`。** 板上实测（1920×1080 RGB8，IDAT-only，stride=5760/7680）：

| 配置 | Decode | state | 输出 | 耗时 | ISR |
|---|---|---|---|---|---|
| vendor 0x20441 + TMO 0x80008 | `0x8000000D` 超时 | 3 ERR | 仅 15 行（~86,400 B 中行 0–14 正确） | 2 s | 0–1 RESUME |
| **AXI=0 + TMO 0x7fffffff** | **0** | **2 FINISH** | **6,220,800 B 全幅、与 ffmpeg RGB24 逐字节一致（1080/1080 行）** | **~100.66 ms** | **7×RESUME + 1×FINISH** |
| AXI=0x20441 + TMO 0x7fffffff（对照） | 超时 | 3 ERR | 仍 15 行 | 2 s | — |

⇒ 决定因素是 **AXIConfig**，不是 TimeOut。另实测 `u32TimeOut(0x94)` 是 `[9:0]`/`[25:16]` 两个
10 bit 域：写 0x7fffffff 只把两域拉满，回读 `0x03ff03ff`（vendor 0x80008 对应两域都是 8）。

### 11.2 机理分析（AXI 0x20441 为什么导致"15 行静默"）

- 0x90 是 PNGD AXI 主口的属性/调优寄存器；SDK 无公开位定义，只有"建议值"。`0x20441 = 0x0002_0441`
  （低半字 0x0441、高半字 0x0002），最可能是 AXI burst/4 K 边界/outstanding 类字段的组合。
- 同族 GFX 解码器 JPEGD 有 **`JPGD_REG_AXI4KCNT(0x11C)` / `JPGD_REG_AXI16MCNT(0x120)`**
  （4 KB / 16 MB DDR 边界计数，需 `CONFIG_JPEG_4KDDR_DISABLE_SHOWMSG` 才暴露），说明该 GFX 家族
  AXI 主口对 DDR 4 K/16 M 边界与突发行为敏感；vendor 的 0x20441 是在其参考 NoC/QoS 下调出的。
- 本 mainline/MV300 的 DDR 映射、SMMU bypass（本基线 `CONFIG_GFX_MMU_SUPPORT` 未定义 → 全 bypass）
  与 Qo S 配置下，该建议值使 AXI 事务无法完成：硬件不报错、不产生中断（事务仍在途），只停在
  半途；这正好解释历史所有"无 IRQ/无错误位/Int=0/超时"的观测。
- 为什么小图"能成功"：AXI 挂起发生在读取约 1 KB 码流/固定时长后；高度 15/16/17 行的小图，
  其完整 IDAT 流很小（约 1 KB 级）、解码很快结束（实测 5.66 ms 内含 FINISH），在挂起触发前就已
  完成；而 1080p 需要持续读 200 KB+ 码流，必然触发挂起。这与"停止行数随图像内容变化
  （t1080 15 行/~960 B、solid1080 23 行/~205 B）"也相容——挂起由时间/事务数而非字节数决定。
- **RESUME 语义被平反**：AXI=0 后驱动原有的"RESUME→切下一节点→`ResumeStart`"链式逻辑工作正常
  （7×RESUME + FINISH），说明 vendor 的多段续传设计本来就是对的；此前"RESUME 后切节点无效/只出
  head"是 AXI 挂起造成的假象。因此 §10 的 **16 行 band 假设被推翻**（1920×15 成功只是"流太小，
  在挂起前解完"），V1/V1a 的 pulse 方向无需继续。

### 11.3 最终交付（`work/png-hw/code/final/`）

| 文件 | 内容 |
|---|---|
| `hi_png_axifix.ko` | 基于板上构建树（port/png）的最小修复模块：AXI=0（两处写点，带根因注释）+ ISR 对 bits16–31 具体错误分类（打印错误名/ErrStatics、立即 ERR 唤醒，避免未来静默超时）；TimeOut 暂保留 vendor 0x80008（等 57 实验确认）。sha1 见 `SHA1SUMS.txt`。 |
| `SDK-FINAL-FIX.patch` | 对 `source/msp/drv/png/{src/png_hal.c,src/png_osi.c,include/png_hal.h}` 的统一 diff（`patch -p1 -d <SDK 根>` 已验证可应用） |
| `PORT-FINAL-FIX.patch` | 对 `/home/jason/bringup-7.3/port/png` 的同一修复 diff（`patch -p1 -d <port/png>` 已验证可应用，可直接 make 出 ko） |
| `README.md` | 根因、证据、构建/应用/回滚、上板一行验证命令 |
| `COVERAGE-MATRIX.md` | 全格式覆盖判据：硬件位域能力、驱动/HAL 已实现/未实现、interlace Pass0–6 补齐方案 |
| `make_final.py`, `build/`, `sdk-src/` | 可复现构建脚本与打补丁后的树（便于审计） |

### 11.3.1 最终交付 v2 增量（2026-11-10 16:05）

- **长解码等待参数化**：`PngOsiDecode()` 的同步等待由硬编码 2 s 改为模块参数
  `png_wait_ms`（默认 **10000 ms**，0644；SDK 源用 `msecs_to_jiffies(png_wait_ms)`，
  port 构建的 10 ms 分片循环以它为总预算），超时后仍置 ERR 返回。理由：1080p ~100 ms，
  8000×8000 需 3 s+。64 MP 输出内存：RGB24 192 MB / RGBA8 256 MB（MMZ/CmaFree 需 ≥512 MB）。
- **最终模块（两个，按 57/58 结果二选一）**：`hi_png_axifix.ko`（AXI=0 + vendor TMO 0x80008 +
  png_wait_ms + errbits，sha1 `7a95e326…`）与 `hi_png_axifix_tmo.ko`（另加 TMO=0x7fffffff，
  sha1 `fccb1f4c…`）。对应补丁：SDK/PORT-FINAL-FIX.patch 与 `-v2-TMO.patch` 各一套
  （SDK 两版 sha1 `f15dd8af…` / `ccb07418…`；PORT 两版 `572d5b6e…` / `1a08ec1d…`），
  均对 **git HEAD 原始 SDK** 生成并 `patch -p1` 干跑通过（SDK 工作树在 15:55 已被团队手工应用过
  同内容修复，故直接再次应用会提示已应用——以 git HEAD 为基线复现即可）。
- **生产工具 `hi_png_hw`**（`work/png-hw/code/out/hi_png_hw`，sha1 `fe8bd39d…`，aarch64 静态）：
  HW-only、无软解兜底；校验 PNG 结构/CRC；IDAT 组帧 + 32 KB 节点链；硬件 transform 覆盖
  gray1/2/4→8、16→8/48bit、gray→RGB、tRNS/filler→alpha、strip alpha；CLUT 1/2/4/8 硬件解索引后
  **PLTE/tRNS 查表展开（格式转换，非解码回退）**；`--outfmt rgb24|rgba8|gray8|gray16|rgb48`；
  不支持组合（interlaced、>8191、非法 depth/color）明确拒绝并返回退出码 3。
- **覆盖判定**：见 `work/png-hw/code/final/COVERAGE-MATRIX.md`——硬件位域能力、驱动/HAL/工具的实现
  状态、interlace 结论（寄存器存在但 SDK 从未实现/未验证 ⇒ **记为限制，不假装支持**；给出 Pass0–6
  补齐实验与"硬件解+软件拼图"备选方案）、13 bit 8191 上限、CLUT 查表说明、验收打勾清单。

### 11.4 产品路径建议

1. **内核驱动修复是唯一必需项**：所有入口（hi_png 裸 ioctl、vendor 加速 libpng、png_test8）
   都经同一驱动；AXI 修复一次覆盖全部。
2. **验收/产品入口建议用 hi_png 裸 ioctl**（如 `png_hwprobe` 风格）：无软解回退，结果可判真伪；
   vendor 加速 libpng 的 `hipng_read_rows` 失败会**静默回退软解**（§6.2），会把问题再次掩盖。
3. 若产品必须用 libpng API：使用 `source/component/png` 的 HIPNG_ACCELERATE 补丁版 + 本文驱动补丁；
   但须显式关闭软解回退（`png_set_swdec()` / 修改 `hipng_read_rows` 的 `ERR:` 分支）以便暴露错误。
   注意 AXI=0 后 vendor 非 push 路径的"整段预填 + 单次 Decode + 链式 RESUME"已被实测等价打通
   （board-eng 7×RESUME + FINISH），可整幅；64 MP 时还需放宽驱动 2 s 等待与 HAL 的 <4096 限制。
