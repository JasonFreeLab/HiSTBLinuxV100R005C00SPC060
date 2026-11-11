# 硬件加速任务计划（VDEC/VENC 强需求）— 2026-11-03

状态：进行中（M0 完成）
关联：`docs/porting/vdec-venc-porting-plan-2026-11-03.md`（初版计划）、`docs/porting/logs/p4-vdec-m0-spike-2026-11-03.log`

## 1. 目标

### 1.1 强需求（必须交付）
1. **VDEC 硬件解码**：至少 H.264 1080p 硬件解码，播放器可用（mpv/ffmpeg 或自研播放器），≥30fps 无丢帧。
2. **VENC 硬件编码**：至少 H.264 1080p 硬件编码（录屏/转码），≥25fps。

### 1.2 中等需求（尽力）
3. **JPEG/MJPEG 硬解**：作为最小编译/接口验证路径（M1）。
4. **GPU 加速**：lima GL 简单场景可用；GPU 调频需先实现 SoC 内置调压器（PMC 0xF8A23020）。
5. **2D 加速**：TDE/VPSS（可选，如时间允许）。

### 1.3 非目标
- HDMI 音频、4K 输出（HDMI TX 不可 CPU 访问，另行记录）
- 蓝牙硬件（已知硬件未启用）

## 2. 现状与依据

| 项目 | 现状/证据 |
|---|---|
| 厂商栈规模 | vdec 62.7k、vfmw 141k、hal 61.3k、omxvdec 29.3k、venc 49k、tde 33.5k、gfx2d 13.4k、jpeg 4.7k、api 26.4k 行 |
| M0 试编译 | JPEG: 单文件 0 error/0 未解析符号；全驱动 73 errors（机械性问题） |
| 内存模型 | 厂商用 MMZ 私有分配器；mainline 用 CMA/dma-buf |
| 接口 | 厂商私有 ioctl（无 V4L2） |
| GPU 电压 | SoC 内置调压器 PMC 0xF8A23020（驱动源码缺失）；我们未调压，故 GPU 保持 200MHz |
| 固件 | VDEC/VENC 依赖 vfmw/微码固件（厂商二进制） |

## 3. 技术方案

### 3.1 驱动适配策略
- **shim 层**：`port/` 工作区，统一 mainline 兼容头（`shim.h`）解决老内核 API、宏、寄存器类型头。
- **寄存器访问**：沿用厂商 `hi_reg_*.h` 结构体定义，ioremap 方式与现有 hi3798_drm 一致。
- **中断/时钟**：改用 mainline 框架（devm_request_irq、clk 框架已在 DTS 中）。
- **内存**：第一步保留 MMZ 语义但用 CMA 实现最小分配器（或 dma-buf heaps），后续再优化。

### 3.2 接口策略（渐进）
1. **M1-M2**：保留厂商 ioctl（`/dev/hi_jpeg`、`/dev/hi_vdec`）+ 自研 userspace 测试程序（最快验证硬件）。
2. **M3**：在驱动内/外增加 **V4L2 mem2mem**（JPEG）与 **V4L2 stateful decoder**（H.264/HEVC）接口，ffmpeg/mpv 直接可用。
3. 用户态：优先复用 `msp/api` 源码（重编译 aarch64/glibc）；若有困难，按厂商 UAPI 自写轻量 lib。

