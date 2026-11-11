# 剩余未完成功能可行性分析（2026-11-01，Round 62）

本文档评估 4 项尚未完成规格要求的实现路径、vendor 资源、工作量与风险，作为后续决策依据。

---

## 1. HDMI 音频（规格 P2.4）

### 现状
- AIAO（音频输入输出 IP，base `0xF8CD0000`，IRQ 84）已成功上电：`ver=0x20130516, cap=0x03070001`（见 `hi3798_aiao_early()`）。
- HDMI TX（`0xF8CE0000`；音频寄存器块 `+0x1000`）由 bootloader 的 vendor HDMI 固件完整驱动，电视 HDMI 画面正常。
- **从 Linux CPU 侧 ioremap 读 HDMI TX 全部寄存器返回 0**；对 CRG0x110 逐位扫描无效。
- 判断：HDMI TX 寄存器窗口被 bootloader/ATF 隔离，或 HDMI TX 属独立 MCU 域（vendor HDMI 驱动带 C8051 MCU 固件 `c8051_hdcp22_program.bin` 等）。

### vendor 资源
| 组件 | 位置 | 规模 |
|---|---|---|
| HDMI 驱动（2.0 IP） | `source/msp/drv/hdmi/hdmi_2_0` | **141 文件 / 100,935 行** |
| AIAO 音频驱动 | `source/msp/drv/aiao/aiao_v1_1` | 66 文件 / 40,683 行 |
| HDMI MCU 固件 | `hdmi_2_0/hal/ctrl/imagev200/c8051_hdcp22_program.bin` 等 | — |

### 实现路径（若要做）
1. 移植 vendor HDMI TX 驱动（含 HDMI MCU 固件加载、PHY 配置、infoframe、ACR/N/CTS），约 100k 行级别的裁剪（PCM 音频可只取 HDMI1.4/2.0 audio 子集，估 5–10k 行）；
2. 移植 AIAO 的 AO 通道子集（寄存器初始化、DMA 环形缓冲、HDMI/I2S 输出模式），估 3–5k 行；
3. 接入 ALSA/ASoC（simple-card 或自写 platform driver）；
4. 验证：`aplay` 出声 + 电视识别 PCM 48kHz。

### 工作量/风险
- 估计 **10–20 人日**（熟悉 vendor 代码前提）；风险高（依赖 HDMI MCU 交互协议文档缺失）。
- **当前结论：短期内不做**。AIAO 上电作为后续基础保留。

---

## 2. VDEC 4K 硬解（规格 P2.5/P4）

### 现状
- mainline 无 HiSilicon VDEC 驱动（OpenMAX/vdec 私有 IP，非 Hantro/Verisilicon 路线）。
- 当前 1080p H.264 软件解 ~25 FPS（mpv），4K 不可用。

### vendor 资源
| 组件 | 位置 | 规模 |
|---|---|---|
| VDEC 驱动（v2.0/v2.1） | `source/msp/drv/vdec` | 26 文件 / **60,488 行** |
| OpenMAX VDEC 封装 | `source/msp/drv/omxvdec` | 47 文件 / 26,007 行 |
| 中断 | IRQ 95 (vdec_vdh)、97 (jpeg)、104/105/106 (scd/safe) 等 | — |

依赖：vendor 的 MMZ（媒体内存管理）/ 内存池、硬件描述（VDH/SCD/JPEG 寄存器表）、可能的固件。

### 实现路径
1. 把 VDEC 硬件抽象层移植成 mainline 风格驱动（V4L2 或 DRM 私有接口），完成寄存器初始化、码流解析中断、参考帧管理、tile 输出；
2. 提供用户态解码 API（V4L2 stateless/M2M 最理想）；
3. 与 mpv/ffmpeg 集成（v4l2m2m 或私有插件）。

### 工作量/风险
- 估计 **30–60 人日**；极高风险（60k 行私有驱动 + 无公开寄存器手册）。
- **结论：不做**。1080p 软解已可用。

---

## 3. VENC 1080p60 录屏（规格 P4）

### 现状
- 无驱动；需求为“像手机一样录屏”。

### vendor 资源
- `source/msp/drv/venc`：58 文件 / **34,287 行**（v1.0/v2.0），IRQ 101。

### 工作量/风险
- 估计 **15–30 人日**，极高风险。
- **结论：不做**。替代方案：软件录屏（weston-screenshooter + ffmpeg x264，1080p 会低帧率，可作为“能用”的折中，后续可做）。

---

## 4. 蓝牙 RTL8822BS（规格 P5）

