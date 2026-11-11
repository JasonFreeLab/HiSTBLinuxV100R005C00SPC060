# M2 · VDEC 硬件加速 — 详细交接文档（2026-11-05）

> **2026-11-06 round51 最终验收通过（覆盖下文所有旧状态）**：SCD DownMsg缓冲请求uncached，但port默认映射为WB，缺少CPU写描述符到设备读的发布交接。新增启动前合法描述符链`dc cvac`+`dsb sy`，同模块off/on/off/on前三AU输出1/3/1/3，non-live边界4/0/4/0；2136字节长PPS只在off时出现。两次完整50帧像素/PTS验收均50/50、序列0..49完整，第二次使用最终模块独立fresh boot。补丁`caea912`在独立诊断仓库`/home/jason/bringup-7.3/port/vdec-m2diag-r2`，板端`/root/m2/hi_vdec_downmsg_r51_final.ko`已加载；**必须启用`m2_sync_downmsg=1`**，保留VDH消息clean、SCD payload IVAC和正确输出stride flush。诊断`m2_record=0`。原移植目录未覆盖，其他编码/多通道/吞吐尚未验收。详见[round51完整证据及复现](artifacts/venc-reverse/m2-diag/round51-downmsg-fix-acceptance-20261106.md)和[最终逐帧报告](artifacts/venc-reverse/m2-diag/round51/r51-final-full-report.json)。Android树已找到实际SCD/OSAL/MMZ实现，旧“无源码”概括撤回。无需继续旧H1/H2、ring valid-end扫描或PPS截短实验。

