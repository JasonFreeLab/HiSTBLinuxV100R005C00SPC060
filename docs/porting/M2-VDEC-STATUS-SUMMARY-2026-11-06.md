# M2 VDEC 状态总结（2026-11-06）

## 2026-11-06 round51 最终验收（最高优先）

**M2本阶段验收通过。**补齐SCD DownMsg CPU→设备发布：对合法描述符链执行`dc cvac`及`dsb sy`，恢复原厂uncached映射隐含的可见性契约。前三AU同模块可逆off/on/off/on输出为1/3/1/3，non-live boundary为4/0/4/0；异常2136字节PPS仅在off时出现。随后两次全50帧采集（含最终模块独立fresh boot）均为**50/50 NV21像素完全一致、50/50 PTS正确、完整有序**。没有修改packetizer、parser或跨packet边界处理。

补丁提交`caea912`，位于独立诊断仓库`/home/jason/bringup-7.3/port/vdec-m2diag-r2`的`m2/scd-sync-r4`分支。板端最终模块`/root/m2/hi_vdec_downmsg_r51_final.ko`已加载，必须开启`m2_sync_downmsg=1`，并保留`m2_sync_msgs=1,m2_sync_scd=1,vdec_flush_frame=2`，诊断`m2_record=0`。原移植目录未覆盖。

详见[根因、ABAB证据、部署和复现说明](artifacts/venc-reverse/m2-diag/round51-downmsg-fix-acceptance-20261106.md)、[最终逐帧报告](artifacts/venc-reverse/m2-diag/round51/r51-final-full-report.json)。验收范围是当前640×360 H.264测试流；其他编码、多通道和实时吞吐尚未验收。**下文为修复前历史状态，不再代表当前阻塞。**

## 2026-11-06 22:44 接手校正（历史）

Android 目录已找到实际 VFMw/SCD 实现：`/home/jason/bringup-7.3/tools/HiSTBAndroidV600R003C00SPC020/device/hisilicon/bigfish/sdk/source/msp/drv/vfmw/vfmw_v5.0/firmware/product/Hi3798MV200/HD_FULL/{32bit,64bit}/driver/HiSCDV300/scd_drv.S`，以及 OSAL 和 MMZ 源码。**撤回下文“Android SDK只有资料、没有源码”的概括。**这不等于已经确认其与板上原厂固件二进制完全匹配；Android 与 Linux SDK 的结构体/硬件访问版本存在差异，不能直接替换汇编。

新验证：源流 packet0 的三字节 SPS 起始码位于8898，packet1长度6769，差值2129恰等于non-live boundary的越界距离；加正常PPS的7字节得到异常段2136。结合round49变异证据，下一步重点验证SCD DownMsg描述符发布和旧packet尾部的关系。详见 [round50](artifacts/venc-reverse/m2-diag/round50-downmsg-publication-20261106.md)。这仍是机制假设，M2未完成。

## 结论

**M2 尚未通过验收，不能称为稳定可用或已修复。**目标验收是同一码流连续解出50帧，每帧 NV21 像素与参考解码逐字节一致，PTS 序列正确且无缺帧。当前能持续启动 VDEC/VFMw/SCD/VDH 路径，也已验证若干单帧 bit-exact 和缓存交接修正；但最新多为诊断采样，只记录帧数而未保存全帧像素，不能作为通过证据。

最新根因线索已收敛：SCD/UpMsg 在 RawPacket 队列尚未包含对应 packet 时，给出了一个指向 SCD ring 中旧 SPS 字节的 boundary；VFMW 的 `GetRawNumOffset` 会把 exclusive Tail 当作成功的 RawPacket 索引，后续路径没有 live-slot 校验，因而接受该 boundary。SCD 为什么能扫描/报告到此处的旧内容，以及 ring 写入/读出有效范围如何界定，仍未最终解释或修复。

## 已充分验证

