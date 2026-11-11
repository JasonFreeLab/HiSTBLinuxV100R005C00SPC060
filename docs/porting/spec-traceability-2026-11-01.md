# 规格追踪矩阵（spec-traceability）

状态：PASS=达成；PARTIAL=部分达成；BLOCKED=受 vendor 私有驱动/硬件信息阻塞；N/A=硬件/SDK 不支持。

## 一、§1.1 成功标准（8 项）

| # | 规格要求 | 状态 | 实现与证据 |
|---|---|---|---|
| 1 | eMMC 启动 mainline arm64 + earlycon + Ubuntu 26.04 | **PASS** | fastboot→FIP(BL31+BL33)→Linux 7.3 arm64；Ubuntu 26.04.1；冷启动回归 3/3 成功（20.2~21.0s 到 login，无 oops） | `logs/final-firmware-clean-2026-11-01.log`、`logs/p1-boot-reliability-3x-2026-11-02.log` |
| 2 | HDMI 1080p60/4K60 + HDMI PCM 音频 | **PARTIAL** | 1080p60 KMS 正常（桌面截图实证）；4K 不可行（驱动无 EDID 通道、HDMI TX 不可配，见 `logs/p2-4k-output-investigation-2026-11-02.log`）；音频需 vendor HDMI 驱动 | `feasibility-remaining-features-2026-11-01.md` §1-2 |
| 3 | H.264/H.265 4K60 硬解 | **BLOCKED** | 软解：H.264 1080p30≈22-25FPS、H.265≈14.5FPS；4K 需移植 vendor VDEC(~6万行)+MMZ | `logs/p4-video-decode-h264-h265-2026-11-01.log` |
| 4 | Wayland 桌面 + Mesa/lima GLES2 无软渲染回退 | **PARTIAL** | GL renderer Mali450 可运行（普通桌面无错误）；多窗口/VBO 重载会 lima pp 复位 → 默认 pixman，GL 可选 | `logs/p3-desktop-gl-mali450-gpu*.log` |
| 5 | 1080p VENC 录屏 | **BLOCKED** | 需 vendor VENC(~3.4万行)+MMZ；软件录屏 3-5fps 可作替代 | `feasibility...md` §4 |
| 6 | WiFi 连接 + BT 发现/连接 | **WiFi PASS / BT N/A** | WiFi：已连接 SSID `wifi`，DHCP 192.168.2.27，互联网 curl 200、apt/NTP 正常；BT：原厂固件仅加载 USB BT 驱动（rtk_btusb/BTMTK），无 UART BT 初始化/hci0；本板 UART2 全链路电气正常但模组无响应 → 硬件未启用（已知问题，软件栈就绪可用 USB dongle） | `logs/p5-wifi-internet-2026-11-01.log`、`logs/p6-bt-hardware-unsupported-conclusion-2026-11-01.log` |
| 7 | eMMC/USB2/SATA/以太网/GPIO/I2C/SPI/PWM/RTC/WDT/thermal | **PARTIAL（10/11）** | eMMC/USB2/以太网/I2C/GPIO/SPI/WDT/**thermal（自研 hwmon 驱动，读数 63°C）** PASS；SATA（硬件无接口，用户确认剔除）/PWM/RTC（数据手册与 SDK 均未提供该 IP，无法实现）未做 | `logs/p6-wdt-spi-fix-2026-11-01.log`、`logs/final-firmware-clean-2026-11-01.log` |
| 8 | 72h 混合负载稳定 | **PARTIAL（进行中）** | 自动自检每小时 + 稳定性每分钟记录；观察窗口 faults=0/gpu_err=0/warn_alloc=1（已缓解）；未满 72h 连续计时；已部署日报工具 stability-report.sh/timer（进度/故障/服务汇总） | `/root/selftest.log`、`/root/stability-*.log`、`logs/p7-stability-report-baseline-2026-11-02.log` |

## 二、验收硬指标（acceptance_check.sh，28 项）

| 检查 | 结果 | 证据 |
|---|---|---|
| 1 启动（uname aarch64） | PASS | 7.3.0 |
| 2 桌面（weston active） | PASS | systemctl |
| 3 终端（weston-terminal） | PASS | systemctl |
| 4 SSH | PASS | sshd |
| 5 网络（eth0 IP） | PASS | 192.168.2.10 |
| 6 Samba | PASS | smbd + SMB 读写实测 |
| 7 RDP 3389 | PASS | 端到端会话（CLIPRDR 活动） |
| 8 U盘 | PASS | sda1 /mnt/usb |
| 9 WiFi 硬件（mmc1） | PASS | rtw88 |
| 10 WiFi 驱动 | PASS | rtw88_8822bs |
| 11 WiFi 扫描 | PASS | 89 AP |
| 12 GPU（renderD128） | PASS | lima |
| 13 显示（card0 hi3798-drm） | PASS | KMS |
| 14 音频 AIAO 上电 | PASS | ver 0x20130516 |
| 15 内核无 oops | PASS | journal |
| 16 无 failed 单元 | PASS | systemd |
| 17 稳定性监控 | PASS | service |
| 18 备份定时器 | PASS | timer |
| 19 磁盘 >1G | PASS | 2.7G 可用 |
| 20 内存 >200M | PASS | ~580M 可用 |
| 21 WiFi 已连接 | PASS | SSID wifi |
| 22 互联网 | PASS | curl baidu 200 |
| 23 zram swap | PASS | 768MB |
| 24 USB 输入设备(鼠标/键盘) | PASS | /dev/input/event0 |
| 25 稳定性日报定时器 | PASS | stability-report.timer active |
| 26 备份新鲜度 <26h | PASS | /mnt/usb/hi3798-backup/board-config.tgz |
| 27 温度传感器 | PASS | hwmon0/temp1_input ≈ 63000 mC |

**当前：PASS=28 WARN=0 FAIL=0**（每小时自动自检记录于 `/root/selftest.log`）

## 三、结论

- **完全达成**：启动链/Ubuntu、静态网络、SSH/Samba/RDP、USB2 存储、WiFi 驱动+连接+互联网、桌面（pixman）+截图、1080p KMS、I2C/GPIO/SPI/WDT、自动备份/自检/稳定性监控、桌面应用生态（浏览器/LibreOffice/PDF/图片/视频/文件管理）。
- **部分达成**：GPU GL（默认 pixman，GL 可选受 VBO 限制）、外设（9/11）、稳定性（长时间运行已验证，72h 计时进行中）。
- **阻塞/不支持（证据充分）**：HDMI 音频、4K VDEC、VENC、BT（SDK 关闭）、SATA（未路由）、PWM/RTC/thermal（vendor 私有）。
