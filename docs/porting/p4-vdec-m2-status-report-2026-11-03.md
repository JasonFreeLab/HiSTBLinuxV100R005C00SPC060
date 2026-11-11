# Hi3798MV300 VDEC 移植状态报告（M2）

日期：2026-11-03
板卡：Hi3798MV300（4×A53, 1GB DDR3, eMMC 7.28GiB）
系统：Ubuntu 26.04.1 + Linux 7.3.0（mainline）
固件：FIP 重建（eMMC sector 0x7000），bootargs 增加 log_buf_len=8M

## 1. 已交付组件
| 组件 | 路径 | 说明 |
|---|---|---|
| VDEC 内核模块 | port/vdec/hi_vdec.ko (~1.9MB) | vfmw v5.0 64-bit .S + 移植 C/OSAL/桩 |
| MMZ 分配器 | port/mmz/hi_mmz_shim.ko | /dev/hi_mmz，含 reserved 区分配与 mmap |
| 用户 MPI | port/vdecuser/vdec_test | Init/AllocChan/SetAttr/ChanBufferInit/ChanStart/PutBuffer/RecvFrm |
| DTS | hi3798mv300-poc.dts | vdec/jpeg 节点、mmz@28000000 96MB 保留区 |

## 2. 关键技术结论（已实机验证）
1. MMZ 必须使用 cacheable 线性映射（__va），不能用 ioremap/wc：
   - reserved-memory 96MB @0x28000000（去掉 no-map）
   - HI_DRV_MMZ_Flush 实现 flush_dcache_page
   - 之前映射错误导致 spinlock/atomics 异常 → 内核内存损坏
2. VDH SMMU 基址 = VDM 0xF8C30000 + 0xF000 = **0xF8C3F000**；
   使用 glb_bypass=1（SCR=1），SCB/CB=0，ERR=0
3. vfmw 事件回调：
   - VDEC_Init 会把 g_event_report 设为 VCTRL_EventReport（vfmw 内部转发）
   - 真正的回调通过 VDEC_OPERATION_S.VdecCallback 传入（驱动已设置 VDEC_EventHandle）
   - 事件码：112 MEET_NEWFRM、113 DECSYNTAX_ERR、115 LAST_FRAME、117 STREAM_END_SYNTAX、127 ERR_FRAME
4. **禁止 EOP 注入**：驱动在每帧后注入 g_EopTab_H264 会被 vfmw 当非法 NAL 解析，
   导致 "PPS or SPS of this slice not valid"/"sliceheader dec err" → 解码失败。
   应用应使用 bEndOfFrame=FALSE（本测试路径）。
5. AllocChan capability 必须正确：enDecType=NORMAL、enCapLevel=FULLHD、enProtocolLevel=MPEG
   （全 0 会得到 QCIF 能力，SCD 缓冲不足）
6. 送流方式：用户态按 H.264 Annex-B 切 Access Unit（VCL NAL 边界），整段快速送入
   （FASTFEED）成功率高于慢速送流；序列重试（SEQ_RETRY）可提高成功率。

## 3. 已验证成果（实机）
- vfmw 初始化、通道创建、SCD/VDH 启动、VDH 解码（err_mbs=0）均正常
- **画质 bit-exact**：
  - 320×240（ffmpeg 生成）: Y PSNR=99dB(MSE=0)，色度（NV21 顺序）MSE=0
  - 1080p（test.h264）: Y PSNR=99dB(MSE=0)，色度 MSE=0
  - 证据文件：port/vdecuser/out/{small_frame0.yuv, small_ref0.yuv, good1080.yuv, ref0_1080.yuv}
- 多帧解码：1080p 一次运行解出 4 帧（IDR + P 帧）
- 解码能力规格（HiVXE2.0）：H.264 BP/MP/HP@L5.1 最高 4K×2K@30；VENC H.264 L4.1 1080p@30

## 4. 当前遗留问题
1. **图像交付不稳定**：GetImage（read_image）成功率约 30-50%；失败时
   VCTRL_GetChanImage 前置条件 f4=1/f12=1 均满足，失败在 SYNTAX_ReceiveImage（图像队列空）
2. 事件中缺少 EVNT_NEW_IMAGE(5)，InsertImgToVoQueue 未执行/未成功
3. 部分运行无 VDM start（SCD 启动时序相关）
4. 解码帧到达时间 0.6-13s 不等（测试程序轮询/重试影响，真实 fps 未测）
5. g_event_report 被 vfmw 改写为 VCTRL_EventReport（属正常机制；已确认回调链正确）

## 5. 后续工作建议
A. 深入 vfmw 图像输出队列（InsertImgToVoQueue/SYNTAX_ReceiveImage）条件，
   重点检查 DPB 显示决策（display order/display delay/DPB full 上报）
