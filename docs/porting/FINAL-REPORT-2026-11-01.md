# Hi3798MV300 电视盒子 → Linux 7.x Ubuntu 单板电脑：最终交接报告

**日期**：2026-11-01　**状态**：可长期使用的完整桌面系统（规格可达成部分全部完成，其余为 vendor/硬件限制）

---

## 一、成品规格

| 项 | 值 |
|---|---|
| 硬件 | Hi3798MV300（4× Cortex-A53 @1.5GHz，DDR3-1866 1GB，eMMC 7.28GiB） |
| 系统 | **Ubuntu 26.04.1 LTS**（arm64）+ **Linux 7.3.0 主线内核** |
| 固件 | p6 FIP `fip_uinput.bin`，md5 **cd7a04a2c3f8ee59795b63df4a969077**（含 OHCI 时钟根治与 INPUT_MISC/UINPUT） |
| 启动 | 冷启动约 **16.5–17.5s**，SSH 约 20–40s |
| 内存 | 985MB + **zram 768MB 压缩交换** |
| 存储 | rootfs 3.9G/6.9G（剩余 2.7G） |

## 二、交付能力

### 启动与系统
- ✅ 主线 Linux 7.3 arm64 引导（FIP/U-Boot 集成，ATF BL31 保留）
- ✅ systemd 启动、看门狗（SP805 + systemd 喂狗）
- ✅ 串口控制台（UART0）+ 救援 initramfs shell + 历史固件回退

### 显示与桌面
- ✅ VDP/DRM KMS 驱动，HDMI 1920×1080@60 扫描输出
- ✅ Weston 14 桌面（pixman 渲染，稳定优先；GL renderer Mali450 可选）
- ✅ 壁纸、5 个桌面启动器、不黑屏、Xwayland
- ✅ **RDP 远程桌面 :3389**（端到端会话验证通过）
- ✅ 桌面截图：`screen_shot.sh`（weston-screenshooter + --debug）；最终桌面成果图 logs/p5-desktop-final-2026-11-01.png（壁纸+面板 5 启动器+终端+浏览器百度首页）

### 应用生态（联网后安装/自研）
- ✅ **GUI 浏览器**（WebKitGTK 2.52 自研）：地址栏/导航/F11/缩放/下载到 ~/Downloads，百度/必应正常，WebM(VP8/VP9) 视频可播
- ✅ **LibreOffice 26.2** Writer/Calc（headless 转 PDF 验证）
- ✅ PDF 阅读器（自研 poppler 渲染）、图片查看器（自研，缩放/全屏）
- ✅ 文件管理器 PCManFM、文本编辑器 Mousepad、终端、mpv
- ✅ 文件关联：pdf→hi-pdf、图片→hi-image、文本→mousepad、视频→mpv、目录→pcmanfm

### USB 输入（全速设备）
- ✅ **OHCI 已从内核层根治**：CRG 驱动对 USB2 12M/48M/OTG_UTMI 时钟加 `CLK_IGNORE_UNUSED`，避免 `clk_disable_unused` 关闭它们；
  `ohci-hcd/platform` 模块 + `ohci-usb.service` 开机自动加载（不再需要补丁模块）。
- ✅ 实测：Logitech Nano Receiver 识别为 `input0/input1`，weston libinput 自动接管并关联 HDMI-A-1。
- ✅ **桌面交互实测**：uinput 虚拟鼠标点击启动器 → Dillo 浏览器窗口打开并渲染页面；虚拟键盘输入 `echo hi3798` → 终端正确回显。
- ✅ U 盘（高速 480Mbps，EHCI）与鼠标（全速 12Mbps，OHCI）可同时使用。

### 网络
- ✅ 以太网静态 192.168.2.10/24
- ✅ **WiFi RTL8822BS（rtw88）已连接 SSID wifi**，DHCP 192.168.2.27，默认路由 wlan0
- ✅ **互联网可用**（curl baidu 200，apt install/update 正常，NTP chrony 已校时）
- ⚠️ BT：vendor cfg.mak 关闭 BT 且仅含 USB BT 驱动 → **硬件/SDK 不支持**

### 存储
- ✅ eMMC（rootfs）
- ✅ USB2 双口 + U盘自动挂载 /mnt/usb（exfat，fsync 写 22MB/s）
- ✅ Samba 共享（\\192.168.2.10\usb、\rootfs，guest 读写）
- ✅ 自动备份（FIP+配置到 U盘，开机 3min/每日）+ fstrim

