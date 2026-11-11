# Hi3798MV300 Linux 7.x + Ubuntu 单板电脑 — 设计规格（v1.0）

- 状态：已冻结（依据 2026-10-30 与用户的最终确认）
- 平台：HiSTBLinux V100R005C00SPC060，SoC hi3798mv300，DDR3-1866 1GB（32bit），eMMC 8GB
- 目标：把板子改造成一台可日常使用的 Ubuntu（arm64）单板电脑，支持 4K60 H.264/H.265 硬解、HDMI 输出/HDMI 音频、GPU（Mesa/lima）Wayland 桌面、1080p60 硬编码录屏、板载 RTL8822BS WiFi/BT，其余常规外设可用

---

## 1. 目标与非目标

### 1.1 成功标准（验收）
1. 板子能从 eMMC 启动 mainline（v7.3 起）arm64 内核，串口输出 earlycon，进入 Ubuntu 26.04 arm64。
2. HDMI 2.0 输出 1080p60/4K60（视频全屏走 KMS 直出）， HDMI 音频 PCM 可播。
3. mpv/GStreamer 可用 V4L2 M2M 硬件解码 H.264/H.265（1080p60 与 4K60 片源不丢帧为目标）。
4. Wayland（Weston/labwc）桌面可用，Mesa/lima GLES2 加速生效，无软件渲染回退。
5. 屏幕录制 1080p60：PipeWire screencast → VENC（V4L2 M2M）→ 文件，CPU 占用可接受。
6. 板载 RTL8822BS WiFi 可连接、BT 可被发现/连接（hci_uart+btrtl）。
7. eMMC/USB2/3/SATA/以太网/GPIO/I2C/SPI/PWM/RTC/WDT/thermal 正常。
8. 长期运行稳定（72h 播放 + 桌面混合负载无致命错误）。

### 1.2 非目标（不做）
- DVB-C 直播、Tuner/Demod/Frontend/Demux/CI。
- CA/TEE/advca/klad/cipher/OTP/DRM/HDCP、安全启动签名。
- HDR/HDR10/HLG/Dolby Vision、PQ 画质增强、DBE。
- HDMI CEC、IR 遥控、前面板 LED/按键。
- 模拟音频/耳机/SPDIF/麦克风；音频只保留 HDMI PCM。
- VI/摄像头/HDMI-in 采集；PVR 时移。
- 多图层/PIP/画中画；硬件 JPEG/PNG 编解码（软件替代）。

---

## 2. 硬件与现状依据

| 项目 | 事实 | 来源 |
|---|---|---|
| SoC | hi3798mv300，Cortex-A53（SDK 用户态按 -mcpu=cortex-a53 编译） | `base.mak:284-289` |
| DDR | DDR3-1866 1GB 16bit×2（32bit，峰值 ≈7.5GB/s） | `cfg.mak:1097` |
| eMMC | 8GB；当前分区布局 fastboot/bootargs/baseparam/pqparam/logo/kernel(32M)/rootfs(256M)/ubuntu | `configs/hi3798mv300/prebuilts/emmc_partitions.xml` |
| 显示 | HDMI 2.0 支持 4K50/60（594MHz TMDS） | `source/msp/drv/hdmi/hdmi_2_0/drv_hdmi_intf_k.c:720-727` |
| 硬解 | VDEC v2.0（mv300），支持到 2160p；固件 VFMw v5.0 有汇编源码 | `source/msp/drv/vdec/Makefile:18-25`、`source/msp/drv/vfmw/Makefile:17-29` |
| 硬编 | VENC v2.0，H.264/H.265 编码 | `source/msp/drv/venc/venc_v2.0/drv_venc_efl.h` |
| GPU | Mali-450（Utgard），mainline `lima` 支持 | `cfg.mak:1357`、`source/msp/drv/gpu/utgard` |
| WiFi/BT | RTL8822BS（SDIO WiFi + UART BT；当前 DB 里 BT 开关关闭） | `cfg.mak:1464`、`source/component/wifi/drv/sdio_rtl8822bs` |
| 启动链 | 32 位 fastboot，从 eMMC kernel 分区 `bootm` uImage；arm64 启动路径依赖 TEE/ATF 配置 | `source/boot/fastboot/arch/arm/lib/bootm.c`、`source/boot/fastboot.mak:56` |
| ATF | 仅有 hi3798cv200/hi3798mv200/hi3796mv200 平台，无 mv300 | `source/kernel/arm-trusted-firmware/plat/hisilicon` |

