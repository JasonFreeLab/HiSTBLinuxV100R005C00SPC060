# 硬件加速任务交接文档（新会话执行用）

- 文档日期：2026-11-04
- 目标板：Hi3798MV300 电视机顶盒（4×Cortex-A53，1GB DDR3，eMMC HS400 ~7.28GiB）
- 当前系统：Ubuntu 26.04.1 LTS + Linux 7.3.0（mainline，aarch64）
- 本文件目的：让**新的会话**在没有历史上下文的情况下，能独立接续硬件加速任务（M1–M5）

---

## 1. 环境与访问方式

### 1.1 板卡
| 项 | 值 |
|---|---|
| Ubuntu IP | `192.168.2.10/24`（eth0） |
| SSH | `ssh -i ~/.ssh/id_ed25519 root@192.168.2.10` |
| 串口控制台 | `/dev/ttyUSB0` @ **115200** |
| 复位 | `/dev/ttyUSB1` 的 **RTS** 拉高 0.4s 再拉低（`serial.Serial(...).rts=True/False`） |
| 内核 | `Linux 7.3.0 aarch64` |
| 已验证服务 | weston / ssh / smbd 均 active |

> SSH 在板子刚启动或正在重启时经常 `Connection refused/timeout`，此时用串口 shell；
> 串口 shell 提示符为 `root@hi3798mv300:~#`（自动登录，无需密码）。

### 1.2 主机（开发机）
| 项 | 值 |
|---|---|
| 主机 IP | `192.168.2.20/24`（eth3） |
| 内核源码树 | `/home/jason/bringup-7.3/src/linux-7.3` |
| 交叉工具链 | `/home/jason/bringup-7.3/toolchain/usr/bin`（aarch64-linux-gnu-*） |
| VENC 移植目录 | `/home/jason/bringup-7.3/port/venc`（**不在 SDK 仓库内，是独立移植目录**） |
| SDK | `/home/jason/HiSTBLinuxV100R005C00SPC060`（本仓库 docs 所在） |
| 厂商固件备份 | `/mnt/f/design/Hi3798/FW/BK/BK/`（`fastboot_emmc.bin`、`kernel_emmc.bin`、`system_emmc.img` 等） |
| 系统恢复镜像 | `/mnt/f/design/Hi3798/FW/restore-20261104/` |

### 1.3 关键限制
- 主机**没有** pip/ensurepip，不能装 Python 包；但可下载 deb 解包（`ar x` + `tar`）。
- 板卡内核**没有** `/proc/kcore`、`/dev/mem` 设备区不可读（CONFIG_STRICT_DEVMEM）。
- `/tmp` 是临时的：**重要产物已复制到** `docs/porting/artifacts/venc-reverse/`。
- **改板子上的 .ko 后必须 `sync`**：`reboot -f` 会丢掉未落盘的页缓存，曾导致板上 ko 与主机不一致（`Invalid module format`）。
- 移植目录 `/home/jason/bringup-7.3/port` 已做备份：`/home/jason/bringup-7.3/backup/port-<date>.tgz`（改前建议再备份一次）。

---

## 2. 总体进度

| 阶段 | 状态 | 说明 |
|---|---|---|
| **M1 JPEG 硬解** | ✅ **验收通过** | `/dev/jpeg`，1080p 单帧 5.3ms / 189fps / PSNR 66.16dB（详见 `p4-hardware-acceleration-final-report-2026-11-04.md`） |
| **M2 VDEC H.264** | 🟡 **当前阻塞、已产出交接文档** `HANDOFF-M2-vdec-2026-11-05.md`。新证据：**偶发 `err_mbs=0`**（硬件解码有时正确）⇒ 矛盾在 repair 信息/完成时序（H1/H2）；已排除硬件/固件/vfmw 逻辑/缓存/ErrorThred（§4.94） | 见 §4 + 交接文档 |
| **M3 V4L2 播放器** | ⛔ 未开始 | 依赖 M2 |
| **M4 VENC 编码** | ✅ **验收通过（2026-11-04 21:58）** | 见 §3.6：H.264 High 码流可解码（`ffmpeg` rc=0），中断累计 425，P 帧正常，300 帧无 oops |
| **M5 GPU 调压/TDE** | ⛔ 未开始 | 可选阶段 |

**结论性事实**：厂商固件在本板可正常出 H.264 码流（SPS High/PPS/IDR，946,176 B，md5 `4cd99f2b9fa97bb7ed30d7b79d5a7401`）→ 硬件与厂商驱动栈没问题，差距在 mainline 移植。

---

## 3. M4 VENC：已完成的全部工作（重点）

### 3.1 逆向原厂固件（已完成）
1. 从原厂 bootimg 取 uImage → payload 是 **zImage（自解压）**
2. 扫描发现 gzip 流 @偏移 18552 → 解压得到**完整内核 Image = 20,240,332 字节**
3. 在厂商 Android 上 `echo 0 > /proc/sys/kernel/kptr_restrict` 后读 `/proc/kallsyms` 得到真实地址：
   - `DRV_VENC_HAL_V500R001_CfgReg = 0xc0a2536c`
   - `Init = 0xc0a272c4`、`ReadReg = 0xc0a25028`、`EflCfgRegVenc = 0xc0a17c88`
4. 换算文件偏移 = vaddr − 0xC0008000，用 SDK 32 位 objdump 反汇编
   → **存档：`docs/porting/vendor-venc-cfgreg-disasm.asm`**（81KB，7808 字节函数）

**反汇编得出的关键事实：**
- 配置结构是 **32 位布局**：`memcpy 长度 680`，DDR 镜像指针在结构偏移 **676**
- 硬件寄存器写入只有 ~11 个（其余全走 DDR 镜像，RegConfigMode=1）
- 启动位是**函数最后一条写**：`str ip,[r9,#8]`（即 VEDU `0x008 = 1`）
- SMMU 是**使能 + 真实页表**（不是 bypass）

### 3.2 主机端 qemu 仿真器（已完成，可复用）
**做法**：用 SDK 的 32 位软浮点工具链，把**厂商 32 位 HAL 汇编**编译成 ARM 可执行，配 `harness.c`（提供 OSAL 表 + 假寄存器区 + 假配置），在 `qemu-arm-static` 下运行。

**产物（已入库）**：`docs/porting/artifacts/venc-reverse/`
| 文件 | 说明 |
|---|---|
| `harness.c` | 仿真器主程序（含 cfg 文件输入模式） |
| `drv_venc_hal.S` | 厂商 32 位 HAL 汇编（从 SDK 复制，便于脱离 SDK 复现） |
| `cfg.bin` | 一份真实运行时配置（680 字节，来自驱动 dump） |
| `image.bin` | 该配置对应的厂商 HAL 生成的 DDR 镜像（688 字节） |
| `regs.txt` | 该配置对应的寄存器写入清单 |
| `venc_trace_cfg.log` | 驱动 dump 的原始 trace（含 170 行 `CFGHEX:`） |

**复现步骤：**
```bash
cd docs/porting/artifacts/venc-reverse
TC=/home/jason/HiSTBLinuxV100R005C00SPC060/tools/linux/toolchains/arm-histbv310-linux/bin
$TC/arm-gcc49-linux-gnueabi-gcc -march=armv7-a -static -O1 -o hal_harness harness.c drv_venc_hal.S

# 获取 qemu-arm-static（无需 root）：下载 Debian qemu-user-static deb 后解包
# http://deb.debian.org/debian/pool/main/q/qemu/qemu-user-static_7.2+dfsg-7+deb12u18+b3_amd64.deb
#   ar x *.deb && tar xf data.tar.xz   → usr/bin/qemu-arm-static

./qemu-arm-static ./hal_harness cfg.bin    # 输出 image.bin + REG 清单
```

### 3.3 驱动侧改造（已完成）
**移植目录**：`/home/jason/bringup-7.3/port/venc`

| 文件 | 改动 |
|---|---|
| `inc/venc_hal_ext.h` | 覆盖 SDK 头：`VIRT_ADDR`→`HI_U32`、`pRegBase`→`HI_U32` ⇒ **`sizeof(VENC_HAL_CFG_S)=680`** |
| `inc/venc_img_cur.h` | 自动生成：qemu 厂商 HAL 输出的 **688 字节 DDR 镜像模板** |
| `inc/venc_regs_cur.h` | 自动生成：VEDU 寄存器写入表（{off,val}），来自 qemu |
| `src/port_stubs.c` | **核心**：C 版 CfgReg（写寄存器+镜像+SMMU+启动位）、SMMU 4MB 页表、MMZ/DMA/中断/日志桩、`venc_nokick`/`venc_smmu_off` 参数、诊断探针 |
| `src/product_hw.c` | CRG 开关/复位（与厂商 `product.c` 逐行一致） |
| `src/drv_venc_efl.c` | 32 位布局适配（`ExtCfg.DdrRegCfgVirAddr` 填物理地址）、CFGHEX dump、探针 globals |
| `src/drv_venc_intf.c` | 模块退出时清理（避免 `hi_venc_dma` 设备 EEXIST） |
| `Kbuild` | `-DVENC_REG_CONFIG_MODE=1`（DDR 模式） |

### 3.4 已验证与厂商一致的部分（有证据）
| 项 | 证据 |
|---|---|
| DDR 镜像 | 我们的构造（模板 + 16 地址补丁）与 qemu 厂商 HAL 输出**逐字节相同（diff=0）** |
| 寄存器程序 | 与 qemu 实测表一致 |
| CRG | 与厂商 `product.c` 逐行一致；dmesg 确认 `OpenHardware` 执行：`CRG35 write=0x3 read=0x3 CRG203=0x1` |
| SMMU | 页表/TTBR/SCR 与厂商手册式实现一致；**开/关 SMMU 结果相同 → 已排除** |

**寄存器 ground truth（320×240 H264）：**
| 偏移 | 值 |
|---|---|
| VEDU 0x0000 | 0x000000CF |
| VEDU 0x0008 | 0x00000001（启动位，最后写） |
| VEDU 0x0018 | 0x02625A00 |
| VEDU 0x001C | 0x000300D6（随配置变化） |
| VEDU 0x0034 | 0x00370006 |
| VEDU 0x0038 | 0x0000007F |
| VEDU 0x0044 | 0x000091B1 |
| VEDU 0x0080 | 0x00010001 |
| VEDU 0x0118 | DDR 镜像物理地址（运行时填） |
| VEDU 0x024C | 0x0000023B（随配置变化） |
| VEDU 0x0250 | 0x00000003 |
| SMMU 0x0000 | 0x00030008 |
| SMMU 0x0208/0x020C | 页表物理地址（TTBR） |
| SMMU 0x0530 | 0x09070001 |

**镜像地址字段映射（16 个，运行时从配置拷贝）：**
```
img0x058←PmeInfoAddr[1]  img0x05C←PmeInfoAddr[0]  img0x060←PmeInfoAddr[2]
img0x068←SrcYAddr        img0x06C←SrcCAddr
img0x080←RcnYAddr[1]     img0x084←RcnCAddr[1]
img0x098←RcnYAddr[0]     img0x09C←RcnCAddr[0]
img0x0B0←PmeAddr[0]      img0x0D0←PmeAddr[1]
img0x0D8←TmvAddr[1]      img0x0DC←TmvAddr[0]
img0x0E0←StrmBufAddr[0]  img0x0E4←StrmBufWpAddr  img0x0E8←StrmBufRpAddr
```

### 3.5 当前实测现象（阻塞点）
```
Create rc=0，Start rc=0，CfgReg 完整返回，oops=0，板子稳定
无 kick（venc_nokick=1）时 5ms 后回读：MODE=0xCF R18=0x02625A00 R118=镜像物理地址 SCR=0x30008 CRG35=0x3 → 值保持
有 kick 后：
  VKICK（写 0x008=1 后立即读）：MODE=0x300f5000  R8=0x300f5000  R118=0x300f5000（三偏移同一浮空值，从未写入过）
  同刻 SMMU SCR 读到正确 0x00030008
  VSYNC +3ms：全 0；VPROBE +16ms：全 0
  VWPRP（Wp/Rp）：全 0
  VSTRM（码流缓冲 4KB）：全零
  ISR=0；out_venc.h264 = 0 字节
```
**判读**：VEDU 寄存器块的**读通路不可用**（读到浮空值），因此无法用回读验证配置是否被接受；硬件不产生中断、不写码流缓冲。

> **⚠️ 以下「剩余可能原因」已被证伪，真实根因见 §3.6。**


**剩余可能原因（按概率）**：
1. **VEDU 寄存器访问时钟/NIU 侧配置未打开**——厂商侧由未移植的 PM 时钟框架完成，CRG35 bit0/bit1 已置 1 但仍可能缺访问时钟门控位
2. 配置语义字段不完整（我们的配置大量字段为 0，厂商真实配置由 RC/码控填满）

### 3.6 ✅ 已解决（2026-11-04 晚）—— 真实根因与修复
1. **DDR 镜像只拷贝了 688 字节**：qemu 只截取了 688B，但厂商 HAL 实际写到 `0x680`。
   `StrmBufAddr[16]`@0x57C、`StrmBufSize`@0x53C、`ParaSetAddr`@0x5BC、`ParaSetReg[48]`@0x5C4、λ 表 0x2B4–0x3F0 全缺。
   补全（`inc/venc_img_full.h`）后**首次出 ISR、码流缓冲出现 `00 00 00 01 65`**。（时钟/NIU 假设不成立；kick 后读回浮空值是 VEDU 忙时的正常现象）
2. **改为直接运行 SDK 原版 64 位 HAL**（`src/drv_venc_hal.S` = `64bit/3796mv200` 原版，仅导出两个全局）：
   移植层 ioremap `g_pRegBase` 后调用厂商 `Init`（自己 vmalloc scratch）。以前 64 位 HAL「挂总线」是因为
   `g_pHalRegInfo` 被指向 MMIO。现在每帧镜像由厂商 HAL 按真实 RC/帧类型生成 → 出现正确的 P 帧。
   模块参数 `venc_hal_mode`（1=厂商 64 位 HAL，默认；0=旧 32 位模板路径）。
3. 移除 ISR 中的 `ioremap`（`venc_smmu_bypass` → `BUG at mm/vmalloc.c` 内核 panic）、kick 后 MMIO 读、读已释放缓冲的 probe；
   `venc_log` 默认不写文件（`venc_filelog=1` 打开），ISR 计数 `g_venc_isr_cnt`。

**验收（板上，`VENCBUILD: 1104-v64-1`）**：
- `out_venc.h264`：SPS(67, High) / PPS(68) / IDR(65) / P(61)；`ffprobe` h264 High 320x240，`ffmpeg` 解码 rc=0 无错误
- `/proc/interrupts`：`GIC-0 133 Level venc` 行计数递增（virq 号随启动映射变化，实测见过 38 / 41；编码中采样 40+ 次）
- 解码画面与输入渐变图逐帧对应（PSNR≈27.6dB @1Mbps）
- 证据：`docs/porting/artifacts/venc-reverse/m4-pass/`（码流 md5 `9ad7d0dc8d5ae092e9ad92150fd11cc8`、日志、ko、源码快照），说明见该目录上级 README
- 测试程序已修（2026-11-04 晚）：`venc_test.c` 改为每帧重试取流 + Dequeue 重试 + 结束 drain；实测 300 帧 → `streams=309`、解码 299 帧、无 oops、venc 中断累计 425

---

## 4. M2 VDEC 现状

详见 `docs/porting/p4-vdec-m2-status-report-2026-11-03.md`。要点：
- 预编译 vfmw 核能解出 **1 帧**且功能正确
- 后续帧不再交付：事件 116/118/121/122/123 缺失、`NEW_IMAGE(5)` 从未出现
- 已排除：喂流（PUTBM 正常）、帧缓冲分配（4 帧保底）、缓冲回收、协议级别（MPEG≡H264）
- **根因**：厂商通路要求 **VPSS 作为图像消费端**（`VDEC_Chan_VpssRecvFrmBuf` / `VPSS_SOURCE_MODE_VPSSACTIVE`），无 VPSS 时只交付 1 帧
- 突破方向：移植 VPSS，或逆向 `VDEC_CID_SET_FRAME_INTF`（移植代码从未调用，参数格式未知）

### 4.1 2026-11-04 晚追加排查（本轮未突破，但排除了三个方向）
新增两个内核模块参数（`port/vdec/port_stubs.c`），默认值即下面实测用的值：

| 参数 | 默认 | 作用 |
|---|---|---|
| `vdec_eop` | 0 | 关闭 EOP 注入（`bEndOfFrame=1` 时驱动追加 `00 00 01 1E HSPICEND`）。厂商默认开启，实测该 NAL 被 vfmw 当非法 NAL |
| `vdec_maskdfs` | 1 | 置 `MaskCtrlWord bit0` → `u32DynamicFrameStoreAllocEn=0`（静态帧存） |

实测（320×240 / 60 帧 libx264 干净码流，`/root/t60.h264`）：

| 配置 | 交付帧 | 事件 |
|---|---|---|
| EOP=1（厂商默认）/ DFS 动态 | 1 | `113`×49、`127`、`117`、`115`、`20` |
| EOP=0 / DFS 动态 | 1 | 同上（**EOP 不是根因**） |
| EOP=0 + `vdec_maskdfs=1`（静态帧存） | 1 | `113`×49 |
| EOP=0 + 按帧率慢喂（`PUTDELAY=33`，不 FASTFEED） | 0 | `113`×81 |

判读：
1. **EOP 注入、动态/静态帧存、喂流节奏 三个方向都不是根因**（M2 报告里"EOP 有害"的结论仍成立，但那是另一个 bug）
2. 决定性线索：该码流下 **`113`(DECSYNTAX_ERR) 次数 ≈ P 帧数**（60 帧流里 49~81 次），即基本只有 IDR 能解 → 指向 **参考帧/DPB 不可用**，而不是"图像出队"环节
3. 与 §4 原结论一致的方向仍是：图像消费端（VPSS / `VDEC_CID_SET_FRAME_INTF`）未接通，vfmw 拿不到"可复用参考帧"

**下一步建议**：优先做 A/B——同一码流用 SDK 自带的 omxvdec 通路（有 VPSS/processor，`omxvdec_v2.0/processor_vpss.c`）跑一次，确认"1 帧"是否随通路变化；若 omxvdec 能出多帧，则 M2 的正确路线是把 omxvdec 的 channel 序列移植过来，而不是继续修 SDK vdec 直连路径。

### 4.2 2026-11-04 深夜追加：机制性发现 —— 图像通路的 VPSS-pull 机制（**结论已被 §4.6 修正为不完整**）

#### 结论（机制发现，以及它解释到哪一步）
1. `HI_MPI_VDEC_AllocChan` 会**无条件**创建 VPSS（`port/vdecuser/mpi_vdec.c` → `VPSS_CMD_CREATEVPSS`
   → 内核 `VDEC_Chan_CreateVpss`），通道随即进入 `VPSS_SOURCE_MODE_VPSSACTIVE`。
2. 在这种模式下，解码图像由 **VPSS 侧主动 pull**：
   `VPSS_GET_SRCIMAGE = VDEC_Chan_VpssRecvFrmBuf` → `HI_DRV_VDEC_RecvFrmBuf`
   （源码注释原文：`/*VPSS Read a frame from VDEC */`）。
3. 移植的 VPSS 桩（`port_stubs.c`）里：
   - `vp_set_source_mode()` **只返回成功，不保存回调表** → 谁也没拿到 `VPSS_GET_SRCIMAGE`
   - `vp_put_image()` / `vp_get_image()` 空实现 / 直接 FAILURE
   → **没有任何消费者去 pull 图像**，用户 `ChanRecvFrm` 自然一直拿到空队列
4. 这解释了"为什么图像一直不出队"，但**不是全部原因**：跳过 VPSS 创建后依然 0 帧（见上表最后一行），
   说明 vfmw 侧本身也没有把解码图放进 `SYNTAX_ReceiveImage` 队列（与 M2 报告一致：`NEW_IMAGE(5)` 从未到达）。
   即：**两个缺口并存** —— (a) vfmw 不出图（主因）(b) 即便出图，VPSS 桩也不消费（次因）。

#### 本轮为此做过的对照实验（都排除）
| 实验 | 结果 |
|---|---|
| 全 IDR 码流（20 帧，每帧 I 帧，`talli.h264`） | **0 帧**、无 113 语法错误（事件 104/111/112/114）→ 与 P 帧/参考帧无关 |
| 关闭 EOP 注入（`vdec_eop=0`）+ 帧边界保持 `bEndOfFrame=TRUE` | 仍 0~1 帧；**注意**：不能靠把 `bEndOfFrame` 置 0 来"关 EOP"，那会同时破坏帧边界 |
| 整段码流单缓冲送入（`WHOLE=1`） | `GetBuffer` 返回 `0x80120002`(INVALID_PARA)，单包超限 → 该实验路径不可用 |
| 启用 SDK `VFMW_VPSS_BYPASS_EN`（无 VPSS 直取通路） | 编译失败：缺 `BUFFER_NODE_STATUS` 等类型（该通路依赖未移植的 `drv_vdec_buf_mng` 部分） |
| 用户态跳过 `VPSS_CMD_CREATEVPSS`（`NOVPSS=1`，通道不留 VPSS 句柄） | 仍 **0 帧**（事件 2/6/20/104/111/112/113/114），无 oops → 说明"仅缺消费者"不是全部；驱动在无 VPSS 时会走另一条也不出图的路径 |

#### 下一步（按性价比排序）
1. **转向 vfmw 出图侧（主因）**：拿到"为什么不出图"的直接证据——用厂商固件（4.4 内核）同码流跑一次
   `vdec_test` 对照一次事件序列，或在 vfmw 适配层给 `SYNTAX_ReceiveImage` / `InsertImgToVoQueue`
   打桩打印入参，确认是"未生产"还是"生产后被丢弃"
2. **VPSS 桩做成真消费者**（次因，仍需做）：保存 source 回调表 + 后台 pull 线程，把帧转交用户
   （即使 vfmw 出图，不修这条用户也拿不到帧）
3. 补齐 `VFMW_VPSS_BYPASS_EN` 依赖的类型/函数（SDK 有 `VDEC_DRV_SpecialFrmListInit` 等），走"无 VPSS"通路
4. 换 `vfmw_v5.1`（SDK 里另有该目录）重新适配——若 5.0 预编译核在直连模式下确实不出图

诊断材料（码流、测试源码、桩源码、板上流程）：`docs/porting/artifacts/venc-reverse/m2-diag/`

### 4.3 2026-11-05 凌晨：因果链打通 —— **帧存从未分配**（决定性证据）

#### 实测证据（同一模块、多次运行稳定复现）
| 观测点 | 结果 | 含义 |
|---|---|---|
| `GETES: ok` / 唯一 phy | 60 次 / 60 个唯一地址 | 用户送流完全正确（每 AU 一次，长度 3728/280/184/…B）|
| `VDECDBG5 ... len=` | 大量 `len=0` + 少量非零 | `len=0` 是"队列空"的探测读，非喂流问题 |
| `CFGDBG: CFG_CHAN` | `eStd=0`(H264 正确) **`ret=0x0`** | 通道配置被 vfmw 接受（`sedOnly` 现默认 0，见下）|
| `ALLOCREADY` | **`allocFrame=0 allocPmv=0 allocHdr=0 ... needFrame=4`**（972 次重试）| 该分配的 4 块帧存**一次也没分配出来** |
| `ALLOCBUF`（上报 vfmw 的返回值）| **0 次**（全部运行、全部版本）| 帧存**从未上报给 vfmw** |
| vfmw 事件 | 只见 2/20/112/113/115/117/127，**无 118/121/122/123** | vfmw 从未报告帧存需求（`reportImageNum=0`）|
| `total_mbs / err_mbs` | 首帧 0~300，后续稳定 284~300 | 首帧偶尔成功；**P 帧因无参考帧全部报错** |

#### 因果链（已确认）
```
vfmw 不上报帧存需求 (reportImageNum=0，无 118/121)
   → CheckIsNeedAllocMem 不成立 → 不分配 (allocFrame=0)
      → AllocFrameMem 用 ImageSize=0 分配（必然失败）→ ALLOC_MEM_TO_DECODER 从未调用 (ALLOCBUF=0)
         → 无 DPB/参考帧 → 只有首帧可能解出，P 帧 err_mbs≈300
            → 无 NEW_IMAGE(5) → 用户 0~1 帧
```
> 注：`maskdfs`/`force_alloc` 都无法绕开——因为 `AllocFrameMem` 需要 vfmw 上报的 `ImageSize`，该值为 0 时分配必然失败。

#### 顺带确认的两点
- `s32SedOnlyEnable`：SDK 在 mv200/mv300 默认 1。改为可配置（`vdec_sed_only`，现默认 0）后
  `DEC PARAM is not ready` 从 30 次降到约 10 次，但**交付帧数仍在 0~2 波动**（多次重复实测：0/1/2 帧），
  属已知不稳定，不是本次的关键杠杆
- 新增诊断参数（`port/vdec/vdec/drv_vdec_intf_k.c`）：`vdec_sed_only`（默认 0）、`vdec_force_alloc`（默认 0）

#### 下一步（针对"vfmw 为何不上报帧存需求"）
1. 查 `VFMW_Init` 的 `VDEC_OPERATION_S`（`port/vdec/vfmw/adapter/vfmw_intf.c`）：
   `mem_malloc` / `mem_free` 传的是 NULL；对比 omxvdec 是否也 NULL、以及 `Purpose`/`MemAllocMode`
2. 查 `VDEC_CID_SET_IMG_OUTPUT_INFO` 使能时机（必须在 CFG_CHAN 后、START 前）与 `VDEC_CID_SET_FRAME_INTF`
   （omxvdec 用过、移植代码从未调用）
3. 给 vfmw 的 `VCTRL_...`（预编译 .S）里的帧存上报函数下断点式打印（可用 `hi_vdec_dbg_imgins` 这类钩子的方式加桩）

### 4.4 2026-11-05：用 M4 的方法定位到两个决定性差异（帧存链路已打通）

M4 的取胜路径是「拿到厂商侧真实期望 → 找我们与它的**精确**差异 → 直接复用厂商代码」。
对 M2 照做，命中两处：

#### 差异 1：必须开启动态帧存，vfmw 才会下发帧存需求（事件 121）
- 静态帧存时（原默认）vfmw **从不**上报，`reportImageNum` 恒 0 → 驱动不分配 → 无参考帧（§4.3 的因果链）
- 新增参数 `vdec_dfs`（**现默认 1**）。置 1 后立即看到：
  `ARRANGE: imgNum=8 imgSize=197664 pmvNum=4 pmvSize=19328 hdrSize=1024`

#### 差异 2（关键）：上报给 vfmw 的帧存长度必须**精确等于**它要求的值
按 M4 方式反汇编 vfmw 的接受函数 `VCTRL_AllocMemToDecoder` / `VCTRL_SetSingleFrameBufToChan`：
后者把 `pBuf->u32Size`（结构偏移 12）与通道期望值做**相等**比较。
我们原来上报的是 MMZ 分配后的**对齐**大小（200704），而 vfmw 要 197664（=SPS 算出的 ImageSize）
→ 每次都被拒：`ALLOCBUF: ret=0xffffffff`（628 次全失败）。
改为上报 `stVFMWReportFrameInfo.u32ImageSize` 原值后：**`ALLOCBUF: ret=0x0`，12/12 全部接受**。

同时补上 omxvdec 有、移植漏掉的一步：收到 ARRANGE 后回
`VDEC_CID_SET_FRAME_BUFFER_NUM`（`ARRANGE_ACK: need=12 ret=0x0`）。

#### 当前实测状态（默认参数，`VENCBUILD` 见 ko md5）
| 观测 | 结果 |
|---|---|
| 帧存上报 | ✅ 12/12 接受（`ALLOCBUF ret=0x0`，`cfgImg` 递增） |
| `NEW_IMAGE(5)` 事件 | ✅ **首次出现**（同时出现 1/2/4/7 等事件） |
| 解码 | 首帧 `err_mbs=0`，后续 `err_mbs≈300`；用户交付 0~2 帧 |
| 语法错误 | `113` 仍大量（60 帧流 50~62 次） |

#### 下一步（顺理成章）
1. `113` 大量出现 + 日志里 `PPS decode error` → 怀疑**码流缓冲生命周期**：vfmw 还没解完，
   用户态缓冲区就被复用/覆盖（GETES 曾出现同一包被读到两次）。核对
   `VDEC_Chan_RlsStrmBuf` 与 BUFMNG 读/释放配对，以及 FASTFEED 下的写入位置推进
2. 首帧能 `err_mbs=0` 说明解码通路本身正确，把送流时序/缓冲生命周期修好即可连续出帧
3. 之后再接 VPSS 消费端（§4.2）让用户稳定拿到帧

### 4.5 2026-11-05 深夜：送流方式 A/B（EOP / 连续送流均被证伪）+ 修复模块重载

#### 送流方式对照（每次改动都从干净启动单次加载）
| 配置 | 交付帧 | `113` | `NEW_IMAGE(5)` | `err_mbs` |
|---|---|---|---|---|
| 默认（`vdec_dfs=1, vdec_eop=0`，按 AU + 帧尾） | 0~2 | 31~62 | 有 | 首帧 0，后续 284~300 |
| `vdec_eop=1`（厂商默认的 EOP 标记 NAL） | 1 | **80** | 1 | 0 / 300 |
| 不设帧尾（`NOBOUND=1`，连续送流） | 0 | **181** | 0 | 292 |

结论：**按 AU 分帧 + 帧尾标志是正确送法**；EOP 注入无益（此前"EOP 有害"的结论方向正确）；
连续送流明显更差。三者都不是当前 `113` 的根因。

#### 顺带修好：模块可重复 rmmod/insmod（省掉大量重启）
- 根因：`HI_DRV_DEV_UnRegister` 曾是空实现，`class_create("himedia")` 的名字在卸载后仍残留在 sysfs，
  第二次 `insmod` 报 `kobject_add_internal failed for himedia with -EEXIST` → 只能重启
- 修复（`port/vdec/port_stubs.c`）：实现真正的注销（`device_destroy` + `cdev_del` +
  `unregister_chrdev_region`，无设备时 `class_destroy`），并让 class 名每次加载唯一
  （`himedia%u`，取 jiffies 低 16 位），避开 sysfs 延迟回收
- 实测：连续 3 轮 `insmod/rmmod` 全部成功，`/dev/hi_vdec` 干净清理
- ⚠️ 注意：**重载虽成功，但 vfmw/驱动会留脏状态**（解码行为异常），功能测试仍应"重启后单次加载"

### 4.6 2026-11-05：原厂固件离线验证（重要修正 + 路线判定）

按 M4 的思路，从原厂固件拿"厂商到底怎么跑"的事实（无需切固件，纯离线）：
```bash
python3 docs/porting/artifacts/venc-reverse/m2-diag/extract_vendor_kernel.py \
        /mnt/f/design/Hi3798/FW/BK/BK/kernel_emmc.bin /tmp/vendorkernel.Image
# gzip@35000 -> Image 20,240,332 字节（ARM32 vmlinux，与 HANDOFF 记录一致）
```

#### 结论 1：厂商 Android 的播放通路是 **omxvdec**，不是 SDK vdec 直出
原厂内核里同时存在两套驱动字符串，但关键 omxvdec 专有字符串都在：
`Get EVNT_ARRANGE_FRAME_BUF Report`、`Get EVNT_NEED_ARRANGE Report`、`decoder_event_arrange_frame_buffer`、
`bVpssBypass`、`specialFrame`、`OmxVdec`。
→ 厂商能出图的通路是 omxvdec（SDK 里有完整源码 `msp/drv/omxvdec/omxvdec_v2.0`），
  这也解释了它为什么自带 DFS/帧存协商（`SET_FRAME_BUFFER_NUM`）——正是我们这轮补上的那一步。
**M2 的正确路线因此有两条**：① 继续修 SDK vdec 直出（当前路线，已打通帧存但与厂商栈不同）；
② 直接移植 omxvdec（与厂商一致，工作量大但语义已被厂商验证）。

#### 结论 2（修正 §4.2）：`VFMW_VPSS_BYPASS_EN` 一直是开着的
`vfmw/adapter/vfmw.h:11` **无条件** `#define VFMW_VPSS_BYPASS_EN`（另有 `VP9_DYNAMIC_FSP_EN`）。
所以"VPSS 旁路 / specialFrame"通路在我们所有构建里都已编译进去，
§4.2 中"图像通路只能由 VPSS pull"的推断不完整——bypass 模式下有专门的 special frame 匹配逻辑
（`VDEC_DRV_SpecialFrmListInit` / `stRemainFrmList`），这正是需要继续查的地方。

#### 下一步（按性价比）
1. 读通 `VFMW_VPSS_BYPASS_EN` 下的 special frame 逻辑：`VDEC_DRV_SpecialFrmListInit`、
   `stRemainFrmList` 的插入/匹配条件，确认用户取帧是否必须经它
2. 若需要实机 ground truth：切原厂 Android（镜像在 `/mnt/f/design/Hi3798/FW/BK/BK/`），
   跑一次播放并 dump 通道状态，再切回 Ubuntu（恢复镜像见 §10）
3. 或直接移植 omxvdec（与厂商一致）

### 4.7 2026-11-05：补上厂商帧存协议的两步（解码质量明显改善，但仍不稳）

按 omxvdec 的 `decoder_event_arrange_frame_buffer` 逐步对齐，补上移植代码缺的两件事：

| 补丁 | 厂商依据 | 效果 |
|---|---|---|
| ARRANGE 时调用 `VDEC_RecordOccupiedFrame()`（原代码**只有定义没有调用**）| omxvdec 第一步就是 `decoder_record_occoupied_frame` | 占用帧上报给 vfmw，DPB 才能回收 |
| 按 vfmw 上报的 `hdrSize>0` 分配 HDR metadata（原代码在未定义 DOLBYVISION 时强制 0）| `ARRANGE: ... hdrSize=1024`；帧存结构里 `enBufHdrMetadataNodeStatus` 必须有效 | 上报状态由 `1/255/1` 变为 **`1/1/1`**；`init list error`（`InitListX` 失败）**归零** |

**最好的一次实测**（干净启动首个 run）：
`err_mbs = 0,0,0,0`（前 4 帧解码零错误）、`113` 从 502 降到 **8**、`init list error` 0、`NEW_IMAGE` 5 次。

**但方差很大，不能算稳定收益**（同一构建、干净启动，多次实测）：

| run | 交付帧 | `113` | `init list error` | `err_mbs` |
|---|---|---|---|---|
| A（最好） | 0 | 8 | 0 | 0,0,0,0 |
| B | 0 | 30 | 16 | 300 |
| C | 1 | 52 | 43 | 300,300 |
| D | 0 | 29 | 29 | 294 |

#### 当前真正的阻塞点：vfmw 出图了但用户取不到
- `NEW_IMAGE(5)` 事件会出现（说明 vfmw 产出图像）
- 但用户 `ChanRecvFrm` 走 `VDEC_RecvFrm → VFMW_GetImage → VCTRL_GetChanImage` 一直返回 -1
- 该路径里 vfmw 通道状态字段 `f12` 由 1 变成 0（`IMGD: chan=0 ret=-1 f4=1 f12=0 f8=1`），取图前置条件不满足
- 调用者已确认只有 `VDEC_RecvFrm`（没有别的线程偷帧），所以是 vfmw 侧队列/状态问题

#### 新增诊断工具（下轮直接用）
- **`/proc/vfmw/`**：vfmw 自己的状态接口，已可用
  - `info`：`chan: 0, is open: 1, is run: 1`、by-vdh 分配、优先级队列
  - `vfmw_statis`：每帧 Syntax/VDH/Isr 耗时与 fps（当前 `0.0fps`）
  - `scd`、`vfmw_diff` 等
- 新增参数：`vdec_hdr_meta`（默认 1，按上报分配 HDR metadata）
- 日志点：`OCCFRM`（占用帧上报返回值）、`ARRANGE_ACK`、`ALLOCBUF`、`IMGD ra=`（取图调用者）

#### 下一步
1. 用 `/proc/vfmw/info` + `vfmw_statis` 对比"有图"和"无图"两次运行，找出 `f12` 对应字段（vfmw 通道状态）为 0 的原因
2. 检查 `VDEC_CID_SET_IMG_OUTPUT_INFO` 的使能时机/参数（`IMGOUTEN3` 曾返回 0，但 `f12=0` 说明状态没保持）
3. 若仍无解，按 §4.6 路线二移植 omxvdec（厂商验证过的通路）

### 4.8 2026-11-05：定位并修复"图像输出使能未恢复"（用户取帧打通，吞吐仍低）

