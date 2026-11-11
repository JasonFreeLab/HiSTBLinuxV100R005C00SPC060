# 驱动技术规格（v1.0）

本文档定义每个硬件子系统在 Linux 7.x 下的目标框架、DTS 约定、实现路径与验收标准。厂商 4.4 源码只作为寄存器/时序参考，不复用其 UAPI。

## 0. 已知地址（来自 vendor DTS/代码，P0 需实测确认）

| 块 | 地址 | 来源 |
|---|---|---|
| GIC-400 | dist 0xF1001000 / cpu 0xF1002000 / hyp 0xF1004000 / vctrl 0xF1006000 | `arch/arm64/boot/dts/hisilicon/hi3798mv200.dts`、mainline `hi3798cv200.dtsi` |
| PL011 UART0 | 0xF8B00000，SPI 49 | vendor dts + `CONFIG_HISI_DEBUG_UART_PHYS` |
| 系统 timer | 0xF8A29000（vendor clocksource） | vendor `hi3798mv200.dts:407` |
| 内存 | 0x0 起 1GB（0x40000000） | DDR3-1866 1GB 配置 |
| HDMI 2.0 4K60 | 594MHz TMDS | `source/msp/drv/hdmi/hdmi_2_0/drv_hdmi_intf_k.c:720` |

> 其余媒体块（VDEC/VPSS/VO/HDMI/VENC/GPU）寄存器基址需从 `source/msp/drv/*` 的 `include` 头文件与 `mach-hi3798mv2x` 中提取，P2–P5 阶段逐项确认并记录。

## 1. 显示（VO + HDMI）→ DRM/KMS

- 目标：单 CRTC + primary plane + 1 个 video overlay plane；支持 1080p60/4K60 模式、EDID、HDMI 音频 ELD。
- 结构：`drivers/gpu/drm/hisilicon/hi3798/`（自建目录），文件建议：
  - `hi3798_drm_drv.c`（DRM device/CRTC/plane 注册）
  - `hi3798_vo.c`（VO/DC 时序、layer 配置）
  - `hi3798_hdmi.c`（HDMI PHY/PLL、EDID、模式）
  - `hi3798_hdmi_audio.c`（ASoC hdmi-codec 绑定）
- DTS：`display`、`hdmi`、`vou` 节点；`ports/endpoints` 连接 encoder/bridge。
- 验收：`modetest -M hi3798` 列出 4K60；电视出图；`aplay -D hdmi` 出声。
- 参考：vendor `msp/drv/vo`、`msp/drv/hdmi`（hdmi_2_0）、mainline `hi3798cv200.dtsi` 的 GIC/时钟写法。

## 2. 视频解码（VDEC + VFMw）→ V4L2 M2M

- 目标：`/dev/videoX` stateful mem2mem H.264/H.265 解码，支持 1080p60/4K60；输出 DMABUF 供 DRM/VPSS 使用。
- 结构：`drivers/media/platform/hisilicon/hi3798-vdec/`：
  - `hi3798_vdec_drv.c`（V4L2 M2M 注册、队列、格式）
  - `hi3798_vdec_hw.c`（VPU 寄存器/中断/时钟/复位）
  - `hi3798_vfmw.c`（VFMw v5.0 固件加载与消息环）
- 固件：`source/msp/drv/vfmw/vfmw_v5.0` 汇编源码 → 生成固件镜像，作为 `firmware` 由驱动加载（或编译进内核）。
- DTS：`vdec@...` 节点（基址/中断/时钟/复位/保留内存）。
- 验收：mpv `--hwdec=v4l2m2m` 播 4K60 HEVC，CPU<30%，掉帧<1%。

## 3. 视频后处理（VPSS）→ V4L2 M2M 或 DRM 属性

- 目标：缩放、去隔行、CSC；1080p 内容输出 4K 屏必需。
- 方案：优先 V4L2 M2M scaler 节点；若 DRM plane 支持硬件缩放则并入 DRM。
- 验收：1080p60 输入 → 4K60 输出，`v4l2-ctl` 可枚举格式/尺寸。

## 4. 视频编码（VENC）→ V4L2 M2M

- 目标：H.264/H.265 编码，1080p60（录屏）；输入为 DRM/PipeWire 帧（DMABUF）。
- 结构：`drivers/media/platform/hisilicon/hi3798-venc/`。
- 验收：GStreamer `v4l2h264enc` 录屏 1080p60 10 分钟，CPU 可接受，文件可播。

## 5. 音频（HDMI PCM）→ ASoC

- 目标：仅 HDMI 音频，PCM 输出；ASoC `hdmi-codec` + simple-audio-card；ELD 从 HDMI 驱动获取。
- DTS：`sound` 节点连接 HDMI codec。
- 验收：`aplay -D hdmi` 播放 48kHz PCM；`pactl list sinks` 可见。

## 6. GPU（Mali-450）→ lima + Mesa

- 目标：mainline `lima` 驱动 + Ubuntu Mesa（GLES2）；Wayland compositor 使用 GLES2。
- DTS：`gpu@...` 节点（寄存器、中断、时钟、电源域、复位）。
- 验收：`es2_info` 显示 lima；Weston/labwc 桌面无 llvmpipe 回退；4K 视频全屏走 KMS 直出。