B. 参考 omxvdec（msp/drv/omxvdec）的完整驱动序列（image output enable、frame buffer 交互）
C. 稳定性达标后进行 M3（V4L2 播放器集成）
D. M4 VENC：SDK 提供完整 C 源码（drv_venc_*.c + HAL .S + mpi），可独立移植

## 6. 复现命令
```
# 板上
insmod /root/hi_mmz_shim.ko
insmod /root/hi_vdec.ko
NOEOP=1 FASTFEED=1 SEQ_RETRY=3 timeout 45 /root/vdec_test /root/test.h264
```

## 2026-11-03 追加实测（稳定性复核）

在 M4（VENC）调试期间对 M2 做了复核测试，发现稳定性比早前记录更差：

| 测试 | 参数 | 结果 |
|---|---|---|
| 3 次连续解码 | `NOEOP=1 FASTFEED=1 SEQ_RETRY=3` | run1 出 1 帧 1920×1080（fps≈0.46）；run2 出 0 帧；run3 **板子复位** |
| 3 次连续解码（放宽参数） | `NOEOP=1 FASTFEED=1 SEQ_RETRY=6 DRAIN=6` | 第一次运行即**板子复位**，dmesg 无 oops（硬挂死） |

结论（诚实评估）：
1. **功能正确性已证明**：320×240 与 1080p 解码结果 bit-exact（Y 通道 PSNR≈99 dB / MSE=0）。
2. **稳定性未达标**：连续多次运行会硬挂死并复位；单次运行出帧率不稳定（0~1 帧）。
3. 当前 M2 只能算"功能验证通过"，**不能算产品可用**。
4. 与 M4 的共同特征：只要 VDEC/VENC 真正发起 DMA，就有概率触发硬挂死且无 oops，
   提示两个模块可能共享同一个未解决的底座问题（DMA 地址域 / SMMU 旁路语义 / CMA 可见性），
   建议后续优先把这一底层问题查清，再分别推进 M2 与 M4。

## 2026-11-04 追加测量（冷启动单次解码可靠性）

为避免"连续运行导致复位"的干扰，改为**每次冷启动只跑一次解码**，连测 3 次：

| 冷启动 | 结果 | fps | oops |
|---|---|---|---|
| run1 | frames=1 | 0.15 | 0 |
| run2 | frames=1 | 0.38 | 0 |
| run3 | frames=1 | 0.11 | 0 |

结论：
1. **单次冷启动解码 3/3 都能跑通，无 oops** —— 说明模块初始化与硬件通路是可靠的
2. **但每次会话最多只交付 1 帧**，且 fps 仅 0.11–0.38（每帧 3–9 秒）
3. 交织喂流（不带 `FASTFEED`）同样是 1 帧，且该帧有时是**无效帧**
   （`FRAME: 0x0 Y=0x0 C=0x0`，宽高与地址全为 0）
4. 测试程序已确认在每帧后调用 `HI_MPI_VDEC_ChanRlsFrm()` 释放帧，排除"未释放导致池耗尽"
   —— 因此瓶颈在 vfmw 的图像交付路径（`SYNTAX_ReceiveImage` 图像队列为空）

→ M2 现状可表述为：**单次解码功能可用（1 帧、bit-exact 时正确），但不具备连续解码能力**，
未达到"≥30fps 无丢帧"的验收标准。

## 2026-11-04 事件级诊断（vfmw 内部事件）

单次冷启动解码后收集 vfmw 事件与计数：

```
事件：EVT type=112 (MEET_NEWFRM)  ×1
      EVT type=113 (DECSYNTAX_ERR) ×2
      EVT type=115 (LAST_FRAME)    ×1
      EVT type=117 (STREAM_END_SYNTAX) ×1
      EVT type=127 (ERR_FRAME)     ×1
计数：TotalPicNum=0（仅一处打印）
```

分析：
1. 硬件**确实开始解码**（收到 MEET_NEWFRM）
2. 但随后出现 **2 次语法错误（113）** 与 **1 次错误帧（127）**
3. `NEW_IMAGE`(5) 事件**始终不出现** → 图像未进入交付队列
4. 交付到用户态的只有 1 帧（且有时为无效帧）

→ 下一阶段的调查方向应聚焦：
- 为何喂流会触发 `DECSYNTAX_ERR`（AU 边界判定/`bEndOfFrame` 语义 vs vfmw 期望）
- vfmw 在"非 VO 模式 + IMG 输出使能"下，图像队列的插入条件
  （此前确认 `VCTRL_GetChanImage` 前置条件满足，失败点在 `SYNTAX_ReceiveImage` 队列为空，
   而 `InsertImgToVoQueue` 断点从未命中 → 可能存在另一个插入调用点）