#### 字段定位（把 §4.7 的 `f12=0` 查实）
`VFMW_CHAN_S`（`vfmw/product/Hi3798MV200/vfmw_ctrl.h:253`）前几个字段：
| 偏移 | 字段 |
|---|---|
| 0 | `s32ChanID` |
| 4 | `s32IsOpen` |
| 8 | `s32IsRun` |
| **12** | **`s32IsImgOutputEn`（图像输出使能，`VFMW_VPSS_BYPASS_EN` 下才存在）** |
| 16 | `s32IsInit` |
| 20 | `s32Priority` |

即 `IMGD: ret=-1 f4=1 f12=0 f8=1` 的真实含义是 **`IsOpen=1, IsRun=1`，但 `IsImgOutputEn=0`**
→ `VCTRL_GetChanImage` 必然返回空。这也解释了"`NEW_IMAGE` 有事件、用户却拿不到帧"。

#### 根因与修复
`VDEC_RecordOccupiedFrame()`（`drv_vdec_intf_k.c`）入口把 `SINT32 s32ImgOutputEn = 0`
并通过 `VDEC_CID_SET_IMG_OUTPUT_INFO` **关闭**图像输出（为了让 vfmw 在报告占用帧期间不产新图），
**但结尾没有恢复**。对照 omxvdec `decoder_record_occoupied_frame`：它在末尾显式
`s32ImgOutputEn = 1; SET_IMG_OUTPUT_INFO(...)` 恢复。
→ 移植代码补上同样的恢复（新增日志 `OCCFRM_EN: ret=0x0`）。

#### 效果（干净启动各一次）
| 项 | 修复前 | 修复后 |
|---|---|---|
| vfmw 通道 `s32IsImgOutputEn` | 0 | **1** |
| 用户是否拿到真实解码帧 | 否（只有 fake/last 帧） | **是**（`FRMDBG: 320x240 type=0 pts=…`）|
| 单次运行交付帧 | 0 | 1~2（其中至少 1 个真实帧） |
| `113` / `init list error` | 8~52 / 0~43 | 18~74 / 14~72（**方差依旧大**） |

#### 仍未解决
- 吞吐极低（60 帧码流一次运行只交付 1~2 帧），`113`/`init list error` 波动大
- 慢速送流（`PUTDELAY`）更差（0 帧、73 次 113），仍以 FASTFEED 为准
- 下一步：把 ARRANGE 的 `imgNum=8` 与实际 DPB 需求（SPS `num_ref_frames=3`，
  `max_dec_frame_buffering=3`）对齐；核对 `VDEC_RecordOccupiedFrame` 里
  `stFrameBufferRecord` 的状态机是否把刚解码的帧误标为 `BUTT` 导致 vfmw 拿不到参考帧

### 4.9 2026-11-05：EOS 注入是污染源；连续 3 帧零错误（但仍不可复现）；一个死锁陷阱

#### 发现 1：`HI_MPI_VDEC_SetEosFlag` 注入会污染码流解析
只喂 5 个 AU 的对照实验（干净启动各一次）：

| 配置 | `113` | `init list error` | `err_mbs` | 交付 |
|---|---|---|---|---|
| 有 `SetEosFlag`（原测试程序） | 5 | 3 | 300 | 1（fake） |
| `NOEOS=1`（不注入 EOS） | **2** | 2 | **0** | 1（**真实** 320×240） |

vfmw 日志里能看到注入后出现 `NAL: EOSTREAM` 与非法 `UNSUPPORT` NAL（`nalu header:e137df00`），
说明 EOS 标记与码流本身冲突。→ 测试程序已加 `NOEOS` 开关，默认改为不注入。

#### 发现 2：最好一次跑出 **连续 3 帧零错误**
`NOEOS=1` 全量码流一次运行：交付 3 个真实帧 `pts=0,1,2`，
`err_mbs = 0,0,0`，之后 `298,298` —— 正好卡在 **DPB 满**（SPS `num_ref_frames=3`）之后。
**但同一构建复跑两次都是 0 帧**（`113=36/68`，`initlist=29/47`），说明结果与时序强相关
（帧存 ARRANGE/分配 与 首帧送流 的先后），这条线索值得继续。

#### 发现 3（重要陷阱）：在"还帧路径"调用 `VDEC_RecordOccupiedFrame` 会死锁
按 omxvdec bypass 通路（`channel_record_occupied_frame`）尝试在 `VDEC_RlsFrm` 里补一次占用帧上报，
结果**板子直接挂死**（SSH 无响应，只能复位）。原因：`VDEC_RecvFrm` 调用 `VDEC_RlsFrm` 时
**已持有 `stRemainFrmList` 自旋锁**，而 `VDEC_RecordOccupiedFrame` 内部再次
`BUFMNG_SpinLockIRQ(&stRemainFrmList.stIrq)` —— 同一把锁重复加锁 → 死锁。
→ 已回退（模块回到 `87011cc3…`）。若要做，必须在**锁外**调用（如放进工作队列或
在 ioctl 层返回后再调）。

### 4.10 2026-11-05：占用帧上报改到"用户还帧 ioctl（锁外）"——目前最好的成绩，但方差仍在

#### 先定位到真正的瓶颈：vfmw 只解析 10 个 NAL 就停了
用全 IDR 码流（`talli.h264`，20 个 AU）测：驱动侧 20 次读取都成功（`GETES ok=20`），
但 vfmw 只解析了 **10 个 NAL（3 个 IDR）** 就停，随后 `VDMDRV_ChnDecReady The channel 0 is not active`。
→ 不是"解码质量"问题，而是**帧存回收不畅导致 vfmw 停止取流**。

#### 修复：按 omxvdec 的语义，在"用户还帧"之后上报占用帧
omxvdec 的占用帧上报由**用户态独立 ioctl** 触发
（`OMXVDEC_IOCTL_CHAN_RECORD_OCCUPIED_FRAME → channel_record_occupied_frame`），
不在任何自旋锁内。移植侧此前只在 ARRANGE 时上报一次。
本次在 `HI_DRV_VDEC_RlsFrmBuf()` **解锁之后**补一次 `VDEC_RecordOccupiedFrame()`
（`RLSOCC: ret=0x0`），与厂商语义一致。

⚠️ 位置很关键：放进 `VDEC_RlsFrm()` 内部会**死锁**（§4.9 已记录），因为那里已持
`stRemainFrmList` 自旋锁。

#### 效果（干净启动首跑，当前最好成绩）
| 指标 | 修复前 | 修复后（最好） |
|---|---|---|
| vfmw 解析 NAL 数（20 AU 流） | 10 | **36**（3.6×） |
| `113` | 0~8 | **0~1** |
| `init list error` | 14~72 | **0** |
| 连续真实帧 | 最多 3 | **4**（`t60`：pts 递增，前段 `err_mbs=0,0`） |

#### 但方差依旧很大（同一构建、干净启动）
| 次 | 交付帧 | `113` | `init list` | `err_mbs` |
|---|---|---|---|---|
| 1 | 3 | 44 | 25 | 286,298,0,0,0,0 |
| 2 | 1 | 108 | 99 | 0,300,295,300,300 |

**同一次启动内复跑必然变差**（0 帧、113 破百），所以每次测量都必须重启后单次加载。

#### 已证伪（本轮新增）
- `STARTDELAY`（启动后先等再送流）：ARRANGE 永远不来 → 8 次 113、无解码
  （原因：vfmw 必须先解析 SPS 才能算帧存需求，不能先断流）
- `PRIME`（先送 AU0、等 300ms、再送其余）：更差（`113=97`、`initlist=68`）

### 4.11 2026-11-05：取帧失败点精确到 `SYNTAX_ReceiveImage`（VO 队列为空）

反汇编 `VCTRL_GetChanImage`（`core/common/vfmw_ctrl.S`）得到取图的**全部**前置条件：

| 顺序 | 条件 | 我们的状态 |
|---|---|---|
| 1 | `ChanID <= 31` | ✓ |
| 2 | 通道上下文非空 | ✓ |
| 3 | `pImage != NULL` | ✓ |
| 4 | `ctx[4] == 1`（`s32IsOpen`） | ✓ |
| 5 | `ctx[12] == 1`（`s32IsImgOutputEn`） | ✓（§4.8 已修）|
| 6 | `SYNTAX_ReceiveImage(&ctx[507904+1744], pImage) == 1` | ✗ **返回 -3（队列空）** |

`SYNTAX_ReceiveImage`（`core/syntax/syntax.S:942`）逻辑：
`SYNTAX_GetVoQue(pChan)` 按**编解码类型**取对应的 VO 队列；比较队列里的
`read_idx(u16@6)` 与 `write_idx(u16@8)`，**相等即空**，直接返回 -3。

→ 结论：`NEW_IMAGE(5)` 事件会出现（说明 vfmw 确实产出了图像），但图像**没有被写进 VO 队列**，
所以取图永远失败。**下一轮的目标就是找到写队列的那一侧**（写 `write_idx` 的函数/其门控条件），
例如是否需要有显示/输出端口绑定（`SYNTAX_GetVoQue` 只按 eSyntaxType 返回全局队列，
写入方大概率在 vfmw_ctrl.S 的"输出一帧"逻辑里）。

#### 顺带排除
`ALLOCFDB` 在一次运行里被调用 **1191 次**（`neededFrame=4 reportImgNum=0 imageSize=0`），
看着像异常，但对照 SDK 原版 `VDEC_AllocMemForDecoder` 后确认：函数体与 SDK 完全一致
（只有我们加的日志），空转是因为 `bAllocFrameBuffer=FALSE` 时直接返回，**属正常**。
这 1191 次里 `ALLOCBUF` 仍只有 12 次，说明没有重复上报帧存。

### 4.12 2026-11-05：占用帧上报改为"后台任务延迟执行"；两个新线索（重复读流 / 写路径自旋锁）

#### 改动：不再在 vfmw 事件回调里调控制接口
上一轮在 ARRANGE 事件回调里直接调 `VDEC_RecordOccupiedFrame()`。但该回调运行在 **vfmw 线程上下文**，
在里面再调 `pfnVfmwControl` 属重入，且涉及自旋锁，风险高（本轮确实抓到板子失去响应的现场）。
改为：ARRANGE 里只置位 `g_occfrm_pending[chan]`，由驱动后台线程 `HI_VDEC_Task` 在安全上下文
补调（日志 `TASKOCC: chan=0 ret=0x0`）。用户还帧路径的 `RLSOCC` 保留。

#### 新线索 1：解析器重复读流
同一构建 3 次干净启动测量（`/tmp/vdrun.sh` 自动复位+单次加载）：

| run | 交付帧 | `113` | `initlist` | vfmw 解析 NAL 数 |
|---|---|---|---|---|
| 1 | 2 | 57 | 28 | 42 |
| 2 | 0 | **225** | 1 | **385** |
| 3 | 2 | 49 | 27 | 41 |

run2 的 **385 个 NAL** 远超码流本身（60 AU ≈ 120 NAL），说明 vfmw **把同一段数据反复读了**。
这与之前观察到的重复释放（`DeleteRawPacket release RawPhyAddr = 0x286b4000` 两次）一致
→ 下一轮重点查 BUFMNG 读/释放配对（是否存在同一包被读两次、或未释放导致重读）。

#### 新线索 2：用户写码流线程卡在 `BUFMNG_PutWriteBuffer`
用 `/proc/<tid>/stack` 抓到运行中的 `vdec_test` 线程停在
`BUFMNG_PutWriteBuffer+0x178 → VDEC_PutStrmBuf → VDEC_Ioctl_PutEsBuffer`。
该函数内部全程只持**自旋锁**、不睡眠，因此"卡在里面"只能解释为自旋锁被长期占用
（谁在持锁时睡眠/阻塞）。已确认 `drv_vdec_buf_mng.c` 内部没有睡眠调用，
嫌疑集中在**上层持 BUFMNG 锁后又调用了可能睡眠的接口**。这也解释了"板子偶尔彻底失去响应"。

#### 工程改进
新增 `docs/porting/artifacts/venc-reverse/m2-diag/vdrun.sh`：一条命令完成
"复位 → 单次加载 → 跑一次解码 → 输出 帧数/113/initlist/NAL 数/err_mbs/首个 ALLOCBUF"，
后续 A/B 只需多跑几次即可得到分布（不再靠单次运行判断）。

### 4.13 2026-11-05：**VDEC 中断从未注册**（结构性缺陷）+ 帧存回执时机前移

#### 根因：vfmw 用 `-D__VFMW_REGISTER_ISR__` 编译 = 中断必须由驱动注册，而移植层没注册
`/proc/interrupts` 里**根本没有 VDH/VDEC 中断线**（VENC 有 `GIC-0 133 venc` 且计数正常）。
于是 VDH 解码完成中断永远收不到，vfmw 每帧只能等满 `CFG_VDH_TIME_OUT`(3000) 超时才继续
→ 现象正是"每帧 3~4 秒、`err_mbs=300` 整帧无数据、偶发正确帧"。
中断号权威来源：`vfmw/product/Hi3798MV200/sysconfig.h`
```
VDM_INT_NUM = 95+32 = 127   (VDH 解码完成)
SCD_INT_NUM = 104+32 = 136  (SCD)
MMU_VDH_NUM = 149+32 = 181  (VDH MMU)
```
vfmw 已导出 ISR 入口 `VCTRL_Isr_0` / `VCTRL_Scd_Isr` / `VCTRL_MMU_ISR`（各自 `bl VDMDRV_IsrProcess` 等后返回 1）。

**修复**（`port/vdec/port_stubs.c`）：在 `hi_vdec_port_stubs_init()` 里按 DT
（`hisilicon,hi3798mv300-vdec`）解析出的 virq 注册三个中断，处理函数分别调用上述 vfmw ISR，
并计数（`g_vd_isr_cnt`）。实测：
```
hi_vdec port: IRQ vdec-vdh registered virq=38
hi_vdec port: IRQ vdec-scd registered virq=39
hi_vdec port: IRQ vdec-mmu registered virq=40
38: 15 ... GIC-0 127 Level vdec-vdh      <= 开始真正收到中断
39:  5 ... GIC-0 136 Level vdec-scd
```

#### 顺带修正：帧存回执（SET_FRAME_BUFFER_NUM）改到"配齐之后"
时间线证据显示 vfmw 在帧存只配了 0~1 块时就开始解码，前 12 帧全错；
配满 16 块后立刻连续输出正确帧。改为：ARRANGE 只在事件里置位
`g_ack_pending[chan]`，由 `HI_VDEC_Task` **先分配、配齐后再回执**
（日志 `TASKACK: chan=0 need=12 cfg=12 ret=0x0`）。

⚠️ 已证伪：在 ARRANGE 事件回调里**同步**调用 `VDEC_AllocMemForDecoder()` 会**死锁板子**
（该回调持 `stAllocMemLock`，分配路径也要它）→ 已回退。

#### 实测（新构建，干净启动单次；用 `vdrun.sh` 自动测）
| 流 | 交付帧 | `113` | `initlist` | `err_mbs` |
|---|---|---|---|---|
| `t60.h264`（P 帧） | 3 | **12** | 11 | `0,0,0,296`（前 3 帧连续正确）|
| `talli.h264`（全 IDR） | 0 | 38 | 29 | `296,300` |

比修复前（`113` 常年 30~70、`initlist` 20~70）明显下降，但仍未达到连续解码，方差依旧。

### 4.14 2026-11-05：**日志刷屏把整机拖慢**（实测 7070 行/30 秒）；VDH 耗时首次可量化

#### 发现：printk 量级惊人，串口 115200 下等于自残
单次 30 秒解码运行产生 **7070 行 dmesg**（`ALLOCFDB` 445、`IMGDBG` 327、vfmw `N: SH:...` 数百…）。
115200 串口每行 ~100B ⇒ 单次运行光串口输出就要几十秒，整机被严重拖慢。
这解释了"每帧几十毫秒~几秒"、"解码断续"、"同一构建时好时坏"的大量怪现象。

两处根因与修复：
1. **vfmw 打印开关被改成"全部打印"**：`IsDprintTypeEnable()` 曾被硬改成 `return 1`。
   已恢复 SDK 原逻辑（只打印 `PRN_ALWS` 与 `g_PrintEnable` 允许的等级）。
2. **移植层自加的高频打印**：`GETES`/`VDECDBG5`（每包）、`IMGDBG`（每次取帧轮询）、
   `ALLOCFDB`（每次分配调用，实测 1191 次/运行）统一挂到新参数 `vdec_dbg`（**默认 0**）。

效果：dmesg 行数 **7070 → 1072~1567**。

#### 首次拿到 VDH 硬件耗时（`/proc/vfmw/vfmw_statis`）
| 列 | 320×240 实测 |
|---|---|
| Syntax | 6~39 us |
| **VDH** | **37,341 ~ 84,772 us（37~85 ms）** |
| IsrProcess | 数十 us ~ 4.2e6（单位可疑）|

即：**硬件每帧解码要 37~85 ms**（300 个宏块），比正常慢约 1~2 个数量级；
进一步印证"时钟/带宽/中断唤醒路径"仍需排查，但也可能是日志拖慢的连带效应，需在静默环境下重测。

#### 最好的一次（静默后单次运行）
交付 **6 帧**，且 `pts=30,31,32,33,34` 五帧在 **8.43~8.53 秒之间连续突发**（间隔约 15~25 ms）——
说明"解码→投递"链路一旦跑起来是可以很快的。

#### 但复测仍是 0 帧（诚实记录）
两次干净启动复测：`frames=0`、`113≈58`。

⚠️ **指标可信度提醒**：`113`/`init list error` 这些计数是从 dmesg 行里数出来的，
恢复打印等级后这些行被过滤，计数**不再与之前可比**（本轮 `initlist=0` 不代表问题消失）。
后续测量统一用：`frames`（程序自带）+ `vdec_dbg=1` 时的明确计数 + `/proc/vfmw/vfmw_statis` 的 VDH 时间。

### 4.15 2026-11-05：VDH 耗时不是吞吐瓶颈（1080p 仅比 320×240 多 14ms）；日志已压到 261 行

#### 关键量化：VDH 时间是"固定延迟"，不是"算力不足"
| 码流 | 宏块数 | VDH 耗时（`/proc/vfmw/vfmw_statis`）|
|---|---|---|
| 320×240 | 300 | 37,283 ~ 37,355 us |
| 1080p（`test.h264`）| 8160（27×）| **51,268 us（仅 1.4×）** |

若受算力/时钟限制，1080p 应约为 320×240 的 27 倍；实测只有 1.4 倍
⇒ **瓶颈是固定的 ~35~50ms 唤醒/调度延迟，而不是硬件吞吐**。
（也排除了"VDEC 时钟过低"的猜测。）

#### 日志已压到 261 行（原 7070 行）
新增两个开关，都可运行时设：
- `vdec_print_always`（默认 **0**）：是否保留 vfmw 的 `PRN_ALWS`（"总是打印"）。
  它每帧打好几行（`SH: luma_we`/`chroma_`/`reorder`/`SCDDRV_CheckDevice`），单次运行 ~1000 行。
- `vdec_dbg`（默认 **0**）：移植层所有高频调试（`GETES`/`VDECDBG*`/`IMGDBG`/`ALLOCFDB`/
  `FILEDBG`/`PUTBM`/`IOCTLDBG`/`EVT:` 等）统一开关。

效果：dmesg **7070 → 261 行**（`vdec_dbg=0`）/ 2636 行（`vdec_dbg=1`）。

#### 一个必须如实记录的"反常"结果
| 模式 | 交付帧（多次干净启动）| VDH 活动 |
|---|---|---|
| `vdec_dbg=0`（静默） | **3/3 次都是 0 帧** | VDH=0，完全没启动解码 |
| `vdec_dbg=1`（有打印） | 1 ~ 6 帧 | VDH 有活动 |

静默后整机变快、送流更"猛"，反而一帧都不出 —— 这说明**问题不在日志速度，而在送流/取流节奏**
（送得太快时 vfmw/SCD 进入某种不启动状态）。下一轮应做**真正的流控**：
`ChanGetBuffer` 在环形缓冲达到阈值时阻塞、或按"一帧进一帧出"握手送流，而不是靠 `usleep` 凑。

### 4.16 2026-11-05：加入"双线程送流/取帧"模型（贴近真实播放器）；送流端已证明不阻塞

之前测试程序是**单线程**："先把 60 个 AU 全灌进环形缓冲，再慢慢取帧"。真实播放器不是这样，
所以本轮给 `vdec_test.c` 加了 `THREADED=1` 模式：**一个线程持续送流，主线程持续取帧**
（`THRDELAY` 控制送流间隔）。

实测（干净启动）：
```
[t=  111.2ms] feed: put 0 ok
[t= 1131.7ms] feed: put 10 ok      <= 送流稳定推进，约 10 AU/s
[t= 4371.6ms] feed: put 50 ok
THREADED done: frames=0
```
- **送流端完全顺畅**（60 个 AU 在 4.4 s 内送完，没有 `GetBuffer` 阻塞/失败）
- 另一次运行里**首帧在 313 ms 就解出**（此前常常 1.5~8 s 才出首帧）⇒ 双线程模型明显改善了启动时延
- 但随后仍然停住：每次运行 VDH 只跑 3 次左右，最终交付 0~1 帧

#### 新增观测点
`/proc/vfmw/scd`（样例存档 `vfmw_scd_info.txt`）：
```
IsScdDrvOpen :0   SCDState :0   HwMemAddr :0x0
```
注意这是**运行结束后**抓的（通道已销毁，SCD 自然关闭），下一轮应在**运行中**抓，
判断 SCD（硬件起始码检测）是否真的被打开、是否为 0 内存地址。

#### 下一步（明确）
1. 运行中抓 `/proc/vfmw/scd` + `/proc/vfmw/channel`，确认 SCD 打开状态与 `DecodeFrameNum` 增长曲线
2. 利用 vfmw 的 proc 写接口（`/proc/vfmw/<entry>`）临时提高 `PRN_CTRL`/`PRN_VDMREG` 等级，
   定位"syntax 线程为何在 3 帧后停住"（现在日志量已可控，可以按需开）
3. 如仍无解，按 §4.6 结论改走 omxvdec 通路

### 4.17 2026-11-05：运行中采样确证"DPB 满即停"；延迟回执逻辑已验证正确

#### 运行中采样（`THREADED=1`，每秒一次读 `/proc/vfmw/channel`）
```
--t=1s DecodeFrameNum:0 OutputFrameNum:0 Ref,Read,New:(-1,0,0) VoQue:(0,0,0)
--t=2s DecodeFrameNum:3 OutputFrameNum:1 Ref,Read,New:(3,0,0)  VoQue:(1,1,1)
--t=3s DecodeFrameNum:3 ...
--t=5s DecodeFrameNum:4 ...
```
即：**解到 3~4 帧、参考帧占满 3 个（`num_ref_frames=3`）后就不再前进**，
而总共只**输出 1 帧**。同时 `/proc/vfmw/scd` 显示运行中 `IsScdDrvOpen:1`（SCD 是打开的，
`SCDState:0` 表示空闲），`LastProcessTime` 有值 ⇒ 排除"SCD 没工作"。

结论收窄为：**vfmw 解出 3~4 帧却只输出 1 帧，DPB 无法滑动 → 解码停住**。
"输出门控"（为什么解的帧不进 VO 队列）就是下一个要查的点。

#### 顺带验证：延迟回执（TASKACK）逻辑是对的
`ACKCHK: chan=0 cfg=12 report=8 extra=4` —— 条件满足后回执已发出；
本次运行交付 **3 帧**。之前"看不到 TASKACK"只是因为它的日志被 `vdec_dbg` 关掉了，不是逻辑没执行。

#### 已证伪
- `vdec_dfs=0`（静态帧存）：仍然 0 帧，不比动态好
- 打印开关不影响本质：`vdec_dbg=1 vdec_print_always=1` 下同样 0 帧（当次）
- 方差依旧：同一构建干净启动多次，交付 0~6 帧不等

#### 下一步
查"解码完成→进 VO 队列"的输出门控：在 `VDEC_RecvFrm`/`SYNTAX_ReceiveImage` 侧统计
`VoQue` 的 write/read 索引增长，并结合 `OutputFrameNum` 判断是"没入队"还是"入了队但被取走"。

### 4.18 2026-11-05：拿到运行中完整通道配置；`/proc/vfmw` 成为主要观测手段

运行中（`THREADED=1`，4 秒时）`cat /proc/vfmw/channel` 全量输出关键项：
```
IsOpen:1  IsRun:1  eVidStd:H264  ChanCapLevel:4
CfgDecMode:0  CfgOutputOrder:1  ErrorThred:0  StreamThred:0   LastFrameState:BLANK
DecodeFrameNum:1   OutputFrameNum:0        <= 4 秒只解了 1 帧、没输出
Ref,Read,New:(3,0,0)   VoQue detail:(0,0,0)
CTX Mem: 0x28df4000 / 2260992    SCD Mem: 0x28ab4000 / 3407872   VDH Mem: 0x0 / 0
VDH INFO: VDH 0 = 0.0%  Cycle State 0/mb      <= VDH 空闲
DFS INFO: Frame size 216992  Reference frame num 4  All frame num 12
```
要点：
- **`VDH Mem Phy/Size = 0x0/0`**（其余通道内存都有值）——VDH 通道内存没登记，值得单独查
- `Reference frame num: 4`、`All frame num: 12`：帧存配置数量符合预期
- 4 秒只解 1 帧，而 VDH 单帧只需 ~37ms ⇒ 时间花在"等"上（等码流/等帧存/等事件）

#### 新增 A/B 开关：`vdec_occfrm_rls`（默认 1）
`VDEC_RecordOccupiedFrame()` 内部会先关"图像输出使能"再恢复；我们现在每还一帧就调它一次，
怀疑在关闭窗口里丢图（对应"解了 3~4 帧只输出 1 帧"）。已加参数便于对比。
本轮 A/B（`=1` / `=0`）各一次干净启动：**都是 0 帧** —— 单次运行方差太大，A/B 需多轮取样。

#### 下一步（按可靠性排序）
1. **切原厂 Android 实机验证**（素材 `/mnt/f/design/Hi3798/FW/BK/BK/`，恢复见 §10）：
   跑一次播放并 `cat /proc/vfmw/channel`，拿到**健康通道**的 `Ref,Read,New`/`VoQue`/`DFS` 数值对照，
   这是当前最快的定位手段（我们自己的数值已全部拿到，缺的就是"正确值长什么样"）
2. 若不便切固件：查 `VDH Mem Phy/Size=0x0` 是否正常，以及 `/proc/vfmw/scd` 的 `HwMemAddr`
3. 用 vfmw 的 `/proc/vfmw/*` 写接口（数值命令）临时提高相关打印等级

### 4.19 2026-11-05：排除"VDH 通道内存"与"送流粒度"两个假设

#### 假设 1（VDH 通道内存未分配）→ 证伪
动态帧存模式下驱动**故意**把 VDH 内存置 0（源码注释"动态帧存方案不需要整块申请"），
所以 `/proc/vfmw/channel` 显示 `VDH Mem Phy/Size = 0x0/0` 属正常。
改用静态帧存（`vdec_dfs=0`）对照，运行中抓到：
```
VDH Mem Phy :0x28da9000   VDH Mem Size :14209024   (13.5MB，分配正常)
DecodeFrameNum :1 -> 2    OutputFrameNum :0
```
⇒ 有 VDH 内存也一样只解 1~2 帧，**不是内存分配问题**。

#### 假设 2（送流粒度不对）→ 证伪
怀疑"按 AU 分段 + 每段打帧尾标记"不符合厂商用法，于是给测试程序加了
`RAWCHUNK=<n>` 模式：**按固定大小送原始码流、不打帧尾**（让 vfmw 用 SCD 自己切帧）。
实测 `RAWCHUNK=4096`（整段 18502B 共 5 块）：**0 帧**，比按 AU 送更差。
⇒ 按 AU 送流（带帧尾）反而是目前最好的送法，排除粒度假设。

#### 新的关键观测：SCD 那边其实"都读走了"
运行中 `/proc/vfmw/scd`：
```
Raw num count:60   Seg current num:0   Seg read addr == Seg write addr   SCDState:0
```
即 60 个包**全部被 vfmw 取走并切分完毕**，SCD 队列已清空、无积压。
但 `DecodeFrameNum` 仍只有 1~2 —— 数据进了 vfmw，却没有变成解码帧。
范围进一步收窄到 **vfmw 内部"syntax 解析 → 送 VDH 解码"这一步**。

#### 下一步：切原厂固件取"健康通道"基准（执行清单）
素材与流程已确认（§7.2、`/mnt/f/design/Hi3798/FW/restore-20261104/`）：
1. 串口持续发 `\x03` 进 `fastboot#`，按 §7.2 的 `setenv bootcmd/bootargs` + `saveenv` 启动厂商 Android
2. 厂商侧跑一次视频播放，同时 `cat /proc/vfmw/channel`、`/proc/vfmw/scd`、`/proc/vfmw/vfmw_statis`
   —— 重点是健康通道的 `Ref,Read,New`、`VoQue detail`、`DFS INFO`、`DecodeFrameNum/OutputFrameNum` 增长速率
3. 记录后用 `board-boot-32M.bin` + `ubuntu-p1.img.zst` 恢复 Ubuntu（§10）
4. 用健康值反推我们缺的东西（最可能是某个 CID 配置或 vfmw 内部状态）

### 4.20 2026-11-05：**找到 cache 一致性问题（重大）**——MMZ 该 uncached，我们用了 cached 线性映射

#### 证据链
1. vfmw 提供了两个 cache 刷新接口：`klib_flush_cache`（`OSAL_FP_flush_cache`）与
   `KernelFlushCache`（`OSAL_FP_kernel_flush_cache`）。**两个都插了计数**，在一次完整解码运行里
   **调用次数都是 0** ⇒ 解码路径上 vfmw 根本不刷 cache，它假定相关内存是 uncached 的。
2. 我们的 MMZ 分配器（`port/vdec/port_stubs.c`）给内核的映射是
   `g_mmz_reg = __va(MMZ_BASE)` + `b->vaddr = g_mmz_reg + off` —— 这是**cached 线性映射**。
3. DT 里 `mmz_reserved: mmz@28000000` **没有 `no-map`**，因此该 96MB 区域仍在
   arm64 线性映射里（cached），并且被内核当作普通保留内存。
4. 于是：CPU（vfmw/驱动）写进 MMZ 的码流、上下文、帧存可能停在 cache 没写回 DDR，
   而 VDH/SCD 硬件直接读 DDR ⇒ 读到旧数据 ⇒ **解码随机失败、`err_mbs` 整帧错误、
   同一构建时好时坏**（正是长期困扰我们的现象）。
   （注：用户态经 `hi_mmz` 回退路径 `remap_pfn_range + pgprot_writecombine` 映射，是 uncached 的，
    所以"用户读到的帧"与"内核/hardware 看到的"属性不一致，进一步加剧问题。）

#### 修复方案（改动已就绪，**必须配套刷内核**）
1. DT：给 `mmz@28000000` 加 `no-map;` ⇒ 该区域不再进线性映射
2. 驱动：`g_mmz_reg = ioremap_wc(MMZ_BASE, MMZ_SIZE)` ⇒ 全区域 uncached，CPU 写直达 DDR
3. 已验证 DTB 可编译：`make hisilicon/hi3798mv300-poc.dtb` 通过（10,890 B）

> ⚠️ **配套约束**：新模块（md5 `cb6c7999…`）**必须**与带 `no-map` 的新 DTB 一起用；
> 旧 DTB + 新模块会导致 `__va` 时期望的线性映射不存在 → 立即崩。
> 板上目前仍是旧组合（模块 `2931b43…`），不要单独把新模块拷上去。

#### 下一步（下一轮执行）
1. 编译内核镜像（`Image` + 新 DTB 打进 uImage），进 fastboot `printenv` 确认 bootcmd 的分区/块号
2. 写入后启动，验证：`DecodeFrameNum` 是否开始连续增长、交付帧是否 >10
3. 若仍不理想，再回到"vfmw 输出门控"继续查（但 cache 一致性是必须先排除的基础问题）

### 4.21 2026-11-05：**内核刷写通道打通**（已成功换入 no-map 内核并启动）；新组合在 ioctl 路径崩溃

#### 一、刷写通道已验证（重要能力，后续可复用）
内核在 eMMC **p6（块偏移 `0x7000`，32MB）**，形式是 **FIP（BL31 + uImage）**，可**从 Ubuntu 直接 dd 写入**
（历史做法 §runbook 第 136 行）。本轮完整走通：
1. 构建：`Image` + 新 DTB（`cpp -DROOTFS_BOOT -DGENERIC_MMC -DLOW_MMC` + `dtc`）→
   `mkuimage.py --pack --load/--ep 0x2000000 --pad-to <ISIZE>` → `fip_create --bl31 bl31_smp_fixed.bin --bl33 uImage` →
   补齐到 `0x5D34*512 = 12,216,320 B`
2. 板上：`dd if=/root/fw/fip_ct_pad.bin of=/dev/mmcblk0 bs=512 seek=$((0x7000)) conv=fsync; sync`
3. 复位 → **成功启动**，启动日志确认 DT 生效：
   `OF: reserved mem: 0x28000000..0x2dffffff (98304 KiB) nomap non-reusable mmz@28000000`
   `/proc/device-tree/reserved-memory/mmz@28000000/no-map` 存在。
- 回滚镜像：`/home/jason/bringup-7.3/out/fip_desk_pad.bin`（md5 `977e1d6e…`，与板上原 p6 逐字节一致，已验证）
  刷回命令同上。**这是安全的 AB 手段，可放心使用。**

#### 二、新组合（no-map DT + `ioremap_wc` 模块）在 ioctl 路径崩溃
现象：`insmod` 正常；跑解码测试时内核 Oops → `panic_on_oops=1` 自动重启（复现 2 次）。日志：
```
IOCTLDBG: cmd=c370268b evtptr=ffff800078d6f440
Unable to handle kernel paging request at virtual address ffffffffc221ad08
Unable to handle kernel NULL pointer dereference at virtual address 0000000000000000
Data abort: EC=0x25 DABT, FSC=0x06 level 2 translation fault, user pgtable
Call trace: vprintk ← VDEC_Ioctl+0xf8 ← HI_DRV_UserCopy ← VDEC_DRV_Ioctl ← __arm64_sys_ioctl
Code: ... (394002c1)   /* ldrb w1,[x22] */
```
即：**模块地址空间（`0xffffffffc2…`）的地址在用户页表上下文里被当成数据解引用**。
两种可能：① 用户态 mapp 该 nomap 区域失败/映射异常，ioctl 里拿到的用户指针无效；
② 某处仍按"它是线性映射 RAM"处理（例如把物理地址当内核 VA 用）导致野指针。

#### 三、当前状态（已回滚，板子可用）
- 内核：已刷回 `fip_desk_pad.bin`（无 no-map），启动正常
- 模块：`/root/hi_vdec.ko = 2931b43…`（原版，`__va` 线性映射）；解码 1 帧（与之前一致）
- 保留待用：板上 `/root/fw/fip_ct_pad.bin`（新内核）、`/root/hi_vdec_ct.ko`（`ioremap_wc` 版模块）
  本地：`out/fip_ct_pad.bin`、`out/ct.dtb`、`port/vdec`（源码即 uncached 版）

#### 四、下一轮（按顺序）
1. 先定位崩溃点：新内核 + 新模块，只 `insmod` 不跑解码；再单独测试用户态 mmap 该区域
   （`HI_MPI_MMZ_MapSize` 走 `/dev/hi_mmz` 的 `remap_pfn_range` 回退分支，nomap 区域可能不支持）
2. 若用户映射是问题：改从驱动 ioctl 提供 mmap，或把 MMZ 做成"驱动自己 mmap + ioremap"的一致实现
3. 崩溃解决后再验证 cache 一致性假设对解码的影响（`DecodeFrameNum` 是否连续增长）

### 4.22 2026-11-05：no-map 组合的第一处崩溃已定位并修复（`flush_dcache_page` 用于 ioremap 地址）；暴露第二处（SCD 中断路径 NULL）

#### 崩溃 1（已修）：`hi_vdec_flush_range` 对 ioremap 地址用了 `flush_dcache_page(virt_to_page())`
这是**真实 bug**，与 cache 无关也一直在：`virt_to_page()` 只接受**线性映射**地址；
MMZ 改成 `ioremap_wc` 后该地址在 vmalloc 空间 → 算出非法 `struct page` → Oops：
```
pc : flush_dcache_page+0x8/0x24
lr : hi_vdec_flush_range+0x44/0x70 [hi_vdec]
（同目录 port_stubs.c 的 HI_DRV_MMZ_Flush 有同样写法）
```
修复：两处都改为内联 `dc civac` 循环 + `dsb sy`（`vdec_dc_civac()`），
对 uncached 映射也安全（等价空操作）。修复后该崩溃消失。