### 现状（本轮已推进）
- UART2/UART3 DT 节点 + 别名已加；内核 bluetooth/HCI H4 栈 + blueZ 工具已加载；RTL8822B BT 固件（51KB）已放在 `/lib/firmware/rtl_bt/`。
- `btattach -B /dev/ttyAMA1 -S 115200 -P h4` → hci0 创建但 `Opcode 0x0c03 failed: -110`（BT 芯片无响应）；UART3 同样无响应。

### 可能原因（按概率）
1. **BT 模组未上电**：RTL8822BS 组合模组通常有独立 `BT_REG_ON`/`BT_WAKE` 引脚，本板可能由 GPIO 控制（需原理图）；
2. **UART 引脚未复用**：UART2/UART3 引脚默认可能是 GPIO/I2S/SPI，需要编程 pinmux（xlsm 参考表有 UART2/3 引脚定义，但功能码需对照手册）；
3. BT 在其它 UART（如 UART1）或经由 SDIO 以外接口。


### 2026-11-01 更新（BlueZ 栈已就绪）
- 已达成：标准 BlueZ 软件栈全部可用 —— `bluetooth.ko`、`hci_uart.ko`、`btusb.ko`、`btrtl/btbcm/btintel/btqca` 模块均加载成功，
  `bluetooth.service` active，`rtl8822b_config.bin/rtl8822b_fw.bin` 就位；**插入标准 USB 蓝牙 dongle 即可用 bluetoothctl 配对**。
- 内部 RTL8822BS BT 仍未打通：`btattach` 对 ttyAMA0/1/2 × {h4,h5} × {115200,921600,1500000,3000000} 共 24 组全部 `BD Address 00:00:00:00:00:00`（芯片无响应）；
  UART1 实际基址为 0xF8006000、UART4 为 0xF8B04000，运行时访问均触发外部 abort（未开时钟/未上电）。
- 需要：板卡原理图（BT UART 引脚/时钟门、BT_REG_ON 电源 GPIO）才能进一步打通内部 BT。

### 下一步（需要外部信息）
- 板卡照片/丝印、原理图，或原厂固件中蓝牙是否可用；
- 确认后：配置 pinmux + GPIO 电源 + `hciattach/btattach`（可能需内核 `BT_HCIUART_RTL`，依赖 `SERIAL_DEV_BUS=y`，需重编 Image）。

### 工作量/风险
- 若接线已知：**1–3 人日**（低风险）；若不知：不可推进。

---

## 5. 4K60 HDMI 输出（规格 P2.3/P3.5）

- 当前 bootloader 固定 1080p 输出；4K 需修改 fastboot baseparam/HDMI 配置或移植 vendor HDMI 驱动（同上 100k 行）。
- **结论：不做**（1080p 已满足日常使用）。

---

## 总结

| 功能 | 结论 | 阻塞因素 |
|---|---|---|
| HDMI 音频 | 暂不做 | HDMI TX 寄存器被隔离，需 vendor HDMI 驱动（~100k 行） |
| VDEC 4K | 不做 | 60k 行私有驱动 + MMZ 依赖 |
| VENC 录屏 | 不做（可软件替代） | 34k 行私有驱动 |
| 蓝牙 | ❌ 硬件未启用（原厂固件亦无 UART BT 初始化、无 hci0）；软件栈 ✅ | 可用标准 USB 蓝牙 dongle（btusb） |
| 4K 输出 | 不做 | 需 vendor HDMI/VDEC 全家桶 |

当前交付（桌面/RDP/SSH/Samba/USB/WiFi/1080p 软解/GPU 验证）已是这套 vendor 封闭 SDK 硬件上“可实际使用”的合理终点。

---

## 6. 其他外设（2026-11-01 Round 76-78 结果）

| 外设 | 结果 | 说明 |
|---|---|---|
| I2C | ✅ 已实现 | mainline `i2c-hix5hd2` + DTS i2c0/1/2；/dev/i2c-0..2 |
| GPIO | ✅ 已实现 | ARM PL061 ×10，mainline `gpio-pl061`；/dev/gpiochip0..9 |
| WDT | ✅ 已实现 | ARM SP805，mainline `sp805_wdt`；systemd RuntimeWatchdogSec=30s 喂狗（否则 bootloader 已启用的看门狗会 ~3min 复位） |
| SPI | ✅ 已实现 | ARM PL022 @0xf8b1a000，mainline `spi-pl022`；spi0 master（无外接设备） |
| SATA | ➖ 剔除 | 用户确认硬件无此接口（非缺口） |
| PWM | ❌ 不可实现 | 数据手册 DS02/03/04 与 SDK 均无 PWM IP 描述/驱动（Round 160 定案） |
| RTC | ❌ 不可实现 | 数据手册与 SDK 均无 RTC IP/驱动；时间同步由 chrony(NTP) 覆盖 |
| thermal | ✅ 已实现 | 自研 mainline `hi3798-thermal` hwmon 驱动（PMC 0x28/0x30 序列 + 中位数滤波），`/sys/class/hwmon/hwmon0/temp1_input` ≈63°C；验收项 27 |