| 项目 | 结论 | 证据边界 |
|---|---|---|
| 原厂平台硬件能力 | 同一块 Hi3798MV300 在原厂 Android 播放内置 4K HEVC 流约62–63fps、290/290帧，VDH占用约67%；原厂 2K MPEG2 约29.9fps。 | 证明 SoC/VDH/原厂软件栈可工作；不是对当前 H.264 测试流的逐帧对照。见 [vendor baseline](artifacts/venc-reverse/m2-diag/vendor_hw_decode_baseline.txt)。 |
| 用户 ES 数据交接 | 用户源与 PutBuffer 后内核端样本/hash 对前16个 AU 一致，当前样本未显示用户态 payload 被破坏。 | 不排除后续 SCD/VFMw ring 或设备解析交接问题。见 [round 14 ES 记录](artifacts/venc-reverse/m2-diag/round14-findings-20261106.md)。 |
| VDH 输入消息缓存 | VDH start 前 clean picture/slice 消息具有同启动、可逆 A/B：50 AU 输出2/3帧变为41/42帧；至少首帧与软件参考345600字节完全一致。 | 证明这是主要故障点之一，不证明全序列正确；补丁仍限定特定消息布局。见 [round 3 记录](artifacts/venc-reverse/m2-diag/round3-findings-20261105.md)。 |
| NV21 输出 stride | VFMW 未压缩 stride 使用16-byte单位；Y/C flush 旧长度算法会超出分配。改为按 `y_stride/16` 计算后，flush 范围 guard 有效，像素正确计数改善。 | 这是已修正的独立错误，但不解决剩余损坏/丢帧。历史错误尺寸下的 A/B 已撤回，见交接 §round35。 |
| 原厂 MMZ 页属性 | SDK 的 `HI_DRV_MMZ_Map(cached=0)` 与 `MapCache(cached=1)`走不同页属性；原厂 ARM32 kernel `_mmb_map2kern` 反汇编确认 cached 参数改变 pgprot。 | 当前 port 的 Map/MapCache 被合并为 cached `__va`，SCD payload IVAC 和 VDH 消息 clean 是补偿，不是原厂映射语义的完整恢复。见 [round 21](artifacts/venc-reverse/m2-diag/round21-findings-20261106.md) 与 [round 40](artifacts/venc-reverse/m2-diag/round40-vendor-map-disassembly-20261106.md)。 |
| SCD phantom boundary | non-live RawPacket offset2129 对应的 segment `CheckSegValid` snapshot 是 SPS（`00000167...`）；packet2 后来入队后，同偏移源码为 `dd34d120...` slice 字节，不是 startcode。 | 这是同次运行的 segment 物理地址和 parse-time 字节对齐，不是 teardown 后物理读数。见 [round 46](artifacts/venc-reverse/m2-diag/round46-nonlive-boundary-bytes-20261106.md)。 |
| `WriteScdMsg` 输入 descriptor | 目标 64-bit SCD 汇编按 RawPacket Length 和 DownMsg 剩余容量构造 descriptor；未发现把源 packet 长度向上取整的越读。 | 不能据此排除硬件 scan pointer、UpMsg count、SCD ring writer/read pointer 错误。zero word 是 descriptor-list terminator，不是 stream byte terminator。详见 round46、round48。 |

另有历史单帧 320×240 和 1080p bit-exact 样例；完整的逐帧证据以 round4 等对应日志为准。曾有单次输出50帧的运行，但开启全帧比较后仅39帧像素完全正确。因此**帧数、`capture_errors=0`、偶发 `err_mbs=0` 均不等同验收通过**。

## 当前阻塞

1. **SCD/UpMsg 产生了超出当前有效 RawPacket 的边界。**round48 同次采样：PPS 属于 raw_idx1，长度6769，包内 offset6762 只剩7字节；segment 长2136字节，跨出2129字节。该时刻 RawArray 为 `Head=1,Tail=2`，slot2 尚未入队。
2. **错误边界实际指向 stale ring SPS。**SCD segment phys `0x28ad62cf` 保存 SPS 字节；稍后 packet2 注册后，同偏移源码是 slice payload。SCDREG 采样在 boundary 前已记录两次配置：最新 pre-write `BufferIni=0x28ad400f`；下一配置 `BufferIni=0x28ad62f0` 正好位于 SPS+PPS 33字节之后。`BufferFirst=0x28ad4000`、`BufferLast=0x28da81f0` 跨整个约2.966MB ring。
3. **消费者会接受 Tail 索引。**汇编 `GetRawNumOffset` 走到 exclusive Tail 时仍返回成功和 Tail 索引/余数；`GetSegPts` 与 `ProcessNotMpeg4ScdUpMsg` 不验证该slot是否 live，仍插入 boundary/segment。这是明确的放大条件，但单独丢弃它可能破坏合法跨packet NAL，不能未经验证直接改。
4. **硬件有效输入上界语义未知。**SCDREG hook记录的是 `WriteScdVtrlReg` 写 MMIO 前的 `SM_CTRLREG_S` 参数，不是寄存器读回。当前不知道 `BufferLast` 是循环分配边界还是硬件有效数据边界，也没有确认 `BufferIni` 与有效写入尾的关系。
5. **PTS 和序列完整性未闭环。**`Pts=UINT64_MAX` 是重复抑制，`RawPts` 仍保留；下游实际选择哪个字段、PTS 偏移/缺失的完整因果尚未定位。也未取得最终50帧全像素与PTS序列报告。

