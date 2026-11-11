# VDEC/VENC 移植到 mainline（方案 B）— 工作计划 2026-11-03

## 一、厂商栈清单（source/msp）

| 组件 | 行数 | 作用 | 移植难度 |
|---|---|---|---|
| `drv/vdec` | 62.7k | 解码驱动（v1.0/2.0/2.1） | ★★★★★ |
| `drv/vfmw` | 141.0k | 视频固件管理（多标准解码器调度） | ★★★★★ |
| `drv/omxvdec` | 29.3k | OpenMAX 适配 | ★★★★ |
| `drv/venc` | 49.0k | 编码驱动 + 微码固件 | ★★★★★ |
| `drv/gfx2d` | 13.4k | 2D/SMMU 图形公共层 | ★★★ |
| `drv/jpeg` | 4.7k | JPEG 硬解/硬编 | ★★ |
| `drv/tde` | 33.5k | 2D 加速 | ★★★ |
| `component/hal` | 61.3k | 厂商 GFX HAL（hi_drv_* 实现） | ★★★★ |
| `msp/api`（vdec/venc/omx） | 26.4k | 用户态 API | ★★★ |
| `gstreamer` 集成 | - | OpenMAX 插件 | ★★ |

**总计 ~355k 行**（不含内核基础 kapi/MMZ）。

## 二、主要移植障碍

1. **内核 API 差异**：驱动为 Linux 4.4 编写（`asm/uaccess.h`、`get_fs`、`procm`、`ioremap_nocache` 等），需适配 7.3。
2. **MMZ 私有内存管理器**：厂商物理连续内存分配 → 需替换为 CMA + dma-buf（或移植 sec_mmz）。
3. **vfmw 固件/微码**：解码器依赖厂商固件加载与调度框架（141k 行，含专有算法接口）。
4. **厂商 GFX HAL**：hi_drv_jpeg/vdec 的 `HI_DRV_*` 实现在 component/hal + gfx2d（含 SMMU 配置）。
5. **中断/时钟/复位/电源**：厂商 PM/DVFS 接口（drv/pm）与 mainline 无对应。
6. **用户态**：msp/api 为 ARM32 Android/glibc 混合构建，需重编译 aarch64 + 适配；播放器需通过 OMX/GStreamer 或 V4L2 接入。
7. **无 V4L2 接口**：若要让 ffmpeg/mpv 直接用，需在驱动外再包一层 V4L2 或 V4L2 Request API（额外工作量）。

## 三、分阶段计划

### M0 可行性验证（本次会话内可完成）
- 建立独立移植目录 + Kbuild 骨架
- 选取 **drv/jpeg（4.7k 行）** 试编译，列出具体 API/头文件阻塞清单
- 产出：`porting-notes` + 编译错误统计 + 依赖闭包
- 验收：能明确回答"一个最小厂商驱动要改多少处才能编译"

### M1 JPEG 硬解（V4L2 mem2mem）
- 用厂商 jpeg 驱动寄存器逻辑 + mainline V4L2 mem2mem 框架实现 JPEG 硬件解码
- 验收：`v4l2-ctl` 解码 1080p JPEG ≥50fps，ffmpeg/mpv 可用（MJPEG 视频加速）

### M2 vfmw + VDEC 单路 H.264
- 移植 vfmw 框架（先 H.264 8bit 1080p），MMZ→CMA shim
- 对齐厂商 ioctl 与 mainline 内存模型；优先走厂商 API + 自研 userspace（不改 ffmpeg）
- 验收：自研 `hi-vdec-test` 解 1080p H.264 ≥60fps

### M3 V4L2 接口 + 播放器集成
- 驱动外包装 V4L2 stateful/stateless 解码器（或提供 libva 接口）
- 验收：`mpv --hwdec=v4l2` 播放 1080p H.264 无丢帧

### M4 VENC
- 移植 venc 驱动 + 微码；V4L2 encoder 接口
- 验收：`ffmpeg -c:v h264_v4l2m2m` 1080p 编码 ≥30fps

## 四、风险与结论

- 工作量：M1 约 1-2 周、M2 4-8 周、M3 2-4 周、M4 4-6 周（有经验工程师，单人）。
- 关键风险：vfmw 专有算法接口无文档、固件二进制兼容性、DVFS/电源缺失导致性能不稳。
- 备选：若时间不可接受，双系统（Ubuntu + 原厂 Android）是唯一快速获得硬解的方案。