下一步建议：SATA 与 PWM/RTC 因硬件无接口或文档/SDK 无 IP 描述，均不再投入；thermal 已完成。

---

## 7. 蓝牙 RTL8822BS —— 结论：BlueZ 栈已就绪；内部模组需原理图才能打通

- 已做：获取 rtl8822b_fw.bin；启用 `CONFIG_BT_HCIUART_RTL`（需 `SERIAL_DEV_BUS=y`）并新增 UART1 节点后重新构建。
- 结果：新固件启动时 **内核在 `amba_read_periphid`（对象 0xf8b02000，即 uart2）发生 Data abort → Kernel panic**（Attempted to kill init），板卡进入 30s 重启循环。
- 恢复：U-Boot 下 tftp 旧固件到 0x1FFAE30 + bootm 从 RAM 启动 → 从 Linux 将已验证的 `fip_wdt.bin`（md5 89e34745…）dd 回 p6 → 正常重启恢复（I2C/GPIO/WDT/SPI/UART2/3 均在）。
- 结论：在**未知板上 BT UART 接线/供电**的情况下盲试 UART 会触发硬件总线错误；已回退相关改动。
- **决定性证据（2026-11-01 Round 96）**：
  1. vendor `cfg.mak:1474` → `# CFG_HI_BLUETOOTH_SUPPORT is not set`（原厂 SDK 构建时关闭蓝牙）；
  2. `source/component/bluetooth/drv/` 仅有 **USB** BT 驱动（usb_mt76x2、usb_rtl8822bu），**无 SDIO-combo(UART) BT 驱动**；
  3. 设计规格 §2 亦记录"当前 DB 里 BT 开关关闭"。
  ⇒ RTL8822BS 的 BT 部分在该板/SDK 上**未启用/未引出**，主线移植无从谈起；BT 正式标记为"硬件/SDK 不支持"。

### 1.1 HDMI TX 可达性复查（2026-11-01 Round 137）

- 动机：OHCI 问题被证明是时钟被关；用同样思路复查 HDMI TX。
- 结果：HDMI 时钟**并非**被关（CRG67=0x12537、CRG68=0x41、CRG54=0x8601004d 均正常），
  但 CPU 读 `0xf8ce0000`（HDMI TX 寄存器块）会触发 SIGSEGV/异常，无法访问。
- 结论不变：HDMI TX 由 bootloader/内部 MCU 管理，主线 CPU 侧不可安全访问；HDMI 音频/4K 输出需要厂商 HDMI 驱动。
### 7.1 硬件加速现状（2026-11-03 实测更新）

- **GPU(lima/Mali450)**：可初始化；基线 glmark2 Score=233，但 VBO/纹理路径 1FPS、mipmap 66s/帧，并伴随大量 lima MMU 超时错误（gpmmu command timeout / pp0/pp1 error irq state=201）→ 复杂 GL 不可用。已尝试厂商 CRG73 GPU 调频（600MHz 锁定成功），但 400/600MHz 下错误更多、性能更差（电压 OPP 未同步）→ 回滚默认 200MHz。默认 pixman 渲染正确。
- **VDEC/VENC**：SDK 中无厂商驱动源码（再次确认），闭源二进制无法移植 → mainline 下硬件编解码不可实现。
- **HDMI 音频/4K 输出**：HDMI TX 寄存器不可 CPU 访问，维持 BLOCKED。

## 8. VDEC/VENC 强需求评估（2026-11-03）

- 厂商源码**存在**（source/msp）：vdec 62.7k 行、venc 49k 行、omxvdec 29k 行，另有 jpeg/png/tde/vpss/vo 等配套；userspace 有 msp/api + OMX + GStreamer 集成。
- 但为**私有 ioctl/API 驱动**（无 V4L2），依赖 kapi/MMZ/mailbox/vfmw/固件，移植到 mainline 7.3 工作量 >150k 行、数周~数月。
- **推荐替代**：双系统（Ubuntu 桌面 + Android 硬解），或长期分阶段移植（先 JPEG/TDE，后 VDEC/VENC）。