#### 崩溃 2（待查）：SCD 中断处理里 NULL 解引用
```
pc : CheckStream.part.3+0x48   lr : InsertStreamSeg+0x154
Call trace: CheckStream ← InsertStreamSeg ← ProcessNotMpeg4ScdUpMsg
            ← ProcessScdReturn ← SM_SCDIntServeProc ← VCTRL_Scd_Isr ← 我们的 vdec-scd ISR
Unable to handle kernel NULL pointer dereference at 0x0  (ldrb w1,[x22], x22=0)
```
即在 **SCD 中断上下文**里 vfmw 处理上行消息时解引用了空指针。
怀疑与"我们的 ISR 无条件转调 `VCTRL_Scd_Isr()`"有关（SCD 中断可能在无活动通道/通道状态切换时到来）。
这条**未必是 no-map 引入的**：旧组合历史上也偶发挂死，只是没有这次这么容易复现。

#### 当前状态（已回滚，稳定）
- 内核刷回 `fip_desk_pad.bin`（无 no-map）；DT 确认 `mmz@28000000` 只有 `name reg`
- 模块 `/root/hi_vdec.ko = 2931b43…`（原版）；测试 2 帧、无 Oops
- 保留：`/root/fw/fip_ct_pad.bin`（no-map 内核）、`/root/hi_vdec_ct.ko`（含 flush 修复的 uncached 版）

#### 下一轮
1. 给 `vdec-scd` ISR 加保护：只在"有活动通道且 SCD 有 pending 消息"时转调 `VCTRL_Scd_Isr()`
   （或先读 SCD 状态寄存器确认），再重试 no-map 组合
2. 若崩溃消除，立即验证 cache 一致性对解码的影响（`DecodeFrameNum` 是否连续增长）

### 4.23 2026-11-05：no-map 方案遇到 vfmw 的"线性映射假设"（暂时放弃）；改为在交接点做定向 cache 维护

#### 一、SCD 中断加保护后，no-map 组合仍然崩 —— 崩溃点在校验码流
给 `vdec-scd` ISR 加了"仅当有活动通道才转调 `VCTRL_Scd_Isr()`"的保护（`g_vdec_running_chan`，
驱动在 `enCurState=RUN` 时 ++、离开 RUN 时 --）。但同一处崩溃依旧：
```
pc : CheckStream.part.3+0x48   lr : InsertStreamSeg+0x154
x0=x1=x2=0   x3=0x28ab4000(SCD 缓冲的物理地址)
Call trace: CheckStream ← InsertStreamSeg ← ProcessNotMpeg4ScdUpMsg ← ProcessScdReturn
            ← SM_SCDIntServeProc ← VCTRL_Scd_Isr
```
`x3` 是一个**物理地址**、而指针是 0 —— 说明 vfmw 内部有把"物理地址当线性映射 VA"用的路径
（`phys_to_virt` 语义）。在 `no-map` 下该地址不再映射，于是拿到空/非法指针。
⇒ **no-map + ioremap_wc 这条路线与 vfmw 的假设冲突，暂时放弃**（已回滚内核与模块）。

#### 二、改为"保留缓存映射 + 交接点定向 cache 维护"（本轮实现）
既然不能换映射，就在**两个 CPU↔硬件交接点**做 `dc civac`：
1. **用户写码流 → 内核/硬件读**：`VDEC_PutStrmBuf` 里已有的 `hi_vdec_flush_range()`，
   其实现从 `flush_dcache_page(virt_to_page())` 改为内联 `dc civac`（原实现对 vmalloc 地址会崩，是真 bug）
2. **硬件写 YUV → 用户读**：`VDEC_RecvFrm` 取帧成功后，按帧的 **物理地址** 新增
   `hi_vdec_flush_phys()`（内部经 MMZ 表换算 VA 后 `dc civac`）刷新 Y/C 平面
3. 同时给 `vdec_uncached_mmz` 加了模块参数（默认 0=`__va` 缓存映射；1=`ioremap_wc`，需 no-map DT），
   两种模式一个构建都能测，便于将来继续验证 cache 假设

#### 三、实测（当前构建，默认参数）
3 次干净启动：**0 帧、无 Oops**。定向刷新解决了"崩溃/一致性正确性"，但**没有改善交付帧数**，
说明 `DecodeFrameNum≈1~2` 的主因不在这些交接点的缓存一致性上。

### 4.24 2026-11-05：MMZ 映射健壮性增强；实测已到"噪声底"（提出测量方法学要求）

#### 一、排除"MMZ 映射失败导致空指针"
上一轮崩溃现场出现"物理地址在、指针为 0"，怀疑 `HI_DRV_MMZ_Map` 只认块起始地址、
vfmw 用块内偏移（base+off）请求时会失败并返回 NULL。已增强为**支持块内任意地址**：
```
map phys=0x28000000 / 0x28600000 / 0x28604000 / 0x286b3000 / 0x286b4000 ...
mmz map NOT FOUND 次数 = 0     base+0x 次数 = 0
```
⇒ 所有映射请求都是块起始地址、全部成功。**该假设排除**（增强保留，无害）。

#### 二、把近期改动都参数化，便于 A/B
| 参数 | 默认 | 作用 |
|---|---|---|
| `vdec_scd_isr_guard` | 0 | 1=SCD 中断仅在 `g_vdec_running_chan>0` 时转调 vfmw（no-map 崩溃时加的守卫；默认关） |
| `vdec_flush_put` | 1 | PutBuffer 后对码流区间做 `dc civac` |
| `vdec_flush_frame` | 1 | 取帧后按物理地址刷新 Y/C 平面 |
| `vdec_uncached_mmz` | 0 | 1=MMZ 用 `ioremap_wc`（需 no-map DT）；0=`__va` 缓存映射 |

#### 三、单次运行已无法区分优劣 —— 必须多轮取样
最近 6 次"干净启动 + 单次加载 + 单跑"结果：**全部 0 帧**（含 flush 开关全关的对照）。
而更早的构建偶尔能出 1~2 帧。结合历史数据，**同一构建的交付帧数在 0~2 之间随机波动**，
单次运行（甚至两次）不足以判定 A/B。今后任何 A/B 必须 **每个配置 ≥5 次干净启动**，
并在文档中给出分布，不能再用单次结果下结论（此前的若干"改善"结论可能都受此影响，已在 §4.10 等标注方差）。

#### 四、M2 现状（诚实评估）
- 已修：帧存上报长度、动态帧存默认、VDEC 中断注册、图像输出使能恢复、占用帧上报时机、
  cache 维护 API 误用（`flush_dcache_page(virt_to_page)`）、MMZ 块内映射
- 未解：`DecodeFrameNum` 长期只到 1~2，`SYNTAX_ReceiveImage` 队列空（§4.11）
- 已排除：VDH 内存、送流粒度、EOP、静态帧存、cache 映射方式（no-map 与 vfmw 冲突）、MMZ 映射失败
- 建议后续两条路（择一）：
  1. **移植 omxvdec**（厂商 Android 实际使用、语义已被验证；工作量大但要绕开的坑都绕开了）
  2. **切原厂固件取健康通道基准**（`/proc/vfmw/channel` 数值对照，见 §4.19 清单）

### 4.25 2026-11-05：与 omxvdec 逐项对照通道选项——发现 `s32MaxRefFrameNum` 从未设置（=0）

#### 做法：不看 CID 名，改看"值"
omxvdec 是厂商 Android 实际使用的通路，把它的通道选项初始化（`decoder_init_option` /
`decoder_init_capability`）与我们驱动传给 vfmw 的 `VDEC_CHAN_OPTION_S` 逐项对照。

#### 加诊断后看到的真实值（关键）
新增 `CHANOPT` 日志，打印**在 cap-level 处理器执行之后**的最终选项：
```
CHANOPT: cap=4 max=1920x1088 scdbuf=3063808 dispnum=2 extra=4 dynfs=1 maxref=0  DispFrameNum=4 BUF_FRAME=2
```
| 项 | 我们 | omxvdec | 结论 |
|---|---|---|---|
| `s32MaxWidth/Height` | 1920x1088 | 按 cap 档（SD/HD/UHD） | ✅ 一致 |
| `s32SCDBufSize` | 3,063,808 | `g_SegSize*1024*1024` | ✅ 量级一致 |
| `s32DisplayFrameNum` | 2 | `g_DispNum` | 基本一致 |
| `s32ExtraFrameStoreNum` | 4 | `g_DispNum` | 基本一致 |
| **`s32MaxRefFrameNum`** | **0** | **SD=12 / HD=10 / UHD=4** | ❌ **我们从未设置** |

原因：SDK 的 cap-level 初始化函数（`VDEC_InitCapLevel_FHD` 等）只设 MaxWidth/Height/SCDBufSize，
`s32MaxRefFrameNum` 仅在 **MVC / MJPEG** 分支被赋值（16 / RefFrameNum-PLUS_FS_NUM/2），
普通 H.264 路径一直是 0。而 vfmw 用这个值限定 DPB 的参考帧数——**0 会让 DPB 极小，
解 1~2 帧后无法继续**，与长期现象高度吻合。

#### 改动
新增模块参数 `vdec_maxref`（默认 16）：
```c
if (pstChan->stOption.s32MaxRefFrameNum <= 0)
    pstChan->stOption.s32MaxRefFrameNum = vdec_maxref;
```
实测确认生效：`CHANOPT: ... maxref=16`。**但本轮单次运行仍是 0 帧** ——
按 §4.24 的方法学要求，这需要 ≥5 次干净启动才能判定，下一轮补齐分布。

#### 下一轮
1. `vdec_maxref` = 0 / 4 / 16 三档，各 ≥5 次干净启动，比较交付帧数与 `DecodeFrameNum`
2. 顺带核对 `g_DispNum` 的厂商默认值，以及 `s32DisplayFrameNum` 是否也需按 cap 调整

### 4.26 2026-11-05：`vdec_maxref` 的 A/B 分布（按方法学 ≥5 次干净启动）

#### A/B：maxref=16 vs maxref=0（每档 5 次干净启动，THREADED=1 THRDELAY=15）
| maxref | 每次交付帧 | 出帧次数 |
|---|---|---|
| 16 | 0, 0, 1, 0, 2 | **2/5** |
| 0  | 0, 0, 0, 0, 0 | **0/5** |
结论：`maxref>0` 是"能出帧"的必要条件之一（0 时 5/5 完全无帧）；但 16 也不保证出帧。

#### 追加对照
- `maxref=32`（3 次）/ `maxref=16`（3 次）：出帧 0,0,2 / 0,0,0，
  但**运行中采样 `DecodeFrameNum` 始终只有 1~2**（12 秒时仍是 1~2，而 SCD 已消费全部 60 个包）
- `maxref=8`（3 次）：0/3 出帧；`ACKCHK` 与 16/32 完全一致（见下）

#### 关键观测（本轮新增）
1. **动态帧存下 `VDH Mem Phy/Size = 0x0/0`**（静态模式曾是 0x28da9000/14209024）。
   注意 omxvdec 在动态模式下也把 VDH 尺寸传 0（`decoder_vfmw.c:1061`），故这可能是正常语义。
2. 帧存账目固定为：
   ```
   ACKCHK: chan=0 cfg=12 report=8 extra=4
   ```
   `needed = report + extra - cfg = 8 + 4 - 12 = 0` ⇒ 驱动不再额外分配帧存。
   `maxref` 取 8/16/32 都不改变这三个数 ⇒ vfmw 的 ARRANGE 需求与 maxref 无关。
3. 运行中 `/proc/vfmw/channel`：`DecodeFrameNum:2 OutputFrameNum:0`,
   `Ref,Read,New:(3,0,0)`, `VoQue detail:(0,0,0)`, `VDH 0: 0.0%`, `Cycle State: 0/mb`
   ⇒ 3 块帧存被当作参考帧占住，VO 队列全空，VDH 之后不再被启动。
4. `/proc/vfmw/vfmw_statis` 的 VDH/IsrProcess 列出现 4.2e6 µs（≈4.3 s）量级的累计值，
   说明 VDH 中断/等待曾长期空转，之后不再有解码活动。

#### 推断与下一步
- 出帧 = f(maxref>0) 已被证实；但**卡在 2 帧**与 maxref、帧存数量都无关
- 下一步应查"vfmw 为何不再启动 VDH"：统计**每帧的 VDH 中断次数**（`g_vd_isr_cnt[0]` 增量），
  若只启动 2 次，则问题在 syntax→VDH 的判定（例如等待 more-data / EOP / `WaitMoreStart`）；
  若启动很多次但无输出，则是 VDH 侧参数或帧存状态机
- 另可试：在 maxref=16 基础上开启 EOP（`vdec_eop=1`）重测 5 次，看是否解除等待

### 4.27 2026-11-05：**用中断计数把瓶颈钉在 syntax→VDH**（SCD 60 次 vs VDH 2~4 次）；EOP 复测统计上不成立

#### 一、VBH/SCD 中断计数（决定性定位）
给两个 ISR 都加了计数打印（`VDHISR n=…` / `SCDISR n=…`）：
```
SCDISR = 60 (每包一次)      VDHISR = 2~4
DecodeFrameNum = 2         OutputFrameNum = 0
```
即：**60 个包全部被 SCD 扫描处理，但 VDH 只被启动 2~4 次** ⇒ 瓶颈在
「SCD 上行消息 → syntax 判定 → 启动 VDH」这一步，不在送流、不在 SCD、不在 VDH 输出。

#### 二、线程栈（sysrq `t` 抓取，卡住时）
```
HI_VFMW_VideoDe   R  OSAL_WaitEvent ← Osal_WaitWaitQue ← VCTRL_RunProcess
VDH_Distributor   S  OSAL_WaitEvent_l ← VDH_Distributor
HI_VDEC_Task      D  msleep ← VdecTaskFunc
```
syntax/ctrl 线程停在事件等待上，VDH 分发线程也在等；驱动任务线程正常 msleep 轮询。

#### 三、排除项（本轮新增）
| 假设 | 证据 | 结论 |
|---|---|---|
| 帧存不足 | 12 块帧存(200704)+4 块 PMV(20480) 全部实际分配；`ACKCHK cfg=12 report=8 extra=4` | ❌ |
| 静态 vs 动态帧存 | `vdec_dfs=0` + maxref=16：VDHISR 仍只有 2/4 | ❌ 与模式无关 |
| AU 切分粒度 | `WHOLE=1`（整文件单包）：SCDISR=1、能解 3 帧/VDH 5 次 | ❌ 单包也能解，但同样会停 |
| 送流不足 | `PUTBM: try=60 ok=59` | ❌ 60/60 入队 |

#### 四、EOP（帧结束标记 NAL）复测：单次惊艳但**统计上不成立**
SDK 默认 `DEFAULT_EOP_EN=TRUE`，我们此前因"污染解析"把它默认关了（并一直用 `NOEOP=1`）。
在 `maxref=16` 基础上开 `vdec_eop=1`，**6 次干净启动**：
```
frames: 8, 0, 0, 0, 0, 0     VDHISR: 11, 1, 2, 0, 1, 2     SCDISR: 60 (每次)
```
第一次 8 帧 / VDH 11 次看着像突破，但后续 5 次全部 0 帧 ⇒ **那是一次离群值**。
⇒ EOP 不是可靠解法（结论与 §4.26 的方法学一致：单次结果不可信，必须看分布）。
未来若要再试 EOP，应固定 `vdec_eop=1` 作为基线而不是一跑一议。

### 4.28 2026-11-05：**纠正一个长期误判——测试在 ~12s 就销毁通道，我们一直在"已结束"状态下判断"卡死"**

#### 一、怎么发现的
分时采样（每 3 秒读一次 `/proc/vfmw/channel` 与 `/proc/vfmw/scd`）：
```
t=8s   DecodeFrameNum:4  OutputFrameNum:1  IsScdDrvOpen:1  Raw num:59
t=11s  DecodeFrameNum:4  OutputFrameNum:1  IsScdDrvOpen:1  Raw num:60
t=14s  /proc/vfmw/channel 里已没有 DecodeFrameNum 字段；IsScdDrvOpen:0
```
⇒ **通道在 t≈12~14s 已被测试程序销毁**（`vdec_test` 在"送流结束 + 3s 后"就 `ChanBufferDeInit/FreeChan`）。
历史上大量「VDH 只启动 2~4 次」「DecodeFrameNum 卡在 2」的结论，都是在这个时间窗**之后**采样的，
属于**测量假象**。

#### 二、测试程序加"循环送流"后，解码其实是在稳定推进
给 `vdec_test` 增加 `REPEAT=1`（循环送流）与 `REPEATSEC`/`POLLSEC` 参数，然后：
```
REPEAT=1 REPEATSEC=18 THREADED=1 THRDELAY=15
t≈6s  DecodeFrameNum:1     t≈10s 3     t≈14s 5     t≈18s 7     t≈22s 8
VDHISR = 8~9（与 DecodeFrameNum 一致）
```
⇒ **解码链路是通的、在持续工作**，只是**非常慢（约 0.4 fps）**，且 `OutputFrameNum` 一直是 0。

#### 三、新的待解问题（从本轮开始才是真问题）
1. **每帧约 2.3~4.3 秒**：VDH 中断时间戳间隔 ≈2.3s；`/proc/vfmw/vfmw_statis` 里
   `VDH` 列出现 4,290,373 µs、`IsrProcess` 列出现 4,246,773 µs 这种量级
   ⇒ 强烈提示**每帧都在等某个超时**（SDK 配置里 `VFMW_VDH_TIME_OUT=1000ms`、
   `VFMW_SCD_TIME_OUT=2000ms`，与观测到的 2.3s 同量级）
2. **`OutputFrameNum` 恒为 0**：解码出的帧没有进入 VO 队列
3. 对照实验：`vdec_occfrm_rls=0` 与默认完全一致（都是 1,3,5,7,8）⇒ 占用帧上报机制不是节流源

#### 四、下一步（明确）
1. 在 `VDEC_Chan_RecvFrm` 与 `SET_IMG_OUTPUT_INFO` 路径上打点，确认帧在驱动侧是否被"扣住"
2. 统计连续供流下 `SCDISR` 的速率（若 SCD 每帧都在等 2s 超时，则问题在 SCD 上行消息消费）
3. 用 `vfmw_diff`（每 100ms 差分）观察 `VDH` 列的累计值在单帧内如何增长，定位超时点

> 结论一句话：**M2 不是"解码卡死"，而是"解码极慢 + 不出帧"**。此前基于 12s 窗口的所有"卡死"推断作废。

### 4.29 2026-11-05：继续缩小"每帧 2.3~4.3 秒"的范围

#### 排除项（本轮）
| 假设 | 做法 | 结果 |
|---|---|---|
| `RecvFrm` 内部阻塞拖慢 | 给测试的每次 `ChanRecvFrm` 计时，>50ms 打印 | **SLOWCALL 次数=0** ⇒ RecvFrm 立即返回，不是它拖慢 |
| 占用帧上报机制是节流源 | `vdec_occfrm_rls=0` vs 默认，连续供流 | 两者 `DecodeFrameNum` 完全一致（1,3,5,7,8）⇒ ❌ |
| 帧存不足 | 12 块帧存 + 4 块 PMV 实际分配 | ❌（见 §4.27） |

#### 数据
- 连续供流 16~18s：`DecodeFrameNum` 每 4 秒 +2（≈0.4 fps），`VDHISR` 与 `DecodeFrameNum` 一致
- `/proc/vfmw/vfmw_statis` 的 `VDH` 列大量出现 `4,290,373 µs`、`IsrProcess` 列 `4,246,773 µs`
  ⇒ 量级与 SDK 的 `VFMW_VDH_TIME_OUT=1000ms`/`VFMW_SCD_TIME_OUT=2000ms` 同阶
- 连续供流下 `OutputFrameNum` 恒 0；用户侧 `ChanRecvFrm` 拿不到有效帧（`frames=0~1`）

#### 稳定性提示
本轮有一次"连续供流 + `vdec_dbg=1`"运行导致整机重启（未抓到 Oops，随后两次相同配置均正常）。
判断为偶发（可能是 SCD ISR 路径旧问题），后续长时间连续供流测试需**同时开串口记录**。

#### 下一步（按顺序）
1. 在 `VCTRL_Isr_0` 包装里打印时间戳与 `VDHISR` 序号，和 `DecodeFrameNum` 对齐，
   确认 2.3s 是"VDH 启动→完成"还是"完成→下次启动"
2. 用 `/proc/vfmw/vfmw_diff`（100ms 差分）看 `VDH` 列在单帧周期内何时跳变，锁定等待点
3. 若确认是"完成→下次启动"之间的超时：重点查驱动是否有该发的"帧已就绪/可复用"通知没发
   （对照 SDK `VDEC_Chan_RecvFrm`/`RlsFrm` 上下游调用与 vfmw 的 CID 时序）

### 4.30 2026-11-05：清除"中断重复注册"隐患；再排除两项

#### 一、发现并修掉"中断被处理两次"
SDK 驱动**不**调用 `VCTRL_Isr_0`：`__VFMW_REGISTER_ISR__` 打开时是 **vfmw 自己**
通过 `osal_request_irq()` 注册 ISR（日志 `hi_vdec port: request_irq hwirq=127 -> virq=38`）。
我们移植时又加了一层 wrapper ISR 调 `VCTRL_Isr_0()` ⇒ 每次中断被处理两次。
已改为 `vdec_own_isr`（默认 0）只保留 vfmw 自身注册：
```
hi_vdec port: skip wrapper IRQ registration (vfmw registers its own ISRs)
```
**实测：解码速度与出帧数完全不变**（仍 ~0.4 fps、`OutputFrameNum` 0~1）⇒ 双注册不是根因，
但这是正确性修复，保留。

#### 二、再排除两项
| 假设 | 做法 | 结果 |
|---|---|---|
| 帧尾标记语义不对（vfmw 应靠 SCD 自己切帧） | `NOBOUND=1`（`bEndOfFrame=FALSE`）+ 连续供流 | 曲线与默认一致（1,2,5,6,7）⇒ ❌ |
| 帧存/占用房机制 | `vdec_occfrm_rls=0` | 与默认一致 ⇒ ❌ |

#### 三、当前事实（连续供流，18s 窗口）
```
t≈5s  Decode:1   t≈8s 2   t≈11s 5   t≈14s 6   t≈18s 7
OutputFrameNum: 0~1     用户侧交付有效帧: 0~1
```
即：**解码在推进（0.4~1 fps，有突发），但输出队列几乎不增长**。
`vfmw_statis` 的 `VDH` 列 4,290,373 µs 量级说明 vfmw 认为**每帧 VDH 耗时 ~4 秒**
——这不像真实硬件耗时（320x240 实测 VDH 曾 37ms），更像**等待/超时被计入 VDH 统计**。

#### 四、下一轮（聚焦输出/回收握手）
1. 在驱动 `VDEC_Chan_RecvFrm` → `VCTRL_GetChanImage` 路径加返回码统计（`ret=-1/-2/-3` 分布），
   确认是"VO 队列空"还是"图像输出被禁用"
2. 查 `SET_IMG_OUTPUT_INFO` 的 NetEffect：在 `VDEC_RecordOccupiedFrame` 里置 1 之后，
   是否有别处又把它置 0（我们移植里有 7 处调用，SDK 只有 2 处）
3. 统计驱动侧占用帧（12 块）在各状态下的数量随时间变化，判断是否被 vfmw 一直持有

### 4.31 2026-11-05：**关键线索——驱动打印（vdec_dbg）让解码从 0.4fps 变成 1~2fps 且能出帧**

#### 一、连续供流正式基线（5 次干净启动，无打印）
```
REPEAT=1 REPEATSEC=16 THREADED=1 THRDELAY=15 maxref=16
交付帧: 1, 0, 0, 0, 0          14s 时 DecodeFrameNum: 4, 6, 5, 6, 6
```

#### 二、同一配置加 `vdec_dbg=1`（3 次干净启动）
```
交付帧: 17, 10, 9              14s 时 DecodeFrameNum: 24, 20, 18
```
**解码速度提升 3~4 倍，且帧能稳定交付**。⇒ 系统本身**有能力**跑起来，
现在的瓶颈是**时序/同步问题**：printk 拖慢驱动路径后，某种竞争被规避。

#### 三、尝试定位（本轮未成功）
| 变量 | 结果 | 结论 |
|---|---|---|
| 用户侧取帧间隔 `POLLDELAY=30/60ms` | f=0,1,0,0；dec 8,7,6,6 | 不是"用户取帧频率"造成 |
| 仅打开 `IMGDBG`（每帧一次打印，新增 `vdec_dbg_img`） | f=1,0,0；dec 5,3,4 | 不是这一条打印造成 |

⇒ 效应来自 `vdec_dbg` 打开的**其他**打印（`FILEDBG`/`IOCTLDBG`（ioctl 路径）、
`VDBG`（adapter）、`MAPCHK` 等）。下一步应把打印**按组拆开关**做二分，锁定是哪一段的时序在起作用。

#### 四、值得注意的其他观测
- `VCTRL_GetChanImage` 返回码分布：`-1` 658 次、`0` 348 次、`1/2/3` 少量；
  且 `IMGD: ret=-1 f4=1 f12=1 f8=1`（IsOpen/IsRun/IsImgOutputEn 都正常）
  ⇒ 不是"输出被禁用"，而是"暂时无帧可给"
- `NOORDER=1`（`bOrderOutput=FALSE`）：f=0,2,0；dec 6,8,6 —— 略好但不决定性
- 连续供流下 `DecodeFrameNum` 仍按 ~0.4 fps 推进（无打印时）

#### 五、下一轮计划（明确）
1. 把 `vdec_dbg` 的打印按模块拆成 3~4 个参数（ioctl / adapter / 驱动任务 / cache/map），
   逐组打开做二分，锁定产生时序效应的那一段
2. 定位后在对应路径用**显式同步**替代 printk 副作用（锁顺序、内存屏障、或重试）
3. 若最终证实是"驱动任务线程与 ioctl 路径对 `BUFMNG` 锁的竞争"，则把锁粒度缩小/改用 mutex

> 这是 31 轮来第一次看到**交付帧 ≥10** 的可重复结果（3/3），意义重大：M2 不是硬件不通，而是同步问题。

### 4.32 2026-11-05：`vdec_dbg` 效应确认可重复；二分未定位到单条打印 ⇒ 更像全局时序竞争

#### 一、可重复性确认（共 6 次干净启动，`vdec_dbg=1`）
```
交付帧: 17, 10, 9, 10, 5, 7        14s 时 DecodeFrameNum: 24, 20, 18, 19, 7, 13
```
对照无打印基线（5 次）：`交付帧 1,0,0,0,0`、`DecodeFrameNum 4,6,5,6,6`。
⇒ 效应**稳定可重复**（6/6 次都有 ≥5 帧）。

#### 二、分组二分（每组 3 次干净启动，其余打印关闭）
| 开关（新增参数） | 覆盖的打印 | 结果 |
|---|---|---|
| `vdec_dbg_put=1` | `VDECDBG3/4`（每包 PutBuffer 路径） | f=0,2,0；dec 4,3,4 ⇒ 无效 |
| `vdec_dbg_alloc=1` | `ALLOCFDB/ALLOCREADY/SCDCOND`（任务分配循环） | f=0,0,0；dec 4,4,3 ⇒ 无效 |
| `vdec_dbg_img=1` | `IMGDBG`（每帧取图） | f=1,0,0；dec 5,3,4 ⇒ 无效 |
| `vdec_dbg_osal=1` | `EVWAIT/EVWAKE/WQWAIT`（vfmw 事件等待路径） | **f=17,1,1**；dec 21,6,7 ⇒ **部分** |
| `POLLDELAY=30/60ms` | 用户取帧间隔 | f=0,1,0,0 ⇒ 无效 |
| `vdec_ack_delay=30/100ms` | 帧存回执前延时 | f=0×4 ⇒ 无效 |
| `vdec_task_ms=10/30` | 驱动任务线程轮询间隔 | f=0,0,0,1 ⇒ 无效 |

⇒ **没有任何单组能复现完整效果**（最接近的是 OSAL 事件路径组），
说明起作用的是**总 printk 量带来的整体调度/时序改变**，即典型的**全局时序竞争**。

#### 三、顺带修掉一处真实竞态（正确性，暂无性能改善）
任务线程读 `stVFMWConfiguredBufferNum` / `stVFMWReportFrameInfo` 时没有持锁，
而这两个字段由 vfmw 线程在 `VDEC_Event_ArrangeFrameBuf()` 里持 `stAllocMemLock` 写入 ⇒ 撕裂读风险。
已改为：**锁内取快照并决策、锁外调用 `pfnVfmwControl`**；`g_ack_pending`/`g_occfrm_pending` 加 `volatile`。
实测（3 次）：f=0,0,3；dec 6,6,8 —— 与基线同量级，未立即体现改善（但这个竞态必须修）。

#### 四、下一轮
1. 直接验证"全局减速"假设：加 `vdec_slow_us=N`，在 PutBuffer / RecvFrm / 任务循环各插一小段 `udelay`，
   只要总量与 printk 相当，看能否复现 9~17 帧 ⇒ 若可以，问题定性为纯时序
2. 找真正的同步点：重点看我们引入的"延迟回执/占用帧上报"与 vfmw 线程之间的时序依赖，
   尤其是 `VDEC_RecordOccupiedFrame` 里那次 `SET_IMG_OUTPUT_INFO(1)`（锁外调用）是否与解码线程竞争
3. 若证实是 `SET_IMG_OUTPUT_INFO`/`REPORT_OCCUQIED_FRM` 的时序问题：改为在一个受控的线程里串行执行

### 4.33 2026-11-05：否决"超时"与"SMMU"两个假设；交付逻辑与 SDK 一致 ⇒ 需引入 ftrace

#### 一、超时假设：否决
把 `CFG_SCD_TIME_OUT / CFG_VDH_TIME_OUT` 从 2000/3000 改为 **100/100** 重新编译（3 次干净启动）：
```
dec(14s) = 6, 6, 6     交付帧 0,0,0
```
与默认 2000/3000 的 `dec=4,6,5,6,6` **完全相同** ⇒ 每帧那 ~2.3s **不是** vfmw 的超时等待。
（已把 Kbuild 恢复为官方值；注意官方 `CFG_VDH_TIME_OUT=1000`，我们是 3000，但无实质影响）

#### 二、SMMU 假设：部分否决
现状：`hi_vdec_smmu_bypass()` 写 `SCR=1`（启用）但 `SCB/CB_TTBR = 0`，
而 `smmu_pt_map()` 填充的恒等页表 `g_smmu_pt` **从未分配、也从未写进 TTBR**（历史遗留空实现）。
新增 `vdec_smmu_mode`：1=彻底关 SMMU（`SCR=0`），0=现状。
实测：
```
smmu_mode=1（SCR=0）: dec = 0, 0      ← 解码完全停摆
smmu_mode=0（SCR=1）: dec = 6, 5      ← 与之前一致
```
⇒ **SCR=1 是必须的**（关掉反而不能解码），现有配置虽“看起来矛盾”但功能正确。
（推测 CRG 0x334 的 bypass 位已让硬件直通，SCR 只是总开关）

#### 三、交付逻辑：与 SDK 逐函数 diff，几乎一致
对 `RecvFrm/GetFrm/RlsFrm` 相关 24 个函数做自动 diff：
| 函数 | 差异 |
|---|---|
| `VDEC_RecvFrm` | 仅多一条 `IMGDBG` 调试打印（+5 行） |
| `HI_DRV_VDEC_RlsFrmBuf` | 仅多我们的占用帧记录逻辑（+17 行） |
| `VDEC_RlsFrm` | 仅多一条 `RLSIMG` 调试打印（+1 行） |
| 其余 21 个 | **完全一致** |
⇒ 交付/回收逻辑不是问题源头，问题在时序/状态。

#### 四、下一轮：上 ftrace（需要重编内核并刷写，流程已验证 §4.21）
`/sys/kernel/tracing` 与 `/sys/kernel/debug/tracing` 目前都不可用（内核未开 `CONFIG_FUNCTION_TRACER`）。
计划：
1. 内核 config 打开 `CONFIG_FTRACE`、`CONFIG_FUNCTION_TRACER`、`CONFIG_FUNCTION_GRAPH_TRACER`、
   `CONFIG_DYNAMIC_FTRACE`（+ debugfs），重编 `Image` → 打 FIP → 刷 p6（回滚镜像已备）
2. 用 `set_ftrace_filter` 限定 `hi_vdec` 的驱动函数与 vfmw C 函数（`VCTRL_*`、`SM_*` 在 .S 里但符号可 tracing）
3. 跑一次连续供流，导出 `function_graph`，直接看**单帧 2.3s 花在哪个函数/等待上**

### 4.34 2026-11-05：**ftrace 已打通（含"放大内核分区读取窗口"的通用手段）**；首次 trace 结论

#### 一、开启 ftrace 并刷入（可复用流程）
1. 内核 config：`DEBUG_FS/TRACING/FTRACE/FUNCTION_TRACER/FUNCTION_GRAPH_TRACER/DYNAMIC_FTRACE` 全开
   → `Image` 从 10.5MB 涨到 **14.3MB**
2. **问题**：FIP 上限 12.2MB（原 bootcmd `mmc read … 0x5D34`），装不下
3. **解决（重大能力）**：HiSilicon fastboot 的**环境变量存在 eMMC 偏移 `0x100000`，共 64KB**，可读写：
   - 布局：`[4 字节 CRC32 小端][key=value\0 …]`
   - **CRC 算法**：`crc32_le(数据区[4:65536])`（已实测匹配）
   - 把 `bootcmd=mmc read 0 0x1FFAE30 0x7000 0x5D34; bootm 0x1FFAE30`
     改成 **`… 0x8000 …`**（16MB），重算 CRC，`dd` 写回 `bs=512 seek=$((0x8000))`
   - 已验证：改完复位能正常启动；原环境备份在板上 `/root/env_orig_backup.bin`
4. 刷入 14.8MB 的 tracing FIP → 启动成功（`#178`），
   `available_tracers: function_graph function nop` ✔
5. **注意**：内核 config 变化会改 vermagic ⇒ **所有模块必须重编**（否则 `Invalid module format`）；
   已重编并部署 `hi_vdec.ko / hi_mmz_shim.ko / hi_venc.ko`，M4 回归通过

#### 二、第一次 function_graph 结论（12s，18 万行，630 个可追踪模块函数）
```
VDH_Distributor 总时长 11.65s（循环线程，属正常）
单次最长等待：OSAL_WaitEvent_l 48ms、Osal_WaitWaitQue 44ms、schedule_timeout 48ms
调用计数：OSAL_GetTimeInMs 2762、VDH_Acquire_Usage 1595、VDEC_RecvFrm 828、
          VFMW_GetImage 828、VDH_Process_MfdeTask 798
```
⇒ **没有任何一次调用接近 2.3s**，且 CPU 侧一直在忙 ⇒ 每帧那 ~2.3s 花在
**不可追踪的路径**上：vfmw 的 `.S` 核心（`VCTRL_*`/`SM_*`）与 VDH 硬件本身。

#### 三、又排除两项
| 假设 | 做法 | 结果 |
|---|---|---|
| SMMU 翻译拖慢 VDH | 新增 `vdec_smmu_mode=2`：真实分配恒等页表(1MB)并写 SCB/CB_TTBR | dec=6,6 与现状一致 ⇒ ❌ |
| 动态模式 `VDH Mem=0` 导致慢 | `vdec_dfs=0`（静态）：`VDH Mem 0x28da9000 / 76,062,720` | dec=6,8、out=0,3，速率不变 ⇒ ❌ |

#### 四、下一轮
1. 用 `function` tracer（带 **绝对时间戳**，`trace_options` 里 `funcgraph-abstime` 或
   `function` + `printk` 时间）跑 3~5 秒，直接看**相邻两条记录之间的时间空洞**落在哪个函数之后
2. 在驱动关键路径插入 `trace_marker`（写 `/sys/kernel/tracing/trace_marker`）标记：
   收包 / 帧存回执 / VDH ISR / 取帧，把 2.3s 精确夹到两标记之间
3. 若确认为 VDH 硬件本身慢：检查 CRG 里 VDEC 时钟/复位与 vendor 是否一致（下一步读 CRG 寄存器对照）

### 4.35 2026-11-05：轻量时序统计（VTSTAT）——**输入侧健康、输出侧完全停滞、VDH 每 2.5s 才启动一次**