---

## 3. 总体架构

```
eMMC: fastboot(1M) | bootargs(1M) | baseparam(4M) | pqparam(4M) | logo(4M)
      | kernel(32M, uImage=Image+DTB) | rootfs(256M, 保留) | ubuntu(~7G, ext4)
                                   │
                        fastboot bootm 0x1FFFFC0
                                   │
                  Linux 7.3 arm64 (mainline)
        ┌──────────────┬──────────────┬───────────────┬──────────────┐
        │ V4L2         │ DRM/KMS      │ ASoC          │ rtw88/btrtl  │
        │ VDEC/VENC/   │ VO+HDMI      │ HDMI audio    │ WiFi/BT      │
        │ VPSS (M2M)   │ (4K60 modes) │ (PCM)         │ (8822BS)     │
        └──────────────┴──────────────┴───────────────┴──────────────┘
                  Ubuntu 26.04 arm64 rootfs (systemd + Wayland)
        Weston/labwc + Mesa/lima(GLES2) + GStreamer/mpv + PipeWire
```

### 3.1 启动链
- bootloader：沿用板载 32 位 fastboot（不引入 U-Boot）。
- 内核镜像：mainline arm64 `Image`（必要时裁剪以 <31MB）与 DTB 一起封装成 uImage；DTB 追加在 uImage payload 之后（fastboot `bootm` 用 `image_get_image_end` 校验 FDT）。
- bootargs：写在 DTS `/chosen/bootargs`，`console=ttyAMA0,115200 earlycon=pl011,0xf8b00000 root=/dev/mmcblk0p8 rootfstype=ext4 rootwait rw cma=256M`（去掉 `mmz=ddr`）。
- arm64 启动路径风险：当前 fastboot 源码中 arm64 启动位于 `CONFIG_TEE_SUPPORT`/`CONFIG_TEE_ATF_SUPPORT` 或 `CONFIG_SBL_VXX_UXX` 分支。需验证板载 fastboot 是否支持；不支持则按 D3 决策处理（移植 ATF 或给 fastboot 增加非 TEE arm64 启动路径）。

### 3.2 内核驱动边界
- 全部走标准 Linux 框架：V4L2（M2M）、DRM/KMS、ASoC、ALSA、mac80211（rtw88）、Bluetooth（btrtl/hci_uart）。
- 不再使用 vendor `msp` 用户态、`libHA.AUDIO`、`libhigo`、`libMali`、CA 库。
- 厂商 4.4 驱动源码仅作为寄存器序列/初始化参考，所有驱动重新实现为 7.x 风格。

### 3.3 用户态
- Ubuntu base 26.04 arm64（`third_party/open_source/ubuntu-base-26.04.1-base-arm64.tar.gz`）。
- 播放：GStreamer（v4l2 M2M、waylandsink）与 mpv（`--hwdec=v4l2m2m`）。
- 桌面：Weston（bring-up）→ labwc/lxqt（日常）；Mesa/lima GLES2。
- 录屏：xdg-desktop-portal-wlr/PipeWire → GStreamer → v4l2h264enc → 文件。
- 无线：linux-firmware + wpa_supplicant/NetworkManager；BT 用 bluez。

---

## 4. 关键设计决策（D 编号见 risk-register-and-decisions.md）