> 本文写给**下一个会话的执行者**：读完这一份即可无缝接手，不必重读全部历史。
> 历史细节在 `HANDOFF-hardware-acceleration-2026-11-04.md` §4.1–§4.94 与
> `artifacts/venc-reverse/m2-diag/`（原交接时 91 个证据文件）。
>
> **2026-11-06 round 49 最新进展（最高优先）**：见 [round49 packet-tail provenance](artifacts/venc-reverse/m2-diag/round49-packet-tail-provenance-20261106.md)。同一 fresh boot/同一模块连续跑 baseline 与仅改 IDR0 一个字节的码流；legacy AU0为`[0,8933)`、含IDR0，AU1为`[8933,15702)`且PPS2的RawPts=1；长PPS现场快照第8字节随AU0/IDR0 offset6769的单字节变异从`c5`同步变`c4`，尾57字节各自精确匹配相应AU0 IDR0。**强证据表明 packet0 IDR数据会出现在随后 packet1 PPS segment长尾**，支持当前流中的跨packet buffer extent/alias；不是与本次流无关的旧boot残留。两轮长PPS记录地址不同，样本在 `CheckSegValid` 时按slot复制；环dump计数320、基线记录完后变异run slot158采到变异字节，尾部57字节分别只匹配各自流的AU0 IDR绝对offset6769。暂停VDEC teardown 30秒期间物理地址仍被producer复用，因此必须用`CheckSegValid` slot snapshot作时间关联，物理after-read不可替代。尚未从 RawPacket/segment 物理坐标确认alias/跨界机制。新增快照工具提交`f1493cb`，8项单元测试和模块/用户态构建通过。Round45 已采 `GetSegPts` 实际选中RawPacket指针与queue head/tail：长PPS时Head=1,Tail=2，仅slot1 live；offset6762+len2136超packet1长度6769 2129字节。紧接着SCD boundary映射到raw_idx2，但此时slot2位于exclusive Tail之外且descriptor为空；稍后queue推进至Head=2,Tail=3，slot2才注册。确认VFMW在raw packet进入live queue前就处理了越界UpMsg boundary/长PPS segment；packet2注册后该boundary对应的packet2 offset 2129源码为`dd34d1...` slice bytes，并非startcode。segment存储池与ES pool不同，这不是CPU物理PA直接越界，而是逻辑stream区间越过当前live packet。静态控制流显示`GetRawNumOffset`遍历到Tail仍成功返回Tail slot+残余offset，`GetSegPts`和`ProcessNotMpeg4ScdUpMsg`均不拒绝非live slot，消费者侧缺少队列边界校验已确认。详见 [round45 raw/segment range](artifacts/venc-reverse/m2-diag/round45-rawpacket-segment-range-20261106.md)。接下来仍需查SCD为何报告packet尾之后的startcode，同时设计如何保留跨packet合法NAL而只拒绝越界伪boundary；不直接截短segment。Round42前缀AU分组实验板端变差，维持legacy默认。PTS双字段已校正：`Pts=UINT64_MAX`时`RawPts`仍保留，下游实际消费哪个字段和像素因果未证实。
>
> **2026-11-06 round46 latest SCD boundary evidence**：见 [round46 non-live boundary snapshot](artifacts/venc-reverse/m2-diag/round46-nonlive-boundary-bytes-20261106.md)。新鲜legacy采样把`raw_idx=2, packet_off=2129, Head=1,Tail=2`的UpMsg boundary join到 `seg_phys=0x28ad7d5d` 的parse-time bytes snapshot，内容为 `00000167...` SPS；该packet2之后注册，offset2129源码实际是 `dd34d120...` slice payload。已确认SCD/UpMsg提供了指向SCD ring内SPS内容的non-live伪边界；consumer无live-slot检查会接受它，长PPS被扩成2136字节。**首个输入/UpMsg内容分歧定位到SCD boundary generation/ring write-limit，同目标`WriteScdMsg`按RawPacket descriptor Length和DownMsg剩余容量限制源数据量，未见源packet长度round-up；末尾zero word是descriptor terminator，不是stream end marker。`SCDDRV_SaveRawStream`通过OSAL FileWrite把raw stream dump到可选日志文件，不是SCD ring写入。所以上游重点转为`SCDDRV_StartSCD`中BufferFirst/Last/Ini的实际值/语义、SCD input/segment ring的读写pointer，以及`ReadScdStateReg`返回的UpMsgLen/StartCodeNum是否越过valid data tail；还不能在hardware scan boundary与ring pointer管理间定因。** Consumer guard 是放大条件，不要直接丢弃所有跨packet segment。Round47–48新增寄存器ring：false boundary当时已记录2次SCD register写，最新ini=`0x28ad400f`，false SPS位于`0x28ad62cf`；下一次ini=`0x28ad62f0`恰好在SPS+PPS的33字节之后。`BufferFirst/Last`待写值为全2.966MB ring范围（不是MMIO读回）；valid-write-end语义仍未查明。对应rawmap row附`scdreg_count`字段，诊断提交`7b4ec6d`；单测15项、模块构建exit0。hook采样的是MMIO写前SM_CTRLREG_S入参，不是hardware readback。
>
> **2026-11-06 round 40 进展**：见 [round 40 原厂内核反汇编](artifacts/venc-reverse/m2-diag/round40-vendor-map-disassembly-20261106.md)。已用原厂 ARM32 objdump 直接反汇编 `_mmb_map2kern`，确认 `cached=0` 改变 page protection。
>
> **2026-11-06 round 39 进展**：见 [round 39 输出 cache A/B](artifacts/venc-reverse/m2-diag/round39-findings-20261106.md)。在正确 Y/C flush 长度下，同启动 IVAC/CIVAC/IVAC/CIVAC 的像素正确帧数为39/39/42/37，PTS同时正确37/39/42/37；IVAC均值略优但差距小、仍有波动。继续保留 `vdec_flush_frame=2`，不能称作最终修复。板子参数 `vdec_flush_frame=2,m2_sync_msgs=1,m2_sync_scd=1,m2_record=0,vdec_frame_map_probe=0`。
>
> **2026-11-06 round 35 进展**：见 [round 35 帧 flush 记录](artifacts/venc-reverse/m2-diag/round35-findings-20261106.md)。确认输出帧 flush 长度单位错误：未压缩 NV21 硬件 stride 是16-byte单位，旧代码未除16，Y/C请求超出446KB allocation、被范围guard跳过。现按 `y_stride/16` 计算Y/C字节stride，FRMAP 16对范围全部有效，像素正确数40→42。**撤回 round28/33 的输出flush CIVAC/IVAC结论**：那些A/B运行时flush范围越界、实际 `va=NULL`，并未执行缓存操作。正确范围下IVAC优于CIVAC，`vdec_flush_frame` 默认设为2（IVAC-only），板上当前2；payload IVAC和VDH message clean均开启。round36平面分析显示残余VU错帧分两类：PTS9/47少量字节差（MSE≈0.48），PTS12/13/44大面积色度差（MSE≈208–241），UV swap不匹配；下一步查VDH的UV写入/重建路径，不再改flush长度。全帧验收尚未完成。
>
> **2026-11-06 round 33 进展（已撤回）**：见 [round 33 记录](artifacts/venc-reverse/m2-diag/round33-findings-20261106.md)。当时输出 flush 请求范围超出MMZ allocation，被安全 guard 跳过（`va=NULL`），所以该IVAC/CIVAC A/B并未真正执行，结论作废；以 round35 正确边界实验为准。
>
> **2026-11-06 round 28 进展（已撤回）**：见 [round 28 记录](artifacts/venc-reverse/m2-diag/round28-findings-20261106.md)。当时使用了错误的 Y/C flush 尺寸且范围 guard 未执行实际 cache op；该 A/B 不能用于排除输出 cache flush 问题。正确尺寸下的结果以 round35 为准。
>
> **2026-11-06 round 27 进展**：见 [round 27 记录](artifacts/venc-reverse/m2-diag/round27-findings-20261106.md)。新增延迟落盘采集（帧先暂存RAM、解码后写盘），5项验证测试/构建通过；但仍因每帧MMZ读取/复制扰动时序，采集44帧、像素38。per-buffer WC与payload IVAC同启动对照分别44帧/像素39/PTS39、45帧/像素37/PTS37，差异较小，不足定夺。已恢复默认可用 payload-IVAC 配置，M2未完成。
>
> **2026-11-06 round 26 进展**：见 [round 26 记录](artifacts/venc-reverse/m2-diag/round26-findings-20261106.md)。clean payload-IVAC 配置连续五次输出45/42/46/47/**50**帧，证明某些时序可完整跑完；但开启全帧保存重跑为49帧，逐帧仅39帧像素正确，说明保存帧会改变时序，帧数不能代替像素验收。M2仍未完成。
>
> **2026-11-06 round 22 进展**：见 [round 22 记录](artifacts/venc-reverse/m2-diag/round22-findings-20261106.md)。加入默认关闭 `vdec_scd_wc`，仅对 `VFMW_SCD` allocation 建 per-buffer `ioremap_wc`，用户ES保持原映射；避免了整区WC的 `GetBuffer=0x80120002`。实验 `vdec_scd_wc=1,m2_sync_msgs=1,m2_sync_scd=0` 得48帧/像素37/像素+PTS37，未超过payload IVAC基线，故仍保留payload IVAC为主路径，per-buffer WC仅作可行基础设施。当前板子已恢复 `vdec_scd_wc=0,m2_sync_msgs=1,m2_sync_scd=1,m2_record=0`。
>
> **2026-11-06 round 21 进展**：见 [round 21 记录](artifacts/venc-reverse/m2-diag/round21-findings-20261106.md)。源码确认原厂 SCD detail buffer 走 `HI_DRV_VDEC_Map`→noncached/WC `HI_DRV_MMZ_Map`，而当前 port 合并 Map/MapCache 为 cached `__va`；payload IVAC是补偿。全MMZ WC会破坏用户ES（GetBuffer=0x80120002），下一步应做 per-buffer WC，保留用户ES映射。
>
> **2026-11-06 round 20 进展**：见 [round 20 记录](artifacts/venc-reverse/m2-diag/round20-findings-20261106.md)。尝试在 `ReadScdStateReg` 后对 SCD UpMsg 区间做 `dc ivac`，结果降至46帧/像素36/像素+PTS33，已撤销；说明UpMsg不能按简单线性区间失效。clean payload-IVAC模块已恢复，主根因仍是segment payload设备写后CPU cache stale。
>
> **2026-11-06 round 19 进展**：见 [round 19 记录](artifacts/venc-reverse/m2-diag/round19-findings-20261106.md)。在 payload IVAC 后增加全 segment hash ring，运行无热路径打印；本轮47帧、ring160段，两个 `head=00000000` 主异常消失，剩余短特殊段不进入 payload parser。运行结束后物理地址会被 ring 循环复用，不能再用事后 `/dev/mem` 与 ring hash强行配对。hash/ring recorder已关闭，clean payload-IVAC配置保持。
>
> **2026-11-06 round 16 进展**：见 [round 16 记录](artifacts/venc-reverse/m2-diag/round16-findings-20261106.md)。`c8010000` 不在源流，`vdec_eop=0`，且该 segment 长度4，`InsertStreamSeg` 对长度<=31不进入 `CheckStream` payload parser；它是SCD侧特殊/填充segment，不是当前大payload损坏的直接触发点。payload IVAC 修复继续保留，metadata IVAC 实验无结果已撤销，clean模块已恢复。
>
> **2026-11-06 round 13 进展**：见 [round 13 记录](artifacts/venc-reverse/m2-diag/round13-findings-20261106.md)。完整 VA/物理地址 ring 已确认 `va=ffff000028ad...` 对应 `phys=0x28ad...`；异常 segment 的 CPU ring head 为 `00000000`，同物理地址随后 `/dev/mem` 读到正确 `00 00 01 65`，**直接证明 SCD 设备写后 CPU 读到了旧 cache 行**。将 `m2_sync_scd` 从 `dc civac` 改为 `dc ivac` + `dsb sy` 后，异常零起始码消失，逐帧结果提升到 47帧/像素41/像素+PTS41。主根因已验证，但仍有一个4字节特殊段、未达到50/50。保持 `m2_sync_msgs=1`，payload IVAC 已重复验证；metadata ring IVAC 的 META0/META1 实验未产生可用结果且已撤销。当前板子已恢复 clean payload-IVAC 模块（`m2_sync_msgs=1,m2_sync_scd=1,m2_record=0`），下一步确认 `c8010000` 特殊段并继续全帧验证。
>
> **2026-11-06 round 12 进展**：继续审计 SCD 大 segment 地址转换。`InsertStreamSeg` 对长度>31的 `pSeg` 调 `MEM_Phy2Vir` 后解析，主线仍是物理→虚拟转换与设备写后 CPU 读取属性。**重要校正**：round10 环形记录的 `ptr` 用 `unsigned int` 截断了 AArch64 VA，日志中的 `0x28ae...` 不能当作已证实物理地址；首字节摘要有效，但必须补记完整 VA/物理地址后再判断其与 ES 池关系。用户 ES→内核 flush 后摘要一致的结论仍有效。保持 `m2_sync_msgs=1`，停用 probe/测试进程。
>
> **2026-11-06 round 11 进展**：见 [round 11 记录](artifacts/venc-reverse/m2-diag/round11-findings-20261106.md)。
>
> **2026-11-06 round 14 进展**：见 [round 14 ES 交接记录](artifacts/venc-reverse/m2-diag/round14-findings-20261106.md)。已核实用户 ES→内核路径：用户 mmap VA 与内核 WB 别名并存，PutWriteBuffer 不复制 payload，`vdec_flush_put` 对内核别名执行 `dc civac`。修正版低频采样已放在 flush **之后**并在板上运行：前16个 AU 的用户源摘要与 flush 后内核摘要全部一致（含第一版误差的 pts=2/9/12）。因此用户→内核 ES 交接已排除，损坏点后移到 SCD/设备写 segment 路径。更早的 ABBA 对照：flush_put=0/1/1/0 输出49/45/48/43，像素45/40/40/38，存在运行波动，不能单独作为根因证据。当前源码 Git 提交 `e720fae`，修正版已构建；板上最后一次 probe 用后需重启恢复正常模块。
>
> **2026-11-06 round 9 最新进展（最高优先）**：见 [round 9 记录](artifacts/venc-reverse/m2-diag/round9-findings-20261105.md)。① **段切分已证明正确**：M2SEG 显示每 AU 依次为 `000001 67`(SPS)/`68`(PPS)/`06`(SEI)/`65`(IDR)，边界与长度吻合，排除"段整体错位"。② **方法学限制**：`CheckSegValid` 在 SCD 中断路径，逐段 `pr_info` 会把串口压满，35s 只出 1 帧（正常 12–17s 出 42–46 帧）⇒ 热路径打印不可用于时序关联，后续必须改为内存环形记录/异常时批量输出。③ 剩余假设收窄为段内**位流游标字段级误读**（宽度出现 39/42 两种，高度 22→15/6）。当前板子 `m2_diag=0 m2_sync_msgs=1`，`frames=42` 正常。
>
> **2026-11-06 round 8 最新进展（最高优先）**：见 [round 8 记录](artifacts/venc-reverse/m2-diag/round8-findings-20261105.md)。用 `M2TASK` 钩子扫描 task 结构 MMZ 范围内字段，只有 picture message(108)、UpMsg(112)、码流(116)、帧缓冲(132)，**DecParam 不在 task 中**，它随 picture message 内嵌。因此撤回「DecParam 独立缓冲陈旧」假设：`total_mbs` 由 **CPU 解析后计算**，错误几何（40×7=280）在 CPU 解析阶段已产生，不是硬件读错缓存。方向收窄为**解析器位流误读**（宽度对、高度错，提示字段级 ue(v) 级联偏移）。下一步用 `M2SEG` 对比失败帧与成功帧的 segment 地址/长度/位偏移。
>
> **2026-11-06 round 7 最新进展（最高优先）**：见 [round 7 记录](artifacts/venc-reverse/m2-diag/round7-findings-20261105.md)。损坏帧签名已定位：日志中 `total_mbs=280` 恰等于 634×112 的宏块数（40×7），而正常帧为 920（40×23）⇒ **宽度正确、高度字段错误**，说明损坏来自参数缓冲的字段陈旧，不是整块 SPS 读错，也与已修复的消息缓存交接同类。同时排除 VDM 超时/SCD 复位为成因。下一步：扩展 submit 钩子，**只 clean CPU 写、设备读的 DecParam/消息**，绝不对设备写的 UpMsg/帧做 clean；判据为逐帧校验中损坏帧消失。
>
> **2026-11-06 round 6 最新进展（最高优先）**：见 [round 6 记录](artifacts/venc-reverse/m2-diag/round6-findings-20261105.md)。**撤回「PTS 偏移是独立缺陷」的判断**：大步长实测（PTSSTRIDE=1000）显示输出 PTS 为输入值的精确副本（2000→参考帧2、3000→3…），无数值扭曲、无早期系统性错位；round4 的「像素对、PTS 错」是丢帧后输出队列配对错位的**次生现象**。剩余主缺陷收敛为**偶发解码失败**（本轮 37/42 像素正确，失败位置随机；曾见 634×112 错误尺寸）。下一步集中攻偶发解码失败：错误参数来源、reserved-memory 的真正 WC 映射、失败帧 UpMsg 对照。判据仍为逐帧像素校验。
>
> **2026-11-05 round 5 最新进展（最高优先）**：见 [round 5 记录](artifacts/venc-reverse/m2-diag/round5-findings-20261105.md)。① PTS 修正链已排除：驱动直接取 `pstImage->PTS`，133 条 `PTSInfo` 均为 `Src==In==Out`，偏移来自上游 SCD UpMsg→GetSegPts。② `vdec_uncached_mmz=1`（ioremap_wc）**再次送流失败**（`GetBuffer rc=0x80120002`），证明恢复原厂 WC 语义不能靠现有开关，需按 reserved-memory 正确映射。③ 恢复配置后逐帧校验：46 帧输出、**40 帧像素正确、31 帧像素+PTS 同时对**（round4 为 39/27）。保留 `m2_sync_msgs=1`；停用 `m2_sync_scd`。板子启动 ID `f9ff6bb2-9b74-4b40-8f44-70c3e3c62306`，未刷机。
>
> **2026-11-05 round 4 最新进展（最高优先）**：见 [round 4 原厂对照与逐帧实测](artifacts/venc-reverse/m2-diag/round4-findings-20261105.md)。① 原厂固件对照：原厂 Android SDK 包只有文档无源码，MV300 SDK 目录只有 sysreg，确认“原厂对应源码不可得”；但原厂内核 `vendor-kernel.Image` 内 MMZ 驱动特征字符串与仓库 `drv_media_mem.c` 逐条一致，证明原厂固件用的就是这套 MMZ 实现（WC/WB 区分属原厂行为，非 MV200 假设）。② 新增逐帧像素+PTS 校验工具（TDD）；当前 VDH 消息写回后：45 帧输出、**39 帧像素完全正确、27 帧像素与 PTS 同时对**。③ **SCD 段载荷 invalidate 实验为负结果**（41/34/19 → 46/39/27，质量无改善），已停用，剩余缺陷不是段数据陈旧。④ 剩余为两个独立缺陷：6 帧参数解析错误（含 634×112）与 12 帧 PTS 偏 +1、7 个 PTS 缺失。下一步查 PTS 传递与错误参数来源，一律以逐帧校验为判据。Git 分支 `m2/scd-sync-r4` 提交 `191031c`。
>
> **2026-11-05 round 3 进展**：见 [round 3 可逆 A/B 证据](artifacts/venc-reverse/m2-diag/round3-findings-20261105.md)。同次启动只切换 VDH 启动前 picture/slice 消息缓存写回，50 AU输出 **2→41→3→42帧**；开启时首帧与软件解码345600字节完全一致。已确认消息缓存交接缺失是主要原因之一，旧“缓存已排除”结论不适用于控制消息。仍未达到48/50实验门槛，尚未逐帧校验全序列。剩余异常发生在CPU解析阶段：50份源SPS相同，日志偶尔解析出错误宽高/隔行标志，下一步查SCD→CPU的segment/message交接。当前Git分支 `m2/msg-sync-r3`、提交 `74cc2fa`（仓库仍为 `/home/jason/bringup-7.3/port/vdec-m2diag-r2`）；板上模块 `/root/m2/hi_vdec_msgs_r3.ko`，MD5 `86dffd02fea1221c2b88bc57a97bb0f4`；**m2_sync_msgs=1** 保持开启。该补丁严格限定当前单slice消息布局，尚未泛化，原移植目录未改。
>
> **2026-11-05 round 2 进展**：见 [round 2 实验与像素证据](artifacts/venc-reverse/m2-diag/round2-findings-20261105.md)。已取得 PTS=27 的一帧正确图像：硬件 640×368 裁为 640×360 后，与软件第27帧的 345600 字节全部一致。多帧测试只输出1帧，其余多数仍报错，稳定解码尚未完成。21组插桩显示更新时 MMIO 与 `g_BackUp` 一致、报告前副本未变，UpMsg 边界与硬件备份寄存器匹配，**本轮不支持 H1**。运行通道实际 `ErrorThred=0, Compress=0`，撤回由驱动默认值推断运行阈值100/压缩已开启的说法。下一步优先 H4 输入消息/码流描述符。按用户要求使用 Git：诊断仓库 `/home/jason/bringup-7.3/port/vdec-m2diag-r2`，分支 `m2/diag-r2`，基线 `00c7c1c`，诊断提交 `29334f8`；原移植目录未动。当前板上诊断模块 MD5 `7ffc9e66fd6a07a46b2bf96f90a6fbca`，日志64条预算已耗尽，详情及复现限制见记录。
>
> **2026-11-05 22:25 后续校正（优先于下文旧结论）**：见 [round 1 实验记录](artifacts/venc-reverse/m2-diag/round1-findings-20261105.md)。单帧复现自然退出、`frames=0`，仍为 `err_mbs=920`。源码确认状态副本是 `g_BackUp`；`g_HwMem` 首字段为 MMIO 指针，`IsVdmReady/IsVdmRun` 经该指针直接读硬件，所以下文 H2 的“副本判断”前提撤回。`MakeDecReport` 同时读取 `g_BackUp` 和独立 UpMsg 消息内存，需分开验证。`err_mbs=0` 也会发生在超时复位后，本轮已捕获 `DecSliceNum=0 → err_mbs=0 → CorrectType=1 ErrRatio=100`，不能单独证明成功。输入码流的物理内存验证不能排除独立的设备写回 UpMsg/帧缓冲一致性问题；仅限定原排除结论范围，不重复旧码流实验。M2 尚未完成。

---

## 0. 一页速览（TL;DR）

- **目标（长期）**：让 mainline Linux 7.3 板子（Hi3798MV300）具备硬件加速，本阶段是 **M2：VDEC（H.264）硬件解码出正确图像**。
- **当前状态（round 3 更新）**：限定布局的消息缓存写回实验已将50 AU的输出由2–3帧提高到41–42帧，抽检首帧像素完全正确；仍有丢帧、错误参数/PTS，稳定解码与全帧像素验收未完成。下文未更新段落保留历史调查背景，以顶部后续记录为准。
- **最新关键证据（很重要）**：
  1. 原厂 Android 上同一颗芯片、同一套 vfmw/V5R2C1 路径 **HEVC 4K 稳定 62–63fps、VDH 占用 67%** ⇒ **硬件、VDH HAL、vfmw 版本本身没有问题**。
  2. 我们驱动里 `u32ErrCover=100`（原厂 25）⇒ **不是"拒帧阈值太严"**（该假设已撤回）。
  3. 我们移植的 vfmw 汇编 **与 SDK v5.0 原版逻辑一致**（差异仅 `_mcount` 与历史调试 hook）。
  4. 用 `/dev/mem` dump 物理内存 **能找到码流字节** ⇒ 缓存一致性/物理地址映射不是根因。
  5. **偶发 `err_mbs=0`**（同一配置、同一码流，出现 1 帧全对）⇒ 说明**解码本身有时是对的**，主要矛盾在**错误信息（repair param）的来源/时机**。
- **最可能的方向（按优先级）**：
  1. `PostPro_GetErrRatio → VDMHAL_*_MakeDecReport` 读到的 repair 信息是**过期/未更新的副本**（ISR 里 `UpdateHardwareInfo`/`ClearIntState` 顺序或寄存器副本问题）。
  2. `IsVdmReady/IsVdmRun/IsVdhDecOver` 基于 `g_HwMem[]` 副本判断完成，副本若未及时更新 → 提前提交/错误判定。
  3. HAL 内存布局（`OpenHAL/ArrangeMem`）与帧缓冲/FSP 地址错。
- **立刻可做的三条命令**（板子当前就应该能跑，见 §6）：
  ```
  ssh -i ~/.ssh/id_ed25519 root@192.168.2.21
  cd /root/m2 && insmod hi_mmz_shim.ko && insmod hi_vdec.ko vdec_dfs=1 vdec_sed_only=0
  printf "0x0 0xFFFFFFFF" > /proc/vfmw/info
  (STARTDELAY=1500 timeout 20 ./vdec_test gen3_idr.h264 all >/tmp/t.log 2>&1 &); sleep 13; dmesg | grep -E "VTSTAT|err_mbs|ErrRatio"
  ```

---

## 1. 任务与里程碑

| 里程碑 | 内容 | 状态 |
|---|---|---|
| M1 | JPEG 硬件解码 | ✅ 已完成（历史文档） |
| **M2** | **VDEC H.264 硬件解码正确出图** | 🔴 **当前阻塞（本文档主题）** |
| M3 | V4L2 播放器 | ⛔ 依赖 M2 |
| M4 | VENC H.264 编码 | ✅ 已完成（`HANDOFF-hardware-acceleration-2026-11-04.md` §4.1–§4.4；`artifacts/venc-reverse/README.md`） |
| M5 | GPU / TDE | ⏸ 可选 |

**用户已明确的工作方法**（必须遵守）：
- 用 M4（VENC）成功的思路做 M2：**原厂 ground truth 对照 + 结构体/标志 diff + 反汇编预编译核**。
- 允许刷原厂固件到板子上直接看运行结果（已授权，且已验证可行）。
- 报告要诚实：结论必须有证据；被推翻的结论要显式撤回（见 §4）。

---

## 2. 环境事实（先读这一节，少踩 90% 的坑）

### 2.1 板子
- Hi3798MV300 STB，4×Cortex-A53，1GB DDR3，eMMC 7,820,083,200 B（型号 "DG4008"，HS400）。
- **当前跑的是 Ubuntu 26.04.1**，内核 `Linux hi3798mv300 7.3.0 #182 SMP PREEMPT Thu Nov 5 08:42:31 CST 2026 aarch64`。
- **网络（现在会同时有两个地址！）**
  - `eth0 192.168.2.10/24`（静态，主用）
  - `wlan0 192.168.2.21/24`（DHCP，重启后可能只有这个先起来）
  - ⇒ SSH 连不上 `.10` 时立刻改试 `.21`（本轮就发生过）。
- SSH：`ssh -i /home/jason/.ssh/id_ed25519 -o StrictHostKeyChecking=no root@192.168.2.21`（root 免密）。
- 板上有既有服务：`weston.service`（远程桌面）、`stability-load.service`（1080p H.264 循环播放）、`stability-monitor.service`。
- `/proc/vfmw/` 下有：`buffer channel distributor help info pts_info scd vfmw_diff vfmw_statis`。
- 模块参数（`/sys/module/hi_vdec/parameters/`）：
  `En2d EnVcmp RefFrameNum DispFrameNum vdec_ack_delay vdec_dbg vdec_dbg_alloc vdec_dbg_img vdec_dbg_osal vdec_dbg_put vdec_dfs vdec_eop vdec_flush_frame vdec_flush_put vdec_force_alloc vdec_hdr_meta vdec_maskdfs vdec_maxref vdec_occfrm_rls vdec_own_isr vdec_print_always vdec_sb_adj vdec_sb_scan vdec_scd_isr_guard vdec_sed_only vdec_smmu_mode vdec_task_ms vdec_uncached_mmz vdec_vdh_dump`

### 2.2 串口 / 复位
- 串口控制台：`/dev/ttyUSB0`，**115200 8N1**。
- 复位控制：`/dev/ttyUSB1`，RTS 脉冲：
  ```bash
  python3 /home/jason/bringup-7.3/tools/ser_reset.py    # rts=True 0.4s → False
  ```
- 进原厂 fastboot：reset 后**立刻连发 `\x03`**（每 5ms 一次），**不要先 sleep**，否则错过 autoboot 窗口：
  ```bash
  python3 /home/jason/bringup-7.3/tools/fb_prompt.py
  ```
- 启动到 SSH 约 55–75 s。串口在 Ubuntu 下是 console（可登录 root），在 vendor Android 下曾是内核 console（已被我们改成 root shell，见 §8.2）。

### 2.3 主机（WSL Ubuntu）
- 工作根目录：`/home/jason/bringup-7.3`
  - 内核源码：`src/linux-7.3`
  - 工具链：`toolchain/usr/bin/aarch64-linux-gnu-*`（需要
    `export LD_LIBRARY_PATH=/home/jason/bringup-7.3/toolchain/usr/lib/x86_64-linux-gnu`）
  - 移植源码：`port/{vdec,vdecuser,venc,vencuser,mmz,jpeg-user}`
  - 产物：`out/`、备份：`backup/port-MMDD-HHMM.tgz`、工具：`tools/`
- **构建 vdec 模块**：
  ```bash
  cd /home/jason/bringup-7.3/src/linux-7.3
  export PATH=/home/jason/bringup-7.3/toolchain/usr/bin:$PATH
  export LD_LIBRARY_PATH=/home/jason/bringup-7.3/toolchain/usr/lib/x86_64-linux-gnu
  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=/home/jason/bringup-7.3/port/mmz modules
  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=/home/jason/bringup-7.3/port/vdec \
       KBUILD_EXTRA_SYMBOLS=/home/jason/bringup-7.3/port/mmz/Module.symvers modules
  ```
  产物：`port/mmz/hi_mmz_shim.ko`(11,464 B)、`port/vdec/hi_vdec.ko`(1,954,400 B，含大量调试 hook)。
- 测试程序：`port/vdecuser/vdec_test`（aarch64 静态，854,736 B，用法 `vdec_test <file.h264> [all|au]`）。
- **部署包**：`out/deploy-m2.tgz`（含上面两个 ko + vdec_test + `4K_vps.hevc` + `gen3_idr.h264`）。
- 关键 md5（与本轮板子上部署的一致，用于"同一次启动内校验"）：
  ```
  4c60b785378bf0cfe9b96a29f2bec558  hi_vdec.ko
  b0518ba213bf5c946b9b9ea5a1478a7a  hi_mmz_shim.ko
  5dd12e1f688669406de6a034f220ea90  vdec_test
  3234a0439c9843891620b5d63e6973e6  4K_vps.hevc
  ```

### 2.4 网络 / TFTP（刷机通道）
- 刷机用 **Windows 侧 Tftpd64**：`C:\Users\yujia\Desktop\hi3798_boot`（= `/mnt/c/Users/yujia/Desktop/hi3798_boot`）
  - 配置 `tftpd32.ini`：`BaseDirectory`=该目录、`TftpPort=69`、`LocalIP=192.168.2.100`
  - 启动：`cd /mnt/c/Users/yujia/Desktop/hi3798_boot && ("./tftpd64.exe" >/tmp/tftpd.log 2>&1 &)`
  - **Linux 不能绑 69 端口**（`ip_unprivileged_port_start=1024`），所以必须用 Windows 侧。
- 板子侧（原厂 `fastboot#`）：
  ```
  setenv serverip 192.168.2.100 ; setenv ipaddr 192.168.2.10
  setenv netmask 255.255.255.0 ; setenv gatewayip 192.168.2.1
  tftp 0x10000000 <file> ; mmc write 0 0x10000000 <start_blk> <count_blk>
  ```
- **Tftpd64 会在大文件传输若干次后挂起**（表现为 `T T T T` 超时）⇒ 失败时先 taskkill 再启动，等 10 秒。
- **每次传输的文件名必须不同**（Windows 会锁住上次被读取的文件 ⇒ `PermissionError`）。恢复脚本用 `uz_%03d_%d.bin`。
- 辅助脚本（已固化到 `tools/`）：
  - `tools/fb_prompt.py` —— 复位并停在 fastboot#
  - `tools/fb_flash.py <file> <start_blk_hex> [size]` —— tftp + mmc write 单文件
  - `tools/xml_flash2.py` —— **无复位**状态下按 XML 全量刷原厂分区（已验证）
  - `tools/restore7.py` —— Ubuntu 根分区断点续传刷写（RESUME=N 环境变量）
  - `tools/flash_kernel2.py`、`tools/zero_misc2.py` —— 刷 kernel / 清 misc

### 2.5 关键材料（都在 `/home/jason/bringup-7.3/out/`）
| 文件 | 用途 | 大小/说明 |
|---|---|---|
| `board-boot-now.bin` | 恢复 U-Boot/FIP/env（刷到块 0） | 33,554,432 B |
| `ubuntu-p1.img` | Ubuntu 根分区镜像（刷到块 0x97000 起） | 7,503,413,248 B |
| `vendor/kernel_console.bin` | 原厂 Android kernel + **改过的 ramdisk（串口 root shell）** | 41,943,040 B |
| `vendor/system_probe.img` | 原厂 system + 开机探针脚本 | 734,003,200 B |
| `deploy-m2.tgz` | 测试部署包 | 10,753,605 B |
| `media/4K_vps.hevc` | 从原厂 4K.ts 抽出的 HEVC ES（首个 VPS 起） | 9,615,637 B |
| `media/{2K,4K,networktest}.ts` | 原厂自带测试流 | 10MB/10MB/2MB |

原厂固件母本：`/mnt/f/design/Hi3798/FW/BK/BK/`（9.9 GB eMMC 镜像），分区表
`hi3798mv300_M301H_JL.xml`。另有 `F:\design\Hi3798\FW\restore-20261104`（上一会话备份）。

---

## 3. 已确认的结论（带证据位置）

### 3.1 原厂硬件解码基准（决定性 ground truth）
在**原厂 Android**（我们已刷进去、并改 ramdisk 打开串口 root shell）用厂商播放器播放原厂自带测试流，
同时 `cat /proc/vfmw/channel` 采样：

| 流 | 编码 | DecodeFrameNum/OutputFrameNum | VDH 占用 | fps |
|---|---|---|---|---|
| `/system/lib/2K.ts` | MPEG2 | 113/112 | 11.2% | 29.9 |
| **`/system/lib/4K.ts`** | **HEVC** | **290/290** | **66.7–69.6%** | **62–63** |
| `/system/media/networktest.ts` | MPEG2 | 16/15 | 0.1% | 22–26 |

播放中 `channel` 全文（原厂健康值）：
```
IsOpen:1 IsRun:1 Priority:15 eVidStd:MPEG2 ChanCapLevel:9
LastFrameState:RECEIVED IsOmxPath:0 CfgDecMode:0 CfgOutputOrder:0
ErrorThred:25 StreamThred:0 UvmosEnable:1
Compress:0 LossCompress:0 BitDepth:0
DecodeFrameNum:16 OutputFrameNum:15
CTX Mem Size:2226680  SCD Mem Size:3407872
Ref,Read,New:(2,3,7)  VoQue detail:(5,8,15)
VDH0=0.1%  DFS: Frame size=768416  Reference frame num=3
```
**结论**：同一颗芯片、同一 vfmw 版本（`HiVDHFMWV500R001-TAG02-C01`）、`IsOmxPath=0`（非 OMX 的 SDK 路径）
能正常硬件解码 ⇒ **问题 100% 在我们移植层**，不在硬件/固件版本。
证据：`artifacts/venc-reverse/m2-diag/vendor_channel_groundtruth.txt`、`vendor_hw_decode_baseline.txt`、
`vendor_groundtruth_summary.txt`、`vendor_flash_success.txt`。

### 3.2 原厂用到的"开机关机"细节（供对照，不必再验证）
- 原厂 `Compress:0`（**不压缩帧**）、`UvmosEnable:1`、`ErrorThred:25`。
- 原厂 system 里另有 `AdbConsole.apk`、`HiVideoPlayer.apk` 等（`/app`），播放器组件是
  `com.hisilicon.android.videoplayer/.activity.VideoActivity`。

### 3.3 我们驱动的配置对照（重要：一个假设已被推翻）
- 我们 `port/vdec/vdec/drv_vdec_intf_k.c:525` 默认 `.u32ErrCover = 100`，
  并在 `:3473` 把它写进 `stVdecChanCfg.s32ChanErrThr`（即 `/proc/vfmw/channel` 的 `ErrorThred`）。
- **100 比原厂 25 更宽松** ⇒ "错误帧被拒"不是 M2 的根因（§4.89 的假设**已撤回**）。
- `bUVMOSEnable` 我们默认不启用（仅由 ioctl 设置）；原厂播放器会开启。UVMOS 只影响内存优化。

### 3.4 vfmw 汇编逻辑与 SDK 原版一致
把 `port/vdec/vfmw/product/Hi3798MV200/LNX_CFG/64bit` 与
`source/msp/drv/vfmw/vfmw_v5.0/product/Hi3798MV200/LNX_CFG/64bit` 逐文件 diff：
差异**全部**是 SDK 的 `_mcount` 插桩行（我们没有）与**我们自己加的调试 hook**，没有逻辑差异。
⇒ 不要再去怀疑 vfmw 的 .S 逻辑写错。

### 3.5 码流数据确实进了物理内存（缓存嫌疑已排除）
在解码运行中 `dd if=/dev/mem bs=65536 skip=$((0x28A00000/65536)) count=32` dump 2MB，
用源流不同偏移的 24 字节模式去搜：stream off 5000/20000/100000/200000 均能在 dump 中找到且**顺序一致**
⇒ 用户态写入的码流已在物理 RAM，VDH 能读到；**不是 cache/phys 映射问题**。

### 3.6 repair 参数的真实行为（本轮最关键的新证据）
开满打印后，单次 `vdec_test gen3_idr.h264 all` 的 dmesg 序列（节选）：
```
N: total_mbs=920,err_mbs=920, ErrFrame_Flag: 0
N: Chan 0: Current frame:17  ErrRatio = 100
N: store pic err, ret = -1
N: total_mbs=920,err_mbs=0,   ErrFrame_Flag: 0     ← ★偶发全对（同一配置/同一次运行）
N: total_mbs=920,err_mbs=920, ErrFrame_Flag: 0
N: Chan 0: Current frame:19  ErrRatio = 100
N: store pic err, ret = -1
```
之前还观察到 repair 的 MB 范围：
```
frame 21..25 : pRepairParam[0].MbGroup[i].StartMbn=0    EndMbn=919  ErrRatio=100
frame 26     : pRepairParam[0].MbGroup[i].StartMbn=910  EndMbn=919  ErrRatio=1   ← 只最后一行末尾 10 个 MB
```
640x368 = 40 MB/行 × 23 行 = 920 MB；910–919 正是最后一行的最后 10 个。
**解读**：硬件解码本身**有时确实是对的**（err_mbs=0 那一帧）；大多数时候错误信息"整帧错"。
⇒ 主要矛盾从"硬件没工作"转为 **repair 信息（MakeDecReport）的来源/时机** 或 **帧提交/完成同步**。
证据文件：`m2-diag/errmbs_mbgroup_partial.txt`。

---

## 4. 已排除的假设（**不要再重复验证**，否则浪费一整天）

| # | 假设 | 结论 | 证据 |
|---|---|---|---|
| 1 | stream_base 指向非码流（偏移错） | ❌ 撤回：那是熵编码 slice 数据，正常 | §4.67 |
| 2 | `EnVcmp=1` 默认值错 | ❌ 撤回：`EnVcmp=2` 也坏 | §4.79 |
| 3 | `vdec_sb_adj=-7` 能突破 | ❌ 撤回：-9..-4 六次启动全是噪声 | §4.80 |
| 4 | SED 模式能解码（err_mbs=0） | ⚠️ 部分撤回：SED 路径**没有 picture-level 后处理**，`err_mbs` 不算 ≠ 解码正确 | §4.51–4.55 |
| 5 | SMMU 配置问题 | ❌ `smmu_mode=2` + 修复 TTBR 后 `post_mfde=0` | §4.6x |
| 6 | `vdec_uncached_mmz=1` 可用 | ❌ 会破坏送流（`GetBuffer rc=0x80120002`） | §4.7x |
| 7 | 硬件/固件版本不支持 | ❌ 原厂同芯片 HEVC 62fps | §3.1 |
| 8 | ErrorThred 太小导致拒帧 | ❌ 我们 100 > 原厂 25 | §3.3 |
| 9 | vfmw 汇编逻辑写错 | ❌ 与 SDK 逻辑一致 | §3.4 |
| 10 | 缓存一致性 / 物理地址映射 | ❌ /dev/mem 能读到码流 | §3.5 |
| 11 | 送流/解析错误（NAL 切分、段大小） | ❌ vfmw 打印 `Read_seg ... LenByte=6704` 等与 AU 大小吻合，NAL 解析正常 | §3.6 附近 |
| 12 | 队列竞争/送太快 | ❌ `SIMPLE=1` 只送一帧仍 `err_mbs=920` | 本轮 |

历史记录里还有若干"已验证无效"的参数尝试（`vdec_maxref`、`vdec_dfs`、`vdec_occfrm_rls`、`vdec_flush_put`、
`vdec_maskdfs`、`vdec_eop`、`vdec_ack_delay`、`DispFrameNum` 等），细节见 HANDOFF §4.1–§4.87。

---

## 5. 当前阻塞与开放假设（按优先级，含验证方法）

### H1（最高）repair 信息读取的时机/对象错
- 机制：`PostPro_GetErrRatio` 通过 `g_vdm_hal_fun_ptr` **偏移 280 = `pfun_VDMHAL_MakeDecReport`**
  读取错误信息；`MakeDecReport` 从 `g_HwMem[VdhId]` 的**内存副本**（`[x2,40]`、`[x1,4]` 等）读状态，
  该副本由 ISR 里的 **偏移 288 = `pfun_VDMHAL_UpdateHardwareInfo`** 从 VDH 寄存器刷新；
  ISR 顺序是 `UpdateHardwareInfo` → `ClearIntState`(偏移 176)。
- 验证方法（推荐，成本最低）：
  1. 在 `VDMHAL_V5R2C1_MakeDecReport` 入口/读出状态处插桩，打印：帧号、`g_HwMem` 状态字、
     实际 VDH 寄存器（`vdec_vdh_dump=1` 可 dump 0xF8C30000 的 0x60 个 dword）对比。
  2. 在 `VDMHAL_V5R2C1_UpdateHardwareInfo` 入口插桩计数，确认每帧都调用、且调用在 postproc 之前。
  3. 判据：若 `g_HwMem` 副本状态字与实时 VDH 寄存器不一致（副本陈旧），即命中 H1。
- 相关文件：`port/vdec/vfmw/product/Hi3798MV200/LNX_CFG/64bit/core/driver/HiVDHV5R2C1/vdm_hal.S`
  （`VDMHAL_V5R2C1_MakeDecReport:`, `VDMHAL_V5R2C1_UpdateHardwareInfo:`, `VDMHAL_V5R2C1_PrepareRepair:`），
  `core/common/postprocess.S`（`PostPro_GetErrRatio:`），`core/common/vdm_drv.S`（`VDMDRV_IsrProcess:`）。

### H2 ISR/完成判定（`IsVdmReady`/`IsVdmRun`/`IsVdhDecOver`）
- 这三个函数都从 `g_HwMem[VdhId]` 副本读（`IsVdmReady` 读 `[x0+28]` bit17；`IsVdmRun` 读 `[x0+40]==1`）。
- 验证：插桩打印返回值 + 对应 VDH 实时寄存器；对比"提交任务时硬件是否真的空闲"。
- 已有打印：`SPIC7: wake/act/noact`、`SPIC8: active/badslot/noparam`、`SPIC3: isr/afterdec/beforedec`。
  本轮观测 `isr=14 / afterdec=15`（少 1 次），值得追。

### H3 HAL 内存布局（OpenHAL / ArrangeMem）
- `pfun_VDMHAL_OpenHAL`(偏移112) 与 `ArrangeMem`(偏移128) 决定 VDH 的寄存器映射与内部 buffer 布局；
  若与帧缓冲/FSP/stream 区域重叠或尺寸算错，硬件写出的修复信息就会落在错误位置。
- 验证：打印 `OpenHAL` 的入参（mem 起始/大小）、`ArrangeMem` 输出结构（各段物理地址+大小），
  与 `/proc/vfmw/buffer`、`/proc/vfmw/channel` 的 CTX/SCD/VDH mem 实际值对照。

### H4 slice 消息 / SLSRC 描述符字段
- 历史对照发现 SED 与非 SED 只有两处不同：`SLMSG[2]`（0xbf44 vs 0x10230）与 `SLSRC[0]`（0x0 vs 0x01000002）。
- 若 H1/H2 不成立，这是下一个可疑点：解出 SLSRC 结构（起始/长度/flags）并逐字段核对喂给 `VDH_Start_Mfde_Dec` 的
  "slice 消息"是否符合硬件手册语义。

### H5 `EnVcmp`（帧压缩）
- 原厂 `Compress:0`。我们默认 `EnVcmp=1`（SDK 默认），`MaskCtrlWord & 0x4` 时才置 2。
- 尚未做过干净的 `EnVcmp=0` + `SIMPLE=1` 单帧测试 ⇒ 值得花 10 分钟排除。

### H6 测试工具限制（妨碍 HEVC/MPEG2 对照）
- `port/vdecuser/vdec_test.c` 里写死 `attr.enType = HI_UNF_VCODEC_TYPE_H264`、
  `opt.enCapLevel = HI_UNF_VCODEC_CAP_LEVEL_FULLHD`（1080p）⇒ 喂 4K HEVC 根本不会建 HEVC 通道
  （现象：`mfde_tasks=0, vdh=0, DEC PARAM not ready`）——**这不是解码器结论**。
- 解除方法（二选一）：
  a) 改 `vdec_test.c`：`enType` 由 `getenv("VCODEC")` 决定（h264/hevc/mpeg2），`enCapLevel` 由 `CAPLEVEL` 决定
     （4K 用 `HI_UNF_VCODEC_CAP_LEVEL_4096x2160`）；然后重编译：
     ```bash
     cd port/vdecuser
     export PATH=/home/jason/bringup-7.3/toolchain/usr/bin:$PATH
     export LD_LIBRARY_PATH=/home/jason/bringup-7.3/toolchain/usr/lib/x86_64-linux-gnu
     S=/home/jason/HiSTBLinuxV100R005C00SPC060/source
     aarch64-linux-gnu-gcc -static -O2 -I. -I$S/common/include -I$S/common/api/include \
        -I$S/msp/include -I$S/msp/api/include -I$S/msp/drv/include \
        -o vdec_test vdec_test.c hi_codec.c mpi_vdec.c mpi_vdec_adapter.c libmmz_stub.c
     ```
     **已知障碍**：SDK 头文件与本地 `mpi_vdec.c` 版本不一致——`HI_MPI_VDEC_RlsUserData` 原型冲突、
     缺 `hi_drv_struct.h`。需要先把 SDK 头复制到本地 `include/` 并打补丁（或删掉冲突声明）。
  b) 或者放弃 HEVC 对照，直接按 H1–H4 在原 H.264 路径上深挖（**更推荐**，因为 err_mbs=0 的偶发已经证明
     H.264 解码通路本身是通的）。

---

## 6. 复现步骤（精确命令）

### 6.1 板子当前状态（接手时应先确认）
- 应该已加载：`hi_mmz_shim.ko` + `hi_vdec.ko`；`/root/m2/` 下有部署包解压出的 5 个文件。
- 检查：
  ```bash
  ssh -i ~/.ssh/id_ed25519 root@192.168.2.21 'uname -r; lsmod|grep -E "hi_vdec|hi_mmz"; md5sum /root/m2/hi_vdec.ko'
  ```
  期望：`7.3.0`；两个模块都在；md5 = `4c60b785378bf0cfe9b96a29f2bec558`。

### 6.2 标准 H.264 复现（非 SED）
```bash
ssh -i ~/.ssh/id_ed25519 root@192.168.2.21
cd /root/m2
pkill -9 vdec_test 2>/dev/null; sleep 1
printf "0x0 0xFFFFFFFF" > /proc/vfmw/info        # 打开 vfmw 全部打印
dmesg -C
(STARTDELAY=1500 timeout 20 ./vdec_test gen3_idr.h264 all >/tmp/t.log 2>&1 &)
sleep 13
dmesg | grep -E "VTSTAT|TSTAT|total_mbs|ErrRatio|store pic"
pkill -9 vdec_test
```
期望（当前故障态）：
```
N: total_mbs=920,err_mbs=920, ErrFrame_Flag: 0
N: store pic err, ret = -1
N: Chan 0: Current frame:N  ErrRatio = 100
```
**注意**：`vdec_test` 的 stdout 重定向到文件时是**全缓冲**，`kill` 会丢日志。
要看它自己的打印用 `stdbuf -o0` 或直接跑前台（`timeout 20 ./vdec_test ... | tail`）。

### 6.3 单帧隔离（很省时间，用来排除队列因素）
```bash
cd /root/m2; (SIMPLE=1 timeout 25 ./vdec_test gen3_idr.h264 >/dev/null 2>&1 &); sleep 12
dmesg | grep -E "ErrRatio|total_mbs"
```
当前结果：单帧仍 `err_mbs=920`。（但偶发 `err_mbs=0` 也出现过 ⇒ 见 §3.6。）

### 6.4 换参数
- `vdec_sed_only=1`：解码但不做 picture-level 处理（不出图，`err_mbs` 不算）——**不是成功判据**。
- `vdec_dfs=1 / EnVcmp=0 / vdec_maxref=16`：常规可调。
- 重新加载模块必须**重启板子**（`rmmod hi_vdec` 会段错误，见 §9）。

---

## 7. 调试手段速查

| 手段 | 用法 | 说明 |
|---|---|---|
| vfmw 全打印 | `printf "0x0 0xFFFFFFFF" > /proc/vfmw/info` | **绝不要用 `0xF8D7`（会重启板子）** |
| 通道快照 | `cat /proc/vfmw/channel` | IsOpen/帧号/Ref,Read,New/DFS/VDH% |
| 统计 | `cat /proc/vfmw/vfmw_statis` | 每 16 帧一行，含 fps、各段耗时 |
| 缓冲 | `cat /proc/vfmw/buffer`、`/proc/vfmw/scd`、`/proc/vfmw/distributor` | 内存/SCD 状态 |
| VDH 寄存器 dump | `insmod hi_vdec.ko vdec_vdh_dump=1` | ioremap 0xF8C30000 后 dump 0x60 dword |
| 自定义 hook | `port_stubs.c` 里的 `hi_vdec_dbg_*`（GBK 安全 ASCII） | 从 .S 调用，标签 12–57 |
| 编译 .S | 改 `*.S` 后 `make ... M=port/vdec modules` | **必须只用 ASCII 注释**；写 `*.tmp` 再 `os.replace`；改完检查符号 |
| 物理内存 | `dd if=/dev/mem bs=65536 skip=$((0x28A00000/65536)) count=32` | MMZ 从 0x28000000 起 |
| 内核 printk 速率 | `SPIC*`/`VTSTAT`/`TSTAT` 都有速率限制 | 别指望每帧一行 |

---

## 8. 刷机 / 恢复手册（已验证）

### 8.1 恢复 Ubuntu（**当前板子就是这个状态，正常不用再做**）
前提材料：`out/board-boot-now.bin`(32MB)、`out/ubuntu-p1.img`(7.5GB)。
1. 板子停在 fastboot：`python3 tools/fb_prompt.py`（看到 `prompt True`）
2. **重启 Windows Tftpd64**（否则 tftp 会挂）
3. 刷 boot 区：
   ```bash
   python3 tools/fb_flash.py v_boot32.bin 0x0 33554432     # 需先把 out/board-boot-now.bin 复制成 hi3798_boot/v_boot32.bin
   ```
4. 刷根分区（断点续传，112 块 × 64MB，约 1.5–2 小时；**每块前会保活 + 必要时重启 Tftpd**）：
   ```bash
   RESUME=0 nohup python3 tools/restore7.py > /tmp/restore.log 2>&1 &
   ```
   日志里出现 `chunk N/112 ok`；完成打 `RESTORE_DONE`。
5. `python3 tools/ser_reset.py`；等 60–75 s；SSH `root@192.168.2.10` 或 `root@192.168.2.21`。

**注意**：fastboot 提示符**空闲约 30 分钟会自动引导**（本轮踩过），长刷写必须保活（脚本已处理）。

### 8.2 刷回原厂 Android（要取 ground truth / 看原厂运行时再刷）
```bash
python3 tools/fb_prompt.py
# 无复位状态下跑（脚本内部已含分区表与偏移，见 tools/xml_flash2.py 的 JOBS）
python3 tools/xml_flash2.py
```
关键点：
- 必须刷**原厂 fastboot**（块 0）+ **原厂 bootargs**（0x800）+ **原厂 kernel bootimg**（0x50000，40MB ANDROID bootimg）。
- **misc 分区必须清零**（原厂 misc 备份里带 `boot-recovery`）→ 否则进 recovery。
- **backup 分区前 64MB 必须清零**（否则 recovery 会去装 update.zip 并驻留）。
- 自建 ext4 不能用 `metadata_csum_seed/orphan_file`：
  `mke2fs -O ^metadata_csum,^64bit,^orphan_file`
- 想拿串口 root shell：刷 `out/vendor/kernel_console.bin`（已把 `init.rc` 里 `start console` 取消注释）到 0x50000。
  进系统后串口直接是 `root@Hi3798MV300:/ #`。
- vendor 播放器：`am start -n com.hisilicon.android.videoplayer/.activity.VideoActivity -a android.intent.action.VIEW -d file:///system/lib/4K.ts -t video/mp2t`
  播放中 READ `/proc/vfmw/channel` 可拿到 §3.1 的 ground truth。
- **代价**：刷 vendor 会覆盖 Ubuntu 根分区（vendor system 在 821MiB 起），必须整盘重刷 Ubuntu 才能回来（≈2 小时）。

### 8.3 原厂分区表（512B 块，来自 `hi3798mv300_M301H_JL.xml`）
| 分区 | 起始块 | 大小 |
|---|---|---|
| fastboot | 0x0 | 1M |
| bootargs | 0x800 | 1M |
| recovery | 0x1000 | 10M |
| deviceinfo | 0x6000 | 2M |
| baseparam | 0x7000 | 8M |
| pqparam | 0xB000 | 8M |
| logo / logobak | 0xF000 / 0x19000 | 20M |
| loaderdb | 0x23000 | 10M |
| fastplay / fastplaybak | 0x28000 / 0x3C000 | 40M |
| kernel | 0x50000 | 40M（ANDROID bootimg） |
| misc | 0x64000 | 20M |
| stbid | 0x6E000 | 1M |
| cache | 0x6E800 | 600M |
| system | 0x19A800 | 700M |
| keydata | 0x2F8800 | 50M |
| trustedcore | 0x311800 | 40M |
| securestore | 0x325800 | 8M |
| backup | 0x329800 | 600M |
| userdata | 0x455800 | -(到末尾) |
| **Ubuntu p1（我们的）** | **0x97000**（302MiB） | 7.5GB |

### 8.4 原厂 kernel/ramdisk 处理（想改 Android 侧时用）
- `out/vendor/kernel_console.bin` 的做法：解出 bootimg 的 ramdisk（newc cpio.gz，可用 Python 解析：
  头 `070701` + 110 字节字段），改 `init.rc`（取消注释 `on property:ro.debuggable=1 / start console`），
  重新打包并**等长替换**回 bootimg（否则偏移全错），最后只改 header 的 ramdisk_size 字段。

---

## 9. 踩坑清单（血泪，务必遵守）

1. **`rmmod hi_vdec` 会段错误**并把模块置成 refcnt=-1，之后只能重启。⇒ 一轮测试只 insmod 一次，参数改了就重启。
2. **部署异常**：`/root/hi_vdec.ko` 曾出现"重启后回退到镜像内旧版本"的现象。⇒ **部署后必须在同一次启动内 md5 校验**再测试。
3. **SSH 连不上**：用串口 `systemctl start ssh.socket` 救；且注意可能只有 `wlan0 192.168.2.21` 可用。
4. **`scp` 后立刻 reset** 会丢文件（两次踩到）⇒ 同一次启动内完成"部署→校验→测试"。
5. **Windows 文件锁**：同一文件名重复覆盖会 `Permission denied` ⇒ 每块唯一文件名。
6. **Tftpd64 挂起**：大文件传输若干次后失效 ⇒ 重启它并等 10 s；不要在复位后立刻 tftp（首次必失败，重试即可）。
7. **fastboot 空闲自启动**：长时间停在 `fastboot#` 会自己 boot ⇒ 长刷写要保活。
8. **改 .S/.c 规则**：只能用 ASCII 注释（GBK 编码文件用 Python 按 latin1 处理），写 `*.tmp` 再 `os.replace`，
   改完必须重编译并确认符号/大小写回。
9. **vfmw 打印开关**：`/proc/vfmw/info` 写 `0xF8D7` 会重启板子（历史踩坑），只用 `0xFFFFFFFF` 或 `0x0`。
10. **`vdec_test` 输出到文件是全缓冲**：被杀时丢日志，用 `stdbuf -o0`。
11. **`memremap(MEMREMAP_WC)` 失败、`ioremap` 对 DDR 返回 NULL** ⇒ DDR 物理地址用 `__va()`（MMZ 在 0x28000000）。
12. **`insmod` 报 `Invalid module format (Invalid ELF section name table type: 0)`** 时：`cp` 成新文件名再 insmod。
13. 改板子越多次越要**记录 md5 + 启动时间**；不确定就复位重来。

---

## 10. 附件 / 文档索引

- 主历史：`docs/porting/HANDOFF-hardware-acceleration-2026-11-04.md`
  - §4.88–§4.94 是 11-05 这一轮（原厂 ground truth、ErrorThred 复核、Ubuntu 恢复全过程）
- 证据目录：`docs/porting/artifacts/venc-reverse/m2-diag/`（91 个文件）
  - 必看：`vendor_channel_groundtruth.txt`、`vendor_hw_decode_baseline.txt`、`errmbs_mbgroup_partial.txt`、
    `vendor_flash_success.txt`、`vendor_groundtruth_summary.txt`、`regs_diff_zero.txt`、`slice_params_identical_envcmp_retraction.txt`
- M4 参考：`docs/porting/artifacts/venc-reverse/README.md`（VENC 成功的方法论：ground truth + diff + 反汇编）
- 本机工具：`/home/jason/bringup-7.3/tools/`（`ser_reset.py`、`fb_prompt.py`、`fb_flash.py`、
  `xml_flash2.py`、`restore7.py`、`flash_kernel2.py`、`zero_misc2.py`）
- 部署包：`/home/jason/bringup-7.3/out/deploy-m2.tgz`
- 端口备份：`/home/jason/bringup-7.3/backup/port-*.tgz`（最新 `port-1105-1944.tgz`）

---

## 11. 下一会话建议行动顺序（每步都有判据，不要跳）

**Step 1（5 分钟）确认环境**
```bash
ssh -i ~/.ssh/id_ed25519 root@192.168.2.21 'uname -r; lsmod|grep -E "hi_vdec|hi_mmz"; md5sum /root/m2/hi_vdec.ko'
python3 -c "print('host ok')"; ls /home/jason/bringup-7.3/out/deploy-m2.tgz
```
判据：7.3.0、两模块在、md5 匹配、deploy 包存在。
若板子不对：按 §8.1 恢复（2 小时）或先看 §2.1 的 `.21`。

**Step 2（15 分钟）复现并抓 `err_mbs=0` 的那一帧**
按 §6.2 跑 3 次，记录每次是否出现 `err_mbs=0`。判据：至少复现一次"偶发全对"。
若三次都是 920：改用 `SIMPLE=1`（§6.3）确认单帧也 920（已确认过一次）。

**Step 3（1–2 小时）给 H1 插桩（最高优先级）**
在 `vdm_hal.S` 的 `VDMHAL_V5R2C1_MakeDecReport`、`VDMHAL_V5R2C1_UpdateHardwareInfo` 入口加 hook，
打印"帧号 / g_HwMem 状态字 / 实时 VDH 寄存器值"。同时开 `vdec_vdh_dump=1` 对照。
判据：确认 `g_HwMem` 副本是否陈旧、MakeDecReport 是否在硬件完成后才被调用。
（改 .S 的规则见 §9.8；备份 `port/vdec` 再改。）

**Step 4（30 分钟）顺手排除 H5**
`EnVcmp=0` + `SIMPLE=1` 单帧：若 `err_mbs` 变 0 ⇒ 命中帧压缩配置问题（直接解决 M2）。

**Step 5（只在 H1/H5 都不成立时）H2/H3**
按 §5 的 H2（`IsVdmReady/IsVdmRun` 副本 vs 实时寄存器）与 H3（`OpenHAL/ArrangeMem` 入参出参打印）验证。

**Step 6（备选）HEVC 对照**
按 §5 H6 改造 `vdec_test`（或另写最小测试程序）建 HEVC 通道；注意 4K 需要 `CAP_LEVEL_4096x2160` 且 mmz 48MB 可能不够。
**不建议**为此重刷 vendor Android：代价 2 小时，且 §3.1 已经证明硬件没问题。

---

## 12. 一句话给接手者
**不要再怀疑硬件、vfmw 版本、汇编逻辑、缓存、ErrorThred。**
现在唯一没解释清楚的是：**为什么 VDH 明明解码成功过（err_mbs=0），repair 信息却绝大多数时候报告整帧错误（ErrRatio=100）**。
从 `MakeDecReport` 读到的状态副本是否陈旧、postproc 调用时机是否正确入手，是最短路径。