#### 一、为什么不用 trace_printk
`trace_printk()` 在内核里**未导出给模块**（模块链接失败 `Module.symvers Error 1`）。
改用轻量方案：ISR 里只记录 `ktime_get_ns()` 与计数（无打印），由用户线程每 500ms 打印一行 `VTSTAT`。

#### 二、实测数据（连续供流 13s）
```
VTSTAT: put=5  read=65  img=0 ack=1 | vdh=1 scd=5  since_vdh=159ms
VTSTAT: put=29 read=174 img=0 ack=1 | vdh=1 scd=29 since_vdh=2181ms
VTSTAT: put=36 read=209 img=0 ack=1 | vdh=2 scd=36 since_vdh=235ms
VTSTAT: put=62 read=328 img=0 ack=1 | vdh=2 scd=62 since_vdh=2255ms
VTSTAT: put=81 read=422 img=0 ack=1 | vdh=3 scd=81 since_vdh=1375ms
```
解读：
| 指标 | 变化 | 含义 |
|---|---|---|
| `put` | 14/s 稳定增长 | 用户送包正常 |
| `read` | 58/s 稳定增长 | vfmw 的 read_stream 回调在持续取数据（约 4 次/包） |
| `scd` | 与 put 同步增长（7/500ms） | SCD 中断按包触发，硬件在扫描 |
| **`vdh`** | **每 ~2.2~2.5s 才 +1** | 解码启动被严重节流（≈0.4 帧/s） |
| **`img`** | **恒为 0** | `VCTRL_GetChanImage` **一次都没成功** ⇒ 输出队列始终空 |
| `ack` | 仅 1 次 | 帧存回执只发生一次（符合设计） |

⇒ **输入侧完全健康**（数据进来、SCD 在跑、read_stream 在取），
**输出侧完全停滞**（没有任何一帧进入 VO 队列），而 VDH 启动被节流到每 2.5s。

#### 三、推断（下一轮验证方向）
1. vfmw 解码后本应把帧放到 VO 队列供驱动 `VCTRL_GetChanImage` 取；现在队列恒空 ⇒
   解码"完成"事件没有被 vfmw 认可，或者帧被扣在"重排序/参考"状态
2. VDH 每 2.5s 才启动一次，像是**在等一个"帧存可复用"的信号**：
   因为 `img=0`，用户从不取帧 ⇒ 从不 `RlsFrm` ⇒ 帧存永不归还 ⇒ 下一帧只能等超时/兜底才启动
   （但注意：把 SCD/VDH 超时调到 100ms 实验里帧率没变，说明不是纯超时，可能是"等一帧缓冲区"的内部轮询）
3. 优先检查：`VDEC_RecordOccupiedFrame` 那条 `SET_IMG_OUTPUT_INFO(1)` 是否与
   `VDEC_CID_REPORT_OCCUQIED_FRM` 的时序冲突；以及 `pfnVfmwGetImage` 返回 -1 的具体分支
   （在 vfmw 的 `.S` 里，但可通过 `/proc/vfmw/channel` 的 `VoQue detail` 与 `Ref,Read,New` 观察）

### 4.36 2026-11-05：FSP 帧存充足；取帧/送流速率均非关键；决定走"原厂固件基准"

#### 一、FSP（vfmw 内部帧存池）实况 —— 不是帧存不足
运行中读 `/proc/vfmw/buffer`（chan0）：
```
FSP ExpectedDecFsNum :4      FSP TotalValidFSNum :12
FSP ActualDecFsNum   :12     FSP FreeDecFsNum    :11     ← 11 块空闲
FSP ActualPmvNum     :4      FSP FreePmvNum      :4
DecodeFrameNum:4   OutputFrameNum:0   Ref,Read,New:(3,0,0)   VoQue:(0,0,0)
```
⇒ 帧存**大量空闲**，却只解了 4 帧 ⇒ 卡点不在帧存分配。

#### 二、三项对照实验（各 2 次干净启动）
| 变量 | 结果 | 结论 |
|---|---|---|
| `NOPOLL=1`（只送流、完全不取帧） | dec=5, 5 | 取帧路径**不干扰**解码 |
| `THRDELAY=60ms`（≈16 AU/s） | dec=4, 4 | 送流变慢**没有**改善 |
| `THRDELAY=120ms`（≈8 AU/s） | dec=4, 3 | 同上 |
| `vdec_dbg=1`（对照） | f=13 vs 无打印 f=1 | 打印带来的时序效应**仍然成立** |

#### 三、结论与决策
- 已排除：帧存不足、取帧干扰、送流速率、超时、SMMU、VDH Mem、cache 映射方式、送流粒度、EOP
- 剩余可能：vfmw `.S` 核心内部的**状态机/时序依赖**（不可读、不可追踪）
- **决策：走"原厂固件基准"路线**（用户已授权）。素材已盘点：
  - 厂商镜像：`/mnt/f/design/Hi3798/FW/BK/BK/`：`fastboot_emmc.bin`(1M)、`bootargs_emmc.bin`(1M)、
    `baseparam_emmc.bin`(8M)、`kernel_emmc.bin`(40M)、`system_emmc.img`(700M)、`userdata_emmc.img`(5.2G)
  - 分区布局（`configs/hi3798mv300/prebuilts/emmc_partitions.xml`）：
    fastboot@0(1M)、bootargs@1M(1M)、baseparam@2M(4M)、pqparam@6M(4M)、logo@10M(4M)、
    **kernel@14M(32M)**、rootfs@46M(256M)、ubuntu@302M(其余)
  - 恢复资产：`restore-20261104/board-boot-32M.bin`(32M) + `ubuntu-p1.img.zst`(2.2G→7.5G)
  - 注意：厂商 Android 的 system(700M)/userdata(5.2G) 与上述 Linux 布局不同，
    Android 布局应来自 `bootargs_emmc.bin` 里的 `blkdevparts`，需先解析确认

#### 四、下一轮（原厂固件基准）
1. 先**只读**：从当前 Ubuntu 里 `dd` 出 eMMC 前 302MB 作整盘备份（~302MB，可回滚）
2. 解析 `bootargs_emmc.bin` 的 `blkdevparts`，确定 Android 分区表
3. 写入 vendor fastboot+bootargs+baseparam+kernel+system，启动 Android
4. 通过串口控制台触发播放（或用内置播放器），抓 `/proc/vfmw/{channel,buffer,scd,vfmw_statis}` 作为**健康基准**
5. 恢复 Ubuntu（dd 回备份 + 现有 FIP）

### 4.37 2026-11-05：**刷入厂商固件成功启动 Android 内核**；卡在 userdata 未格式化（板子待恢复）

#### 一、厂商固件刷写（从 Ubuntu 里 dd，全部成功）
按 `configs/hi3798mv300/prebuilts/emmc_partitions.xml` 与厂商 `bootargs` 里的 Android 分区表
（`blkdevparts=mmcblk0:1M(fastboot),1M(bootargs),10M(recovery),2M(deviceinfo),8M(baseparam),
8M(pqparam),20M(logo),20M(logobak),10M(loaderdb),40M(fastplay),40M(fastplaybak),40M(kernel),
20M(misc),1M(stbid),600M(cache),700M(system),50M(keydata),40M(trustedcore),8M(securestore),
600M(backup),-(userdata)`）写入：
```
fastboot@0M  bootargs@1M  deviceinfo@12M  baseparam@14M  logo@30M
kernel@160M  cache@221M   system@821M
```
厂商 fastboot 版本：`HiSTBAndroidV600R003C01SPC012CP0001_patch3_20180105`，
其 `bootcmd=mmc read 0 0x1FFBFC0 0x50000 0x5000; bootm 0x1FFBFC0`（块 0x50000 = 160MB ✓）

#### 二、遇到的问题与关键发现（**可复用**）
1. 第一次启动进 **recovery**（`get keycode timeout! → load mode:recovery`），recovery 分区是 Ubuntu 残留 → `Wrong Image Format`
2. **fastboot 控制台可用**：在 `Android_Main entry_mode_flag` 出现时连发 `\x03` 可进 `fastboot#`；
   控制台支持 `md/mw/mm/mmc read/mmc write/setenv/saveenv/printenv/reset/help/uploadx`
3. **清空 misc + recovery 可强制正常启动**（在 fastboot# 下）：
   ```
   mw.b 0x1FFBFC0 0 0x1000000
   mmc write 0 0x1FFBFC0 0x1000  0x5000    # recovery(2MB 偏移, 10MB)
   mmc write 0 0x1FFBFC0 0x64000 0xA000    # misc(200MB 偏移, 20MB)
   saveenv
   ```
4. 之后 **Android 内核 3.18 成功启动、init 运行**，日志确认：
   ```
   mmcblk0: p1(fastboot) … p16(system) … p21(userdata)
   EXT4-fs (mmcblk0p16): mounted filesystem with ordered data mode   ← system 正常
   EXT4-fs (mmcblk0p21): VFS: Can't find ext4 filesystem            ← userdata 未格式化
   init: countError is 4 → reboot: Restarting system                ← 连续失败后重启进 recovery
   ```
   ⇒ 唯一阻塞是 **userdata(p21) 没有文件系统**（我们没刷 5.2GB 的 `userdata_emmc.img`）。

#### 三、当前板子状态（重要）
- **eMMC 已是厂商布局**：Ubuntu 内核/FIP 与 rootfs 已被覆盖（rootfs 在 302M..1521M 等多处损坏）
- 板子每 ~20s 因 init 错误计数而重启；`fastboot#` 需要择机 `^C` 才能进
- **恢复只能靠 fastboot 控制台**：TFTP 不可用（主机无免密 sudo，无法监听 69 端口）；
  串口下载命令待确认（`help` 里只见 `uploadx`，需在 prompt 下看完整列表）

#### 四、恢复通道已确认可用（`loady` 存在）
`fastboot#` 完整命令表里有 **`loadb`（kermit）/ `loady`（ymodem）**、`bootp`、`tftp`、`mmc`、`mw/mm`。
⇒ **串口 YMODEM 恢复可行**（TFTP 因主机无免密 sudo、无法监听 69 端口而不可用）。

恢复计划（明确）：
1. 进 `fastboot#`：复位后在 `Android_Main entry_mode_flag` 出现时连发 `\x03`（已验证可靠，见 `/tmp/fb_enter.py`）
2. 二选一：
   - **低速**：`loady 0x1FFAE30`，主机用 Python 实现 YMODEM 发送 `fip_desk_pad.bin`（12.2MB @115200 ≈ 18 分钟）
   - **高速**：先 `setenv baudrate 921600` + `saveenv`/复位，两侧切到 921600（≈2.5 分钟）；
     若失败可复位后 `setenv baudrate 115200` 恢复
3. 写入我们 Ubuntu 的 FIP 位置（**14MB = 块 0x7000**）：
   ```
   mmc write 0 0x1FFAE30 0x7000 0x5D34
   setenv bootcmd 'mmc read 0 0x1FFAE30 0x7000 0x5D34; bootm 0x1FFAE30'
   setenv bootargs 'console=tty0 console=ttyAMA0,115200 earlycon=pl011,0xf8b00000 keep_bootcon cma=256M log_buf_len=8M blkdevparts=mmcblk0:0x1bf3d0000@0x12E00000(ubuntu) root=/dev/mmcblk0p1 rootfstype=ext4 rootwait rw panic=30 panic_on_oops=1'
   saveenv; reset
   ```
4. Ubuntu 起来后：`nc` 整盘恢复（board-boot-32M.bin + 零填充到 302MiB + `ubuntu-p1.img.zst` 解压流，共 7,820,083,200 B）
5. 若还想继续厂商基准：可先把 `userdata_emmc.img` 或 `userdata_ext4_2M.img` 写入 p21 起始
   （块 0x455800），Android 即可正常启动到 UI

（下面旧计划保留作参考）
   - 用 xmodem 载入我们的 `fip_desk_pad.bin`（12.2MB，约 15~20 分钟）到 `0x1FFAE30`
   - `mmc write 0 0x1FFAE30 0x7000 0x5D34`（我们 Ubuntu 的 FIP 位置是 **14MB/块 0x7000**）
   - `setenv bootcmd 'mmc read 0 0x1FFAE30 0x7000 0x5D34; bootm 0x1FFAE30'`
   - `setenv bootargs '<Ubuntu cmdline：console=tty0 console=ttyAMA0,115200 … cma=256M blkdevparts=mmcblk0:0x1bf3d0000@0x12E00000(ubuntu) root=/dev/mmcblk0p1 rw panic=30>'`
   - `saveenv; reset`
3. 若没有串口下载命令：用 `mw/mm` 把 kernel/initramfs 很小化，或改用 **在 fastboot 里 `mw` 构造**…
   （备用：把恢复 init 做成 <64KB 的裸机 payload 通过 `mm` 逐字写入）
4. Ubuntu 起来后：`nc` 整盘恢复（board-boot-32M.bin + 零填充 + ubuntu-p1.img.zst 解压流）

> 教训：厂商固件刷写会**整体覆盖** Ubuntu 分区，恢复必须整盘流式写回；
> 刷写前应先确认 `userdata` 镜像可用并在 fastboot 内验证恢复通道（TFTP/serial）可行。

### 4.38 2026-11-05：搭好串口恢复通道（YMODEM 已验证）；恢复内核已就绪，差最后一步写 env

#### 一、串口恢复通道（重大能力，已验证）
- 主机无法监听 69 端口（无免密 sudo）⇒ TFTP 不可用；**改用 `loady`（YMODEM）**
- 自写 YMODEM 发送器（`/tmp/ymsend.py`）。**关键坑**：U-Boot 的 YMODEM 里
  **`SOH(0x01)` 表示 128 字节块、`STX(0x02)` 表示 1024 字节块**；
  一开始把 1024 字节块套在 SOH 里，接收端一直回 `C`（重传请求），修正后一次通过
- 实测速率 ≈ **10.5 块/s（1KB 块）≈ 10KB/s**：5.56MB 用 ~9 分钟；407KB 用 ~40 秒
- fastboot 侧可用 `unzip <src> <dst>` 解 gzip（我们传的是 `.gz`，省 3 倍时间）

#### 二、恢复内核已构建并写入 eMMC
1. 写 `/tmp/recovery/init.c`：静态 init（598KB），mkdev `/dev/mmcblk0`，
   开 TCP **4444** 监听，把收到的字节流顺序写入 `/dev/mmcblk0`，完成后 fsync+reboot
2. 内核 config：`BLK_DEV_INITRD=y`、`INITRAMFS_SOURCE=/tmp/recovery`、`RD_GZIP=y`
   → 重编 `Image` = 14,692,360 B（含 initramfs）
3. 打成 uImage（含 DTB）→ FIP（BL31+uImage）= **15,236,130 B**，gzip 后 5.56MB
4. 已通过 YMODEM 传入 RAM（0x1FFAE30），`unzip` 校验（FIP magic `aa640001`）后
   **`mmc write 0 0x1FFAE30 0x7000 0x2970`** 写入 eMMC 14MB 处 ✅

#### 三、发现的问题（下一步的关键）
1. **厂商 fastboot 不支持 FIP**：`bootm <fip>` → `Wrong Image Format`；
   FIP 内 uImage 在偏移 0x5190，但 `bootm` 该地址会复位（无 BL31 无法启动）。
   ⇒ 必须用**我们自己的 fastboot**（支持 FIP），它就在 `board-boot-32M.bin` 的前 1MB
2. 已把我们的 fastboot（1MB）传入并 `mmc write 0 0x1FFBFC0 0 0x800` 写入块 0 ✅
3. **踩坑**：写完 env 后又执行了 `saveenv`（由**厂商 fastboot** 执行）⇒ 它把 vendor 的
   `bootcmd`（读 160MB 处 vendor kernel）写回 ⇒ 重启又进 Android。
   ⇒ 正确做法：**写 env 后不要再 `saveenv`**，直接 `reset`
4. 现在板子反复启动 Android（binder 报错），`^C` 抓 `fastboot#` 的窗口很小；
   **但 Android 连续 boot 失败 4 次会把 recovery 标志写入 misc ⇒ 下次尝试 recovery
   （分区为 0）失败 ⇒ 自然落到 `fastboot#` 长窗口**（第 36 轮已验证此路径）

#### 四、下一步（脚本已备好）
1. `bash /tmp/do_recover.sh`：等 `fastboot#` → YMODEM 传 `/tmp/env_mod.bin`(64KB) →
   `mmc write 0 0x08000000 0x800 0x80` → **不 saveenv** → 复位
   → 我们的 fastboot 读 env（bootcmd 读 14MB FIP）→ recovery 内核(initramfs) 启动
2. 确认 4444 端口就绪后：`python3 /tmp/stream_restore.py`
   （board-boot-32M.bin + 零填充到 302MiB + ubuntu-p1.img.zst 解压流，共 7,820,083,200 B）
3. 恢复完会自动 reboot → 我们的 fastboot + 原 env + 原 FIP（都在前 32MB 里）→ Ubuntu 正常启动

**当前板子状态**：厂商 Android 反复启动；eMMC 14MB 处已是 recovery FIP、块 0 已是我们 fastboot；
Ubuntu rootfs 待整盘恢复。

### 4.39 2026-11-05：恢复流程执行到"启动恢复内核"卡住（BL31 把 BL33 识别成 AArch32）

#### 一、已完成（可复现）
1. **复位后立刻灌 `^C`（不等 Android_Main）即可稳定拿到 `fastboot#`** ——
   这是本轮最实用的操作改进（之前只在 recovery 失败窗口才成功）
2. 确认当前运行的是**我们的 fastboot**：`Fastboot 3.3.0-dirty (jason@) (Oct 31 2026)`
3. 通过 YMODEM 写入我们的 env（`env_mod.bin`：`bootcmd=mmc read 0 0x1FFAE30 0x7000 0x8000; bootm 0x1FFAE30`），
   **没有再执行 saveenv**（这正是上轮把 vendor bootcmd 写回的原因）
4. 复位后日志确认走的是我们的路径：
   ```
   MMC read: dev # 0, block # 28672, count 32768 ... OK
   Load fip from 0x1FFAE30 ...
   Firmware Image Package ToC:
   - EL3 Runtime Firmware BL3-1: offset=0x88, size=0x5108
   - Non-Trusted Firmware BL3-3: offset=0x5190, size=0xE82A92
   bl33_ep->spsr = 0x1D3          ← **异常**：应为 0x3C5（AArch64）
   Start Warm Reseting
   ```
   之后**串口无任何输出**、板子离线（ping 不通、无 ARP）

#### 二、问题定位
- `bl33_ep->spsr = 0x1D3` = **AArch32 模式**；此前 Ubuntu 内核（同一套 FIP 流程）是 `0x3C5`（AArch64）
- 两种 uImage 头格式完全一致（magic/arch=22/type=2/comp=0/load=0x2000000）
- 唯一显著差异：**BL33 大小 15.2MB vs 11.1MB**（恢复内核多了 initramfs + 仍开着 ftrace）
- 结论待验：BL31（`bl31_smp_fixed.bin`）对这个 FIP 的 BL33 判定/装载出了问题，
  可能与镜像过大或某处大小上限有关

#### 三、下一轮（两条路，按优先级）
1. **缩小恢复内核**：关掉 `FTRACE/FUNCTION_TRACER/FUNCTION_GRAPH_TRACER` 重编
   （预计 10.5MB + initramfs ≈ 11MB，与已知可工作的 11.1MB 同量级）→ 重打 FIP（≈11.1MB）
   → YMODEM（gz 约 4MB，6~7 分钟）→ `write 0x7000` → 复位
2. 若仍失败：改用**直接 `bootm` 恢复 uImage**（不走 FIP/BL31），单核启动即可完成恢复
   （我们的 init 不需要 SMP/PSCI）

#### 四、当前板子状态
- 块 0 = 我们的 fastboot；14MB = 恢复（坏）FIP；env = 我们的（bootcmd 指向 14MB FIP）
- 复位后 BL31 卡住 → **串口静默**；需再次用"复位即灌 ^C"拿回 `fastboot#`（已验证有效）

### 4.40 2026-11-05：**板子整盘恢复成功，Ubuntu 重新启动**（串口自救全流程跑通）

#### 一、成功链路（可复现，建议存为 runbook）
1. **进 fastboot#**：RTS 复位后**立刻**持续灌 `\x03`（不必等 Android_Main）→ 稳定拿到 `fastboot#`
   —— 关键：U-Boot autoboot 的 bootdelay 很小，必须**在 bootloader 阶段就把字节塞进 UART**
2. **串口传数据**：`loady 0x08000000` + 主机 YMODEM（`/tmp/ymsend.py`）
   —— U-Boot YMODEM：`SOH(0x01)=128B`、`STX(0x02)=1024B`，实测 ~10KB/s
3. **压缩省时**：传 `.gz` 后 fastboot 侧 `unzip <src> <dst>`（5.56MB→15.2MB、4.77MB→11.4MB）
4. **写 FIP**：`mmc write 0 0x1FFAE30 0x7000 <blocks>`（我们 Ubuntu 的 FIP 在 **14MB/块 0x7000**）
5. **必须用我们自己的 fastboot**（`Fastboot 3.3.0-dirty (jason@)`，来自 `board-boot-32M.bin` 前 1MB）
   —— 厂商 fastboot 不支持 FIP，`bootm <fip>` 直接 `Wrong Image Format`
6. **写 env 后绝不能 `saveenv`**（厂商 fastboot 会把 vendor bootcmd 写回）
7. **恢复内核 = 我们的 kernel + 内嵌 initramfs**（`init` 静态程序）：
   - 监听 TCP 4444，把收到的字节流顺序写入 `/dev/mmcblk0`
   - 需自己 `mkdir /dev` + mknod + `open("/dev/console")` + dup2（否则无输出）
   - 需自己用 `ioctl(SIOCSIFADDR/SIOCSIFNETMASK/SIOCSIFFLAGS)` 配 eth0 IP（initramfs 里没有 ip 工具）
8. **init 的 accept 只能成功一次**：先用裸 connect 探测会消耗掉它（0 字节→立即重启）；
   正确做法是客户端**带重试连接，连上就立即发送**
9. **流式整盘恢复**（board-boot-32M.bin + 零填充到 302MiB + `ubuntu-p1.img.zst` 解压流
   = 7,820,083,200 B）：实测 **11.4MB/s，约 11.5 分钟**（受 eMMC 写入限制）
10. 恢复完 init fsync + reboot → 自动回到 Ubuntu ✅

#### 二、踩坑记录（重要）
- **BL31 把 BL33 误判为 AArch32（`bl33_ep->spsr = 0x1D3`）**：当 BL33 uImage
  **>11.5MB**（恢复内核 15.2MB）时出现；改用 **11.4MB** 小内核后正常（`0x3C5`）。
  ⇒ 恢复/调试用 FIP 建议控制在 **≈11MB**
- 恢复镜像是 **11-04 早上**的快照：板子上的 `/root/*.ko`、`venc_test` 都比最终可用版本旧，
  且 **新编模块与运行内核 #177 不匹配**（insmod hi_venc 导致重启）
- 恢复后 SSH 需 `systemctl start ssh.socket`（镜像默认未启动）；串口 ttyAMA0 有 root 自动登录 shell

#### 三、当前状态
- 板子：Ubuntu 26.04.1 / Linux **7.3.0 #177**（Nov 3 构建，无 ftrace），SSH 已恢复，磁盘 66% 占用
- 内核树 `.config` 目前是**恢复配置**（含 `INITRAMFS_SOURCE`、无 ftrace）≠ #177 配置
  ⇒ 模块需要与内核**重新对齐**后才能继续 M2

#### 四、下一轮
1. 把 `.config` 恢复成常规配置（关掉 `BLK_DEV_INITRD/INITRAMFS_SOURCE`）
2. `make Image` + 打包 FIP（≈11MB）→ `dd` 到 eMMC 14MB → 备份旧 FIP
3. 用**同一份 .config** 重编 `hi_mmz_shim/hi_vdec/hi_venc` 并部署 → 验证 M4 回归
4. 之后恢复 M2 实验（`vdec_maxref=16` 等参数在新的内核/模块组合上重测）

### 4.41 2026-11-05：内核/模块重新对齐完成（#182），M4 功能正常、M2 现象完全复现

#### 一、对齐过程
1. `.config` 恢复正常（关 `BLK_DEV_INITRD`/`INITRAMFS_SOURCE`/`RD_GZIP`，`DEBUG_FS=y`），
   重编 Image = **10,887,176 B**（#182），打 FIP = **11,435,042 B**（<11.5MB 的安全阈值）
2. 板子上先 `dd` 备份旧 FIP 到 `/root/fip_old_backup.bin`（16MB），再
   `dd if=/tmp/fip_desk2.bin of=/dev/mmcblk0 bs=512 seek=$((0x7000)) conv=fsync`
3. **重要坑**：板子里 `reboot` 命令**不可靠**（复位后板子静默/不启动）；
   必须用 **RTS 硬复位**（`/tmp/ser_reset.py`）——之后一次启动成功
4. 串口/SSH 恢复后 `systemctl start ssh.socket` 才可 SSH

#### 二、验证结果
| 项目 | 结果 |
|---|---|
| 内核 | `#182 SMP PREEMPT Nov 5 08:42` ✅ |
| 模块加载 | `hi_mmz_shim` / `hi_vdec`(maxref=16) / `hi_venc` 全部 `insmod` 成功 ✅ |
| **M4 VENC** | 编码正常，`ffmpeg` 解码 **rc=0**（有效 H.264），无 Oops ✅ |
| **M2 VDEC** | **现象完全复现**：`put=18，read 60/s，img=0，vdh=0，scd=30` ✅（同一 bug） |
| rmmod hi_vdec | **段错误**（vfmw 卸载老问题）⇒ 仍必须"一次启动只加载一次模块" |

#### 三、M4 待确认项
- 板上的旧 `venc_test`（11-03 版）行为与主机 `port/vencuser/venc_test`（11-03 17:24 版）不同：
  后者可写 `/root/out_venc.h264` 并被 ffmpeg 解出（1186~1246 B），但只出 **11 条流**（frame 18 起
  `QueueFrame rc=0xffffffff`）；11-04 曾达到 **30 帧/30 流/4236 B**。
  ⇒ 需要重新构建"30/30 通过"那版测试程序（主机上对象文件不全，`/tmp/v_unf_venc.o` 等缺依赖）

#### 四、下一步（M2 主线）
1. 在 #182 + `vdec_maxref=16` 这个干净组合上，重跑关键对照（`vdec_dbg=1` 的吞吐放大效应是否仍在）
2. 继续验证"输入侧健康、输出侧停滞"的假设链：重点看 VDH 为何 0 次启动
3. 若需要原厂基准，**恢复流程已完全可用**（§4.40 runbook），可安全再刷厂商固件

### 4.42 2026-11-05：**打开 vfmw 核心内部打印**，首次看到卡点链条：SCD 永远 Idle ⇒ 不启动 ⇒ VDH 永不跑

#### 一、重大能力突破：vfmw 核心打印可开
`/proc/vfmw/help` 给出写接口：`echo [arg1] [arg2] > /proc/vfmw/info`，
其中 **arg1=0x0 设置 print enable word**（arg2 为位图）。实测有效：
```
printf "0x0 0xD7\n"      > /proc/vfmw/info   # FATAL|ERROR|CTRL|DNMSG|UPMSG|STREAM
printf "0x0 0x40000D7\n" > /proc/vfmw/info   # 再加 SCD_INFO(bit26)
grep "print enable" /proc/vfmw/info   → :0x40000d7   ✅
```
位定义（bit0 起）：FATAL,ERROR,CTRL,VDMREG,DNMSG,RPMSG,UPMSG,STREAM,STR_HEAD,STR_TAIL,
STR_BODY,IMAGE,QUEUE,REF,DPB,POC,MARK_MMCO,SEQ,PIC,SLICE,SEI,SE,DBG,BLOCK,
SCD_REGMSG,SCD_STREAM,SCD_INFO,FOD,DNR,PTS,DEC_MODE

> 注意：**普通 `echo` 有时会卡住**（写 proec 时持锁），用 `printf "...\n" >` 更稳；写后立刻回读校验。

#### 二、看到的核心流程（解码一次，5s）
```
N: Enter VDH_Normal_Init
N: SM_Wakeup prepare to check SCD(0)/(MAX_SCD_NUM = 1)
N: SCDDRV_CheckDevice,4725,SCD(ID = 0) SCDState = 0
N: SCDDRV_CheckDevice,4729,SCD(ID = 0) return Idle!      ← 反复出现
N: SM_Wakeup,4823,find idle SCD(ID = 0)
N: VDMHAL_V5R2C1_GlbResetX VdhId 0 success!
```
⇒ **状态机 (SM) 一直想启动 SCD，但 SCD 始终 Idle**，于是：
无 SCD → 无 up-msg → 无 MfdeTask → VDH 不启动 → `img=0`。这与 VTSTAT
（`put=18 read↑ scd=30 vdh=0~1 img=0`）和 `vfmw_statis`（Task 有计数但 Syntax/VDH 全 0）完全吻合。

#### 三、已核对的环境项
- `VDH_Distributor` / `HI_VFMW_VideoDecode` 内核线程在解码时**存在**（随通道打开创建）
- 缓冲区 cache 属性：`VFMW_Hal_0`(6MB) uncached、`VFMW_ScdMsg_0`(716KB) uncached、
  `VFMW_Chan_Ctx` cached —— SCD msg 是 uncached，cache 一致性不是这里的瓶颈
- `CACHEFL/KFLUSH` 调用计数为 0（vfmw 解码路径不调用 flush，因其缓冲本就不 cached）
- CRG 基址 0xF8A22000 与厂商一致（`REG_BASE_CRG`）；SCD 驱动经 `g_pstRegCrg` 访问
  CRG 偏移 0x78/0x174，`ResetSCD` 会写 SCD 寄存器
- 厂商 product 配置里 `VFMW_SCD_V300_SUPPORT=y`/`VFMW_DSP_V100_SUPPORT=y`，
  但它们只影响**预编译 .S**（我们未重编），驱动 C 代码里未使用

#### 三·补：中断计数实测（解码若干次后）
```
 38:  1   ... 127 Level  vdec_vdh  ×6    ← VDH 只来过 1 次
 39: 56   ... 136 Level  vdec_scd  ×6    ← SCD 中断来了 56 次
 40:  0   ... 181 Level  mmu_vdh   ×6
```
⇒ SCD 硬件确实在出中断（56 次），但核心仍认为 `SCDState=0/Idle`：
要么 ISR 处理时状态没被置位，要么这些中断是空/错误中断，SM 侧判定无效。
**这是下一轮的第一个看点**：反汇编 `scd_drv.o` 的 ISR 与 `SCDDRV_SetStateWork`。

#### 四、下一轮（沿着 SCD 这条线）
1. 反汇编 `scd_drv.o`：`SM_Wakeup` / `SCDDRV_CheckDevice` / `SCDDRV_SetStateWork`，
   搞清 SCDState 由谁置位、SM 启动 SCD 需要哪些寄存器/条件
2. 确认 SCD 时钟是否使能（CRG 位），以及 BootROM/fastboot 是否已放开 SCD 时钟
3. 对比厂商可工作的 vfmw（Android 里同名核心）在同样场景的打印

### 4.43 2026-11-05：**找到 SCD 不启动的确切门控函数**，且 `vdec_dbg=1` 下首次观测到出帧

#### 一、SCD 启动链条（反汇编 `scd_drv.o` 得到，可复核）
```
SM_Wakeup()                                  [scd_drv.o 0x84c8]
  ├─ 对 StartFlag(pInst+0x7100)==1 的实例调用 FillRawData(id)
  └─ SCDDRV_CheckDevice(0) → 若 idle → SCDDRV_ActivateSCD(0)   [0x7df0]
        └─ 若 state@600==0 → SM_DoNextInstance(id,&info)        [0x7c28]
              └─ 遍历 32 实例，用 SCDDRV_CanNotSelectInst(i) 过滤   [0x7b98]
                    └─ 硬条件：pInst != NULL、**StartFlag@pInst+0x7100 必须非 0**、
                       [pInst+0x70F8] != 1、[pInst+20] != 0x13
              └─ 成功才置 **SCDState@pInst+56 = 1**
        └─ 只有 SCDState=1 才算 SCD 已启动
SCDDRV_SetStateWork(id) 就是把 SCDState 置 1（只有 id==0 才做）
```
真正决定"能否开始切流"的是 `CutStreamWithSCD` → **`SCDDRV_CheckConditionOfStartSCD`**（0x3240）：
其返回值 `-5` 就是日志里的 `Cann't Start SCD, Ret = -5`；
判据涉及 `avail_bytes`（流缓冲可读字节）与 `rawpkts`（raw 包数），
失败分支：`avail==3` 或 (`avail>3` 且 `rawpkts==0`) → 返回 -5（其余路径返回 -6）。

#### 二、实测：`vdec_dbg=1` 让 SCD 真正启动并出帧（**首次**）
```
SCDCOND: avail_bytes=0       rawpkts=0     ← 数据未到时
SCDCOND: avail_bytes=248841  rawpkts=1     ← 数据到达，条件满足
N: Start Reason: new_pic_flag              ← SCD 启动、语法开始解码
VTSTAT: put=1 read=5 img=0 ack=0 | vdh=0 scd=0
VTSTAT: put=2 read=15 img=0 ack=0 | vdh=0 scd=2
VTSTAT: put=3 read=19 img=0 ack=1 | vdh=0 scd=3
frames=3 time=11240ms fps=0.27            ← **出帧了**
cannot_start=0
```
而 `vdec_dbg=0`（默认）时：`cannot_start=15/6s`、`Start Reason` 很少、`frames=0`。

⇒ **M2 的真因是"数据就绪 vs SCD 启动检查"之间的竞态**：
`SM_Wakeup` 每 ~10ms 跑一次，若检查时 raw 队列还没数据就失败；
dbg=1 的打印把节奏拖慢，恰好让数据在检查前就位，于是 SCD 能启动并出帧。
这解释了此前所有"dbg=1 吞吐放大 3~4 倍"的现象。

#### 三、当前可复现命令
```
insmod /root/hi_vdec.ko vdec_maxref=16 vdec_dbg=1
printf "0x0 0xD7\n" > /proc/vfmw/info          # 打开核心打印（会显著影响时序）
REPEAT=1 REPEATSEC=5 /root/vdec_test_host /root/test.h264
```

#### 四、下一轮（把竞态消除）
1. 检查驱动侧"写流 → 通知 vfmw"的**顺序**：必须保证 raw/seg 数据在 SM_Wakeup 检查前可见
   （插入流后显式唤醒/置标志，而不是依赖 10ms 轮询）
2. 观察 `FillRawData` 的触发条件与 `StartFlag` 的置位时机
3. 目标：dbg=0 下也能稳定 `Start Reason: new_pic_flag` 且 vdh 递增、img>0

### 4.44 2026-11-05：一次性喂流可绕过 SCD 启动竞态；卡点下移到"取流/取包"

#### 一、绕过竞态的实测（dbg=0，默认参数）
| 送流方式 | cannot_start | Start Reason | frames |
|---|---|---|---|
| 默认（按 AU 逐包） | 15/6s | 0 | 0 |
| `FASTFEED=1` | **0** | 9 | 0 |
| `WHOLE=1` | **0** | 10 | 0 |
| `FASTFEED=1 WHOLE=1` | **0** | 9 | 0 |
⇒ **多次跑之间仍有明显差异**（同一组参数下有时 0 次 `Start Reason`），
  说明"数据是否在 SM_Wakeup 检查时已就位"这个竞态仍然存在，只是被影响的程度不同。

#### 二、SCD 之后的新状态（WHOLE/FastFeed 下）
`/proc/vfmw/vfmw_statis`：
```
Task  SegCope  RandTab  Syntax  VDH  IsrProcess  Wakeup
 43     0(0)      0      75     0       0         0     ← Syntax 在跑，VDH 仍为 0
```
日志里已有真实解码动作：
```
N: receive streambuff=...; bitstream_length=248221
N: Set CompressEn 0, LossCompressEn 0, ...
ALLOCFM: size=3346432 ret=0x0 phy=0x29700000        ← 帧存已分配
N: nal_ref_idc=3, structure=0, image_id=0, pmv_idc=0
N: stream[0]: bitsoffset=16; valid_bitlen=1985712
```
⇒ **语法层已经在真解码**，但 `VDH=0`（硬件从没被启动）。

#### 三、同时发现的新疑点：读流回调返回空包
驱动读流回调 `VDEC_Chan_RecvStrmBuf` 里有我们加的 KSUM 打点，
日志多次出现 **`VDECDBG5: KSUM pkt_Pts=0 calc=0 len=0`**，以及
`GETES: acq ret=-1`（`BUFMNG_AcqReadBuffer` 取不到完整包）。
而 `WHOLE=1`（一次性整包）时 BM 能给出完整包，vfmw 才能切流/解码。
⇒ 高度怀疑 **驱动的 ES 分包/包完成标记链路**（user `bEndOfFrame` → BM marker）
在多包逐次送入时没有正确完成包，导致 vfmw 读流为 0 长度。

