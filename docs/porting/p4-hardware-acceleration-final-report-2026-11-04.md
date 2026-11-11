# 硬件加速任务总报告（M1–M5）— 2026-11-04

关联计划：`docs/superpowers/plans/2026-11-03-hardware-acceleration-plan.md`
关联状态：`docs/porting/STATUS.md`

---

## 0. 总结

| 里程碑 | 状态 | 一句话 |
|---|---|---|
| **M1 JPEG 硬解** | ✅ **验收通过** | `/dev/jpeg` 可用，1080p 单帧 5.3 ms（189 fps），PSNR 66.16 dB |
| **M2 VDEC H.264 硬解** | ⚠️ **功能验证通过，稳定性未达标** | 320×240 与 1080p 解码 **bit-exact**；连续多次运行会硬挂死复位 |
| **M3 V4L2 播放器集成** | ⏸ **未开始** | 依赖 M2 稳定性；VDEC 为厂商私有 ioctl，需自研 shim 或 V4L2 桥接 |
| **M4 VENC H.264 硬编码** | 🚧 **未验收（配置链路已完全打通）** | `CfgReg`/SMMU/时钟/中断全通且稳定；缺厂商启动握手（VEDU 不启动） |
| **M5 GPU 调压 / TDE** | ⏸ **未开始** | 调压器 PMC 0xF8A23020 无驱动源码；GPU 保持 200 MHz 可用（lima） |

**强需求达成情况**：
- VDEC 硬解：功能正确性已证明（bit-exact），**但未达到"播放器可用、≥30fps 无丢帧"的验收标准**
- VENC 硬编码：硬件链路全部打通，**但未产出稳定码流**，未达到"≥25fps"标准

---

## 1. M1 JPEG 硬解（✅ 通过）

交付物：
- `port/jpeg/`（内核驱动 `hi_jpeg.ko`，`/dev/jpeg`）
- `port/jpeg-user/`（用户态 API + MMZ shim）
- `port/mmz/hi_mmz_shim.c`（`/dev/hi_mmz` 分配器）

实测证据：
- 1080p JPEG 单帧解码 **5.3 ms（≈189 fps）**
- 输出与软解基准 **PSNR 66.16 dB**

---

## 2. M2 VDEC H.264 硬解（⚠️ 功能通过、稳定性未达标）

交付物：
- `port/vdec/`（`hi_vdec.ko` + vfmw 5.0 64-bit 预编译核 + 适配层）
- `port/vdecuser/`（MPI 用户态 + 测试程序）

功能证据：
- 320×240 与 1920×1080 解码结果 **bit-exact**（Y 通道 PSNR≈99 dB / MSE=0）
- 单次运行可产出多帧（曾稳定输出 4 帧）

稳定性实测（2026-11-03 复核）：

| 测试 | 结果 |
|---|---|
| 3 次连续解码 `NOEOP=1 FASTFEED=1 SEQ_RETRY=3` | run1 出 1 帧 1080p（fps 0.46）；run2 出 0 帧；run3 **板子复位** |
| 3 次连续（`SEQ_RETRY=6 DRAIN=6`） | **首次运行即复位**，dmesg 无 oops（硬挂死） |

已解决的根因（详见 `p4-vdec-m2-status-report-2026-11-03.md`）：
1. MMZ 使用 `ioremap`/Device 内存导致内核页表破坏 → 改线性映射 + `flush_dcache_page`
2. MMZ 落在 CMA 导致内存损坏 → 迁移到 DTS reserved region `0x28000000`(96MB)
3. VDH SMMU 基址纠正为 `0xF8C3F000`，通过 `SCR=1` 旁路
4. 中断号需 DTS 节点 + hwirq→virq 转换（`127/136/181`）
5. `SM_Wakeup` 的 FillRawData 强制补丁会破坏 SCD → 恢复厂商条件
6. EOP 注入有害（被当成非法 NAL）→ 关闭（`NOEOP=1`）
7. 能力全零导致 QCIF → 显式设置 NORMAL/FULLHD/MPEG

未解决：图像交付不稳定（GetImage 成功率约 30–50%），`EVNT_NEW_IMAGE` 从未到达；
连续运行会硬挂死且无 oops（与 M4 同类的"硬件 DMA 后挂死"特征）。

---

## 3. M3 V4L2 播放器集成（⏸ 未开始）

阻塞原因：M2 稳定性未达标。VDEC 为厂商私有 ioctl（UMAP），无 V4L2 接口，
需要：
1. 稳定的 VDEC 解码循环（先解决 M2）
2. 自研 V4L2 mem2mem 桥接（`v4l2_m2m` + 私有 ioctl 后端）或用户态 shim 库
3. 与 DRM/KMS 显示打通（hi3798-drm 已验证可用）

---

## 4. M4 VENC H.264 硬编码（🚧 未验收）

### 4.1 已达成（有实机证据）