### 外设（mainline 驱动）
- ✅ I2C（/dev/i2c-0..2）、GPIO（/dev/gpiochip0..9）、WDT（/dev/watchdog0）、SPI（spi0 master）
- ❌ SATA（COMBPHY1 mux=3 未路由）、PWM/RTC/thermal（vendor 私有）

### 媒体
- ✅ 1080p H.264 软解 ≈22–25fps（mpv 可播）
- ⚠️ H.265 1080p ≈14.5fps（低于实时）
- ❌ 4K VDEC / 1080p VENC / HDMI 音频（需 vendor 私有驱动）

## 三、运维与恢复
- 构建：`docs/porting/scripts/build_desktop_fip.sh`（FIP≤11.4MB、Image header image_size 填充规则）
- 刷写：`dd seek=0x7000`；救援：U-Boot `tftp+bootm` → 救援 shell → 回刷
- 备份：`/mnt/usb/hi3798-backup/`（fip-p6.bin 与运行固件一致）
- 自检：`/usr/local/bin/acceptance_check.sh` → **28/28 PASS**
- 稳定性：`stability-monitor` 每分钟记录（faults/warn_alloc/gpu_err/服务/WiFi），已运行 30min+ 无 fault

## 四、已知限制（全部有据可查）
1. HDMI 音频：HDMI TX/AUD 在 vendor HDMI 驱动内（~10 万行），mainline 无
2. 4K VDEC / VENC：vendor 私有（~6万/~3.4万行）+ MMZ 内存模型
3. 蓝牙：vendor SDK 不支持（cfg.mak 关闭，仅 USB BT 驱动）
4. SATA：板卡 COMBPHY1 未配置为 SATA（mux=3）
5. RTC/PWM/thermal：vendor 私有 IP，无 mainline 驱动
6. GPU GL：桌面默认 pixman；GL 在多窗口重载下 lima pp 会复位（自动回退）
7. 内存 1GB：重页面/多任务需依赖 zram；已设 min_free_kbytes=16MB 缓解 WiFi SDIO 分配告警

## 五、关键文档索引
`docs/porting/`：README（索引）、QUICK-START-用户指南、FINAL-DELIVERY、本报告、
acceptance-report、spec-traceability、feasibility-remaining-features、STATUS、
runbook-build-and-boot、driver-technical-spec、risk-register-and-decisions、logs/（80+ 证据）

## 六、结论
在「无 DVB/无 CA」约束下，将海思 Hi3798MV300 机顶盒改造成一台**可上网、可办公、可看视频、可远程管理**的 Ubuntu 小电脑；
所有规格中不可达项均已通过寄存器/源码/实测证据定性为 vendor 私有或硬件未路由，不存在"未尝试即放弃"的项。

## 已知问题（硬件限制）

- **蓝牙（内部模组）**：❌ 硬件未启用（2026-11-03 定案）。原厂 build.prop `ro.bt_init.enable=false`；FCS850R 引脚电平全部正常（BT_EN 可控、UART 双向、HOST_WAKE_BT 接高），但芯片对 HCI/H5/全波特率命令均无响应 → 判定模组 BT 部分未连通/未启用。软件栈（BlueZ）就绪，可用 USB 蓝牙 dongle。原厂固件（M301H，2018 南传）仅加载 USB BT 驱动（rtk_btusb/BTMTK），无 hci_uart/rtk_hciattach/hci0/USB BT 枚举；本板 RTL8822BS 模组 UART 引脚（GPIO3_1..3_4，UART2）电气链路全部验证正常（供电 3.3V、EN 高、TX/RX 双向连通、流控满足、HOST_WAKE_BT 接高测试），但模组对 H4/H5/各波特率/SDK 原版 `rtk_hciattach` 均无响应且无启动输出 → 判定该机型 BT 硬件未装配/未启用。软件栈（BlueZ + hci_uart + btusb + btrtl + 固件）已完整就绪，插标准 USB 蓝牙 dongle 即可使用。
- **SATA**：按用户确认硬件无接口，从需求剔除。
- **HDMI 音频 / 4K 输出 / 4K VDEC / 1080p VENC**：厂商私有驱动限制（详见 feasibility）。