## 当前路线

当前不是重写解码器，而是在 Linux 7.3/AArch64 上保留厂商 VDEC/VFMw 分层，用原厂 ground truth 和二进制反汇编逐层对齐：

1. 用户态 `vdec_test` 通过 Hisi MPI Buffer API 喂 H.264 AU。
2. `hi_vdec.ko` + `hi_mmz_shim.ko` 提供 VDEC ioctl、ES/帧缓冲与 MMZ 适配。
3. VDEC v2.0 C 路径与 VFMw v5.0 SCD/VFW parser、VDH HAL/汇编处理 raw descriptors、SCD UpMsg、slice/picture messages 和 NV21 输出。
4. 已验证的缓存补偿：VDH picture/slice message 在启动前 clean，SCD 设备写 segment 后 IVAC；输出帧 flush 按正确 stride 做。当前稳定板态通常为 `vdec_flush_frame=2`、`vdec_flush_put=1`、`m2_sync_msgs=Y`、`m2_sync_scd=Y`，诊断关闭。
5. 目前的下一步不是参数扫描，而是用 SCD 的 `WriteScdMsg`、`WriteScdVtrlReg`、`ReadScdStateReg` 和设备 ring 的 read/write/valid-end 时序解释 phantom SPS，再设计可 defer/validate 的修复；保留合法跨packet NAL。

## 与原厂实现的差异

| 层 | 原厂固件（已观察/可证） | 当前 Ubuntu port（已检查） |
|---|---|---|
| OS/ABI | Linux 3.18.24、ARM32；运行在原厂 Android 镜像及其服务/播放器环境。 | Linux 7.3、AArch64；以可加载的 port module、OSAL 适配和测试程序驱动。原厂 ARM32 `.ko`/闭源核不能直接加载到此内核。 |
| VDEC/VFMw 版本 | 原厂 channel 显示 VFMw `HiVDHFMWV500R001-TAG02-C01`；目标固件对应 Android SDK 没有找到源码。 | 当前 `vdec/Makefile` 选 VDEC v2.0；SDK `vfmw_v5.0` 的 MV300 build 映射到 `Hi3798MV200` product 配置，并按 arm64 选择64-bit `.S`。port `.S` 与仓库该64-bit SDK `.S` 的差异主要为 `_mcount`/诊断 hook；这不等于已证明它与原厂 ARM32 binary 等价。 |
| 内存属性 | `HI_DRV_VDEC_Map`/`HI_DRV_MMZ_Map(cached=0)`是 WC/非普通WB映射，`MapCache` 是 cached；SCD detail buffer 使用前者。 | `Map` 与 `MapCache` 都返回 cached `__va`；为维持设备/CPU可见性使用 payload IVAC、消息 clean 等显式补偿。整区 WC 会破坏用户 ES 映射，per-buffer WC 也尚未证明更优。 |
| SCD/VDH 数据交换 | 原厂在其 ARM32 vfmw、MMZ、SCD/VDEC callback 和中断时序内工作；观察到 `IsOmxPath=0` 的实际播放正常。 | 保留厂商 MPI/VFMw 架构，但 raw source、SCD ring、UpMsg解析、VDH command/fb cache ownership 与原平台衔接必须由 port 重建。现有错误 boundary 与 stale SPS 证明至少一处契约/有效范围未复原。 |
| 用户/显示栈 | Android vendor player 与 OEM 系统组件；本次健康基准有内置 MPEG2/HEVC 流。 | Ubuntu 用户态测试直接走 MPI Buffer API，没有完整 OEM Android user stack；不是 V4L2 stateless，也不是原厂播放器工作环境的复制。 |