| 项 | 证据 |
|---|---|
| 内核模块编译 | `port/venc/hi_venc.ko`（约 185 KB，mode=0 稳定版） |
| 模块加载 + 设备节点 | `insmod rc=0`；`/dev/hi_venc`（class `himedia_venc`） |
| `HI_UNF_VENC_Init` | `rc=0` |
| `HI_UNF_VENC_Create` | `rc=0`（CheckConfig/EflCreateVenc/RcAttrInit/ProcAdd 全 0） |
| `HI_UNF_VENC_Start` | `rc=0` |
| VEDU 时钟 | `CRG35 (0x8C) = 0x3`（core/axi cken 开、clk_sel=250MHz） |
| VEDU SMMU 时钟/复位 | `CRG203 (0x32C) = 0x1`，`srst_req(bit4)` 已释放 |
| SMMU 旁路 | `SCR = 0x00000001`（bypass/identity） |
| 中断注册 | `request irq 133 → virq 38`；`/proc/interrupts`: `GIC-0 133 Level venc` |
| **一次真实硬件编码** | 曾观测 `ISR readback: timeout=0 bufffull=0 slice0=45080`（约 45 KB slice） |

### 4.2 已定位并修复的根因（7 个）

1. **SMMU 长期处于复位**：`PERI_CRG203` 实际偏移 **0x32C**（非 0x334），bit4 = `srst_req`
2. **HAL Init 自初始化路径误判**：厂商 64 位 HAL 的 `.L143` 分支会
   `ioremap(0xF8C80000, 0xF700)` → `g_pRegBase`，`vmalloc(4480)` → `g_pHalRegInfo`
3. **HAL 全局符号未导出**：`.S` 中 `g_pRegBase`/`g_pHalRegInfo` 需 `.global`
4. **中断上下文违规**：`kernel BUG at mm/vmalloc.c:3228`（`BUG_ON(in_nirq())`）
   —— ISR 内 `ioremap` 会走 vmalloc → BUG
5. **ISR 内禁止 printk / 文件 IO**：改用内存环形缓冲 + 任务线程落盘
6. **`die_notifier` 取参错误**：arm64 传入的是 `struct die_args`（非 `pt_regs`）
7. **64 位内核 VA 被 32 位地址总线截断**（关键）：
   `RegCfg.ExtCfg.DdrRegCfgVirAddr`(offset 688) 与另一地址字段(offset 484)
   会经 `memcpy(结构→VEDU 寄存器空间)` 进入硬件，64 位 VA 截断后越界 → 总线挂死
   → 修复：仅在 memcpy 期间临时换为 32 位物理地址，之后把寄存器镜像
     的 484/688 都改写为物理地址

### 4.3 仍未解决：缺厂商启动握手

实测（`CfgReg` 返回后立即 `VENC_HAL_ReadReg`）：

```text
RB timeout=0 endpic=0 buffull=0 pbover=0 picbits=0 meanqp=0 slice0=0
```

→ **硬件完全没有开始编码**。

| 模式 | 行为 |
|---|---|
| `mode=0`（直接寄存器模式） | `cfg_done=1`、`oops=0`、板子稳定，**但 HAL 不含厂商启动握手 → VEDU 永不启动** |
| `mode=1`（DDR 配置模式） | VEDU 会尝试启动，但 DDR 配置镜像/握手协议不满足 → **总线挂死复位** |

### 4.4 下一步（明确、可执行）

1. **逆向 32 位 HAL 的 DDR 配置协议**：对比 `32bit/3796mv200/drv_venc_hal.S`
   与 64 位版本在 `CfgReg` 尾部的启动序列差异（32 位是厂商实际出货配置）
2. 或获取 **VEDU (HiVEDUV500R001) 寄存器手册**，按手册实现
   `DdrRegCfgPhyAddr` + 启动位序列
3. 备选：改用 `msp/drv/venc/venc_v1.0`（纯 C HAL，可调试性好），
   但其 VEDU 版本可能不匹配 V500R001

---

## 5. M5 GPU 调压 / TDE（⏸ 未开始）

- GPU：lima Mali450 可用（GL 简单场景）；重负载会 pp 复位，桌面默认 pixman 保稳定
- 调压：SoC 内置调压器 PMC `0xF8A23020` **无驱动源码**，需自行实现或跳过
- TDE：`0xF8C10000`，厂商私有驱动 33.5k 行，未移植

---

## 6. 复现与构建

```bash
# 内核模块
cd /home/jason/bringup-7.3/src/linux-7.3
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=/home/jason/bringup-7.3/port/venc modules
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=/home/jason/bringup-7.3/port/vdec modules

# 板上
insmod /root/hi_mmz_shim.ko
insmod /root/hi_venc.ko          # VENC
insmod /root/hi_vdec.ko          # VDEC
/root/venc_test 5               # VENC 测试（320x240 NV12）
/root/vdec_test /root/test.h264 # VDEC 测试（NOEOP=1 FASTFEED=1）
```