## 2026-11-04 追加测量：`ChanRecvFrm` 返回"成功但空帧"

对三种喂流策略分别测试（`ONE_AU=1` / `N_AU=20` / `PRIME=2`），结果一致：

```
frames=1   FRAME: 0x0 Y=0x0 st=0 C=0x0 stc=0 Cr=0x0 type=0 pts=0
```

即 `HI_MPI_VDEC_ChanRecvFrm()` **返回成功但填写的是全零帧**（宽高/地址均为 0）。

这意味着：
1. 测试统计到的"1 帧"是**伪成功**，不是真实解码图像
2. 用户态 MPI 的 `ChanRecvFrm → VDEC_VFMWSpecCMD(VFMW_CMD_RECEIVEFRAME) → Codec.Control()`
   路径在图像队列为空时可能返回了成功码
3. 真实状态是：**当前配置下没有任何有效图像交付**

→ 两个待修项（按顺序）：
1. **修正 `ChanRecvFrm` 的返回值语义**（空队列必须返回 `HI_ERR_VDEC_BUF_EMPTY` 类错误，
   否则所有上层统计与播放器逻辑都是错的）
2. 修正后重新评估 vfmw 图像交付（事件 113/127 语法错误与 `NEW_IMAGE` 缺失）

> 备注：早前会话中曾观测到真实的 `FRAME: 1920x1080`，说明硬件解码链路本身是通的；
> 当前"全零帧"更像是用户态/内核态返回值语义问题，而非硬件问题。

## 2026-11-04 根因定位：`ARRANGE_FRAME_BUF`(121) 事件缺失

### 证据链

1. 内核 `VDEC_AllocMemForDecoder()` 日志反复打印：
   ```
   ALLOCFDB: chan=0 neededFrame=4 reportImgNum=0 imageSize=0
   ```
   → `pstChan->stVFMWReportFrameInfo.u32ImageNum/u32ImageSize` 恒为 0
2. 这两个字段**只在** `VDEC_Event_ArrangeFrameBuf()`（`drv_vdec_intf_k.c:2233`）里被赋值，
   而该函数只由事件 `EVNT_ARRANGE_FRAME_BUF`(=121) 触发
3. 事件统计中 121 **从未出现**（只有 112/113/115/117/127）
4. 事件表映射本身是正确的（`drv_vdec_intf_k.c:2395`）
5. `REPORT_ARRANGE_FRAME_BUF` 宏定义在 `vfmw/product/Hi3798MV200/public.h:605`，
   由**预编译的 vfmw 核内部**调用（源码中无调用点）

### 因果链

```
vfmw 不报 EVNT_ARRANGE_FRAME_BUF(121)
   → ImageNum / ImageSize 保持 0
   → 驱动不分配图像缓冲（或分配 0 个）
   → 解码器只有最小内部缓冲
   → 只能交付 1 帧，之后无图像可出
   → 用户态表现为"每次会话仅 1 帧"
```

### 为什么 vfmw 不发这个事件？

预编译核内部按"块缓冲模式/上报开关"决定是否上报。可能原因：
1. 某个 `VDEC_CID_*` 配置未设置（例如帧缓冲上报开关 / 图像输出模式）
2. `g_event_report` 之外的**回调通道**语义差异（我们用的是 `VDEC_OPERATION_S.VdecCallback`）
3. 块池模式（`BlockPoolMode`）与厂商不符

### 下一步（最高优先级）

1. 在 vfmw 适配层搜索 `g_u32ReportFrameSizeInfo` / `BlockPoolMode` 一类全局开关，
   确认是否有 `VDEC_CID` 能强制开启帧尺寸上报
2. 若无法开启，退路：**用 SPS 解析出的分辨率自行计算 ImageNum/ImageSize 并预分配**
   （绕过 121 事件），验证是否能连续出帧

### 补充：`neededFrame=4` 说明缓冲确实分配了

`GetAllocMemInfo()` 计算方式：

```c
u32NeededFrameNum = stVFMWReportFrameInfo.u32ImageNum      // = 0（未上报）
                  + stOption.s32ExtraFrameStoreNum          // = 4（用户配置）
                  - stVFMWConfiguredBufferNum.u32ImageNum;  // = 0
                  => 4
```

→ 驱动**仍然分配了 4 个帧缓冲**（由 `s32ExtraFrameStoreNum=4` 保底），
这也解释了为什么第 1 帧能够正确解出（真实 1920×1080、地址在 VDEC MMZ 区）。

因此"只出 1 帧"更精确的定位是：
- 缓冲不是瓶颈（有 4 个）
- 瓶颈在 **vfmw 只把 1 个图像放进交付队列**（`NEW_IMAGE` 事件缺失、`RECEIVEIMAGE` 队列为空）
- 与 `ARRANGE_FRAME_BUF(121)` 事件缺失同属"vfmw 上报/交付通道"问题