- D1 内核基线：v7.3（2026-10-18 主线）；开发期跟 7.3.y，产品冻结时切最近的 7.x LTS（7.x 目前无 LTS，最近 LTS 是 6.18）。
- D2 架构：arm64 内核（Cortex-A53），Ubuntu arm64；不使用 armhf。
- D3 启动方案：优先复用 fastboot 既有 arm64/TEE 路径；若板载 fastboot 不支持，则 P0 之后按预案 A（移植 ATF plat）或预案 B（fastboot 非 TEE arm64 启动补丁）推进。
- D4 显示：DRM/KMS 重写（1 CRTC + primary/overlay），视频零拷贝直出；`simpledrm/fbdev` 仅作早期点亮手段。
- D5 音频：仅 HDMI PCM（ASoC hdmi-codec + simple-audio-card）。
- D6 录屏：只录屏幕、1080p60；VENC V4L2 M2M + PipeWire 管线。
- D7 无线：WiFi 用 mainline rtw88（rtw8822bs，SDIO）+ linux-firmware；BT 用 btrtl+hci_uart；厂商 4.4 驱动仅作参考。
- D8 内存：CMA 256M（4K 场景可调 384M）；zram 256M；桌面建议 1080p60，4K60 用于视频全屏直出。
- D9 分区：沿用 302M 之前的 bootloader 区；ubuntu 分区扩到 ~7G，Sel=1，镜像名改为 `ubuntu-rootfs_7168M.ext4`。
- D10 构建环境：不安装系统级交叉编译器（无 sudo）；使用从 TUNA 镜像下载的 Ubuntu 26.04 cross 工具链 deb 解包到 `/home/jason/bringup-7.3/toolchain`，运行时设 `LD_LIBRARY_PATH`。

---

## 5. 内存与带宽预算（1GB DDR3-1866）

| 项 | 预算 |
|---|---|
| 内核 + 页缓存/系统 | 150–250MB |
| Ubuntu base + Weston/labwc + PipeWire | 250–400MB |
| CMA（视频/显示/GPU 预留） | 256MB（4K 时 384MB） |
| 4K 解码缓冲（8–16 帧） | 100–400MB（含在 CMA/dma-heap） |
| zram（压缩 swap） | 256MB |

结论：1080p60 桌面 + 1080p60 视频/录屏可稳态运行；4K60 视频采用全屏 KMS 直出 + cage/Weston 轻会话，桌面仍按 1080p60。

---

## 6. 验收测试矩阵（详见 test 文档）

1. 启动：串口 earlycon、Ubuntu 登录、`uname -a` 为 7.3 arm64。
2. 显示：`modetest` 枚举 4K60 模式；HDMI 电视出画面。
3. 硬解：`gst-launch-1.0 filesrc ! qtdemux ! h264parse ! v4l2h264dec ! waylandsink`；`mpv --hwdec=v4l2m2m`。
4. 硬编录屏：PipeWire 录制 1080p60 10 分钟，检查文件、CPU、掉帧。
5. 音频：HDMI 播放 PCM 音轨。
6. 无线：WiFi iperf、BT 配对。
7. 外设：USB 键鼠/U 盘、SATA、以太网、RTC/WDT。
8. 稳定性：72h 混合负载。

---

## 7. 风险摘要（详见 risk-register-and-decisions.md）

- R1 arm64 启动路径（fastboot/TEE/ATF）— 最高风险。
- R2 VO/HDMI DRM/KMS 驱动无主线参考 — 工作量最大。
- R3 VDEC/VFMw 固件与 V4L2 适配 — 技术复杂度高。
- R4 1GB 内存/带宽下 4K60 + 桌面 — 需持续调优。
- R5 VPSS 缩放/去隔行重写 — 影响画质与兼容性。
- R6 rtw88 SDIO + BT 固件/使能脚适配。
- R7 无 TRM 资料时寄存器反推 — 工期不确定性。

## 8. As-Built 状态（2026-11-01 实测）

实现结果与差距详见 `docs/porting/spec-traceability-2026-11-01.md`（规格→实现→证据矩阵）与 `docs/porting/FINAL-DELIVERY-2026-11-01.md`。

摘要：
- ✅ 启动链/Ubuntu/静态网络/SSH/Samba/USB2 存储/WiFi 驱动与扫描/桌面+RDP/1080p KMS 输出已达成。
- ⚠️ GPU GL（lima VBO 重负载限制）、软件录屏、部分外设、稳定性未满 72h、WiFi 连接（待凭据）为部分达成。
- ⛔ 4K 输出、4K VDEC/VENC、HDMI 音频、蓝牙受限于 vendor 私有驱动/固件/硬件资料，本阶段不投入。