#### 四、下一轮
1. 给 `BUFMNG_AcqReadBuffer` 成功/失败与 `u32Marker/bEndOfFrame` 转换加计数打点，
   确认"多包送入时包是否真的闭合"
2. 检查 `VDEC_Chan_PutStrmBuf` 把用户 `bEndOfFrame` 翻成 `BUFMNG_*_BIT` 的那一段
3. 若确认是分包问题 → 修完预期 `GETES: ok size>0` 稳定出现，SCD/VDH 自然启动

### 4.45 2026-11-05：加入分发器任务计数器（TSTAT），**精确定位到"语法只提交 1 个解码任务"**

#### 一、新增可复用插桩（`vfmw/module/distributor/vdh_normal.c` 是我们自己的 C 代码）
```c
unsigned long g_vdh_mfde_calls, g_vdh_mfde_tasks, g_vdh_scd_calls, g_vdh_scd_tasks;
unsigned long g_vdh_post_scd, g_vdh_post_mfde, g_vdh_post_busy;
```
- `VDH_Process_ScdTask` / `VDH_Process_MfdeTask`：调用次数 + 真正取到任务次数
- `VDH_PostTask`：按类型统计入队次数（SCD/MFDE）+ TaskNode 忙次数
- 周期打印在既有 VTSTAT 之前：`TSTAT: mfde_calls=.. mfde_tasks=.. scd_calls=.. scd_tasks=.. | post_scd=.. post_mfde=.. post_busy=..`

#### 二、实测结论（干净单次启动 + 整包喂流）
```
TSTAT: mfde_calls=864 mfde_tasks=1 scd_calls=864 scd_tasks=27 | post_scd=27 post_mfde=1 post_busy=0
VTSTAT: put=29 read=165 img=0 ack=2 | vdh=1 scd=40 since_vdh=39127ms
```
- **SCD 侧完全正常**：`post_scd=27/28`、`scd_tasks=27/28`
- **语法侧只提交了 1 个解码任务**（`post_mfde=1`）⇒ 只有 1 次 VDH（`vdh=1`）
⇒ 卡点被精确定位到 **"语法解析完 SPS/PPS 后，只对第一帧提交解码任务，后续帧不再提交"**

#### 三、同时排除了"数据损坏"这一层
在 `VDEC_Chan_RecvStrmBuf` 加十六进制打印后，vfmw 实际收到的包首字节是：
```
VDECDBG5: KSUM ... len=6687 hdr=000000016742c01e      ← 00 00 00 01 67 = SPS，与文件一致
```
打开全量打印后也确认 SPS/PPS 解析正常：
```
N: ***** NAL: SPS, nal_unit_type=7   profile_idc 66 level 30, 640x368, num_ref_frames 3
N: ***** NAL: PPS, nal_unit_type=8   entropy_coding_mode 0, num_slice_groups_minus1 0
```
⇒ **送流/取流数据链路正确**，问题在语法层的状态推进。

#### 四、观察到的旁证
- 第一帧后反复出现 `sliceheader dec err`、`PPS or SPS of this slice not valid`、
  `Baseline stream, try to decode, exit when FMO occurred.`
- `img` 始终 0：即使那 1 次 VDH 完成，也没有影像进入输出队列

#### 五、下一轮
1. 针对"只提交 1 个任务"：检查 h264 语法层对**后续帧 POC/DPB/ref** 的处理；
   重点看 `sliceheader dec err` 的触发点（是否我们喂的 AU 边界把多 slice 帧拆坏）
2. 试 **把 SPS/PPS 周期性重复插入**（TS 风格）的流，看是否改变提交行为
3. 用 `TSTAT` 作为回归指标：目标 `post_mfde ≈ 帧数`

### 4.46 2026-11-05：重复 SPS/PPS 的流让错误归零并**首次出现 `img=1`**；剩余卡点=DFS 帧存分区握手延迟

#### 一、换流实验（每个数据点都是干净单次启动）
| 流 | SPS/PPS | post_mfde | vdh | img | `pps havn't decode` |
|---|---|---|---|---|---|
| `gen1.h264`（单次头） | 1 次 | 1 | 1 | 0 | 多次 |
| `gen2.h264`（每 IDR 重复头） | 5 次 | **4** | **4** | **1** | **0** |

⇒ **SPS/PPS 的送达/重复发送是关键**：重复头后语法解析全对（`sliceheader dec err` 归零），
  IDR 帧都能提交解码任务，且**第一次有影像进入输出队列（img=1）**。

#### 二、剩余卡点的直接证据（vfmw 核心打印）
在 `gen2` + 默认参数（无 dbg）的一次运行里：
```
N: get back frm
N: VDMHAL_V5R2C1_ArrangeMem_Normal, need arrange, Size: 0x7aaa0, Num: 0x4, RefChanged: 0x1
N: Report arrange frame buffer: wxh 640x368, FsNum 8, PmvNum 4
N: DFS, report event. Size: 0x7aaa0, Num: 4, RefChanged: 1
N: DFS, Wait Partition
N: The channel 0 DEC PARAM is not ready        ← 出现 977 次！
N: DeleteRawPacketInBuffer release RawPhyAddr = ..., Len = 382   ← 随即丢包
```
对照开 `vdec_dbg=1` 的同场景：
```
ARRANGE=1  DECPARAM=0  ALLOCFM=12  post_mfde=3  vdh=3   (TSTAT)
```
⇒ **驱动对 ARRANGE 事件的处理被延后到 HI_VDEC_Task**（历史原因：在事件上下文里直接调 vfmw 会挂死），
   vfmw 的 DFS 只等很短时间就判定 "DEC PARAM not ready" 并丢弃该 raw 包；
   打印把节奏拖慢后握手反而完成——这与历次"dbg=1 才工作"的现象完全一致。

#### 三、驱动侧现状（已核对）
- `VDEC_Event_ArrangeFrameBuf`：记录 `stVFMWReportFrameInfo`（imgNum/imgSize/pmvNum/pmvSize/hdrSize），
  置 `g_occfrm_pending/g_ack_pending`，然后 `wake_up_process(pVdecTask)`
- 真正分配与上报在 `VDEC_AllocMemForDecoder()`：通过 `VDEC_CID_ALLOC_MEM_TO_DECODER`
  把 `FRAME_BUF_S` 逐个报给 vfmw；配合 `VDEC_CID_SET_FRAME_BUFFER_NUM` 回执
- ⇒ 延迟来自"唤醒任务 → 任务里做 mmz 分配（12 次）→ 逐个上报"

#### 四、下一轮（把延迟压到 vfmw 能接受）
1. **通道启动时预分配帧存**（按 cap 档位算好 FsNum/PmvNum 一次性 mmz 分配），
   ARRANGE 时只做"上报地址"这一步，避免运行中反复 mmz 分配
2. 或把 ARRANGE 处理放进独立高优先级 kthread（不占 VDEC_Task 的轮询循环）
3. 用 TSTAT 作回归指标：目标 `post_mfde ≈ 帧数`、`img > 0` 稳定、`DECPARAM = 0`

### 4.47 2026-11-05：量化 ARRANGE→ACK 延迟 **~80ms**（vfmw DFS 等不了这么久）；顺带发现 `osal_free_irq` 传错 dev_id

#### 一、新增时间戳插桩
- `VDEC_Event_ArrangeFrameBuf`：`ARR: n=%d t=%lld imgNum=.. imgSize=.. pmvNum=..`（前 20 次必打）
- 任务回执处：`ACKCHK: n=%d t=%lld chan=%d cfg=%u report=%u extra=%d`（前 20 次必打）
均带 `ktime_get_ns()/1e6` 毫秒时间戳。

#### 二、实测（干净单启 + STARTDELAY=2000 + gen2 + WHOLE=1）
```
ARR:    n=1 t=46537  imgNum=8 imgSize=443424 pmvNum=4 pmvSize=59008 hdrSize=1024
ACKCHK: n=1 t=46617  chan=0 cfg=12 report=8 extra=4
TSTAT:  mfde_calls=1150 mfde_tasks=4 scd_calls=1150 scd_tasks=30 | post_scd=30 post_mfde=4
DECPARAM=0
```
⇒ **ARRANGE 请求到回执间隔 80ms**。vfmw 的 DFS 在 `DFS, Wait Partition` 之后等不到这么长，
   就会打印 `The channel 0 DEC PARAM is not ready` 并 `DeleteRawPacketInBuffer` 丢弃该帧（§4.46）。
   `STARTDELAY=2000` 这一轮恰好 `DECPARAM=0`，说明给足初始化时间后握手能完成，但**每帧的
   `ArrangeMem ... RefChanged=0x1` 重排仍可能超时**。

#### 三、顺带修掉/发现的问题
1. **`osal_free_irq()` 传错 dev_id**：`free_irq(translate(irq), dev)` 应传 `request_irq` 时的
   wrapper 指针 `w`，现在传的是 vfmw 的 dev ⇒ 关通道/卸载时 `free_irq+0x170` 告警 trace
   （`x19=0`），也是 rmmod 段错误的根因之一。
2. 运行间方差依旧很大：同一配置不同次启动会出现 `post_mfde=0` 的"什么都没解"的轮次，
   说明仍有与初始化时序相关的竞态。

#### 四、下一轮（把 80ms 压到几毫秒）
1. 任务循环的睡眠粒度与 `VDEC_AllocMemForDecoder` 里的 mmz 分配是主要耗时：
   **通道启动时预分配**（按 cap 档位一次分配全部 Fs/Pmv），ARRANGE 时只上报地址
2. 或让 ARRANGE 处理走独立高优先级 kthread，绕过 VDEC_Task 的轮询
3. 修 `osal_free_irq` 的 dev_id（低成本高收益，能消掉关通道时的 trace/段错误）
4. 回归指标：`ARR→ACK < 5ms`、`DECPARAM=0`、`post_mfde ≈ 帧数`、`img>0`

### 4.48 2026-11-05：**`vdec_dfs=0`（静态帧存）绕过 ARRANGE 延迟**，post_mfde=5 / vdh=5 / img=1 为目前最佳

#### 一、延迟来源确认（新增 TASKSEE/TASKDONE 时间戳）
```
ARR:      n=1 t=43453  imgNum=8 imgSize=443424 pmvNum=4 ...
TASKDONE: n=1 t=43546  chan=0          ← ARR→分配完成 93ms（VDEC_AllocMemForDecoder 里 12 次 mmz 分配）
ACKCHK:   n=1 t=43565  chan=0 cfg=12 report=8 extra=4
```
⇒ 延迟几乎全部在 `VDEC_AllocMemForDecoder()` 的 mmz 分配，不在任务唤醒/睡眠（睡眠仅 2ms）。

#### 二、解法：改用**静态帧存**
`vdec_dfs` 模块参数直接映射到 `stOption.u32DynamicFrameStoreAllocEn`（`drv_vdec_intf_k.c:10233`）。
以 `vdec_dfs=0` 干净启动 + `STARTDELAY=2000` + gen2 + WHOLE 运行：
```
CHANOPT: cap=4 max=1920x1088 ... dynfs=0 maxref=16 ...
TSTAT:  mfde_calls=1112 mfde_tasks=5 scd_calls=1112 scd_tasks=30 | post_scd=30 post_mfde=5
VTSTAT: put=30 read=1127 img=1 ack=0 | vdh=5 scd=30
DECPARAM=0        ← 完全没有 "DEC PARAM is not ready"（因为根本不发生 ARRANGE 重排）
ARR 打印 = 0      ← 无 ARRANGE 事件，延迟问题被彻底绕开
```
⇒ **目前最佳组合：`vdec_dfs=0 vdec_maxref=16`**（历史记录里"vdec_dfs=0 无效"的结论是在
   错误测试流/脏状态下的判断，需要更新）。

#### 三、剩余问题：**只解 IDR，P 帧不解**
keyint=10 的 50 帧流里 IDR 有 5 个，`post_mfde=5` 恰等于 IDR 数 ⇒ P 帧没有提交解码。
`img=1`（5 次 VDH 只取到 1 帧影像）。
推测：IDR 解完后**参考帧标记/DPB 未更新**，P 帧找不到参考而被丢弃。

#### 四、下一轮
1. 用全量打印看 P 帧被丢弃的具体原因（"no ref"/"DPB"/"ref list" 相关）；重点看
   VDH 中断后参考帧状态回写（`VDH_...` → FSP/DPB 更新）是否发生
2. 检查 `vdec_maxref=16` 与流内 SPS 的 `num_ref_frames=3` 是否冲突
3. 以 `vdec_dfs=0` 作为基线配置，继续推进"P 帧可解 → 连续出帧"

### 4.49 2026-11-05：P 帧失败的直接原因 = **`StorePicInDPB` 失败**（参考帧存不进 DPB）

#### 一、现象（`vdec_dfs=0 vdec_maxref=16` + gen2 + 全量打印）
```
START_REASON=40   post_mfde=3~5
N: for P slice size of list equal 0.        ← 参考列表为空（27 次）
N: init list error.
N: DecList error, ret=-1
N: H264_DecOneNal ERR
N: StorePicInDPB return(-1) from L3972       ← 解码后的图存不进 DPB（每个 IDR 一次）
N: GAP found while DPB is empty!
```
⇒ 逻辑链：**IDR 解码完成 → 存 DPB 失败 → DPB 一直为空 → P 帧建不出参考列表 → 丢弃**。
   这解释了为什么 `post_mfde` 恒等于 IDR 数、P 帧全丢。

#### 二、maxref 扫描（每次干净单启，`vdec_dfs=0`）
| maxref | post_mfde | vdh | img | START_REASON |
|---|---|---|---|---|
| 3 | 4 | 4 | 0 | 40 |
| 4 | 3 | 3 | 0 | 39 |
| 8 | 3 | 3 | 0 | 39 |
| 16 | 5 | 5 | 1 | 40 |
⇒ **与 maxref 无关**，`StorePicInDPB` 每个解码图都失败。

#### 三、反汇编定位（`core/syntax/h264.S`，StorePicInDPB = 行 21473..22313）
失败打印在 **h264.S:21745** 附近（`mov w3,#3972` / `mov w2,#-1`），其前置逻辑是 DPB 滑动窗口判定：
```
ldr x0,[x20]      ; DPB ctx
ldr w2,[x0,#4]    ; 当前 ref 数
cmp w2,w1
bcs .L3793        ; 未超限 → 正常
ldr w0,[x0,#684]
cmp w0,#1
beq .L3793
… FSP_SetDisplay(fs, 0) …
print "StorePicInDPB return(-1) from L3972"; return -1
```
即：**"DPB 参考数 vs SPS num_ref_frames"判定进入错误分支，且滑动窗口无法回收**。

#### 四、两个高度可疑的根因（下一轮验证）
1. **帧存回收/上报链路**：驱动没有把"某帧已解码完成、可作参考"的状态回写给 vfmw
   （即 `VDEC_CID_REPORT_OCCUQIED_FRM` / FSP ref 标记这条链没走通），导致 DPB 认为所有帧仍被占用
2. 帧存数量/编号与 vfmw 期望不一致（我们报 12 块，DPB 按 level 8 管理）

#### 五、下一轮
1. 运行中 dump `/proc/vfmw/buffer` 的 per-fs 字段（IsValid/IsRef/DispState/IsOccupied）看 DPB 是否真的为空
2. 在驱动里给 `VDEC_RecordOccupiedFrame` / `REPORT_OCCUQIED_FRM` 加计数，确认这条链是否被调用
3. 对照 `vdec_dfs=0` 与 `=1` 两种模式下 FSP 的 ref 状态差异

### 4.50 2026-11-05：FSP 实测"解码后所有帧都 IsRef=0"；修掉 `osal_free_irq` dev_id bug

#### 一、FSP 现场（`vdec_dfs=0`，解码进行中 dump `/proc/vfmw/buffer`）
```
FSP ExpectedDecFsNum :4      FSP TotalValidFSNum :32
FSP ActualDecFsNum   :32     FSP FreeDecFsNum    :  (全部 Free)
逐块:  IsValid=1  IsRef=0  DispState=0/1  IsOccupied=0  Size=0
```
⇒ **解码完成后没有任何帧被标记为参考帧（IsRef 全 0）**，与 `StorePicInDPB` 失败、
   “DPB 恒空 → P 帧 `for P slice size of list equal 0`”完全一致。
   另注意 `ExpectedDecFsNum=4` 但 `ActualDecFsNum=32`（数量口径不一致，值得排查）。

#### 二、已修：`osal_free_irq()` 传错 dev_id（`port_stubs.c`）
原实现 `free_irq(translate(irq), dev)` 用的是 vfmw 的 dev，而 `request_irq` 时登记的是
我们的 wrapper 指针 ⇒ 关通道/卸载时 `free_irq+0x170` 告警 trace，也是 rmmod 段错误根因。
改法：用 `g_isr_wrap[virq]` 记录 wrapper，`free_irq(v, w)` 后再 `kfree(w)`。
**验证**：同一流程下 `free_irq` 相关 trace 计数从有到 **0** ✅

#### 三、A/B 结果（每次干净单启，gen2 + `vdec_dfs=0`）
| 配置 | post_mfde | vdh | img | P 帧空列表 |
|---|---|---|---|---|
| maxref=16，occfrm_rls=1（默认） | 3~5 | 3~5 | 0~1 | 27 |
| maxref=16，occfrm_rls=0 | 4 | 4 | 0 | 35 |
⇒ 关闭"占用帧释放"**没有**改善 P 帧问题，排除该路径。

#### 四、下一轮（追参考帧标记）
1. 解码完成路径：确认 VDH 中断后 vfmw 是否走到 `FSP_SetRef`（参考帧标记）
2. 若 `FSP_SetRef` 未被调用，检查驱动是否在 VDH 完成后过早释放帧存
   （`VDEC_RecordOccupiedFrame` / `RlsFrm` / FSP 状态回写）
3. 排查 `ExpectedDecFsNum=4` vs `ActualDecFsNum=32` 的口径差异

### 4.51 2026-11-05：**万恶之源找到 —— VDH 解出来是 100% 错误帧**（`err_mbs == total_mbs`）

#### 一、决定性证据（全量打印，`vdec_dfs=1 maxref=16`）
```
N: total_mbs=920,err_mbs=920, ErrFrame_Flag: 0
N: Chan 0: Current frame:0  ErrRatio = 100
N: line 3947, REPORT_IFRAME_ERR
N: store pic err, ret = -1
```
⇒ VDH 处理了全部 920 个宏块、**每一个都报错**（ErrRatio=100%）→ vfmw 判定整帧错误
   → `store pic err` / `StorePicInDPB` 失败 → DPB 恒空 → P 帧参考列表为空 → P 帧全丢。
   **这是 M2 所有下游现象的同一个根因。**

#### 二、本轮系统性排除的变量（每次干净单启）
| 变量 | 取值 | err_mbs/920 | 结论 |
|---|---|---|---|
| `vdec_maxref` | 0 / 3 / 4 / 8 / 16 | 均 920 | 无关 |
| `vdec_dfs` | 0 / 1 | 均 920 | 无关（改的是 FSP 数量：32 vs 12） |
| `vdec_occfrm_rls` | 0 / 1 | 均失败 | 无关 |
| `vdec_flush_put` | 0 / 1 | 均 920 | **不是 cache flush 方向问题** |
| `vdec_uncached_mmz=1` | — | 取流路径直接坏掉（`GetBuffer rc=0x80120002`） | 不可用 |

#### 三、已修（上一轮）并验证
`osal_free_irq()` dev_id 修正：free_irq 相关 trace 计数 → 0 ✅

#### 四、下一轮（直击 VDH 100% 错误）
1. **码流物理地址/偏移**：vfmw 给 VDH 的 bitstream phy 是 `0x28ad426b`（非对齐、位于 ES ring 内偏移），
   核对 VDH 侧 DecParam 里拿到的地址/偏移是否与 CPU 解析用的是同一块内存
2. **SPS/PPS 是否正确进入 VDH 寄存器/上下文**：CPU 语法解析 OK，但硬件切片头解析可能拿不到参数
3. 打开 VDMREG 相关打印（bit3 已包含在 0xFFFFFFFF 内）逐帧看 VDH 起跑前的寄存器/参数
4. 对照 SDK 里 `vdm_hal.S`/`vdh_module.S` 对 DecParam 字段的期望，检查我们 port 里对应数据结构的填充

### 4.52 2026-11-05：SMMU 三种模式对照（mode2 把 ErrRatio 从 100 降到 96），并加"物理内存回读"探针

#### 一、SMMU 模式对照（全量打印，gen2，每次干净单启）
| `vdec_smmu_mode` | SCR | post_mfde | ErrRatio | 结论 |
|---|---|---|---|---|
| 0（默认） | 1 | 3~5 | **100** | 全宏块报错 |
| 1（关 SMMU） | 0 | **0** | — | 完全不解码（`post_mfde=0`） |
| 2（恒等页表） | 1 | 3 | **96** | 略改善，仍不可用 |

⇒ SMMU 不是"全有全无"的开关：`SCR=1` 必须有；恒等页表（TTBR=0x19100000，1GB 恒等映射）
   让 ErrRatio 从 100 降到 96，说明**硬件确实在按地址读码流**，只是数据/参数仍有问题。

#### 二、新增探针：物理内存回读（`VDEC_Chan_RecvStrmBuf`）
在原有 KSUM/hdr 打印旁，增加用 `ioremap(PhyAddr & PAGE_MASK)` 直接读**物理内存**的 8 字节，
与内核 VA 读出的 hdr 对比，用于判定 cache 一致性：
```
VDECDBG5: ... len=6140 hdr=000000016742c01e       (内核 VA, 正确)
            phy[........]                          (预期: 物理内存内容)
```
本轮运行时 `phy[...]` **没有输出**（说明 `ioremap()` 返回 NULL），下一轮先修这个探针
（改用 `memremap` 或打印 ioremap 失败原因），再做 cache 一致性判定。

#### 三、其他核对
- 厂商 vdec 驱动只用 3 个平台钩子（`HI_DRV_SYS_GetChipVersion/GetFlag/GetVideoCodecSupport`），
  **没有时钟/复位调用** ⇒ 时钟由 vfmw 核心（经 `g_pstRegCrg`）或启动阶段负责
- 码流地址实测为非对齐物理地址（如 `0x28ad4001`），位于 vfmw 3MB 环形缓冲（0x28ab4000）内偏移，
  符合"SCD 从环形缓冲切 NAL"的设计

#### 四、下一轮
1. 修物理回读探针（ioremap 失败原因），确认 DRAM 内容与 VA 一致（排除 cache）
2. 在 mode2（恒等页表）基础上，检查 SCD 切出的 NAL 地址/长度是否与 CPU 侧一致
   （即交给 VDH 的 bitstream 起点/长度是否正确）
3. 若地址/长度都正确 → 重点转向 VDH 的 **SPS/PPS 参数装载**与 slice header 解析

### 4.53 2026-11-05：修正 SMMU mode2 —— 原来 TTBR 写入后又被清零（等于从未生效）；真正配好页表后反而完全不解码

#### 一、发现并修掉的 bug（`port_stubs.c`）
`hi_vdec_smmu_bypass()` 在 mode2 分支里写完 `SCB_TTBR/CB_TTBR` 之后，**紧接着又无条件清零**
```
writel(0, g_vd_smmu + 0x208); /* SCB_TTBR */
writel(0, g_vd_smmu + 0x20c); /* CB_TTBR */
```
⇒ 历史上所有 `vdec_smmu_mode=2` 的对照其实**都没真正装页表**（等同 mode0）。
本轮改为：mode2 不清零，且页表用正确的 **ARMv8 一级 1GB block 描述符**
（`(i<<30)|0x71D`，valid+block+WB+inner-shareable+AF，覆盖 0~4GB 恒等）。

#### 二、修复后的实测（干净单启，gen2）
```
SMMUPT: pt phys=0x19100000 e0=0000071d e1=4000071d
SMMUCFG: SCR=00000001 SCB=19100000 CB=19100000 ERR=00000000   ← TTBR 确实生效
TSTAT:  post_mfde=0   ← **完全不解码**（比 mode0 更差）
```
⇒ 结论：**配了页表但 SMR/CB 上下文没配置好，硬件访问全部失败**；而 mode0（TTBR=0）属于
   "无页表即旁路"，硬件直接用物理地址（所以还能解，只是 100% 宏块错）。
   **即 SMMU 地址翻译不是 100% 宏块错的根因**，可以把它排除。

#### 三、下一步（聚焦码流内容/参数）
1. 回到 mode0（默认），做**物理内存回读探针**（上一轮 ioremap 方式未输出，本轮继续修：
   改用 `memremap(..., MEMREMAP_WC)` 或先打印 ioremap 返回值判定失败原因）
2. 对比 CPU VA 内容与硬件可见物理内容，判定 cache 一致性
3. 若一致 → 检查 SCD 切出的 NAL 地址/长度（交给 VDH 的 bitstream 起点/长度）与 SPS/PPS 装载

### 4.54 2026-11-05：**关键突破 —— `vdec_sed_only=1` 后硬件逐帧解码成功（30/30）**

#### 一、发现
构建里带 `-DVFMW_H264_SED_ONLY_SUPPORT`（预编译核按 SED-only 编译），但驱动参数
`vdec_sed_only` 默认 0 ⇒ **驱动告诉 vfmw "非 SED-only"，与核的编译配置冲突**。
改成 `vdec_sed_only=1` 后：

| 配置（干净单启，gen2.h264） | post_mfde | vdh | 说明 |
|---|---|---|---|
| `sed_only=0`（默认） | 3~5 | 3~5 | 只有 IDR 解，100% 宏块错 |
| **`sed_only=1` + `dfs=1` + maxref=16** | **30** | **30** | **全部 30 帧都由硬件解码** |
| `sed_only=1` + `dfs=0` + maxref=16 | 27 | 27 | 同样几乎全解 |

对应 VTSTAT：`put=30 read=1181 img=0 ack=1 | vdh=30 scd=30`（`since_vdh` 只有 21ms，
说明硬件持续工作，不再"几秒一次"）。

#### 二、结论
- **`vdec_sed_only=1` 是必需配置**（与预编译核匹配）。这一条把 M2 从"硬件基本不动"
  推进到"硬件每帧都解码"。
- 剩下的唯一问题变成 **输出侧**：`img=0`（`VCTRL_GetChanImage` 拿不到影像），
  Luma/Chrom 地址全 0、`w=h=0`。
- 曾出现 `img=1`（带 `vdec_dbg=1` 的那次），说明输出链路本身是通的，只是"何时把帧放进
  VO 队列"的逻辑没有覆盖每一帧。

#### 三、下一轮（专攻输出）
1. 看 `/proc/vfmw/buffer` 的 VoQue/`IsOccupied` 与 `OutputFrameNum`，对照 `DecodeFrameNum=30`
2. 检查驱动 `VDEC_RecordOccupiedFrame`/`REPORT_OCCUQIED_FRM` 与 `RlsFrm` 的时序：
   现在每帧都解码成功，若驱动把帧立刻释放，vfmw 就不会把它放进输出队列
3. 检查 `stOption` 里 `s32ExtraFrameStoreNum=4`、`dispnum=2` 与 `IsImgOutputEn` 的配合

### 4.55 2026-11-05：解码已通后，输出侧定位到 `SYNTAX_ReceiveImage` 返回非 1（vfmw 影像队列为空）

#### 一、反汇编确认取图失败点（`core/common/vfmw_ctrl.S:4686 VCTRL_GetChanImage`）
```
cmp  w20,#31        ; chan id 合法
ldr  x0,[chan_array + id*8]   ; pCtx 非空
cbz  x19,...        ; pImage 非空
ldr  w1,[x0,#4];  cmp w1,#1   ; ① 通道 state == 1
ldr  w1,[x0,#12]; cmp w1,#1   ; ② IsImgOutputEn == 1
bl   SYNTAX_ReceiveImage      ; ③ 从影像队列取图
cmp  w0,#1;  b.eq .L608       ; 非 1 ⇒ 返回 -1
```
驱动侧 IMGDBG 也显示 ①② 都满足（f4/f12 均为 1），失败点就是 **③ 影像队列为空**。

#### 二、入队函数 `OutputFrmToVO`（`core/syntax/h264.S:17001`）的提前返回条件
```
ldr x0,[x19]; ldr w0,[x0,#24]
cbz w0, .L2869                    ; 若该字段为 0 才继续
ldr w0,[x19,#65536+1908]
cmp w0,#2; beq .L2869             ; 该字段 == 2 才继续
; 否则：清 pending 影像直接返回（**不入 VO 队列**）
```
⇒ 多数帧很可能卡在这两个字段的判定上（字段语义待与 `vfmw_ctrl.h` 结构体偏移对齐）。

#### 三、本轮实测（`vdec_sed_only=1 vdec_dfs=1 vdec_maxref=16`，干净单启）
```
TSTAT : mfde_calls=1272 mfde_tasks=28 scd_calls=1272 scd_tasks=30 post_scd=30 post_mfde=28
VTSTAT: put=30 read=1038 img=0 ack=1 | vdh=28 scd=30 since_vdh=21ms
```
⇒ **硬件 28/30 帧解码稳定**；输出仍 0（个别轮次 img=1）。
另外：打印位开到 IMAGE/QUEUE/REF/DPB（0xF8D7）时打印量过大导致板子重启 ⇒ 这些位不可全开。

#### 四、下一轮
1. 用 `vfmw_ctrl.h` 结构体偏移对齐 `[ctx+24]` 与 `[ctx+65536+1908]` 的字段语义，
   确认是"解码状态/输出开关/disp 标记"中的哪一个在拦输出
2. 检查 `VDEC_RecordOccupiedFrame`（会把 IsImgOutputEn 置 0 再置 1）是否在解码窗口内被调用，
   以及在它关闭窗口内解出的帧是否被丢弃
3. 用 `VDEC_CID_GET_CHAN_STATE` 在运行中打印通道状态字段，验证上述判定值

### 4.56 2026-11-05：帧既没进 vfmw 影像队列、也没走 VO 回调（`voacq=0`）；解码后帧被立即回收

#### 一、新增计数（`voacq`）
在 `VDEC_Chan_VOAcqFrame()`（VO/VPSS 侧取帧回调）加计数并接入 VTSTAT：
```
TSTAT : mfde_tasks=29 post_mfde=29 scd_tasks=30
VTSTAT: put=30 read=1173 img=0 ack=1 | vdh=29 scd=30 | voacq=0
```
⇒ **硬件解了 29 帧，但既没进 vfmw 内部影像队列（read_image 恒 -1），也没走 VO 回调（voacq=0）**。
  之前 FSP dump 里"解码后帧全部 Free、IsRef=0"与此一致：**帧被解出后立即被当作"不需要显示"回收**。

#### 二、字段对齐进展
`VFMW_CHAN_S`（`vfmw_ctrl.h`）字段顺序已确认：
```
0 s32ChanID | 4 s32IsOpen | 8 s32IsRun | 12 s32IsImgOutputEn | 16 s32IsInit |
20 s32Priority | 24 s32StopSyntax | 28 MatchVdhIdPlus1 | ...
```
⇒ `VCTRL_GetChanImage` 校验的 `[ctx+4]`=IsOpen、`[ctx+12]`=IsImgOutputEn 都对得上（均满足）；
  `OutputFrmToVO` 的第一个判定 `[ctx+24]` = **s32StopSyntax**（为 0 时走正常输出路径，我们应为 0）。

#### 三、当前判断
卡点在 **DPB → 显示输出的决策**：
- 帧解码完 → FSP 立即回收（IsRef=0、Free）⇒ 说明 vfmw 认为"这帧不需要显示"
- 可能原因：显示相关配置（`DispFrameNum`/输出顺序/`s32IsInit`）或 `OutputFrmToVO` 后续的
  `CheckFrameStore` 返回 -3（帧存不可用）而被丢弃

#### 四、下一轮
1. 反汇编 `CheckFrameStore`（h264.S）看 -3 的返回条件，判断是否我们的帧存/FSP 状态不满足
2. 检查 `[ctx+16] s32IsInit`（"刚初始化未解码"）是否在解码后被正确清零
3. 对照 omxvdec 的显示配置（`DispFrameNum`、`bOrderOutput`、`s32Speed`）逐项核对驱动下发值

### 4.57 2026-11-05：**核心 `.S` 原来是参与汇编的源文件**（可任意插桩）；实测输出链一次都没进入，`StorePicInDPB` 只被调用 3 次

#### 一、能力突破：`.S` 可插桩
`port/vdec/Kbuild` 以 `xxx.o` 形式列出核心对象；Linux kbuild 在只有同名 `.S` 时**会用汇编器现场编译**。
证据：之前加的 `hi_vdec_dbg_scdcond`、`hi_vdec_dbg_imgins` 钩子都生效了。
⇒ 现在我们可以在 vfmw 核心的**任意函数/标签**处插入探针。

#### 二、插桩结果（干净单启，`sed_only=1 dfs=1 maxref=16`）
| 探针 | 位置 | 计数 |
|---|---|---|
| `OFV` | `OutputFrmToVO` 入口（h264.S:17001） | **0** |
| `OFD` | `OutputFrmFromDPB` 入口 | **0** |
| `DIROUT` | `DirectOutput` 入口（h264.S:20939） | **0** |
| `INSQ` | `InsertImgToVoQueue` 入口（syntax.S:452） | **0** |
| `IMGINS` | vfmw_ctrl 入队后钩子 | **0** |
| `SPITAG tag=1` | `StorePicInDPB` 入口 | **3**（=IDR 数） |
| `SPITAG tag=2..7` | `.L3808/.L3833/.L3836/.L3837/.L3971/.L3972`（输出判定内部） | **0** |

同时：`STORE_PIC_ERR=0`、`PSLICE_EMPTY=0`、`GAP=0` ⇒ **DPB 存储本身已正常、P 帧解码不再报错**。

#### 三、结论
- 硬件解码 28~30/30 正常、DPB 存储正常；
- **但 `StorePicInDPB` 只被调用 3 次（正好 3 个 IDR）**，25 个 P 帧根本不走这条路径；
- 输出链（DPB 输出/直接输出/入队/取图）**全部 0 次**。

⇒ 打开 `sed_only=1` 后，vfmw 对 P 帧的处理路径与 IDR 不同：P 帧解码完成但没进入
  "图片级"处理（`StorePicInDPB` → 输出判定）。下一轮要查的是**每帧解码完成后的图片级处理入口**。

#### 四、下一轮
1. 在 `StorePicInDPB` 的 5 个调用点（h264.S:22549/22612/24941/25010/25130）前后加 tag，确认哪些调用点被执行
2. 找到"VDH 解码完成 → syntax 图片级处理"的入口（SED 消息处理函数），确认 P 帧是否只做了 slice 级处理
3. 若 P 帧确实缺少图片级处理 → 查 SED_ONLY 模式下的 picture 边界判定（可能依赖 SCD 的 frame 边界消息）

### 4.58 2026-11-05：**VDH 完成后处理路径实测 —— 26/29 帧走 SED-only 专用分支**（不走 `VDMDRV_AfterDec`）

#### 一、插桩覆盖（vm_drv.S + vfmw_ctrl.S + h264.S）
| tag | 位置 | 计数 |
|---|---|---|
| 15 | `VDMDRV_IsrProcess` 入口 | **30**（=vdh 中断数）|
| 21 | `VDMDRV_DoBeforeDec` 入口 | **30** |
| 16 | `VDMDRV_AfterDec` 入口 | **3** |
| 28 | `.L340` → `bl VDMDRV_AfterDec` 处 | **3** |
| 24 | **`.L401` 分支（`[vdh_inst+56]==1`）** | **26** |
| 23/25/26/27 | `.L400/.L402/.L403/.L404` | 全 0 |
| 12/13/14 | `VCTRL_VdmPostProc` 入口/通过点/提前返回 | 3/3/0 |
| 1/2/6/8/10 | `StorePicInDPB`/`.L3808`/`.L3971`/`VDMPostProc`/调用点 | 3/0/0/3/3 |
| — | `OFV/OFD/DIR/INSQ` | 0/0/0/0 |

⇒ **30 次 VDH 完成中断中：3 次走普通 `VDMDRV_AfterDec`（→ VDMPostProc → StorePicInDPB），
   26 次走 `.L401` → `VCTRL_VdmProcSedOnly(chan, vdhId)`**。