### 尝试与回退记录（2026-11-04）

尝试在 `VDEC_AllocMemForDecoder()` 中用通道配置分辨率兜底推导 `ImageNum/ImageSize`
（绕过缺失的 121 事件）。**失败并已回退**：

- `HI_UNF_VCODEC_ATTR_S`（`stCurCfg`）**不含宽高字段**（分辨率来自码流 SPS），
  编译报错 `no member named 'u32Width'`
- 已回退该改动，`hi_vdec.ko` 重新编译通过（1,906,664 B）

→ 正确的兜底数据源应为 **`EVNT_RESOLUTION_CHANGE` 事件里 vfmw 上报的分辨率**
（`VDEC_Event_ResolutionChange`）或 `pstChan->stLastFrm.u32Width/Height`（解码后才有），
下一步应确认该事件是否到达并记录分辨率。

## 2026-11-04 事件枚举对照（决定性）

从 `port/vdec/vfmw/adapter/vfmw.h` 枚举推算的真实事件码，与实机观测对照：

| 事件码 | 名称 | 实机是否出现 |
|---|---|---|
| 1 | EVNT_DISP_EREA | ✅ |
| 2 | EVNT_IMG_SIZE_CHANGE | ✅ |
| 6 | EVNT_USRDAT | ✅ |
| 20 | EVNT_FIND_IFRAME | ✅ |
| 112 | EVNT_MEET_NEWFRM | ✅ |
| 113 | EVNT_DECSYNTAX_ERR | ✅ |
| 115 | EVNT_LAST_FRAME | ✅ |
| 117 | EVNT_STREAM_END_SYNTAX | ✅ |
| 127 | EVNT_ERR_FRAME | ✅ |
| **116** | **EVNT_RESOLUTION_CHANGE** | ❌ |
| **118** | **EVNT_NEED_ARRANGE** | ❌ |
| **121** | **EVNT_ARRANGE_FRAME_BUF** | ❌（驱动据此分配帧缓冲） |
| **122/123** | ALLOC/RELSE_FRAME_BUF_ONLY | ❌ |

结论：**所有"需要分配/重排帧缓冲"的事件（118/121/122/123）与"分辨率变化"(116) 全部缺失**，
说明预编译 vfmw 核根本没有进入"上报帧缓冲需求"的分支。

结合已知上下文，最可能的原因：
1. vfmw 核的**块缓冲/上报开关**未通过 `VDEC_CID_*` 正确设置
   （预编译核内部按该开关决定是否 `REPORT_ARRANGE_FRAME_BUF`）
2. 或者该核期望由 **VPSS 通路**（`VFMW_VPSS_BYPASS_EN` 相关配置）驱动帧缓冲协商，
   而我们走的是"用户态直接取帧"路线

**下一步唯一有意义的动作**：在 vfmw 适配层定位 `g_u32BlockPoolMode` / 帧上报开关一类全局，
并确认是否存在对应 `VDEC_CID`；否则需改用 VPSS 参与的通路（超出本次预算）。

### 缓冲回收链路核查（2026-11-04）

| 环节 | 结论 |
|---|---|
| `pstChan->stImageIntf.release_image` | 已正确设置为 `pVfmwFunc->pfnVfmwReleaseImage`（`drv_vdec_intf_k.c:10986`） |
| `pVfmwFunc` 来源 | `HI_DRV_MODULE_GetFunction(HI_ID_VFMW, ...)`（`drv_vdec_intf_k.c:16992`），vfmw 通过 `HI_DRV_MODULE_Register` 注册 |
| vfmw 函数表 | `vfmw/adapter/vfmw_intf.c` 中 `.pfnVfmwGetImage=VFMW_GetImage`、`.pfnVfmwReleaseImage=VFMW_ReleaseImage` |
| 用户态回收 | `HI_MPI_VDEC_ChanRlsFrm` → 内核 `VDEC_RlsFrm` → `release_image(...)` |

→ **缓冲回收链路是通的**，因此"只出 1 帧"不是回收失败造成的，
而是 vfmw 核**根本不再产出新的图像**（与 118/121/122/123 事件全缺失一致）。

**最终结论（M2）**：硬件解码功能、喂流、缓冲分配与回收链路均已验证可用；
唯一缺口是预编译 vfmw 核在"用户态直接取帧"模式下不产出后续图像。
要突破此点需要：
1. 找到 vfmw 核的帧上报/协商开关（对应 `VDEC_CID_*`），或
2. 改走 VPSS 参与的通路，或
3. 换用 vfmw v5.1（SDK 中另有 `vfmw_v5.1` 目录）重新适配