DTS 必需节点（`hi3798mv300-poc.dts`）：
- `vdec@f8c30000`（6 个中断）
- `venc@f8c80000`（GIC_SPI 101）
- `mmz@28000000`（96MB，VDEC MMZ，线性映射）
- `venc-mmz@34000000`（32MB，VENC 缓冲）

---

## 7. 结论

- **M1 已通过验收**；**M2 功能正确性已证明但未达可用标准**；
  **M4 硬件链路完全打通但缺启动握手**；M3/M5 未开始。
- 硬件加速任务**未完成**。剩余工作的关键路径是：
  1. 解决「硬件真正发起 DMA 后随机硬挂死」的共享底座问题（影响 M2 与 M4）
  2. 逆向/获取 VEDU DDR 配置与启动序列（M4）
  3. 在此基础上推进 M3（V4L2 桥接）与 M5（可选）

---

## 8. 2026-11-04 补充：M2 的最新关键发现

在"冷启动单次解码"复测中发现 `HI_MPI_VDEC_ChanRecvFrm()` **返回成功但填写全零帧**：

```
frames=1   FRAME: 0x0 Y=0x0 st=0 C=0x0 stc=0 Cr=0x0 type=0 pts=0
```

三种喂流策略（`ONE_AU=1` / `N_AU=20` / `PRIME=2`）结果一致。

含义：
1. 测试统计到的 "1 帧" 是**伪成功**，当前实际没有任何有效图像交付
2. 用户态 MPI → 内核 `VFMW_CMD_RECEIVEFRAME` 路径在图像队列为空时可能返回成功码
3. 这是一条**软件返回值语义**问题（硬件链路此前已证明可出真实 1920×1080 帧）

**新增最高优先级待办**：
1. 修正 `ChanRecvFrm` 空队列返回值（必须返回 `HI_ERR_VDEC_BUF_EMPTY` 类错误）
2. 修正后重新评估 vfmw 图像交付（事件 113 `DECSYNTAX_ERR` / 127 `ERR_FRAME`、`NEW_IMAGE` 缺失）
3. 才可进入"≥30fps 无丢帧"的性能验收

同一轮还完成了交付自检：boot 16.7s、服务全部 active、faults=0、
模块 `hi_jpeg.ko`/`hi_mmz_shim.ko`/`hi_vdec.ko`/`hi_venc.ko` 齐全。

---

## 9. 最终状态与后续工作（2026-11-04 收尾）

### 9.1 已交付且可复现

| 项 | 证据 |
|---|---|
| 主系统（Ubuntu 26.04.1 + Linux 7.3.0） | 启动 17.55s，服务全 active，faults=0 |
| M1 JPEG 硬解 | 1080p 5.3ms/189fps，PSNR 66.16 dB |
| M2 VDEC 单帧 1080p | `FRAME: 1920x1080 Y=0x28da9000 C=0x28fc9000`，bit-exact |
| M4 VENC 配置链路 | `cfg_done=1`、`oops=0`、SMMU bypass 生效 |
| 4 个内核模块 + 3 份技术报告 | 见第 6 节与 `docs/porting/` |

### 9.2 未完成项与精确阻塞点

**M2（连续解码）**
- 现象：每次会话只交付 1 帧
- 根因（已坐实）：预编译 vfmw 核不产出后续图像；事件 116(`RESOLUTION_CHANGE`)、
  118(`NEED_ARRANGE`)、121(`ARRANGE_FRAME_BUF`)、122/123 全部缺失；
  `NEW_IMAGE(5)` 从未出现
- 已排除：喂流链路（PUTBM 6 次大块写入正常）、帧缓冲分配（sExtraFrameStoreNum=4 保底）、
  缓冲回收（`release_image` 已正确指向 `VFMW_ReleaseImage`）、协议级别枚举（MPEG≡H264）
- 未验证的最后线索：`VDEC_CID_SET_FRAME_INTF` 在整个移植代码中**从未被调用**
  （厂商可能通过它把"帧由驱动提供"的接口告知 vfmw）；调用参数格式未知，需逆向
  预编译核的 `VDEC_Control` 分支
- 突破路径（按代价排序）：① 逆向 `SET_FRAME_INTF` 参数并调用；
  ② 改走 VPSS 参与的通路；③ 换用 SDK 内 `vfmw_v5.1` 重新适配

**M4（硬件编码出码流）**
- 现象：`CfgReg` 可完成（mode=0）但硬件不启动；mode=1 会启动但总线挂死
- 已坐实根因（7 个，见第 4.2 节）并全部修复
- 剩余缺口：厂商在 DDR 配置模式下的**启动握手序列**
- 突破路径：① 对比 32 位 HAL 的 `CfgReg` 尾部启动序列；② 获取 VEDU 寄存器手册；
  ③ 改用 `venc_v1.0`（纯 C HAL）

### 9.3 建议的接手步骤

1. 先读三份报告（总报告 → M2 → M4）
2. 复现命令见第 6 节；DTS 必需节点清单同节
3. 从 9.2 的"突破路径 ①"开始（各自只需 1-2 天，若环境/手册可得）