#### 二、`.L401` 分支真相
```asm
.L401:
	mov	w1, w19
	mov	w0, w25          ; w25 = 通道号
	bl	VCTRL_VdmProcSedOnly
```
`VCTRL_VdmProcSedOnly`（vfmw_ctrl.S:5690）：
- 校验 `[ctx+8]==1`（IsRun）、`VCTRL_GetDecParam` 非空
- 按 `[ctx+632]` 编解码类型分派：`0 → H264DEC_VDMProcSedOnly`，`16 → HEVCDEC_VDMProcSedOnly`

而 `H264DEC_VDMProcSedOnly`（h264.S:25295）**只做完成计数比较并返回 0/1**：
```c
x3 = ctx->pVdmInst;                 // [ctx+616]
w19 = [x3+44] * [x3+36] - 1;        // 期望值
if (w19 == [x20+20])  ...  else if ([ctx+65536+1992] != 1) return 0;
ctx->pVdmInst = NULL;
```
⇒ **SED-only 模式下"帧完成"的图片级处理不在这个函数里**；普通路径（AfterDec）只覆盖了 3 帧。
   这解释了为什么输出链计数几乎全 0：**26 帧只做了 SED 完成计数，没进入图片级处理**。

#### 三、下一轮
1. 在 `H264DEC_VDMProcSedOnly`（tag 29/30/31）与 `H264DEC_IsNeedSedOnly`/`CheckSedOnly`（tag 32/33）加探针
2. 找 SED 模式下"帧完成 → 图片级处理"的真正入口（候选：`CutStreamWithSCD`、SED up-msg 处理、scd_drv 回调）
3. 若确认 SED 路径缺少图片级处理 → 检查驱动是否漏了某个 SED 相关回报（up-msg / segment 信息）

### 4.59 2026-11-05：**原厂与 SDK 都是 `SedOnlyEnable=0`**；`sed_only=0` 实测只启动 3 次解码（全 100% 宏块错），`sed_only=1` 则 30/30 正常但走 SED 路径

#### 一、关键对照（源码事实）
| 代码 | `s32SedOnlyEnable` 取值 |
|---|---|
| 原厂 omxvdec `decoder_vfmw.c:1380` | `HI_FALSE` |
| SDK vdec v2.1 `drv_vdec_intf_k.c:2574` | `0` |
| 我们的移植（`vdec_sed_only` 参数） | 默认 0，本轮证明 **1 才能让硬件真正解码** |

⇒ 即 `sed_only=1` 对我们是"能用但非原厂语义"的绕行；原厂走的是 `0`。

#### 二、两种配置的实测对比（插桩后，干净单启，gen2）
| 配置 | vdh | isr | beforedec | afterdec | L401(SED) | err_mbs | img |
|---|---|---|---|---|---|---|---|
| `sed_only=0` | **3** | 3 | 3 | 3 | 0 | 3 帧全 100% | 0 |
| `sed_only=1` | **30** | 29 | 28 | 3 | **26** | 0 | 0~1 |

- `sed_only=0`：SCD 切了 30 帧（scd=30），但**只有 3 次解码启动**，且 3 帧都 `err_mbs=920`（ERRMB=3）
  ⇒ 这正是 M2 最初的"只解 IDR + 100% 宏块错"现象。
- `sed_only=1`：30 次解码全部成功、无宏块错，但 26 帧走 SED 专用完成路径，图片级处理极少。

#### 三、SED 路径内部计数（`sed_only=1`）
`H264DEC_VDMProcSedOnly`（26 次调用）内部：
```
match(.L4533)=14   decvdm=3   abort(.L4534)=1   mismatch(.L4525)=1   done(.L4523)=1
```
其中 `match` 后若 `[ctx+65536+1992]==1` 走"done"直接返回，否则才 `bl DecVDM`。
⇒ 26 帧里只有 3 次真正进入 `DecVDM`（图片级处理），其余只做计数/清理。

#### 四、下一阶段的判断
两条路：
- **A. 修 `sed_only=0`（原厂语义）**：先解决"只启动 3 次解码 + 100% 宏块错"，
  一旦打通，输出链应走 `AfterDec → VDMPostProc → StorePicInDPB → 输出` 的成熟路径。
- B. 继续 SED 路径反解（`DecVDM` 语义、`[ctx+1992]` 含义），不确定性更高。

下一轮优先走 A：查非 SED 模式下 VDH 启动参数/slice 信息为何全错（对照 `H264DEC_VDMPostProc`
与 `VDMDRV_AfterDec` 的入参），以及为什么只启动 3 次。

### 4.60 2026-11-05：结构性澄清 —— `StorePicInDPB` 失败是"100% 解码错误"的**结果**，不是独立 bug

#### 一、新工具：头文件偏移计算器（已跑通）
用 Kbuild 相同的 `-D` 与 include 路径，在主机上编译一个小程序打印 `offsetof`：
```bash
cd /tmp && gcc $DEFS $SDK_INCS $VM_INCS offs.c -o offs && ./offs
```
输出（**实测值**）：
```
IMAGE size=640
H264_FRAMESTORE_S size=856  fs_image off=16
  logic_fs_id=656  frame_num=660  poc=672  is_displayed=676
  pic_type=684  err_level=688  pmv_address_idc=692
H264_DEC_PIC_PARAM_S size=1192
```

#### 二、`.L3791` 判定含义（已确认）
`StorePicInDPB` 里：
```asm
.L3783:
	ldr	w0, [x22, 708]      ; 帧存字段
	str	w0, [x24, 688]      ; -> framestore.err_level
...
	ldr	w1, [x24, 688]      ; w1 = err_level
	str	w1, [x19, 152]      ; image.error_level
	cbz	w1, .L3793          ; **err_level==0 → 正常存储**
	ldrb	w0, [x19, 64]
	and	w0, w0, 3
	cbz	w0, .L3966
.L3791:                      ; err_level != 0 → 错误处理分支
```
插桩实测（`sed_only=0`）：`q(688)=100 cnt(+4)=0 flag(+684)=0`
⇒ `err_level = 100`（**100% 错误率**）→ 必然进错误分支 → 打印 `StorePicInDPB return(-1) from L3972`。
而 `sed_only=1` 时 `.L3791` **一次都不进**（`DPBCHK=0`），因为解码无错（err_level=0）。

#### 三、结论（修正 §4.47/§4.49 的判断）
- `StorePicInDPB` 失败**不是** DPB 配置/maxref 的问题，而是 **VDH 报了 100% 宏块错（err_level=100）**
- 因此路线 A 的唯一问题收敛为：**非 SED 模式下为什么 VDH 全宏块报错**
- `sed_only=1` 时硬件不报错（err_mbs=0），说明码流/地址本身没问题，差异在**非 SED 模式下交给硬件的参数**

#### 四、下一轮
1. 在 `VDMDRV_DoBeforeDec` 处 dump 交给 VDH 的关键参数（两次运行对比 `sed_only=0/1`）
2. 重点看 slice 参数/bitstream 地址与 `IsSedOnly` 字段是否被正确填写
3. 若确认是 slice 参数缺失 → 对照 `H264DEC_VDMPostProc` 之前 CPU 解析出的 DecParam 内容

### 4.61 2026-11-05：SED 路径内部实测 —— `flag1992=1` 时直接走"done"，**永不调用 `DecVDM`**（因此无图片级处理）

#### 一、偏移表扩展（主机端计算器）
`H264_DEC_PIC_PARAM_S`（size=1192）关键偏移：
```
SliceParaNum=940  vdh_start=952  basic_cfg0=960  stream_base_addr=736  mbtodec=740
ApcSize=936  IsSedOnly=1188  RefPicType=1056  RefPicFsId=1120
IMG: error_level=152  image_id=148  frame_num=176
H264_FRAMESTORE_S: logic_fs_id=656 frame_num=660 poc=672 is_displayed=676
                   pic_type=684 err_level=688 pmv_address_idc=692
```
（`IMAGE.error_level=152` 与 `StorePicInDPB` 里 `str w1,[x19,152]` 完全对上 ⇒ `[x24+688]=err_level` 确认）

#### 二、`H264DEC_VDMProcSedOnly` 判定实测（`sed_only=1`）
插桩位置：`mul w19` / `ldr w3,[x20,20]` 之后。实测 10 次采样：
```
SEDP: exp=919 got=919 flag1992=1 c1904=1      (多数帧 MB 数完全匹配)
SEDP: exp=919 got=809 flag1992=1 ...
SEDP: exp=919 got=895 flag1992=1 ...
```
判定逻辑：
```asm
cmp  w19, w0            ; 期望MB数-1 vs 实际
ldr  w0, [ctx+1992]
beq  .L4533             ; 相等 → .L4533: cmp w0,1; beq .L4523(done，直接返回)
                        ;              否则 bl DecVDM
```
⇒ **`flag1992`(=ctx+1992) 恒为 1** ⇒ 即使 MB 数完全匹配也走 `done` 分支，
   `DecVDM`（含 ClearDPB/FSP_SetDisplay 等图片级处理）只在 3 次调用里出现过。
   **这就是 SED 路径下"解码成功但无输出"的直接原因。**

#### 三、当前结论
- `sed_only=1`：硬件 30/30 解码、MB 数匹配，但 `ctx+1992==1` 让完成处理走 done 分支，无图片级处理
- `sed_only=0`：VDH 100% 宏块错（err_level=100）→ DPB 存储失败 → 参考帧建立不了
- 两条路都需要弄清 `ctx+1992` 的语义（SED 成功标志？）或非 SED 模式的宏块错原因

#### 四、下一轮
1. 找出 `[ctx+65536+1992]` 的写入点（谁置 1），确认它是否是 "SedOnlySucc/已处理" 标志
2. 若可控，令其为 0 使流程进入 `DecVDM` → 看是否产生图片级处理与输出
3. 同时保留 `sed_only=0` 的宏块错排查（逐帧 err_level + DecParam dump）

### 4.62 2026-11-05：`ctx+1992` 写入者 = `H264DEC_CheckSedOnly`；强制走 `DecVDM` 的实验（部分改善但不出图）

#### 一、`ctx+1992` 语义已确认
写点只有两处：
```asm
H264DEC_CheckSedOnly:                  # h264.S:20488
	add	x19, x20, #65536
	ldr	w0, [x19, 1988]        ; sed 状态
	str	wzr, [x19, 1992]       ; 先清 0
	...
.L3563:                                ; 判定为"SED 可接受"时
	mov	w0, #1
	str	w0, [x19, 1992]        ; 置 1
```
判定依据：SED 状态、`VCTRL_CheckFreshSeg`/`VCTRL_CheckFreshRaw`、以及从 SED 数据里解析出的
slice 类型（`BsSkip 24` → `BsGet 5`）。⇒ **1992 = "本图走 SED-only 完成流程"** 的标志。
`H264DEC_VDMProcSedOnly` 里只要它==1 就直接 done 返回，不调用 `DecVDM`。

#### 二、受控实验：强制让 SED 完成走 `DecVDM`
在 `.L4533` 前置 `w0=0`（强制不跳 done 分支），干净单启实测：
| 指标 | 正常 | 强制 DecVDM |
|---|---|---|
| `decvdm` | 2~3 | **13** |
| `StorePicInDPB` 调用 | 2~3 | **5** |
| `VDMPostProc` | 2~3 | 4 |
| `OutputFrmToVO` / 入队 | 0 | **1 / 1** |
| `img` | 0~1 | 1 |
⇒ 强制后图片级处理确实变多（`DecVDM` 13 次、真出了一次入队），但**仍然只有 1 帧输出**，
  说明缺的不是"调不调 DecVDM"，而是**每帧的图片级处理/输出链仍有别的门**。
实验已回滚（保持构建干净）。

#### 三、事故与恢复（记录）
本轮第一次改 `h264.S` 时，Python 以 latin1 写入含中文注释的内容 → 编码异常发生在
`open('w')` 之后，导致 **`h264.S` 被截断为 0 字节**，构建报一堆 `undefined symbol`
（`H264DEC_VDMPostProc`/`g_CabacMN` 等）。
**恢复**：从 `backup/port-1105-1118.tgz` 还原该文件（含当时全部插桩），重建即恢复。
**教训**：改 `.S` 必须 (1) 只用 ASCII 注释；(2) 先写临时文件再 `os.replace`；
(3) 改完立即 `make` 验证符号完整。

#### 四、下一轮
1. 在 `H264DEC_VDMProcSedOnly` 返回 done 的分支上，尝试补一次"上一个图片的后处理"
   （`VCTRL_VdmPostProc`/`H264DEC_VDMPostProc`），看能否逐帧产出图片
2. 或改从 `H264DEC_CheckSedOnly` 的判定入手，让部分帧走 CPU 解码路径（非 SED）
3. 保留 `sed_only=0` 的宏块错排查作为备选

### 4.63 2026-11-05：`H264_IsNewPicNal` 属 PTS 链（`DecChanProcessPts`），本流程从未调用

#### 一、插桩结论（干净单启，`sed_only=1`）
给 `H264_IsNewPicNal` 的三条返回路径 + first_mb 解析点都插了计数：
```
SPIC6: slice=0 spspps=0 neg1=0 parsed=0 firstmb=0
```
⇒ **该函数一次都没被调用**。

调用链反查：
```
H264_IsNewPicNal  (h264.S:16177)
   ← IsNewpicSeg      (syntax.S:3967)
       ← DecChanProcessPts (vfmw_ctrl.S:8170)
```
`DecChanProcessPts` 是 **PTS 处理**函数，只在有 PTS 相关处理时进入。
⇒ 它**不是**解码/出图路径的"图片边界"判定，之前对它寄予的期望不成立。

#### 二、再次确认的因果链
- SED 完成的 26 帧走 `.L401 → VCTRL_VdmProcSedOnly → H264DEC_VDMProcSedOnly`（只计数）
- 只有非 SED 完成的 3 帧走 `VDMDRV_AfterDec → VCTRL_VdmPostProc → H264DEC_VDMPostProc`
  → 这才是 `StorePicInDPB` 与输出链的唯一入口
- 而 `H264DEC_VDMPostProc` 全文件只有 `VCTRL_PostProc` 一个调用者，
  `VCTRL_PostProc` 又只被 `VCTRL_VdmPostProc` 调用，后者只出现在 `vdm_drv.S` 的完成路径
⇒ **SED 模式下漏掉的正是"完成时调用 VDMPostProc"这一步**（或等价的后处理）

#### 三、方法备忘
板子在测试**结束卸载模块时**会崩溃重启（已知问题），因此分析用的计数器要在
**运行中取数**（`sleep 6` 后 grep dmesg 再 `pkill`），不能等测试进程退出后再取。

#### 四、下一轮
1. 在 `H264DEC_VDMProcSedOnly` 的 done 分支**补一次 `VCTRL_VdmPostProc`/`H264DEC_VDMPostProc`**
   （参数可从 `.L401` 现场对齐），验证是否能逐帧产出图片
2. 若参数难对齐，则改在 `VDMDRV_AfterDec` 之外，让 SED 完成也走一次 post-proc
3. 观察 `StorePicInDPB`/`OutputFrmToVO`/`InsertImgToVoQueue` 是否变成 ~30 次

### 4.64 2026-11-05：实验 —— SED 完成也调用 `VDMDRV_AfterDec`（结构生效，但后处理仍被内部守卫挡住）

#### 一、改动与实测
在 `vdm_drv.S` 的 `.L401`（SED 完成分支）里，`VCTRL_VdmProcSedOnly` 之后追加：
```asm
	mov	w1, 1
	mov	w0, w25        ; chan
	bl	VDMDRV_AfterDec
```
干净单启、运行中取数（避免退出时崩溃丢日志）：
```
SPIC3: isr=8 afterdec=8 beforedec=8     ← 每次完成都进 AfterDec（结构生效）
SPIC : t1=3 t2=1 t6=2 t8=2 ... ofv=1 ofd=1 insq=1
SPIC5: decvdm=2 match=5
VTSTAT: put=9 read=285 img=1 vdh=7 scd=9
```
⇒ `afterdec` 由 3 提升到"等于中断数"，但 **`VDMPostProc` 仍只有 2 次、`StorePicInDPB` 3 次、输出仍 1 帧**。
实验已回滚（无收益）。

#### 二、判断
`VDMDRV_AfterDec` 内部对 `VCTRL_VdmPostProc` 的调用有多重守卫，至少包括：
- 局部标志 `[x29+96] == 1`（"需要后处理"）
- `VCTRL_GetDecParam(chan) != NULL`
- `[vdh_inst+36]/[vdh_inst+56]` 等状态位

SED 完成时这些条件不满足（DecParam 可能已被 `VdmProcSedOnly` 消费）⇒ 后处理被跳过。

#### 三、下一轮
1. 在 `VDMDRV_AfterDec` 的 4 个 `VCTRL_VdmPostProc` 调用点前 dump 守卫值
   （`[x29+96]`、`VCTRL_GetDecParam` 返回值、`[vdh+36]/[vdh+56]`），确定是哪一条挡住
2. 如果是 DecParam 已被消费 → 考虑在 SED 完成路径中"延迟消费"或重新取参数
3. 若是状态位 → 在 SED 路径里补相应状态

### 4.65 2026-11-05：`DecParam` 实测对比（`IsSedOnly` 逐帧不同）；`DecVDM` 实为"清图"函数

#### 一、修正探针后拿到真实 DecParam（`pDecParam = [x20]`）
`sed_only=0`：
```
DPARM : chan=0 isSedOnly=0 slicenum=1 stream_base=0x28ad43fc mbtodec=920
DPARM2: img0=0x2901c000 img1=0x29099000 pmv0=0x2908a000 refid0..3=0,0,0,0
```
`sed_only=1`（逐帧采样 8 条）：
```
frame1 : isSedOnly=1 stream_base=0x0
frame2 : isSedOnly=0 stream_base=0x28ad4418
frame3+: isSedOnly=1 stream_base=0x28ad4418 ...   (之后基本恒 1)
```
⇒ **vfmw 逐帧决定是否用 SED**（`H264DEC_CheckSedOnly`），不是整条通道一刀切；
   `sed_only=1` 时绝大多数帧走 SED，`sed_only=0` 时全部非 SED。
   同一次 `sed_only=1` 运行中只有 1 帧 `err_mbs=920`，其余无错。

#### 二、`DecVDM` 的真实身份
`DecVDM`（h264.S:19566..19913）全部调用只有：
`H264_ClearCurrPic ×7`、`ClearDPB ×1`、`FSP_SetDisplay ×3`、`dprint ×5`
⇒ 它是**清图/放弃当前图**的函数（错误处理），**不是解码或出图**。
这也解释了上一轮"强制走 DecVDM 后仍只出 1 帧"。

#### 三、SED 完成分支直接调用 `VCTRL_VdmPostProc(chan,1,NULL,vdhId)` 的实验
实测：`t1/t8/OFV/OFD/INSQ 全 0`，`img=0` —— 无效果（`DecParam` 已被消费或状态不符）。已回滚。

#### 四、当前结构性认识（累积）
- 图片入库/出队**只**发生在 VDH 完成路径 `VDMDRV_AfterDec → VCTRL_VdmPostProc → H264DEC_VDMPostProc`
- SED 完成路径（`.L401`）不调用它，只做 MB 计数
- 非 SED 模式：硬件 100% 宏块错（IDR 首帧偶有干净）→ DPB 存储失败 → 跑 3 帧就停

#### 五、下一轮
1. 用修好的 DPARM 探针，对比非 SED 模式下**第一帧（干净）与第二帧（100% 错）**的 DecParam
   （重点 `refid0..15`、`slice` 字段、`stream_base_addr`），找出第一帧后状态如何变坏
2. 若发现参考帧列表为空/无效 → 查 `StorePicInDPB` 是否真正写入 DPB（用 FSP/DPB 计数验证）

### 4.66 2026-11-05：非 SED 模式**首帧 IDR 也 100% 宏块错**（加大启动延迟无效）；外部帧存路线不可用

#### 一、非 SED 模式 DecParam 与错误关联（干净单启）
```
DPARM : isSedOnly=0 slicenum=1 stream_base=0x28ad43f0 mbtodec=920
DPARM2: img0/img1 有效, pmv0=0x2908a000, refid0..3 = 0,0,0,0
→ total_mbs=920,err_mbs=920 → StorePicInDPB return(-1) from L3972
（第二帧 stream_base=0x28ad64b8，同样 err_mbs=920、同样失败）
```
`STARTDELAY` 从 1500/2000 提到 **5000**：仍 `err_mbs=920`（2 次解码，两次都全错）。
⇒ 与"SCD 分段来不及"无关；**首帧 IDR 本身就解错**（IDR 不依赖参考帧，说明问题在
   slice 数据/参数，而非 DPB）。

#### 二、外部帧存（FRAME_INTF）路线不可行
在核心 `.S` 全量检索 `FRAME_INTF/frame_intf/get_frame/release_frame`：**零命中**
⇒ 我们的 vfmw 核心构建**没有编译外部帧存模式**（omxvdec 用的正是这条路）。
`vfmw.h` 里虽有 `FRAME_INTF_S` 定义，但核心未使用 ⇒ **无法通过补 FRAME_INTF 走 omxvdec 语义**。

#### 三、当前 M2 的两难
| 模式 | 硬件解码 | 图片级处理/输出 |
|---|---|---|
| `sed_only=0`（原厂语义） | ❌ 首帧起 100% 宏块错 | 路径存在但拿不到有效图 |
| `sed_only=1`（我们的绕行） | ✅ 30/30 无错 | ❌ SED 完成路径只计数，不入库/不出图 |

#### 四、下一轮
1. 抓 `sed_only=0` 的完整 `SH:`（slice header）打印，与 `ffprobe`/x264 实际参数对照，
   确认 CPU 解析出的 slice 参数是否正确（若错 → 定位到 NAL 切分/解析；若对 → 硬件参数问题）
2. 若 CPU 解析正确 → 对比 SED 与非 SED 两种模式下 VDH **寄存器编程**的差异
   （`vdm_hal_h264.S` 里按 `IsSedOnly` 分支的寄存器写入）

### 4.67 2026-11-05：**硬件拿到的 `stream_base_addr` 指向的不是码流**（首字节非起始码）——定位到"100% 宏块错"的物证

#### 一、CPU 侧切片解析完全正确（先排除解析问题）
`sed_only=0` 全量打印：
```
SPS: log2_max_frame_num_minus4=0, gaps_in_frame_num_value_allowed_flag=0
SH : first_mb_in_slice=0  slice_type=7  pic_parameter_set_id=0  frame_num=0  idr_pic_id=0
     no_output_of_prior_pics_flag=0 long_term_reference_flag=0 slice_qp_delta=-10
     disable_deblocking_filter_idc=0
```
⇒ SPS/PPS/slice header 全部正确 ⇒ **解析不是问题**。

#### 二、新增"码流内容探针"（`hi_mmz_phys2va` + `__va`）
- 先在 mmz 模块里加并导出 `hi_mmz_phys2va()`（供调试把 phys 翻成 VA）
- shim 里查不到该地址（ES 环形缓冲非 shim 分配）→ 改用 `__va(phys)` 直接在线性映射里读
- 在 `VDMDRV_DoBeforeDec` 打印 `DecParam->stream_base_addr` 处的 16 字节：

```
DPARM : isSedOnly=0 slicenum=1 stream_base=0x28ad43f0 mbtodec=920
DPARMS: [f2 62 80 00 a7 bc 9c 9c | 9c 92 c4 62 80 00 9b d4]      ← 不是码流
DPARM : isSedOnly=0 slicenum=1 stream_base=0x28ad5958 mbtodec=920
DPARMS: [54 05 78 02 81 c1 47 c1 | 77 c1 07 5f fe 09 01 06]      ← 不是码流
```
⇒ **硬件被指向的内存里没有 `00 00 00 01` 起始码、也不是 H.264 语法**。
  这与"硬件 100% 宏块错"完全吻合：硬件读到的根本不是码流。

#### 三、下一轮（关键）
1. 验证 `stream_base_addr` 语义：decparam.h 注明 "word addr" ⇒ 可能不是字节地址；
   也可能只是"相对 ES ring 的偏移"（需再叠加 ring 基址）
2. 扫描 ES ring（0x28ad4000 附近与 vfmw 3MB 环 0x28ab4000）找 `00 00 00 01` 实际位置，
   与 `stream_base_addr` 对比，确定正确换算关系
3. 若确认语义是 word addr / offset → 在驱动或 HAL 侧修正（很可能这就是 M2 的最终根因）

### 4.68 2026-11-05：**修正 §4.67 的过强结论** —— `stream_base_addr` 语义确认；非 SED 的真正瓶颈是"只提交 4 个解码任务"

#### 一、`stream_base_addr` 语义（HAL 实证）
`vdm_hal_h264.S` 的 `H264HAL_V5R2C1_CfgVdmReg`：
```asm
ldr	w19, [x20, 736]        ; DecParam->stream_base_addr
and	w19, w19, -16          ; 16 字节对齐
str	w19, [x20, 976]        ; stream_base_addr_reg_tmp
bl	MFDE_ConfigReg(24, w19) ; 打印串为 "STREAM_V5R2C1_BASE_ADDR = 0x%x"
```
⇒ 它是**字节物理地址**（16 字节对齐），直接写寄存器，无移位/无叠加基址。

#### 二、修正：上一轮"指向的不是码流"结论**过强**
加上 `dc civac` 失效缓存后重读，得到的是**熵编码后的 slice 数据**（如 `88 84 0a f2 62 ...`）：
- H.264 的 slice header 已被 CPU 解析并被硬件跳过，硬件从**宏块数据**开始读
- 熵编码数据本身就是伪随机字节 ⇒ 看到"不像起始码"是**正常现象**，不能据此断定地址错

⇒ §4.67 的"物证"应降级为"待验证"；真正的线索是本轮第三节。

#### 三、非 SED 模式真正的瓶颈：vfmw 只提交 4 个解码任务
```
TSTAT : mfde_calls=1059 mfde_tasks=4  scd_calls=1059 scd_tasks=30 | post_scd=30 post_mfde=4 post_busy=0
VTSTAT: put=30 read=954 img=1 ack=1 | vdh=4 scd=30
```
⇒ SCD 切了 30 帧、语法层解析也正常，但**只有 4 个 MFDE（解码）任务被提交**给 VDH。
   对比 `sed_only=1` 时 `post_mfde=28~30`。
   即：**非 SED 模式的瓶颈在 vfmw 的解码调度/提交侧**（不是硬件、不是解析）。

#### 四、下一轮
1. 查 vfmw 提交解码的条件：`VDMDRV_DoBeforeDec` 前的调度判断（`VDH_TaskInUse`、DecParam 就绪、DPB）
2. 重点看 `H264DEC_SetDecParam`/`H264DEC_Decode` 的调用次数与返回，
   确认是"没有 DecParam"还是"VDH 任务被占用"
3. 用 `g_ofv/g_ofd` 之外的调度计数定位到具体判断点

### 4.69 2026-11-05：**非 SED 只提交 4 个解码的根因：`VCTRL_GetDecParam()` 返回 NULL（占 99%）**

#### 一、逐层插桩（`sed_only=0`，运行中取数）
```
SPIC7: wake=1003 act=1006 noact=1006          ← 唤醒/激活次数很多，但几乎都不成功
SPIC8: active=2 badslot=0 flag=0 noparam=995 taskinuse=0 skip=997
TSTAT: mfde_tasks=3  scd_tasks=30
VTSTAT: put=30 read=1020 img=0 vdh=3 scd=30
```
各计数含义（`VDMDRV_ChnDecReady` 的失败分支）：
| 计数 | 对应分支 | 次数 |
|---|---|---|
| active | `.L116` 通道态异常 | 2 |
| badslot | `.L117` 通道号越界 | 0 |
| flag | `.L118` 槽位标志 | 0 |
| **noparam** | **`.L119` `VCTRL_GetDecParam()==NULL`** | **995** |
| taskinuse | `.L120` `VDH_TaskInUse` | 0 |
| skip | `.L226` 跳过 | 997 |

⇒ **几乎全部激活都因"没有 DecParam"而失败** —— 即 **syntax 侧没有生产解码参数**。
  这解释了 `post_mfde=3~4`：只有极少数时刻 DecParam 就绪。

#### 二、因果链更新
```
SCD 正常切 30 帧（post_scd=30）
→ syntax 解析出 SPS/PPS/SH（此前已验证正确）
→ 但 H264DEC_SetDecParam 很少被调用/成功 ⇒ VCTRL_GetDecParam == NULL
→ VDMDRV_ActivateVDH 几乎每次空转
→ 只有 3~4 次真正提交 VDH ⇒ vdh=3~4
```
⇒ 瓶颈在 **syntax 侧的 DecParam 生产**（不在硬件、不在 VDH 任务、不在解析本身）。

#### 三、下一轮
1. 给 `H264DEC_SetDecParam` / `H264DEC_DecodePacket` / `H264DEC_Decode` 加计数
   （`H264DEC_SetDecParam` 写入 `ctx+616/632` 等，之前已在 `.L4523`/`.L4534` 见过其清理）
2. 查 syntax 线程主循环为何不推进（可能卡在 `VCTRL_CheckFreshSeg` 或读流等待）
3. 若是读流等待 → 对照 `read_stream` 回调返回值

### 4.70 2026-11-05：**`H264DEC_SetDecParam` 从未被调用** —— 26/36 个 NAL 在 `H264_DecOneNal` 处被判错

#### 一、实测（`sed_only=0`，运行中取数）
```
SPIC9 : setdecparam=0   chkdecparam=987
SPIC10: decpkt=36  noparamflag=6  nalerr=26  ret=36
TSTAT : mfde_tasks=3  scd_tasks=30
VTSTAT: put=30 read=974 img=0 vdh=3 scd=30
```
| 计数 | 含义 | 次数 |
|---|---|---|
| decpkt | `H264DEC_DecodePacket` 被调用 | 36 |
| nalerr | `H264_DecOneNal` 返回错误 → 走 `.L4433` | **26** |
| noparamflag | `[ctx+1984] != 1` → 跳过 SetDecParam | 6 |
| ret | 正常 `ret`（`.L4425`） | 36 |
| **setdecparam** | **`H264DEC_SetDecParam` 调用** | **0** |

#### 二、调用条件（反汇编）
`H264DEC_DecodePacket` 里：
```asm
bl   H264_DecOneNal
cmn  w0, #2
beq  .L4400                ; -2: 数据不够，返回等待
cbnz w0, .L4433            ; 其它错误 → nalerr
...
ldr  w0, [x20, 1984]
cmp  w0, 1
bne  .L4395                ; 标志不为 1 → 跳过
bl   H264DEC_SetDecParam   ; 只有这里才生产 DecParam
```
⇒ **DecParam 生产的唯一入口是"`H264_DecOneNal` 成功 且 `[ctx+1984]==1`"**，
   而实测 26/36 个 NAL 在 `H264_DecOneNal` 就失败了。

#### 三、因果链（当前最完整）
```
IDR 解码 100% 宏块错(err_level=100) → 该帧不入 DPB（StorePicInDPB 失败）
→ P 帧解析时参考列表为空（DecList error）→ H264_DecOneNal 错误
→ 不进 SetDecParam → VCTRL_GetDecParam==NULL
→ VDMDRV_ActivateVDH 空转（noparam=995）→ 只提交 3~4 个解码
```
⇒ 所以**最上游仍是"IDR 为什么在非 SED 模式下 100% 宏块错"**（SED 模式下同一帧解码无错）。

#### 四、下一轮
1. 用全量打印抓 `H264_DecOneNal` 失败的具体错误串（`.L4433` 前后的 dprint 文本）
2. 区分"首个 IDR 的失败"与"后续 P 帧的 DecList 失败"
3. 若首 IDR 也失败 → 聚焦非 SED 模式首帧的硬件参数；若只有 P 帧失败 → 聚焦 DPB/参考帧

### 4.71 2026-11-05：`DecOneNal` 失败串全貌（P 帧 DecList）；"强制存储错误帧"实验导致内核崩溃（已回滚）

#### 一、错误串（`sed_only=0`，全量打印）
```
decpkt=1  nalerr=0                    ← 第 1 个 NAL 解析成功
decpkt=2  noparamflag=2
SH: num_ref_idx_override_flag 1
init list error.  / DecList error, ret=-1  / H264_DecOneNal ERR   ← P 帧无参考
...
total_mbs=920, err_mbs=5   ErrFrame_Flag: 0    ← 有一帧几乎干净（5 个宏块错）
total_mbs=920, err_mbs=920 ErrFrame_Flag: 0
line 3947, REPORT_IFRAME_ERR
store pic err, ret = -1
```
⇒ 失败分布：
- **第 1 个 NAL 解析正常**（IDR 的 slice header 已成功解析，§4.65 也证实参数正确）
- 随后 P 帧因 **DPB 为空**（`DecList error`）全部 `H264_DecOneNal ERR`
- 偶有一帧 `err_mbs=5`（接近干净），但 `err_level != 0` 仍会被 `StorePicInDPB` 拒收

#### 二、实验：绕过 `err_level != 0` 强制入库
在 `StorePicInDPB` 的错误分支前插入 `b .L3793`（强制走正常存储路径）：
- 结果：**内核崩溃重启**（板子在 10 秒内 reboot）
- 结论：该错误分支是**保护性的**；把错误帧塞进 DPB 会让后续参考/输出状态崩坏
- 已回滚（构建恢复，md5 `80eb7805…` 已重新部署）

#### 三、当前认识
- 非 SED 模式的**首个 IDR 硬件解码就带错误**（5 或 920 个宏块错），因此永远进不了 DPB
- 只要能消除 IDR 的宏块错，后面的 DecList/SetDecParam/解码提交链条会自然恢复
- 下一步要对比 **SED 与非 SED 两种模式下 HAL 的寄存器编程差异**（`H264HAL_V5R2C1_CfgVdmReg` 中
  `cmp w21,1; beq .L191` 的 SED 分支前后的寄存器写）

#### 四、下一轮
1. 反汇编 `H264HAL_V5R2C1_CfgVdmReg` 的 SED/非 SED 分支，列出两种模式的寄存器差异
2. 重点看：SED 数据地址寄存器、slice 参数寄存器、`basic_cfg0/1`、压缩/线性标志
3. 若发现非 SED 分支漏写/错写某寄存器 → 在 HAL 或驱动侧修正

### 4.72 2026-11-05：VDH 寄存器写入序列对比（SED vs 非 SED）——基础配置一致，差异只在 stream base 与两个标志位

#### 一、方法
给 `MFDE_ConfigReg`（VDH 寄存器写入口）加探针，记录前 24 次 `(寄存器号, 值)`：

SED 模式（首帧）：
```
8:4d000397  12:20019000  16:28001400  20:28000000  24:00000000
60~84:00300c03 (×7)
96:2901c000  100:00003000  104:00048000  108:00000000  128:0  132:0  148:0  152:0  32:ffffffff
（第二帧起）8:41000397  12:2001d000  16:28001400
```
非 SED 模式（首帧）：
```
8:41000397  12:2001d000  16:28001400  20:28000000  24:28ad43f0
60~84:00300c03 (×7)
96:2901c000  100:00003000  104:00048000  108:00000000  128:0  132:0  148:0  152:0  32:ffffffff
```

#### 二、结论
- **基础配置（16/20/60~84/96/100/104/108/128/132/148/152/32）两种模式完全一致**
- 差异只有三处：
  1. `reg24`（STREAM_BASE_ADDR）：SED 首帧 = 0；非 SED = `0x28ad43f0`（码流物理地址，符合预期）
  2. `reg8`：SED 首帧 `0x4d000397` vs 非 SED/后续帧 `0x41000397`（bit26/27 差异）
  3. `reg12`：SED 首帧 `0x20019000` vs 非 SED/后续帧 `0x2001d000`（bit14 差异）
- 且非 SED 首帧的 reg8/reg12 与"**SED 模式下第二帧**"完全相同
⇒ 说明非 SED 首帧的编程路径与 SED 模式的常规帧**基本一致**，差异不在这些基础寄存器，
  更可能在**后续的 slice msg / pic msg 编程**（单帧约 300+ 次寄存器写，本轮只采了前 24 次）。

#### 三、下一轮
1. 把探针上限提高到 ~400 次，完整抓一帧的寄存器序列，逐条 diff SED vs 非 SED
2. 重点：slicemsg D[0..] 系列（`H264HAL_..._SetSliceMsg`）与 picmsg（`SetPicMsg`）
3. 若发现非 SED 分支漏写 slice msg 的某字段 → 定位到 HAL 或 DecParam 字段来源

### 4.73 2026-11-05：完整寄存器序列对比（400 条）——逐帧写入**基本一致**；SED-only 模式无法出图是设计限制