注意：原厂 ground truth 是**原厂内置 MPEG2/4K HEVC流**；没有与当前 `gen3_idr.h264` 同内容的原厂 H.264 逐帧 A/B。因此它证明原厂栈及硬件健康，不证明当前同一H.264在原厂已通过。

## 为什么不能直接采用原厂路线

- **目标不同**：若只需机顶盒硬解，刷回原厂 Android 并使用厂商播放器可以；本 M2 目标是让 Ubuntu/mainline Linux 7.3 获得硬件解码，换回原厂系统不符合交付目标。
- **二进制不兼容**：原厂内核/媒体核是 ARM32 Linux 3.18，当前是 AArch64 Linux 7.3；原厂预编译 VDEC/VFMw 对内核 API、ABI、IRQ、MMZ/ION、设备树和板级地址的依赖不同，不能把原厂模块/库直接插入当前系统。
- **精确源代码不可得**：版本匹配的 Android SDK 包仅有客户文档/原理图等；`Hi3798MV300` SDK目录主要是sysreg资料。仓库能提供共享 VDEC v2.0/VFMw v5.0 代码作移植参考，但不是原厂 kernel binary 的完整可重建源码和配置。
- **必须跨平台复现语义**：VDEC ioctl/MPI、MMZ映射属性、SCD数据供给/边界、设备中断与缓存所有权都需适配 Linux7.3/AArch64。直接移植原厂 binary 不仅架构不匹配，也无法解决 mainline 下物理内存/设备映射接口的差异。

所以原厂路线作为**运行基准和二进制反汇编参考**，不是可直接移植的实现包。当前使用的共享 SDK 源码必须逐项与原厂行为比对，不能因为同属 VFMw 5.0 就认为 target-specific 32-bit binary 已完全还原。

## 原厂实现仍未还原的部分

1. 原厂 VDEC/VFMw ARM32 binary 的完整函数/调用顺序、配置宏、链接版本，以及与当前 arm64 SCD/VFW 代码的逐函数等价性。
2. 原厂 SCD `BufferFirst/BufferLast/BufferIni` 的硬件语义，真正的有效输入/写入尾、roll条件、SCD `StartCodeNum`/`UpMsgLenInWord` 的更新与清除时序。当前记录的寄存器值只是软件写前结构值，尚无硬件 readback。
3. 原厂 SCD detail/segment buffer、DownMsg、UpMsg、VDH消息和帧缓冲在每次分配中的最终页属性与cache ownership。`_mmb_map2kern` 证明cached参数分支，但全套 per-buffer mapping 生命周期尚未恢复。
4. RawPacket head/tail/History、`GetRawNumOffset` 对 Tail 的返回契约，以及上游可能跨packet的合法NAL如何延迟/拼接。当前发现了 Tail 伪boundary被接受，但不能单点加drop/clamp。
5. VDEC/VPSS/OMX与BM/demux具体消费模式、帧释放顺序、PTS/RawPts采用者；运行时是否与原厂每个 callback 顺序相同尚未证明。
6. 以干净采集方式得到50帧逐帧 Y/VU 像素及 PTS 完全匹配的验收报告。

## 接手建议

1. 保持现有稳定设置，不改变 H.264 packetizer、不截短 segment、不改parser。
2. 在 SCD `WriteScdMsg` 完成、硬件启动前记录实际 DownMsg descriptor（地址、每段长度、 terminator）；同时记录 `BufferFirst/Last/Ini` 写入值及寄存器读回、当前 SCD input valid/write pointer。
3. 在 ISR 中记录 `StartCodeNum`、`UpMsgLenInWord`、SrcEaten/roll/read position，并与 SCD ring snapshot、当前 RawPacket live range 对齐，确定哪一层先产生 phantom SPS。
4. 只针对确认的一个契约差异建立红/绿测试或板端判据，再改 defer/valid-end handling；必须保留合法跨packet NAL。
5. 最后用独立 fresh boot/干净输出采集，对50帧全部逐帧比像素和PTS；不能用帧数代替质量。

诊断工具近期提交：`0f8bc85`（RawPacket queue window）、`70439e3`（所有segment现场快照）、`7b4ec6d`（SCD bounds/register correlation）。最近全量单测15/15通过，内核模块构建exit0；板上记录参数为 `m2_record=0`，SCD IVAC及VDH消息clean保持开启。