## 7. WiFi/BT（RTL8822CS）

- WiFi：mainline `rtw88` 的 `RTW88_8822CS`（SDIO）+ `linux-firmware` 中 `rtw88/rtw8822c_*`；DTS 需要 SDIO 控制器节点、`WL_EN` GPIO、32k 时钟。
- BT：`btrtl` + `hci_uart`（UART/H5），固件 `rtl_bt/rtl8822cs_config.bin`（若缺失用厂商文件）；DTS 需要 UART 节点与 `BT_EN` GPIO。
- 验收：WiFi 连接 + iperf；`bluetoothctl` 扫描/配对成功。
- 备注：当前 SDK `cfg.mak` 已选 RTL8822CS，但 `CFG_HI_BLUETOOTH_SUPPORT` 关闭；板级原理图的使能脚/32k 来源必须确认。

## 8. 存储/网络/外设

| 子系统 | 方案 | 验收 |
|---|---|---|
| eMMC | mainline dw-mshc（如 IP 兼容）或基于 dw_mmc 的 host 驱动 | 根文件系统挂载、读写稳定 |
| SD | 同上（如有卡槽） | 插拔识别 |
| 以太网 | mainline `hix5hd2_gmac`（`hisi-gmac-v2`） | `iperf3` 达标 |
| USB2/3 | EHCI/OHCI + dwc3 | 键鼠/U 盘/SSD |
| SATA | ahci-platform | 硬盘识别/读写 |
| GPIO/I2C/SPI/PWM/RTC/WDT/thermal | 通用驱动 + DTS | sysfs/devicetree 验证 |
| 录屏 | PipeWire screencast + VENC | 见 §4 |

## 9. 内存与零拷贝

- 预留 CMA：`cma=256M`（4K 时 384M）；媒体缓冲用 dma-buf heaps。
- V4L2 M2M 输出 DMABUF → DRM plane（zero-copy）；录屏 PipeWire DMABUF → VENC。
- 禁止任何 mmz/物理连续分配接口进入用户态。

---

# 2026-11-01 补充：实测寄存器序列与驱动要点

## USB2 PHY（hi3798_usb2_early，vendor clk-hiusb2.c）
- 2-port PHY @0xf9865000：0x18=0x4、0x408=0x6c、0x474=0x1e、0x400=0x1c、0x410=0xd7、0x47c=0x0e
- 1-port PHY @0xf9960000：0x008=0x6c、0x074=0x1e、0x000=0x1c、0x010=0xd7、0x07c=0x0e
- OTP trim 写 0xf8030000+0xc、0xff2f4000+0xc、**0xff2f4000+0x40c**
- 修正后 U 盘（Kingston 62GB exfat）正常枚举，读 36MB/s。

## USB3 xHCI（hi3798_usb3_early，vendor clk-hiusb3.c host0）
- CRG0xb0：bus clken bit0/5/6、清 VCC reset bit12、utmi/pipe/suspend/ref clken bit1-4
- CRG0xbc：清 USB2 1p POR bit6、清 2p UTMI reset bit10
- COMBPHY0 CRG0x188：REF_SEL1 bit3、REF_CKEN bit0、清 POR bit4
- xHCI：GCTL(0xc110) [13:12]=01 host；GUSB2PHYCFG0(0xc200) 清 bit3/4；GUSB3PIPECTL0(0xc2c0) bit17/1/4；GTXTHRCFG=0x23100000、GRXTHRCFG=0x23180000
- 必须在 xhci 驱动 probe **之前**完成（early_initcall），否则 Host halt -110。root hub 480M+5000M 注册成功。

## SDIO2 + RTL8822BS（WiFi）
- DT：`mmc@f9c40000`，`snps,dw-mshc`，clocks HISTB_SDIO2_BIU/CIU（CRG0x28c bit0/1），resets <&crg 0x28c 4>，4bit、non-removable、cap-sdio-irq、max 50MHz。
- `mmc1: new SDIO card at address 0001`；rtw88_sdio 探测，固件 `rtw8822b_fw.bin` → `Firmware version 30.20.0`，wlan0 可用。

## AIAO 音频上电（hi3798_aiao_early，vendor AIAO_HW_PowerOn）
- AIAO base 0xF8CD0000；COM HW_VERSION@0x24、STATUS@0x30(bit0 srst_rdy)；TX0 @0x2000。
- CRG70(0x118)：bit0 cken、bit4 srst_req、bit8 clk_sel、bit12-16 skipcfg、bit17 loaden、bit20-21 mclk_sel；MV300 mclk_sel=0、clk_sel=1(50M)。
- 序列：复位→等 srst_rdy=0→cken→解复位→等 srst_rdy=1→clk_sel/loaden → 实测 ver=0x20130516、cap=0x03070001。

## HDMI TX 访问结论
- HDMI TX base 0xF8CE0000（音频块 +0x1000、AIDEO +0x800、PHY +0x1800）；bootloader 管理并正常输出画面。
- 从 Linux 侧 ioremap 读该窗口全部为 0；对 CRG0x110 逐位扫描无效 → 判断该窗口被 bootloader/ATF 隔离或属独立 MCU 域。**HDMI 音频需移植 vendor HDMI 驱动/HDMI MCU 固件，暂不可行**。