### 3.3 构建
- 工作目录：`/home/jason/bringup-7.3/port/{jpeg,vdec,vfmw,hal}`，Kbuild 外挂模块。
- 服务器板：FIP 保持现有；驱动以 `.ko` 形式部署到 `/lib/modules/7.3.0/...`（与 rtw88 模块同方式），避免反复刷固件。
- 固件文件：从厂商 SDK/原厂 system 提取（vdec 固件缺失需确认；venc 微码在 drv/venc/*/firmware）。

## 4. 里程碑与验收

### M1 JPEG 硬解（预计 1-2 周）
任务：
- [x] 修完全部编译错误（73 → 0；CHIP_TYPE/GFX SDK 宏、寄存器头、DEFINE_SEMAPHORE、vm_flags、GFX HAL 头）
- [ ] MMZ→CMA 最小分配器
- [x] 驱动 probe 成功：hi_jpeg.ko 加载 rc=0，/dev/jpeg (major 248) 创建，dmesg 无 oops（2026-11-03）
- [x] 自研 `jpeg_test`：1080p JPEG 硬解 **189fps**（5.3ms/帧），Y 平面 PSNR **66.16dB**（2026-11-03 验收通过）
- [ ] 可选：V4L2 mem2mem + ffmpeg MJPEG 解码（未做，厂商 ioctl 路径已可用）
验收：`jpeg_test` 输出正确图像（Y PSNR 66.16dB），189fps ✅

### M2 VDEC 单路 H.264（预计 4-8 周）
任务：
- [ ] 移植 vfmw 框架（先 H.264 8bit）
- [ ] vdec 驱动 probe、固件加载（若需固件，从原厂 system 提取）
- [ ] MMZ 替换为 CMA/dma-buf
- [ ] 自研 `vdec_test`：1080p H.264 解码 ≥60fps，md5 与软解一致
验收：自研测试 ≥60fps、输出正确；`mpv` 可播放（先通过自研 lib 封装 ioctl）。

### M3 V4L2 接口与播放器集成（预计 2-4 周）
- [ ] V4L2 stateful decoder（H.264；HEVC 次之）
- [ ] `mpv --hwdec=v4l2` 或 `ffmpeg -hwaccel v4l2` 播放 1080p H.264 无丢帧
验收：1080p H.264 30fps 播放 CPU 占用 <30%，无丢帧。

### M4 VENC 硬件编码（预计 4-6 周）
- [ ] venc 驱动 + 微码固件加载
- [ ] V4L2 encoder（H.264）
验收：`ffmpeg -c:v h264_v4l2m2m` 1080p 30fps 编码，码率/延迟达标。

### M5 可选：TDE/VPSS 2D 加速、GPU 调压+调频
验收：GPU 600MHz 稳定（需先实现 PMC regulator），简单 GL 性能提升。

## 5. 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| vfmw 无文档、固件兼容性 | M2 卡住 | 先跑 H.264 单路最小流程；对照原厂 system 固件/日志 |
| MMZ 语义差异大 | 内存错误/崩溃 | 先 1:1 CMA 分配器；缓冲对齐/物理连续用 CMA |
| 厂商 ioctl UAPI 复杂 | 用户态工作量大 | 先用厂商 msp/api 源码重编译；必要时自写最小 lib |
| 驱动与 7.3 API 差异多 | 编译/运行问题 | 以 JPEG（4.7k 行）为试点修正 shim，再复用到 vdec |
| 无 PMIC 电压控制 | GPU 无法提速 | 逆向 PMC 0x20；或放弃 GPU 提速（VDEC 不依赖） |
| 时间成本 | 需求延期 | 按里程碑逐步交付，每阶段可独立验证 |

## 6. 执行规则
- 每轮只推进一个里程碑中的可验证小步，编译/运行结果写入 `docs/porting/logs/`。
- 驱动部署走 `.ko` + depmod，不改 FIP（除非必要）。
- 每步完成更新本计划勾选状态与进度账本。

## 7. 执行进度（2026-11-03）

- M0 ✅ 完成：厂商 JPEG 驱动试编译（单文件 0 error；全驱动 73→0 error）
- M1 进行中：
  - ✅ 驱动编译通过（Kbuild + shim.h + port_stubs.c）
  - ✅ 上板加载成功：`insmod hi_jpeg.ko` → rc=0，dmesg: dts irq→virq 38、ioremap OK、
    MODULE_Register rc=0、osal_request_irq(129) rc=0、SetIrq OK、MapSmmuReg OK
  - ✅ 设备节点 `/dev/jpeg`（major 248）创建成功
  - ✅ MMZ→CMA：hi_mmz_shim.ko (/dev/hi_mmz) 分配/mmap/读写/释放验证通过
  - ✅ 用户态厂商库编译：hi_jpeg_api.c/jpeg_hal_dev.c/jpeg_hal_dec.c 0 error；libmmz_shim 提供 HI_MPI_MMZ_*/SMMU_*
  - ✅ jpeg_test 全链路跑到 StartDecompress；输出缓冲 CMA 物理地址分配成功
  - ⏳ JPEG 解码：StartDecompress 超时；已修复 SMMU reset+bypass（SCR=1），但 JPEG 寄存器块读回恒为 0x2（总线无响应），IRQ 0 次 → 怀疑 MV300 基址差异或 IP 未集成；下一步 U-Boot md 验证
  - ⏳ 待做：1080p JPEG 硬解性能（≥50fps）与正确性对比
- 关键适配点（已解决）：CHIP_TYPE_hi3798mv300、CONFIG_GFX_STB_SDK、DEFINE_SEMAPHORE 单参、
  vm_flags_set、ioremap_nocache、DTS JPEG 中断节点（GIC_SPI 97）、PM 设备节点注册

### M1 验收结论（2026-11-03）
- ✅ JPEG 硬件解码跑通：1080p 单帧 5.3ms（189fps），Y 平面 PSNR 66.16dB
- 关键修复：DTS 中断映射、SMMU 复位+bypass、CRG31 时钟/复位脉冲、MMZ→CMA、用户态 API 适配
- 证据：docs/porting/logs/p4-jpeg-m1-acceptance-2026-11-03.log