#### 一、400 条寄存器序列对比
`MFDE_ConfigReg` 提限到 400 条后：
- **SED 模式**（首帧）：
```
8:4d000397 12:20019000 16:28001400 20:28000000 24:00000000
60~84:00300c03 96:2901c000 100:00003000 104:00048000 108:0 128:0 132:0 148:0 152:0 32:ffffffff
（第 2 帧起）8:41000397 12:2001d000 16:28001400 20:28000000 24:28ad43d0 ...
```
- **非 SED 模式**（首帧 + 第 2 帧）：
```
8:41000397 12:2001d000 16:28001400 20:28000000 24:28ad43d0 ...
8:41000397 12:2001d000 16:28001400 20:28000000 24:28ad64a0 ...
```
⇒ 非 SED 每帧的寄存器组与 **SED 模式第 2 帧起完全同构**；只有"SED 首帧"多两个标志位差异。
   每帧寄存器写次数也相近（约 20 次基础 + slice/pic msg）。
   **结论：硬件编程列表不是差异源**，差异应在写入 DDR 的 **slice message / pic message 数据内容**。

#### 二、SED-only 模式的结论（重要）
- SED 完成路径 `VCTRL_VdmProcSedOnly → H264DEC_VDMProcSedOnly` **只计数**；
- `H264DEC_VDMPostProc`（图片入库/出图的唯一入口）只被 `VCTRL_PostProc` 调用，
  而 `VCTRL_PostProc` 只出现在 VDH 完成路径的 `VDMDRV_AfterDec`/`IsrProcess` 分支里；
- SED 帧走的是 `.L401` 分支（不经过 AfterDec）⇒ **SED-only 模式下 vfmw 本身没有图片级处理路径**。
⇒ SED-only 是"只解不显"的模式（设计如此），**不能靠它出图**；必须回到非 SED 模式。

#### 三、当前唯一待查
非 SED 模式：硬件编程寄存器与 SED 一致、CPU 解析（SPS/PPS/SH）正确，
但硬件仍报 100% 宏块错 ⇒ 嫌疑集中在 **slice message / pic message 的 DDR 数据内容**。

#### 四、下一轮
1. 在 `H264HAL_..._SetSliceMsg` / `SetPicMsg` 前后 dump 写入 DDR 的 slice msg 结构（前 32 字节）
2. 与 SED 模式下是否有对应数据做对比
3. 若 slice msg 内容异常 → 回溯 `DecParam` 的 slice 参数来源（`H264DEC_SetDecParam` 之前）

### 4.74 2026-11-05：**决定性实验 —— 全 IDR 码流下非 SED 模式每帧仍 100% 宏块错**（I 帧解码本身坏，与参考帧无关）

#### 一、实验设计
用板载 ffmpeg/libx264 把 gen2 重编码为**全 IDR（50 帧，无 P 帧）**：
```
ffmpeg -r 25 -i gen2.h264 -c:v libx264 -preset ultrafast   -x264-params "keyint=1:min-keyint=1:scenecut=0:slices=1:repeat-headers=1:bframes=0"   -f h264 gen3_idr.h264        # 340171 B, IDR×50, P×0
```
（注意：生成后必须 `sync`，否则重启会丢成 0 字节——本轮踩到过）

#### 二、实测（`sed_only=0`，全 IDR 流）
```
err_mbs=920  × N            ← 每一帧都是 100% 宏块错
TSTAT : mfde_tasks=14  scd_tasks=19  post_mfde=14
VTSTAT: put=19 read=649 img=0 vdh=14 scd=19
DECLIST = 0                 ← 没有任何 DecList 错误
```
#### 三、结论（关键）
- 去掉 P 帧后 **解码提交数从 3~4 提升到 14**、`DecList error` 归零 ⇒ 之前 P 帧失败只是"无参考"的次生现象
- 但**每一帧 IDR 仍然 `err_mbs=920`** ⇒ **I 帧在非 SED 模式下硬件解码本身就是错的**
- 同一条码流在 `sed_only=1` 下解码无错（此前多轮验证）
⇒ 排除：参考帧/DPB、P 帧解析、SCD 时序、寄存器列表差异
⇒ 锁定：**非 SED 模式下 I 帧解码所需的"数据/参数"不正确**（寄存器列表相同，差异只能在写入 DDR 的数据）

#### 四、下一轮
1. 对比两种模式下 HAL 写入 DDR 的 **pic message / slice message** 内容（`SetPicMsg`/`SetSliceMsg`）
2. 若 slice msg 异常 → 回溯到 CPU 解析的 slice 参数（`H264DEC_SetDecParam` 之前）
3. 另可查：非 SED 模式下 vfmw 是否漏写"SPS/PPS → VDH 格式"的数据块

### 4.75 2026-11-05：同码流下逐帧寄存器序列 **diff = 0**（SED 第2帧 ≡ 非 SED 第1帧）⇒ 差异只在 DDR 数据

#### 一、实验（同一全 IDR 码流 `gen3_idr.h264`，两种模式各抓 400 条寄存器写）
抓取结果按"帧边界"（以 reg8 写入为界）切分：
```
SED  : 20 个帧段，每段 21 条   （首段带 SED 标志：8:4d000397 / 12:20019000 / 24:0）
非SED: 20 个帧段，每段 21 条   （首段：8:41000397 / 12:2001d000 / 24:28ad4270）
```
逐帧比较：**`SED[1]` 与 `非SED[0]` 完全相同（diffs = 0）**。

#### 二、结论（重要）
- 每帧的 VDH 寄存器组（21 条）在两种模式下**完全一致**
- 只有"SED 模式的首帧"多两个标志位差异（reg8 bit26/27、reg12 bit14）与 reg24=0
- ⇒ **硬件编程列表不是差异源**；SED 与非 SED 的差别必然体现在**写入 DDR 的数据**
  （pic message / slice message / 参考帧地址等）

#### 三、下一轮
1. 验证硬件读到的码流字节与源文件一致：抓 `stream_base_addr` 处 32 字节，
   在 `gen3_idr.h264` 中搜索定位（若找不到 → 数据/地址错，可能是 cache 或 ES 环偏移问题）
2. 对比两种模式下 HAL 写入 DDR 的 pic message（`SetPicMsg`）内容
3. 若 message 相同 → 检查 SED 数据缓冲（SED buffer）是否在非 SED 模式下被错误清零/复用

### 4.76 2026-11-05：**硬件读到的码流字节验证为正品**（与源文件逐字节吻合、落点正确）

#### 一、做法
抓 `stream_base_addr` 处的 16 字节（非 SED 模式，`gen3_idr.h264`），
再在源文件里搜索定位：

| # | 抓到的字节（hex） | 在文件中偏移 | 归属 NAL |
|---|---|---|---|
| 0 | `2628000902c9c9c9c9c462800088f470` | 634 | IDR NAL 起始 627，**+7** |
| 1 | `821226280008a2c9c9c9c9c462800085` | 8938 | IDR NAL 起始 8933，**+5** |
| 2 | `88844898a000228b27272727118a0002` | 15706 | IDR NAL 起始 15702，**+4** |

14 组样本**全部**在源文件中找到，且落点都在 `start_code` 之后的 **slice 数据起点**（+3~+7 字节）。
文件自身结构：`SPS@1, PPS@29, SEI@36, IDR@627, SPS@8898, PPS@8926, IDR@8933, ...`

#### 二、结论
- **码流数据是真的**（不是缓存/地址错），硬件读的正是我们送的码流
- `stream_base` 语义 = slice 数据起点（跳过 start code），符合硬件要求
- 结合上一轮"寄存器序列 diff=0"，非 SED 模式 100% 宏块错的剩余嫌疑**只剩 DDR 中的 message 内容**
  （slice message / pic message / PMV 缓冲）

#### 三、下一轮
1. 反汇编 `H264HAL_V5R2C1_SetPicMsg`（从 `pDecParam` 读字段 0/1/32/48/52/60…）并 dump 写入的 DDR 结构
2. 对比 SED/非 SED 两种模式下 pic msg / slice msg（`SetSliceMsgStreamAddrInfo`）的内容差异
3. 若 message 也一致 → 检查 PMV 缓冲地址/大小（IDR 帧也需要硬件写 PMV）

### 4.77 2026-11-05：pic message DDR 对比 —— **两种模式完全相同**

#### 一、方法
在 `H264HAL_V5R2C1_SetPicMsg` 的统一出口（`.L203`）前加探针，
打印消息内存（x19 = `MEM_Phy2Vir` 得到的 VA）前 64 字节。

#### 二、实测（同一 `gen3_idr.h264`）
非 SED：
```
82160027 2901c000 00000000 00000000 00000000 28053000 28153000 2908a000
28253000 28001900 2901c000 2901c000 2901c000 2901c000 2901c000 2901c000
```
SED（第 1 条是 SED 首帧的"探针"型消息，第 2 条起与上面**完全相同**）：
```
#1: 02160027 00000000 00000000 00000000 00000000 28053000 28153000 00000000
    28253000 28001900 00000000 ... (全 0)
#2: 82160027 2901c000 00000000 00000000 00000000 28053000 28153000 2908a000
    28253000 28001900 2901c000 ... (与非 SED 完全一致)
```
⇒ **pic message 也不是差异源**。

#### 三、当前证据矩阵（同一码流、同一帧）
| 项 | SED 模式 | 非 SED 模式 | 是否一致 |
|---|---|---|---|
| VDH 寄存器序列（21 条/帧） | ✅ | ✅ | **完全一致** |
| pic message（64B） | ✅ | ✅ | **完全一致** |
| 硬件可见码流字节 | — | 与源文件逐字节吻合 | **真实数据** |
| 硬件解码结果 | `err_mbs=0` | `err_mbs=920` | **不同** |

⇒ 差异不在寄存器、不在 pic message、不在码流数据。
   剩余候选：**slice message 内容**、或"SED 数据缓冲的存在与否"改变硬件解码路径。

#### 四、下一轮
1. dump `H264HAL_SetSliceMsgStreamAddrInfo` 写入的 slice message（起始地址/MV 地址/长度）
2. 对比两模式 slice message → 若也不同则继续往上（DecParam slice 参数）
3. 若都相同 → 说明"非 SED 解码路径"依赖某个我们尚未提供的东西（如 slice 数、SED 段数据）

### 4.78 2026-11-05：slice message 对比 —— 仅两处小差异；需转向 VDH 错误状态寄存器

#### 一、实测（同一 `gen3_idr.h264`，第 1/2 帧）
非 SED：
```
SLMSG1: 00000000 00000040 0000bf44 00000000 00000000 00000000 60000000 00004000
        00000000 00000000 00000000 00000001 00000000 e1005efd 7e025bf6 90004c75
SLSRC1: 00000002?/00000000 00000000 0000bf44 ... 28ad4278
SLMSG2: ... 0000d22f ... 50000000 00004000 ...
```
SED：
```
SLMSG1: 00000000 00000040 00010230 ... 60000000 00004000
        00000000 00000000 00000000 00000001 00000000 e1005efd 7e025bf6 90004c75
SLSRC1: 01000002 00000000 00010230 ... 28ad4278
SLMSG2: ... 0000d22f ... 50000000 ...
```
差异：
- `SLMSG[2]`（首帧）：SED `0x00010230` vs 非 SED `0x0000bf44`
- `SLSRC[0]`（slice 参数结构首字）：SED `0x01000002` vs 非 SED `0x00000000`
- 其余字段（含 stream 物理地址 `0x28ad4278`、slice 数=1、flags `60000000/50000000`）**相同**

#### 二、观察
到目前为止**寄存器、pic message、slice message、码流字节**四项对比全部"基本相同"，
但硬件解码结果截然不同（`err_mbs` 0 vs 920）。
⇒ 静态数据对比已接近极限，下一步应转向**硬件自身的错误状态位**（VDH 解码完成时的
   `int_state` / 错误码），它能直接告诉我们"哪一类错误"。

#### 三、下一轮
1. 在 `VCTRL_PostProc → H264DEC_VDMPostProc` 调用处 dump 状态结构（x3 指向，前 16 dword）
   —— 其中含 VDH `int_state` 原始位
2. 用 VDH 手册/寄存器定义解读错误位（slice 头错、PMV 错、stream 错、参考帧错…）
3. 按错误类型回到对应环节（很可能是"slice 数/切片消息与 SED 数据不一致"）

### 4.79 2026-11-05：**配置对比发现关键项 `EnVcmp`（帧压缩）**；`EnVcmp=2` 后首帧首次解码干净

#### 一、VDH 状态位对比（先做的部分）
`VCTRL_PostProc → H264DEC_VDMPostProc` 前 dump `int_state`：
- 非 SED：`0x64`（多数帧）、偶尔 `0x0`
- SED：`0x10 / 0x7 / 0x64 / 0x5f / 0x64 …`
⇒ `int_state` 两模式都有 `0x64`，**不能作为区分依据**。

#### 二、配置对比（关键）
原厂 omxvdec（`decoder_vfmw.c:1381`）：
```c
pchan_cfg->s32SedOnlyEnable = HI_FALSE;
pchan->is_compress = g_CompressEnable;                 // 默认 = VFMW_COMPRESS_SUPPORT
pchan_cfg->s32VcmpEn = (pchan->is_compress == 0) ? 2 : 1;   // 不压缩时用 2
```
我们驱动（`drv_vdec_intf_k.c:396`）：`static HI_S32 EnVcmp = 1;` → **默认"强制压缩"**
（`GetCMPInfo()` 对非特殊芯片一律 `EnVcmp = 1`）。

#### 三、实验：`EnVcmp=2`（强制不压缩）+ 非 SED 模式
| 码流 | 结果 |
|---|---|
| `gen3_idr.h264`（全 IDR） | **首帧 `err_mbs=0`（首次在非 SED 下解对！）**，后续帧仍 920；`post_mfde=22`、`vdh=22`、`img=1` |
| `gen2.h264`（含 P 帧） | 3 次解码，全 920 |

⇒ **`EnVcmp=1`（强制压缩）是导致 100% 宏块错的主因之一**——改用 2 后首帧解码完全正确。
  后续帧仍错的原因待查（可能与我们上报的帧存 `CompressEn` 状态、或帧存复用有关）。

#### 四、下一轮
1. 检查驱动上报的 `pstImage->CompressEn` / `stCompressInfo` 是否仍按"压缩"处理（与 EnVcmp=2 冲突）
2. 用 `EnVcmp=2` 重跑全 IDR 码流，观察第 2 帧起的 FSP/帧存状态
3. 若确认帧存压缩标志不一致 → 统一为"不压缩"链路（驱动 + frame buffer 上报）

### 4.80 2026-11-05 ★重大突破★：`EnVcmp=2` + `stream_base` 指回 NAL 起始码 → 非 SED 模式**首次出图（img=10）**

#### 一、SCD/CRG 寄存器对比（补完最后一项）
`SCD_ConfigReg` 两模式写入完全一样（`1:0:0 1:8:1 1:4:1 1:12:3` 循环），`CRG_ConfigReg` 未出现。
⇒ 所有可观测寄存器写入、pic msg、slice msg、码流字节在两模式下**全部相同**。

#### 二、关键假设：非 SED 模式下硬件要自己解析 slice 头，起点必须是 NAL 起始码
`stream_base_addr` 当前指向 **slice 数据起点**（文件偏移 634 = IDR NAL@627 + 7），
而硬件自己解析时需要从 **起始码/NAL 头**开始。
为此加了两个模块参数做对照实验：
- `vdec_sb_adj=N`：把 `DecParam->stream_base_addr` 偏移 N 字节
- `vdec_sb_scan=1`：从当前地址**向前扫描 `00 00 01`/`00 00 00 01`** 定位起始码
（均在 `hi_vdec_dbg_dp` 钩子里、`VDMDRV_DoBeforeDec` 之前生效）

#### 三、实测（全 IDR 码流 `gen3_idr.h264`，`sed_only=0`，`EnVcmp=2`）
| 配置 | 干净帧 | `err_mbs=920` | `img` | vdh |
|---|---|---|---|---|
| 基线（无调整） | 1 | 18 | 1 | 23 |
| `vdec_sb_adj=-3` | 1 | 16 | 1 | 19 |
| **`vdec_sb_adj=-7`（指回起始码）** | **9** | 13 | **10** | 26 |
| `vdec_sb_scan=1`（自动扫描） | 2 | 19 | 2 | 24 |

⇒ **`-7` 让非 SED 模式首次稳定出图（img=10）**，说明"起始码起点"方向正确。
  但自动扫描版效果反而更差（可能因为：① 每次都重复调整导致累积偏移；② 多个 4 字节起始码分支判断有误）。
  `slicemsg/DPARMS` 也证实该字段确实被硬件用于 slice 流地址。

#### 四、下一轮（把实验变成修复）
1. 修正扫描逻辑：**幂等**（若当前字节已是 `00 00 01` 则跳过）+ 只认 3/4 字节起始码且优先最近者
2. 用 ≥5 次独立开机做 A/B（基线 vs 修正）统计 `img`/`clean`，避免单次噪声
3. 若稳定 → 固化为正式修复（最好在 vfmw 侧设置正确的 NAL 起点，而不是事后修正）

### 4.81 2026-11-05：**更正 §4.80** —— `stream_base` 偏移实验经 6 次独立开机扫描后证明是**噪声**

#### 一、扫描实验（`sed_only=0`、`EnVcmp=2`、`gen3_idr.h264`，各 1 次独立开机）
| `vdec_sb_adj` | clean | err920 | img | vdh |
|---|---|---|---|---|
| -9 | 3 | 14 | 2 | 18 |
| -8 | 2 | 16 | 2 | 19 |
| -7 | 0 | 15 | 0 | 19 |
| -6 | 2 | 14 | 3 | 19 |
| -5 | 0 | 17 | 0 | 18 |
| -4 | 1 | 14 | 1 | 18 |

⇒ 全部落在同一噪声带内（clean 0~3、img 0~3），**没有任何偏移值带来稳定改善**。
   §4.80 中单次 `-7 → img=10` 属于**单次波动**，按"≥5 次开机才下结论"的既定纪律，该结论**撤回**。

#### 二、自动扫描的实测细节（供后续参考）
`vdec_sb_scan=1`（幂等版）打印每帧找到的偏移：
```
SBADJ: pa=0x28ad4278 k=7 / pa=0x28ad5a34 k=6 / pa=0x28ad7d14 k=5
       pa=0x28ad9784 k=6 / pa=0x28adb1fc k=5 / pa=0x28adcc74 k=5
SBSCAN: n=19 sum=110 skip=0
```
⇒ 逐帧偏移 5~7 不等（与 slice 头长度一致），但同样没有带来改善
   ⇒ **问题不在"流地址起点"**。

#### 三、当前唯一稳定的两个事实
1. `EnVcmp=1`（强制压缩，我们驱动的默认值）会让**整帧 100% 宏块错**；改 2 后**偶有干净帧**
2. SED 模式（`sed_only=1`）同码流下**从不出错**，但 vfmw 在 SED 路径下**没有图片级处理**（§4.73）

⇒ 结合"偶有干净帧"这一特征，下一步应验证是否为**竞态/时序**（而非配置）：
   同一帧重复解码时是否结果不同、以及非 SED 路径下 ES 数据在硬件启动前是否已真正可见。

#### 四、下一轮
1. 记录"干净帧"对应的 `frame_num`（是否重复出现同一帧时结果不同 ⇒ 竞态）
2. 在 `VDMDRV_DoBeforeDec` 后加 `dsb sy` + 对 ES 环的 clean+invalidate，验证数据可见性
3. 若确认竞态 → 在提交解码前补齐内存屏障/刷缓存

### 4.82 2026-11-05：`err_mbs` 溯源（vfmw 自算，非硬件上报）；APC 字段全 0；板上模块加载坑

#### 一、`err_mbs=920` 的真正来源
`common/postprocess.S:PostPro_GetErrRatio` 里：
```asm
ldp  w20, w1, [x26, 28]     ; total_mbs = [x26+28] * [x26+32]  (= 40*23 = 920)
mul  w20, w20, w1
ldr  w0, [x26, 44]          ; slice 个数
... 对每个 slice: w22 += ([x26+78+4i] - [x26+76+4i] + 1)
... 打印 "total_mbs=%d,err_mbs=%d"    ; err_mbs = w22
```
⇒ **`err_mbs` 是 vfmw 按 slice 表累加出来的**（不是直接读硬件错误计数）。
   非 SED 模式下它恰好等于全帧（920）⇒ vfmw 认为"整帧都错"。
   结合 §4.78 的 slice message（`SliceParaNum=1`、`SLMSG[2]` 两模式不同）：
   **slice 参数表的内容很可能就是关键**。

#### 二、APC 字段实测（非 SED 模式，`gen3_idr.h264`）
```
APCDBG0: 00000000 00000000 00000000 00000000 (×8) | apcsz=8 slnum=1
APCDBG1: 同上
APCDBG2: 同上
```
⇒ `Apc2Idc[16]`（偏移 744 起）**全 0**；`ApcSize=8`、`SliceParaNum=1`。
   若硬件本应回写 APC/错误区域而始终为 0，则说明**硬件没有回写**（或地址不对）。

#### 三、板上模块加载的坑（重要运维经验）
现象：`insmod /root/hi_vdec.ko` → `Invalid module format`，dmesg：
`Invalid ELF section name table type: 0`；但 `md5sum` 与主机一致、`readelf` 完全正常。
**解决**：`cp /root/hi_vdec.ko /root/hv2.ko && insmod /root/hv2.ko ...` → 正常加载。
⇒ 以后遇到"文件校验一致但内核拒载"，先复制一份再 insmod。

#### 四、下一轮
1. 在 **SED 模式**下同样 dump `Apc2Idc/ApcSize/SliceParaNum`，对比是否非 0
   （若非 0 ⇒ 硬件会回写，非 SED 没回写 ⇒ 解码确实失败；若也 0 ⇒ 该字段与判定无关）
2. 对比两种模式 `pFirstSlice` 指向的 slice 参数内容（`H264_DEC_SLICE_PARAM_S`：
   `valid_bitlen`/`bitsoffset`/`bytespos` 等），确认非 SED 的 slice 表是否正确

### 4.83 2026-11-05：AVM/VAM 正常、PPFD 字段无生产者；**部署链路必须 md5 校验**（本轮两次假结论都源于旧模块）

#### 一、`avm_addr/vam_addr/ppfd` 实测（非 SED）
```
ADDRDBG0: avm=0x0        vam=0x0        vstate=0x0 ista=0x0
ADDRDBG1: avm=0x28001400 vam=0x28000000 vstate=0x0 ista=0x0
ADDRDBG2: avm=0x28001400 vam=0x28000000 vstate=0x0 ista=0x0
```
- `avm/vam`（VDH 内部表地址）**已正确设置**（`0x28001400` / `0x28000000`，属 vfmw 的 MMZ 缓冲）
- `ppfd_buf_addr/len` 恒为 0 —— 但**全代码搜索确认 `ppfd_buf_addr` 在 vfmw/驱动/SDK 中都没有写入者**
  ⇒ 该字段是遗留字段，**可排除**
- `vstate/ista` 在 `DoBeforeDec` 时为 0（解码后才有值，符合预期）

#### 二、部署链路教训（本轮两次"假结论"的根源）
现象：脚本里"先 `scp` 再 `reset` 跑测试"时，`scp` 常在板子重启窗口内**静默失败**，
测试实际跑的是**旧模块**（本轮两次 SLDBG/ADDRDBG 对比因此无效，已识别并作废）。
**新纪律**：
1. `scp` 之后**必须 `md5sum` 比对主机与板子**
2. 顺序改为：`reset → 等待 → 部署并校验 md5 → 再跑测试`
3. 板上 `insmod` 前 `cp` 一份（见 §4.82 的 ELF 坑）

#### 三、待验证的线索（下一轮）
- `H264_DEC_SLICE_PARAM_S`（`pFirstSlice`，DecParam 偏移 944 的指针）内容：
  `valid_bitlen` / `bitsoffset` / `bytespos`，以及 `first_mb_in_slice`
- 已知两模式 `bitsoffset` 曾观测到 `0xbf44`(非SED) vs `0x10230`(SED)，差异达 26%
  ⇒ 若非 SED 的 slice 位长/偏移确实偏小，硬件会解错整帧

### 4.84 2026-11-05：slice 参数**两模式基本相同**（澄清旧观测）；**`EnVcmp=2` 反而让 SED 模式出错**（重要反转）

#### 一、按新纪律部署后的实测（`gen3_idr.h264`，md5 `0dc34021` 校验通过）
非 SED：
```
ADDRDBG0: avm=0x0        vam=0x0        vstate=0x0 ista=0x0
SLDBG0  : t=2 vbl=49164 bo=0 bp=0x28ad4278 qp=32
SLDBG1  : t=2 vbl=53807 bo=8 bp=0x28ad5a80
SLDBG2  : t=2 vbl=53891 bo=30 bp=0x28ad74ec
```
SED：
```
ADDRDBG0: avm=0x0        vam=0x0        vstate=0x0 ista=0x0
SLDBG0  : t=2 vbl=49175 bo=0 bp=0x28ad4278 qp=32
SLDBG1  : t=2 vbl=49172 bo=0 bp=0x28ad4278
SLDBG2  : t=2 vbl=66096 bo=24 bp=0x28ad5cf0
```
⇒ **两模式首帧的 slice 参数几乎一致**（49164 vs 49175、`bo=0`、同一 `bp`）
   ⇒ 上一轮"`bitsoffset` 差 26%"的观测是**旧模块/不同帧**造成的误读，**予以作废**。

#### 二、反转：`EnVcmp=2` **让 SED 模式也出错**
- 历史：`EnVcmp` 默认 1（强制压缩）时，SED 模式 `err_mbs=0`（稳定无错）
- 本轮：`EnVcmp=2` + `sed_only=1` → 出现 `ERR=16`（16 帧 `err_mbs=920`）
⇒ 说明**帧压缩开关必须与硬件期望一致**（压缩=1 才是该 SoC 的正常配置）
   ⇒ §4.79 的"`EnVcmp=1` 是错误默认值"结论**也要撤回**：
     非 SED 模式在两种 `EnVcmp` 下都失败，`EnVcmp` 不是根因。

#### 三、当前净结论（去伪存真后）
| 观测 | 状态 |
|---|---|
| SED 模式解码无错（`EnVcmp=1`） | ✅ 稳定 |
| 非 SED 模式解码 100% 宏块错 | ✅ 稳定（`EnVcmp` 1/2 都失败） |
| 寄存器序列 / pic msg / 码流字节 / slice 参数 | 两模式基本一致 |
| `err_mbs` 由 slice 表累加 | ✅ 已确认（但两模式 slice 参数一致，故非直接原因） |

⇒ 剩下的最可能解释：**非 SED 解码路径依赖某个"只有 SED 路径才会准备好"的硬件状态/缓冲**
   （例如压缩帧缓冲头、PPFD/AVM/VAM 之外的 VDH 内部表），需要继续从"两模式差异"之外找。

#### 四、下一轮
1. 对比两模式 **frame store（FSP）** 分配：`/proc/vfmw/buffer`、`/proc/vfmw/vfmw_statis`
2. 对比 `IMAGE.BTLInfo`（`u32IsCompress`/`u32HeadOffset`/`u32YHeadAddr`）在两模式的取值
3. 若发现非 SED 下压缩头信息缺失 → 修复帧存分配/上报

### 4.85 2026-11-05：**原厂固件在机分析**（按用户建议）——确认我们的 vfmw 选型与原厂 SDK 完全一致，问题不在 vfmw 配置

#### 一、原厂资料定位（本机 `/mnt/f/` = Windows F: 盘）
```
/mnt/f/design/Hi3798/FW/BK/BK/            9.9 GB：原厂 eMMC 全镜像备份
    kernel_emmc.bin (40MB)  system_emmc.img (ext4)  fastboot/recovery/userdata …
/mnt/f/design/Hi3798/FW/                   启动日志：session*.log、ubuntu22.log、NFS CMD.txt
/mnt/f/design/Hi3798/FW/restore-20261104/  恢复用：board-boot-32M.bin + ubuntu-p1.img.zst
```

#### 二、原厂内核提取（成功）
```
kernel_emmc.bin → Android bootimg(page=16384) → uImage
  uImage name: "Linux-3.18.24_hi3798mv2x"   arch=ARM(32bit)  comp=0(未压缩)
  → zImage(9.0MB) → 解压 zImage 得 20.2MB 原始内核镜像
```
内核内符号/字符串实证：
- **`VDMHAL_V5R2C1_OpenHAL / CalcFsSize / CalcFsNum / ArrangeMem_Normal`**
  ⇒ 原厂用的 VDH HAL **与我们相同的 V5R2C1**（不是别的修订版）
- `VFMW_Init / VFMW_BeforeCfgChan / VFMW_GetImage …`、proc 项 `vfmw_read_proc_scd`
- 内核参数项：`hi_vfmw.extra_cmd / extra_disp / extra_ref`

#### 三、原厂 bootargs（`bootargs_emmc.bin`，NUL 分隔的 env）
```
bootargs=console=ttyAMA0,115200 blkdevparts=… coherent_pool=1M
bootargs_1G=mem=1G mmz=ddr,0,0,48M
```
⇒ **没有任何 vfmw/解码相关启动参数**（即原厂用默认配置）

#### 四、SDK 选型核对（决定性）
`source/msp/drv/vfmw/Makefile`：
```make
ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3798cv200 hi3798mv200 hi3798mv300 hi3796mv200 hi3716mv450),)
VFMW_MAKE_DIR = vfmw_v5.0/product/make_stb
```
`vfmw_v5.0/product/Hi3798MV200/public.h`：`VFMW_VERSION "HiVDHFMWV500R001-TAG02-C01"`
而我们的 port：`product/Hi3798MV200/public.h` **版本号完全相同**（TAG02-C01）。

⇒ **结论**：
1. 原厂对该 SoC（hi3798mv300）就是用 **vfmw_v5.0 / Hi3798MV200 product / TAG02-C01** —— 与我们完全一致
2. 原厂 VDH HAL 也是 **V5R2C1** —— 与我们一致
3. **因此问题不在 vfmw 版本/产品选型/启动参数**，而在我们的**平台适配层**（把 vfmw 从原厂 3.18 32bit 内核搬到 mainline 7.3 aarch64）

#### 五、下一轮（按此结论收缩）
1. 对比**平台层**：`port/vdec/vfmw/platform/osal/linux_kernel/*`（内存/中断/时间/锁）
   与 SDK 原版 `source/msp/drv/vfmw/vfmw_v5.0/platform/osal/linux_kernel/*` 的差异
2. 重点：`MEM_Phy2Vir`/`OSAL_MemAlloc(cached=0)` 的映射属性、IRQ 触发/清除方式
3. 若发现平台层差异 → 直接对齐（这比继续比对 DecParam 更有希望）

### 4.86 2026-11-05：原厂固件分析的**确定结论** + 新发现"部署后被还原"异常（两次实验作废）

#### 一、原厂固件分析（在机）确定结论
1. 原厂内核 = `Linux-3.18.24_hi3798mv2x`（ARM 32bit），内含 **`VDMHAL_V5R2C1_*`** —— 与我们使用的 HAL **同一版本**
2. 原厂 bootargs 无任何 vfmw/解码参数（`bootargs_1G=mem=1G mmz=ddr,0,0,48M`）
3. SDK `vfmw/Makefile` 把 `hi3798mv300` 映射到 `vfmw_v5.0/product/Hi3798MV200`，
   其 `VFMW_VERSION = "HiVDHFMWV500R001-TAG02-C01"` —— **与我们 port 完全一致**
4. 平台层源码对比（`platform/ module/ adapter/`）：除内核 API 适配（`vfs_read→kernel_read` 等）与
   我们加的调试打印外，**逻辑无差异**（`vdh_normal.c` 归一化行尾后 diff≈0）
5. 编译宏对比：SDK 独有的 `SCD_BUSY_WAITTING`/`VDM_BUSY_WAITTING`/`HI_TEE_SUPPORT`/
   `VFMW_H263_SUPPORT` 在源码中**无任何引用**（遗留宏，可忽略）

⇒ 结论：**vfmw 版本、产品、HAL、平台层逻辑均与原厂一致，问题出在"mainline 内核环境"本身的差异上**
   （内存/中断/时钟/缓存属性等），而不是 vfmw 配置或移植代码逻辑。

#### 二、新发现异常（影响此前的实验可信度）
现象：`/root/hi_vdec.ko` 在两次开机之间**被还原成 Ubuntu 镜像自带版本**
（mtime `2026-07-28 04:45`，md5 `b1c03a8e…`，1952624 B），而我们在同一会话内 scp 并校验过的
新版本（如 md5 `6ade542c…`）在同一会话内可用、重开后消失。
- 已排除：磁盘满（`df` 66%）、只读挂载（`mount` 显示 `rw`）、整体 rootfs 回滚
  （我们写的 `/root/persist_test.txt` **确实跨重启保留**）
- 现象特征：**只有被覆盖过的镜像自带文件会被还原**，新建文件保留 ⇒ 疑似"镜像层/覆盖层"式机制
  （例如该 rootfs 由镜像 + 可写层组成，而对镜像内文件的覆盖在特定条件下回落）

**实验纪律（更新）**：
1. 部署后**必须在同一开机会话内** `md5sum` 校验，然后立即跑测试
2. 每次测试前打印 `md5sum`，测试数据与 md5 一起记录
3. 若需跨重启，重启后先重新部署并校验

#### 三、本轮作废数据
-"按 AU 喂流（WHOLE=0）"测试：因模块被还原成旧版，`insmod` 报 `Invalid module format`，未产生有效数据
- 之前的 `SLDBG`/`ADDRDBG` 对比：若当时 md5 正确则有效（其中一次已打印 md5 `0dc34021`，可保留）

#### 四、下一轮
1. 重新部署（带 md5 校验）→ 跑"按 AU 喂流"非 SED 测试（WHOLE=0）
2. 若 AU 模式仍全错 → 说明与喂流粒度无关
3. 继续按 §4.85 方向：对比 mainline 环境下 VDH 的**中断/时钟/内存属性**与原厂 3.18 的差异

### 4.87 2026-11-05：原厂刷机验证的可行性核查（按用户授权"必要时可刷机"）——准备就绪，方案已定

#### 一、原厂分区表（`hi3798mv300_M301H_JL.xml`，eMMC 512B 块偏移）
| 分区 | 起始 | 长度 | 镜像 |
|---|---|---|---|
| fastboot | 0 | 1M | fastboot_emmc.bin |
| bootargs | 1M | 1M | bootargs_emmc.bin |
| recovery | 2M | 10M | recovery_emmc.bin |
| … | | | deviceinfo/baseparam/pqparam/logo/logobak/loaderdb/fastplay/fastplaybak |
| **kernel** | **160M（块 0x50000）** | 40M | kernel_emmc.bin |
| misc | 200M | 20M | misc_emmc.bin |
| cache | 221M | 600M | cache_emmc.img |
| **system** | **821M（块 0x19A800）** | 700M | system_emmc.img |
| keydata/trustedcore/securestore | 1521M… | | |
| backup | 1619M | 600M | backup_emmc.img |
| userdata | 2219M | - | userdata_emmc.img |

#### 二、当前板子状态（关键）
- 板子现由 **U-Boot + FIP/ATF** 引导（串口日志：`Press Ctrl+C to stop autoboot` → `MMC read ... block # 28672` → `FIP ToC: BL3-1/BL3-3`），
  **原厂 fastboot 分区已被我们的 U-Boot 覆盖** ⇒ 直接刷 vendor kernel/system 无法用原厂引导流程启动 Android
- 我们现有可用刷机工具链（已验证过的脚本）：
  - `docs/porting/scripts/tftp_server.py`（高位端口 TFTP，普通用户可跑）
  - `docs/porting/scripts/flash_image_emmc.sh`（TFTP→RAM→`mmc write`，分块+断点续传）
  - `docs/porting/scripts/upload_chunks.sh`（串口 YMODEM 备用）
- 原厂恢复材料：`/mnt/f/design/Hi3798/FW/restore-20261104/{board-boot-32M.bin, ubuntu-p1.img.zst}`

#### 三、方案（两条路，已备好 A 的全部素材）
**A. 完整还原原厂引导链（真·原厂验证，风险可控）**
1. 刷 `fastboot_emmc.bin`→块0、`bootargs_emmc.bin`→块0x800、`kernel_emmc.bin`→块0x50000、
   `system_emmc.img`→块0x19A800（`cache/userdata` 可让 Android 自建）
2. 启动后抓串口日志，确认原厂 Android 是否起、vfmw 是否报错、能否进入播放
3. 验证完用 `flash_image_emmc.sh` 回刷：`board-boot-32M.bin`→块0、`ubuntu-p1.img`→块 0x97000（=302MB）
   ⚠ 写 system(821M) 会覆盖我们 Ubuntu 分区(302M 起) ⇒ **必须完整回刷根文件系统**

**B. 在机寄存器/状态对比（低成本，无需刷机）**
- 直接 ioremap VDH（0xF8C30000）读状态寄存器，对比 SED/非 SED 两次解码后的原始状态位

#### 四、本轮结论
- 刷机路径**已具备**（工具、镜像、分区表、恢复材料齐全），唯一额外步骤是要连原厂 fastboot 一起刷（因为我们把引导区换成了 U-Boot）
- 因风险与耗时，**先把 B 做完**（成本极低）；若 B 仍无法定位，再执行 A

### 4.88 2026-11-05 ★原厂固件已成功刷入并启动★（按 XML 全量刷写；用户授权"直接刷机看运行结果"）

#### 一、刷机通道（关键：用 Windows 侧 Tftpd64，不是 WSL 侧）
- Windows 上已有 **Tftpd64**（`C:\Program Files\Tftpd64\tftpd64.exe`），配置文件在
  `C:\Users\yujia\Desktop\hi3798_boot\tftpd32.ini`：
  `BaseDirectory=C:\Users\yujia\Desktop\hi3798_boot`、`TftpPort=69`、`LocalIP=192.168.2.100`
- 从 WSL 启动：`cd /mnt/c/Users/yujia/Desktop/hi3798_boot && ("./tftpd64.exe" &)`
  （把 exe 复制到该目录即可让它读取本地 ini；WSL 探测 UDP 不通但**板子能正常下载**）
- 板子侧（原厂 fastboot 控制台，`fastboot#`）：
  ```
  setenv serverip 192.168.2.100 ; setenv ipaddr 192.168.2.10
  setenv netmask 255.255.255.0 ; setenv gatewayip 192.168.2.1
  tftp 0x10000000 <file> ; mmc write 0 0x10000000 <start_blk> <count_blk>
  ```
  注意：**刚复位后第一次 tftp 常失败**，需先在"空闲提示符"下重试；不要用 ^C 干扰重试
- 进入 fastboot：复位后立刻持续发 `\x03`（每 4ms），直到出现 `fastboot#`

#### 二、按 XML 全量刷写的分区与偏移（已实证成功）
| 分区 | 起始块 | 大小 | 镜像 |
|---|---|---|---|
| fastboot | 0x0 | 1M | fastboot_emmc.bin |
| bootargs | 0x800 | 1M | bootargs_emmc.bin |
| recovery | 0x1000 | 10M | recovery_emmc.bin |
| deviceinfo | 0x6000 | 2M | deviceinfo_emmc.bin |
| baseparam | 0x7000 | 8M | baseparam_emmc.bin |
| pqparam | 0xB000 | 8M | pqparam_emmc.bin |
| logo/logobak | 0xF000 / 0x19000 | 20M | logo/logobak_emmc.bin |
| loaderdb | 0x23000 | 10M | loaderdb_emmc.bin |
| fastplay/fastplaybak | 0x28000 / 0x3C000 | 40M | fastplay(ba)k_emmc.bin |
| kernel | 0x50000 | 40M | kernel_emmc.bin（ANDROID bootimg）|
| misc | 0x64000 | 20M | misc_emmc.bin（**需清零**，见下）|
| stbid | 0x6E000 | 1M | stbid_emmc.bin |
| cache | 0x6E800 | 600M | cache_emmc.img |
| system | 0x19A800 | 700M | system_emmc.img |
| keydata | 0x2F8800 | 50M | keydata_emmc.bin |
| trustedcore | 0x311800 | 40M | trustedcore_emmc.bin |
| securestore | 0x325800 | 8M | securestore_emmc.bin |
| backup | 0x329800 | 600M | backup_emmc.img（**需清零前 64M**，见下）|
| userdata | 0x455800 | - | 置零 64M 让 Android 自格式化 |

#### 三、恢复模式的两个触发点（踩坑记录）
1. **misc 分区**里带 `boot-recovery` 命令 → fastboot 直接进 recovery
   （原厂 misc 备份是在 recovery 状态下做的，必须清零）
2. **backup 分区里有 `update.zip`** → recovery 启动后会去校验/安装 OTA 并驻留
   ⇒ 把 backup 前 64MB 清零后，recovery 落空 → 自动转**正常启动**
3. 我们自建的 ext4 曾用 `metadata_csum_seed`(feature 0x2000)/`orphan_file` → 3.18 内核不认
   （`Couldn't mount because of unsupported optional features`）⇒ 用 `mke2fs -O ^metadata_csum,^64bit,^orphan_file`

#### 四、当前状态（本轮结束）
- 原厂 Android **已正常启动**：日志可见 `init: VerifyFilesHash OK! counts=2984`、
  lowmemorykiller、`init.svc.adbd=running`、`hieth eth0: Link is Up`
- 串口是内核 console（无 shell）；**adb 存在但走 USB**，主机侧暂无 adb 客户端
- 板子不再 ping 通（Android 用 VLAN 85 网络配置）

#### 五、下一轮（取原厂 ground truth）
1. 找/装 adb 客户端（Windows 侧或 WSL），通过 USB 连上 Android：
   `adb shell` → `cat /proc/vfmw/channel` 等
2. 用 `am start` 播放视频（或用 `stagefright`）驱动 vfmw，抓健康通道数值
3. 对比我们移植版缺什么（重点：Ref/Read/New、VoQue、DFS、DecodeFrameNum 增速）
4. **恢复 Ubuntu 的方法（已验证可用）**：用本刷机通道把
   `/home/jason/bringup-7.3/out/board-boot-now.bin`（32MB，含 U-Boot/FIP/env）写到块 0，
   再把 `out/ubuntu-p1.img`（7.5GB，已解压）写到块 0x97000

### 4.89 2026-11-05 ★拿到原厂 Android 的 root shell 与 vfmw 真实通道数据（ground truth）★

#### 一、如何拿到串口 root shell（关键突破）
原厂 ramdisk 的 `init.rc` 里 `service console /system/bin/sh` 存在但被注释禁用
（`ro.debuggable=1`、`ro.secure=0`）。做法：
1. 解出 vendor bootimg 的 ramdisk（newc cpio.gz，自己用 Python 解析）
2. 把 `init.rc` 里 `#on property:ro.debuggable=1 / #    start console` **取消注释**
3. 重新打包 cpio.gz（等长替换进 bootimg，保持分区内偏移不变），刷到 kernel 分区（block 0x50000）
4. 启动后串口直接得到：`root@Hi3798MV300:/ #`（uid=0）

#### 二、播放视频（厂商播放器）
```
am start -n com.hisilicon.android.videoplayer/.activity.VideoActivity \
  -a android.intent.action.VIEW -d file:///system/media/networktest.ts -t video/mp2t
```
播放期间 `/proc/vfmw/channel` **真实数据**（完整见 artifacts）：
```
IsOpen:1 IsRun:1 Priority:15  eVidStd:MPEG2  ChanCapLevel:9
LastFrameState:RECEIVED  IsOmxPath:0  CfgDecMode:0  CfgOutputOrder:0
ErrorThred:25  StreamThred:0  UvmosEnable:1
Compress:0  LossCompress:0  BitDepth:0
DecodeFrameNum:16  OutputFrameNum:15
CTX Mem Phy:0x2329000 Size:2226680
SCD Mem Phy:0x1fe8000 Size:3407872
Ref,Read,New:(2,3,7)   VoQue detail:(5,8,15)
Act DecMode:0 Act OutputOrder:0  Frame Packing Type:0
VDH INFO: VDH0=0.1%  Frame Rate=0.0fps  Cycle State=0/mb
DFS INFO: Frame size(byte)=768416  Reference frame num=3
          Pre/Dynamic/All frame num=0/0/11
```

#### 三、与我们移植版的关键差异（可执行线索）
| 项 | 原厂（健康） | 我们 | 含义 |
|---|---|---|---|
| **ErrorThred** | **25** | 待查（很可能 0） | 原厂允许 ≤25% 错误率的帧继续输出；若我们为 0，任何 err 帧都被拒（正好解释"整帧错→不出图"）|
| **UvmosEnable** | **1** | 待查 | UVMOS（视频内存优化）开关，影响缓冲布局 |
| Compress | **0** | `EnVcmp=2` 才等效 | 原厂默认就是**不压缩**（印证之前 EnVcmp 结论）|
| IsOmxPath | **0** | 0 | 原厂走**非 OMX 的 SDK 路径**（与我们的移植路径相同）✅ 说明我们的技术路线正确 |
| DecodeFrameNum/OutputFrameNum | 16/15 | 我们 vdh=3~4/img≈0 | 原厂确实在持续解码并输出帧 |

⇒ **最优先**：检查我们驱动/通道配置里的 **ErrorThred（s32ErrRatioThred）** 与 **UvmosEnable**。
   若 ErrorThred=0 ⇒ 与我们"err_level!=0 就拒帧"的现象完全吻合 ⇒ 很可能就是 M2 的直接阻塞点。

#### 四、下一轮
1. 在 `port/vdec/vdec/drv_vdec_intf_k.c` 查 `s32ErrRatioThred`/`UvmosEnable`（stVdecChanCfg 字段）当前值，
   按原厂置 25 / 1（若我们未设置）
2. 重新构建跑非 SED H.264 解码，检查 `err_mbs` 帧是否能继续被 StorePicInDPB 接受并出图
3. 若有效 ⇒ M2 基本打通，转 M3（V4L2 播放器）

### 4.90 2026-11-05 ★原厂硬件解码基准（4K.ts HEVC 62–63fps、VDH 67%）★ + `ErrorThred` 不是根因

#### 一、原厂自带的测试流（在 system 镜像里）
- `/system/lib/2K.ts`（MPEG2，10MB）
- `/system/lib/4K.ts`（**HEVC**，10MB）
- `/system/media/networktest.ts`（MPEG2）

播放并采样 `/proc/vfmw/channel`：
| 流 | 编码 | DecodeFrameNum/OutputFrameNum | VDH 占用 | fps |
|---|---|---|---|---|
| 2K.ts | MPEG2 | 113/112 | 11.2% | 29.9 |
| **4K.ts** | **HEVC** | **290/290** | **66.7~69.6%** | **62~63** |
| networktest.ts | MPEG2 | 16/15 | 0.1% | 22~26 |

⇒ **原厂走同一条 vfmw/V5R2C1 路径（`IsOmxPath=0`），HEVC 4K 能稳定 62fps、VDH 高占用**
  ⇒ 硬件、VDH HAL、vfmw 版本本身**没有问题**；问题在我们移植层。
  ⇒ 也说明"原厂 H.264 一定能解"，只是 system 里没有 H.264 样片
     （我们自制的 TS 封装被播放器拒绝：`ChanId 0 inactive`，封装器还有 bug）

#### 二、`ErrorThred` 复核（重要：不是根因）
- 原厂 `/proc/vfmw/channel`：`ErrorThred = 25`
- 我们驱动：`drv_vdec_intf_k.c:525` 默认 `.u32ErrCover = 100`，`3473: stVdecChanCfg.s32ChanErrThr = pstCfg->u32ErrCover`
  ⇒ 我们是 **100（零容忍…过度宽容），比原厂更宽松** ⇒ **"拒帧"不是阻塞点**（§4.89 的假设被否）
- `UvmosEnable`：原厂=1（播放器启用）；我们默认不启用（`bUVMOSEnable` 仅由 ioctl 设置）
  ⇒ UVMOS 只影响内存优化，非解码正确性关键

#### 三、当前动作
- 已开始**恢复 Ubuntu**（`board-boot-now.bin`→块0、`ubuntu-p1.img`(7.5GB)→块0x97000，分 64MB 块 TFTP 刷写）
  恢复完成后即可继续验证我们移植版的 H.264/HEVC 解码

#### 四、下一轮（恢复完成后）
1. 用 **HEVC 流**（我们有 4K.ts 可拷回）先测我们移植版：若 HEVC 也全错 ⇒ 公共路径问题；若 HEVC 正常、H.264 全错 ⇒ H.264 专用路径
2. 对比原厂 VDH 高占用（67%）与我们 vdh=3~4 的差异，定位"提交/中断"环节
3. 若需要：再把 board 切回原厂 Android（素材齐全），用 root shell 直接对比寄存器

### 4.91 2026-11-05 恢复 Ubuntu 进行中（boot 区已恢复；rootfs 分块刷写 3/112）

#### 一、可靠的刷写流程（踩了 5 次坑后总结）
1. **先把板子停在 fastboot 提示符**：`ser_reset` 后**立刻**连续发 `\x03`（不要先 sleep，否则错过 autoboot 窗口）
2. **重启 Windows Tftpd64**（它处理若干次大文件传输后会挂起，表现为 tftp 超时）：
   `cmd.exe /c "taskkill /F /IM tftpd64.exe"` → 在 `hi3798_boot` 目录重新启动
3. **刷写脚本里不要 reset**：在空闲提示符下 setenv + tftp + mmc write（实测稳定）
   - 刚复位后的第一次 tftp 几乎必失败（网络未就绪），所以"先停提示符、再起 Tftpd、再无复位刷写"是唯一稳的组合
4. 大镜像分 64MB 块，每块 `tftp 0x10000000 tmpchunk_%03d.bin` + `mmc write`
   （文件名必须每块不同，Windows 侧会锁住上次被读取的文件）

#### 二、当前恢复进度
- `board-boot-now.bin`(32MB) → 块 0：**已写入** ✓
- `ubuntu-p1.img`(7,503,413,248B) → 块 0x97000 起（112 块 × 64MB）：**3/112**（后台进行，约 1 分钟/块）
- 脚本：`/tmp/restore_nodereset.py`，日志 `/tmp/restore5.log`
- 完成后启动文件系统一致性修复（Ubuntu 首次启动会 fsck），再继续 M2 验证

#### 三、下一轮计划（恢复完成后立即执行）
1. 板子回到 Ubuntu（Linux 7.3.0 #182），SSH/串口确认
2. 把 `/system/lib/4K.ts`(HEVC) 与 2K.ts 拷回板子（vendor Android 仍在 eMMC 外的备份镜像里，可从
   `/mnt/f/design/Hi3798/FW/BK/BK/system_emmc.img` 用 debugfs 提取）
3. 用 **HEVC 流**测我们移植版非 SED 解码：
   - 若 HEVC 也 100% MB 错 ⇒ 公共路径（VDH 提交/中断/UVMOS）问题
   - 若 HEVC 正常而 H.264 全错 ⇒ H.264 专用路径（slice/Apc/DecParam）问题
4. 用原厂 VDH 67% 占用做参照，检查我们的 `vdh` 计数为何只有 3~4

### 4.92 2026-11-05 恢复期间的本机准备（HEVC 素材 + 模块 + 部署包）

目标：恢复完成后**第一步就跑 HEVC 非 SED 解码**，用于区分
"公共路径问题（VDH 提交/中断/内存布局）" 还是 "H.264 专用路径问题"。

#### 一、从原厂 system 镜像提取测试流（debugfs dump，不需板子）
- `/system/lib/2K.ts`（MPEG2 10MB）、`/system/lib/4K.ts`（**HEVC 10MB**）、`/system/media/networktest.ts`
  → `/home/jason/bringup-7.3/out/media/`
- 用 Python 写的极简 TS 解复用抽 ES：
  - PAT(PID0) → PMT(PID 0x1000) → stream_type **0x24 = HEVC** → ES PID 0x100
  - `4K.ts` 解出 `4K_es.bin`(9.6MB)，再裁到首个 VPS → **`4K_vps.hevc`(9,615,637 B)**
  - NAL 统计：SEI(39)×296、TRAIL_R(1)×287、VPS/SPS/PPS(32/33/34) 各 3、IDR_W_RADL(20)×3
- 注意：`2K.ts` 的 PAT/PMT 解析这次没成功（PID 结构不同），暂不需要

#### 二、本机已构建好的模块（与板上内核 7.3.0 #182 匹配）
- `port/vdec/hi_vdec.ko`（1,954,400 B）
- `port/mmz/hi_mmz_shim.ko`（11,464 B）
- 测试程序 `port/vdecuser/vdec_test`（aarch64 静态，用法 `vdec_test file.h264 [all|au]`，靠码流自动识别编码）
- 部署包：`out/deploy-m2.tgz`（含 ko、vdec_test、4K_vps.hevc、gen3_idr.h264）

#### 三、恢复进度
- boot 区 32MB 已恢复；`ubuntu-p1.img` 分 112×64MB 块刷写，**7/112**（每块前重启 Tftpd64，约 1 分钟/块）
- 脚本 `/tmp/restore2.py`（RESUME 环境变量断点续传），日志 `/tmp/restore6.log`

#### 四、恢复完成后的动作序列
1. `ssh root@192.168.2.10` 确认内核 `7.3.0 #182`
2. `scp out/deploy-m2.tgz` → 板上解压
3. 先测 **HEVC**：`insmod hi_mmz_shim.ko; insmod hi_vdec.ko vdec_dfs=1 vdec_sed_only=0; ./vdec_test 4K_vps.hevc all`
   - `err_mbs`/`img` 计数决定分支：HEVC 也全错 ⇒ 公共路径；HEVC 正常 ⇒ H.264 专用路径
4. 再测 H.264（gen3_idr.h264）作对照

### 4.93 2026-11-05 Ubuntu 已完整恢复；H.264 症状复现；新线索"错误范围只覆盖最后 10 个 MB"

#### 一、恢复完成（重要里程碑）
- `board-boot-now.bin`(32MB)→块0 + `ubuntu-p1.img`(7.5GB,112×64MB)→块0x97000 **全部写入完成**
- 板子启动 Ubuntu 26.04.1 / linux 7.3.0 ✓；根分区 6.9G，已用 4.3G(67%)
- 网络：**eth0 192.168.2.10 + wlan0 192.168.2.21(DHCP)**；本轮 SSH 走 `root@192.168.2.21`
- 板上有既有服务：weston(remote desktop)、`stability-load.service`(1080p H.264 循环播放)、`stability-monitor`

#### 二、踩坑记录（恢复过程）
1. **fastboot 提示符长时间空闲会自动引导**：刷写脚本必须每块前后有交互（保活），否则板子会自己启动
2. **Windows 侧文件会被 Tftpd64 锁住** ⇒ 分块文件名必须每块唯一（`uz_%03d_%d.bin`），否则 `PermissionError`
3. **每块都重启 Tftpd64 反而不可靠**（端口绑定时序）⇒ 只在失败时重启，且重启后 **sleep 10**
4. `rmmod hi_vdec` 仍然**段错误**并把模块弄成 refcnt=-1，只能用重启恢复 ⇒ 测试前先重启板子，一轮只做一次 insmod

#### 三、H.264 症状复现（新模块 1,954,400B，md5 同 host）
```
VTSTAT: put=19 read=355 img=2 ack=1 | vdh=16 scd=16
N: total_mbs=920,err_mbs=920, ErrFrame_Flag: 0
N: store pic err, ret = -1
```
与历史一致 ⇒ 环境恢复正确、问题稳定可复现。

#### 四、★新线索：硬件 repair param 有时只覆盖最后 10 个 MB★
dmesg 里 vfmw 打印的 repair 信息（证据 `m2-diag/errmbs_mbgroup_partial.txt`）：
```
frame 21..25: pRepairParam[0].MbGroup[i].StartMbn=0    EndMbn=919  ErrRatio=100
frame 26    : pRepairParam[0].MbGroup[i].StartMbn=910  EndMbn=919  ErrRatio=1
```
- 640x368 = 40 MB/行 × 23 行 = 920 MB；**910~919 正是最后一行的最后 10 个 MB**
- 说明：硬件并非"完全解不出来"，有一帧几乎全对（只剩最后 10 MB），而 frame25→frame26 的打印只隔 **3ms**
- ⇒ 高度怀疑**repair 信息读取时机/来源错误**（postproc 在 VDH 未完成或状态寄存器未更新时就读），
  或**最后一片 slice 的处理**（slice 表最后一段范围）有问题
- 这条线索把问题从"硬件没工作"转向"**完成/状态/repair 时序**"

#### 五、HEVC 对照实验受阻（测试工具限制，非驱动问题）
- `vdec_test` 里写死 `attr.enType = HI_UNF_VCODEC_TYPE_H264`、`enCapLevel = CAP_LEVEL_FULLHD(1080p)`
  ⇒ 喂 4K HEVC 根本不会建 HEVC 通道（dmesg 只有 `DEC PARAM is not ready`、`mfde_tasks=0`、`vdh=0`）——**不是解码器结论**
- 需要改造 vdec_test（`VCODEC=` 环境变量 + 4K cap level）再编译；当前重编译受阻：
  SDK 头文件与本地 `mpi_vdec.c` 版本不一致（`HI_MPI_VDEC_RlsUserData` 原型冲突、缺 `hi_drv_struct.h`）

#### 六、下一轮（按优先级）
1. **查 postproc 与 VDH 完成的时序**：在 `VDMDRV_IsVdhReady`/`VDMHAL_V5R2C1_GetRepairParam`/`PostPro_GetRepairParam`
   处加打印（帧号、VDH 状态寄存器、调用时距 ISR 的时间），确认 repair 信息是否在完成前读取
2. **对照 SDK 源码**（`source/msp/drv/vdec/vdec_v2.0/`、`vdec_v2.1/`）检查我们的 VDH 完成判断与状态寄存器读取
3. 试 `EnVcmp=0`（关帧压缩）排除 Compress 影响
4. 重建 vdec_test 支持 HEVC/MPEG2 通道后再做编码维度对照

### 4.94 2026-11-05 ★M2 交接文档已产出 + 新证据：偶发 err_mbs=0★

#### 一、交接文档
新会话请**先读**：`docs/porting/HANDOFF-M2-vdec-2026-11-05.md`（493 行）
内容：环境事实、已确认结论、**已排除假设清单（勿重复）**、当前阻塞与开放假设 H1–H6（含验证方法/判据）、
复现命令、调试手段、双向刷机/恢复手册（vendor Android ↔ Ubuntu）、踩坑清单、下一步行动顺序。

#### 二、本轮新增的关键证据（写进交接文档 §3.6）
同一配置、同一次运行里出现：
```
N: total_mbs=920,err_mbs=920, ErrFrame_Flag: 0      ← 绝大多数
N: total_mbs=920,err_mbs=0,   ErrFrame_Flag: 0      ← ★偶发全对（无 ErrRatio=100 行）
```
⇒ **硬件解码本身有时确实是对的**；矛盾集中在"错误信息（repair param）绝大多数时候报整帧错"。
配合之前观察到的 `StartMbn=910..919 / ErrRatio=1`（只最后 10 个 MB）⇒ 指向
`PostPro_GetErrRatio → MakeDecReport` 读到的 **g_HwMem 状态副本陈旧 / postproc 时机**，
或 `IsVdmReady/IsVdmRun` 副本未及时更新。

#### 三、本轮其它已确认（供交接文档引用）
- vfmw 汇编与 SDK v5.0 原版 **逻辑一致**（差异仅 `_mcount` + 我们的 hook）
- 码流数据**确实在物理内存**（/dev/mem dump 中按顺序找到 stream 各偏移的 24B 模式）⇒ 缓存假设排除
- `vdec_test` 单帧隔离（SIMPLE=1）仍 err_mbs=920 ⇒ 队列/竞争假设排除
- 工具已固化到 `bringup-7.3/tools/`：`fb_prompt.py`、`fb_flash.py`、`xml_flash2.py`、`restore7.py` 等

### 4.95 板上操作备忘（踩过的坑）
- **先 `insmod hi_mmz_shim.ko`，再 `insmod hi_vdec.ko`**；`/dev/hi_mmz` 不存在时用户态映射会静默失败，
  表现为 `GetStreamBuf h=0xffffffff`、`GetBuffer rc=0x80120002`，看起来像解码问题其实是环境没搭好
- 反复跑解码容易**硬挂死复位**（无 oops）：每轮只跑一次、跑完看 `dmesg`；复位后模块全丢，需重新 insmod
- 改完板上 `.ko` 必须 `sync`（`reboot -f` 会丢页缓存 → `Invalid module format`）

---

## 5. 复现与验证步骤（M4）

### 5.1 构建模块
```bash
export PATH=/home/jason/bringup-7.3/toolchain/usr/bin:$PATH
export LD_LIBRARY_PATH=/home/jason/bringup-7.3/toolchain/usr/lib/x86_64-linux-gnu
cd /home/jason/bringup-7.3/src/linux-7.3
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=/home/jason/bringup-7.3/port/venc modules
md5sum /home/jason/bringup-7.3/port/venc/hi_venc.ko
```

### 5.2 部署
```bash
scp -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no \
    /home/jason/bringup-7.3/port/venc/hi_venc.ko root@192.168.2.10:/root/hi_venc.ko
ssh root@192.168.2.10 'md5sum /root/hi_venc.ko'   # 必须与本地一致
```
板上已有：`/root/hi_mmz_shim.ko`（MMZ 桩）、`/root/venc_test`（测试程序，参数=帧数；
2026-11-04 晚已换成"每帧重试取流 + drain"版，源码 `artifacts/venc-reverse/m4-pass/venc_test.c`）。

### 5.3 运行与观测
```bash
ssh root@192.168.2.10 '
  insmod /root/hi_mmz_shim.ko 2>/dev/null
  insmod /root/hi_venc.ko            # 可选：venc_nokick=1 / venc_smmu_off=1
  dmesg -C
  /root/venc_test 30          # 期望: done frames=30 streams=30 bytes>0
  dmesg | grep -aE "VENCBUILD|VKICK|VSYNC|VPROBE|VWPRP|VSTRM|VENCCRG|VENCSMMU"
  ls -l /root/out_venc.h264
'
```
- **`VENCBUILD: <build-id>`** 是模块内唯一构建号，**每次必须核对**（历史上多次出现"板上是旧模块"导致误判）
- 驱动 trace 文件：`/root/venc_trace.log`（含 `CFGHEX:` 170 行配置、`C32IMG`、`PREKICK` 等）
- 驱动侧的 `CFGHEX:` dump 可直接喂 qemu harness 生成对应镜像

### 5.4 重新加载模块（重要）
`rmmod hi_venc` 经常失败（refcount = -1，因 workqueue/设备残留），此时必须重启板子：
```bash
ssh root@192.168.2.10 'systemctl mask --now udisks2.service polkit.service; sync; reboot'
# 或串口：/dev/ttyUSB1 RTS 脉冲复位
```
（mask 这两个服务可显著加快关机，否则可能卡 6 分钟）

---

## 6. 下一会话的建议执行顺序

> M4 已于 2026-11-04 晚完成（见 §3.6），下面只列**剩余**工作。

### 优先级 1：M2 —— 大量 `113` 语法错误（送流方式已排除，见 §4.5）
已排除：EOP 标记、连续送流、帧存上报（12/12 接受）、通道配置、动态/静态帧存。
首帧 `err_mbs=0` 说明解码通路正确，问题集中在"第 2 帧起"。下一步建议：
1. 用 `N_AU=2/4/8` 只送前几帧，判定是"逐帧失败"还是"累积后失败"
2. 核对 AU 切分：把 `vdec_test` 的 AU 边界与 `ffmpeg -f h264` 解出的包边界逐字节比对
3. 若确认 P 帧本身有问题，查 DPB 上报（`VDEC_CID_REPORT_OCCUQIED_FRM`）与显示序号

以下为历史方法，保留备查：
### 优先级 1（历史）：修"码流缓冲生命周期 / 大量 113 语法错误"
现状：帧存已通（12/12）、`NEW_IMAGE(5)` 已出现、首帧 `err_mbs=0`；但 60 帧流仍有 50~62 次
`113`(DECSYNTAX_ERR) 与 `PPS decode error`。先查：
1. `VDEC_Chan_RlsStrmBuf` ↔ BUFMNG 读/释放是否严格配对（GETES 出现同包被读两次）
2. FASTFEED 下写入位置是否越界/回绕覆盖未读数据
3. 必要时改成"每帧送一个 AU、等解码完成再送下一帧"的握手式送流，隔离送流问题

以下为已完成/历史方法，保留备查：
### 优先级 1（历史）：修"vfmw 不上报帧存需求"
因果链已确认：没有帧存上报 → 不分配 → 无参考帧 → P 帧全错 → 用户 0~2 帧。要做的事：
1. 在 `vfmw/adapter/vfmw_intf.c` 的 `VFMW_Init` / `VFMW_Control(CFG_CHAN)` 处打印入参
   （`mem_malloc`、`MemAllocMode`、`Purpose`、`s32ExtraFrameStoreNum`、`u32DynamicFrameStoreAllocEn`），
   确认帧存该由谁提供
2. 确认 `VDEC_CID_SET_FRAME_INTF` 是否为开关（omxvdec 用过 `SET_FRAME_BUFFER_NUM`，移植代码从未调用）
3. 若确认必须"驱动预分配后上报"，则改用 `VDEC_CID_ALLOC_MEM_TO_DECODER` 直接把 N 块帧存给 vfmw，
   不再依赖 118/121 事件
4. 备选 A/B：用 SDK 自带 omxvdec（`msp/drv/omxvdec/omxvdec_v2.0`，含 `processor_vpss.c` 完整 channel 序列）
   跑同一码流；若它能多帧输出，就把其 channel 序列移植进 `port/vdec`

### 优先级 2：M3 V4L2 播放器（依赖 M2）
### 优先级 3：M5 GPU 调压 / TDE（可选）
- GPU 已能跑（`gpu@f9200000`），调压可从 `thermal@f8a23000` + `mali` devfreq 入手

### 已尝试但不可行（不要重复）
- 厂商固件侧读 VEDU 寄存器：`/proc/kcore` 不存在、`/dev/mem` 设备区被禁、HAL 打印在 release 构建被裁
- `/proc/hisi/msp/*` 无 venc 条目
- 把 `g_pHalRegInfo` 指向寄存器基址（会让 `memcpy(scratch,cfg,696)` 写进 VEDU 寄存器 → 总线 hang）；
  正确做法是让它由厂商 `Init` 自己 vmalloc（见 §3.6）
- 在 ISR 上下文里 `ioremap`（`venc_smmu_bypass`）→ `BUG at mm/vmalloc.c`

---

## 7. 重要坑与注意事项（必须遵守）

### 7.1 VEDU 寄存器访问禁忌
1. **kick（写 `0x008=1`）之后绝对不要再读 VEDU MMIO** —— 会总线挂死 → 看门狗复位。
   所有寄存器读必须放在 kick **之前**（`PREKICK` 日志就是为此设计）。
2. kick 之后只允许读**内存**（码流缓冲 / WpRp 缓冲）。
3. 读回值不可信：多个偏移会读到同一浮空值（如 `0x300f5000`）→ 不能作为判据。

### 7.2 板子固件切换（如需厂商 Android）
- fastboot 控制台进入：持续发 `\x03` 直到出现 `Press Ctrl+C to stop autoboot` → `fastboot#`
- fastboot 命令里 `mmc read/write` 的块参数是 **HEX 且不带 0x**
- 厂商 Android 启动：
  ```
  setenv bootcmd 'mmc read 0 0x1FFBFC0 0x50000 0x10000; bootm 0x1FFBFC0'
  setenv bootargs 'console=ttyAMA0,115200 <厂商 blkdevparts> coherent_pool=1M androidboot.console=ttyAMA0 androidboot.selinux=permissive'
  saveenv; reset
  ```
- busybox 维护环境在 backup 分区（block `0x329800`），`bootm 0x1FFBFC0` + `root=/dev/ram0 rw init=/init`
- 厂商 Android 的稳定写入钩子：`/system/etc/init.bigfish.sh` 末尾追加命令（`/system/etc/init/*.rc` 的 drop-in 不生效）

### 7.3 固件取证为何失败（不要重复尝试）
| 通道 | 结果 |
|---|---|
| `/proc/kcore` | 厂商内核**没有** |
| `/dev/mem` 设备区 | 读 0 / `mmap: Invalid argument` |
| 厂商 HAL 调试打印 | `HI_LOG_LEVEL=INFO`，`HI_DBG_PRINT` 编译为空；HAL 是汇编无打印 |
| 内核 text 反汇编 | text 18.2MB，但 bootimg 里是 9.09MB **zImage（压缩）**；必须解压后才能按 vaddr 取码（已解压并反汇编了 CfgReg） |

### 7.4 部署一致性
- 每次加载后**必须**核对 `dmesg | grep VENCBUILD` 与本地构建号
- 历史上有 3 次以上因为「板上旧模块」造成误判

### 7.5 串口脚本
`/tmp/*.py` 中的串口/复位脚本是临时的，新会话需按需重建。基本协议：
- 复位：`/dev/ttyUSB1` RTS 高 0.4s → 低
- 进 fastboot：持续写 `\x03`（每 4ms 一次，最多 25s），检测 `fastboot#`
- 进 shell：等待出现 `root@hi3798mv300` 再发包
- 串口输出有 ANSI 转义，解析时建议过滤或只匹配关键子串

---

## 8. 验收标准（供新会话判定）

| 阶段 | 通过判据 |
|---|---|
| M4 VENC | ✅ **已达成（2026-11-04 21:58）**：`/root/out_venc.h264` 头部 `00 00 00 01 67/68/65` + 后续 `61`(P 帧)；`GIC-0 133 Level venc` 中断计数递增（425）；`ffprobe`=h264 High 320×240；`ffmpeg` 解码 rc=0；300 帧跑通、无 oops（证据 `artifacts/venc-reverse/m4-pass/`）|
| M2 VDEC | ⚠️ 未达成：连续解码 ≥ N（建议 30）帧，`NEW_IMAGE`/事件到达，输出 YUV 帧数匹配。当前稳定只出 1 帧（见 §4.1） |
| M3 V4L2 | V4L2 捕获端能取到解码帧并显示/存文件 |
| M5 | GPU 电压/TDE 测点可调可观测 |

---

## 9. 证据与文档索引

| 内容 | 路径 |
|---|---|
| 总报告（M1–M5） | `docs/porting/p4-hardware-acceleration-final-report-2026-11-04.md` |
| **M4 详细报告（含全部轮次记录）** | `docs/porting/p4-venc-m4-status-report-2026-11-03.md` |
| M2 详细报告 | `docs/porting/p4-vdec-m2-status-report-2026-11-03.md` |
| 厂商 CfgReg 反汇编 | `docs/porting/vendor-venc-cfgreg-disasm.asm` |
| 逆向/qemu 产物 | `docs/porting/artifacts/venc-reverse/` |
| **M4 验收证据（码流/日志/ko/源码快照）** | `docs/porting/artifacts/venc-reverse/m4-pass/` |
| **M2 诊断材料（码流/测试程序/VPSS 桩源码/板上流程）** | `docs/porting/artifacts/venc-reverse/m2-diag/` |
| 移植目录备份 | `/home/jason/bringup-7.3/backup/port-*.tgz` |
| 计划与规格 | `docs/superpowers/plans/2026-10-30-hi3798mv300-linux7x-ubuntu-implementation-plan.md`<br>`docs/superpowers/specs/2026-10-30-hi3798mv300-linux7x-ubuntu-design.md`<br>`docs/superpowers/plans/2026-11-03-hardware-acceleration-plan.md` |
| SDD ledger（Round 1–253） | `.superpowers/sdd/2026-10-30-hi3798mv300-linux7x-ubuntu-implementation-plan/progress.md` |
| 状态总览 | `docs/porting/STATUS.md` |

---

## 10. 系统恢复（万一板子起不来）

- **引导区（32MB，含 fastboot/env/FIP）**：`/mnt/f/design/Hi3798/FW/restore-20261104/board-boot-32M.bin`
- **rootfs 镜像**：`/mnt/f/design/Hi3798/FW/restore-20261104/ubuntu-p1.img.zst`
  （2,320,538,498 B → 解压 7,503,413,248 B，正好是 p1 大小）
- 已验证的恢复方法（整盘单流，一次写 7,820,083,200 B = 磁盘总大小）：
  1. 进入 busybox 维护环境
  2. 板上：`nc -l -p <PORT> > /dev/mmcblk0`（`/dev/mmcblk0` 若是普通文件需先 `rm` 再 `mknod b 179 0`）
  3. 主机：python 流 = `board-boot-32M.bin` + 零填充到 302MiB + zstd 解压的 rootfs 镜像
     （主机无常备 zstd，可用 PyPI wheel 解包 `zstandard` 模块：`/tmp/zstdpkg`）
  4. `sync` → RTS 复位
- 厂商固件恢复：`/mnt/f/design/Hi3798/FW/BK/BK/` 下各分区镜像（fastboot 侧用 `mmc write` 写回）

> 注意：busybox 环境里 `dd` 有 bug（读到 0），写分区要用 `nc` 直写设备节点；
> 分区号非顺序，`p1..p7 = 179:1..7`，`p8..p21 = 259:0..13`。
