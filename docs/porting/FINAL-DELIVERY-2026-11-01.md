# Hi3798MV300 → Linux 7.x + Ubuntu 单板电脑：最终交付说明（2026-11-02 更新）

## 〇、当前无线模组（2026-11-03 更新）

- **新模组：Quectel FCS850R（RTL8822CS，SDIO WiFi + UART BT）**，资料见 `docs/fcs850r/`
- 旧模组（RTL8822BS，Fn-Link FG6222BSRB）保留兼容：内核同时编译 `rtw88_8822bs` 与 `rtw88_8822cs`
- WiFi：`rtw88_8822cs` + rtw8822c 固件，已连接 SSID wifi（IP 192.168.2.11/21 DHCP）
- 蓝牙：UART2 链路已全部验证（环回/双向/电平），但 BT 内核仍无响应；怀疑 HOST_WAKE_BT 上拉缺失或 32K 时钟，待硬件确认
- 驱动/固件已纳入每日备份（rtw88_8822c/cs.ko、hci_uart.ko、rtl8822cs_fw/config、rtw8822c_fw/wow_fw）

## 〇、当前固件

- p6 FIP：`fip_desk_pad.bin`（最终版），md5 **310cc74ee70d0365c32b475ea889dbac**（12,216,320 B/0x5D34 块；含 I2C/GPIO/WDT/SPI/rtw88/usb/CONFIG_SWAP/zram + **OHCI CLK_IGNORE_UNUSED 修复** + uinput + WL_EN/BT_EN 早初始化 + **hi3798-thermal 温度传感器驱动**）
- rootfs：Ubuntu 26.04.1（6.9G，已装桌面/RDP/SSH/Samba/浏览器/工具）
- 交换：内建 zram0 **768MB**（lzo-rle，优先级 100，`zram-swap.service` 开机启用）

## 一、交付成果

| 能力 | 状态 | 证据/备注 |
|---|---|---|
| 启动 | ✅ | 内核 7.3.0（aarch64）+ Ubuntu 26.04.1；冷启动回归 3/3 成功（20.2~21.0s 到 login，无 oops）；开机 3min 自动验收 |
| CPU | ✅ | 4× Cortex-A53 SMP/PSCI |
| HDMI 显示 | ✅ | hi3798-drm / VDP G0，1920×1080@60 扫描输出（桌面截图已可用：weston-screenshooter；成果图 logs/p5-desktop-final-2026-11-01.png） |
| 桌面 | ✅ | Weston 14（**pixman 默认**，稳定优先；GL 渲染器 Mali450 可经 `weston-launch.sh` 启用）；Xwayland + weston-terminal + PCManFM + Dillo |
| 远程桌面 | ✅ | RDP :3389（TLS）**端到端会话验证通过**（板内 xfreerdp3 连接，服务端 CLIPRDR 剪贴板通道活动）；Windows mstsc 可连 |
| SSH | ✅ | 密钥免密 root@192.168.2.10 |
| 网络（有线） | ✅ | eth0 静态 192.168.2.10/24，ping 0% loss，100Mbps Full |
| Samba | ✅ | `\\192.168.2.10\usb`、`\rootfs`（guest 读写） |
| USB 存储 | ✅ | 双 USB2 口；Kingston 62GB exfat 自动挂载 /mnt/usb；读 ~36MB/s、fsync 写 22MB/s（缓冲写极快） |
| WiFi 硬件 | ✅ | RTL8822BS（SDIO2 + rtw88 fw 30.20.0），wlan0 扫描 89 AP |
| WiFi 连接 | ✅ | **已连接 SSID `wifi`**（DHCP 192.168.2.27，默认路由走 wlan0）；power_save 已关；**互联网可用**（curl baidu 200，ping 8.8.8.8 0% 丢包） |
| GPU (lima) | ✅/⚠️ | 默认 **pixman**（稳定优先）；GL 渲染器 Mali450 可用（`weston-launch.sh`，普通桌面 3min+ 无错误），但多窗口/VBO 重负载会触发 lima pp 复位 → 自动回退 pixman |
| 视频软解 | ✅/⚠️ | H.264 1080p30 ≈22–25FPS（可播）；H.265 1080p30 ≈14.5FPS（低于实时） |
| 稳定性测试 | ⏳ | 每分钟稳定性采样 + 每小时 28 项自检 + 开机自检 + 每日稳定性日报；faults=0，72h 长跑计时进行中（stability-report.sh 显示进度） |
| 音频 | ⚠️ | AIAO 已上电（ver 0x20130516）；HDMI 音频需 vendor HDMI 驱动 |
| 外设(I2C/GPIO/WDT/SPI) | ✅ | /dev/i2c-0..2、/dev/gpiochip0..9、/dev/watchdog0（systemd 喂狗）、spi0 master |
| **温度传感器** | ✅ | 自研 `hi3798-thermal` hwmon 驱动（PMC 0xF8A23000），`/sys/class/hwmon/hwmon0/temp1_input` 稳定读数 ~63°C |
| SATA | ➖ | 用户确认硬件无接口，从需求剔除（COMBPHY1 mux=3 亦证实未路由） |
| 内存扩展 | ✅ | 内建 zram **768MB** 压缩交换（开机自动 swapon） |
| 备份/维护 | ✅ | `backup-fw.sh` + `hi3798-backup.timer`：FIP + 全部配置/脚本/单元/drop-in/桌面覆盖 → U盘；恢复路径实测可用（§R）；fstrim.timer 已启用 |
| 桌面应用 | ✅ | PCManFM / mousepad / xterm / mpv / Dillo / ffmpeg / python3 / htop / tmux / ncdu |
| **GUI 浏览器** | ✅ | `hi-browser.sh`（WebKitGTK 2.52 自研轻量浏览器，桌面第 5 个启动器；实测百度/必应加载正常，截图 logs/p5-browser-baidu-2026-11-01.png；**WebM(VP8/VP9) 视频可在页内播放**） |
| 录屏 | ⚠️ | `screen_record.sh`（1080p 3–5fps 软编码；受截图限制影响） |
| 蓝牙 | ❌ | **硬件未启用（已知问题）**：原厂固件仅 USB BT 驱动、无 UART BT 初始化/hci0；本板 UART2 全链路电气正常但模组无响应；BlueZ 栈就绪，插 USB dongle 即可用 |
| 4K 解码/编码 | ❌ | 需移植 vendor VDEC(6万行)/VENC(3.4万行)，暂不投入 |

## 二、常用操作

```sh
# SSH
ssh -i ~/.ssh/id_ed25519 root@192.168.2.10        # 密码 root

# 构建 + 刷写固件
bash docs/porting/scripts/build_desktop_fip.sh      # → /tmp/fip_desk_pad.bin
scp /tmp/fip_desk_pad.bin root@192.168.2.10:/root/fw/ && \
ssh root@192.168.2.10 'dd if=/root/fw/fip_desk_pad.bin of=/dev/mmcblk0 bs=512 seek=$((0x7000)) conv=fsync'

# WiFi 连接
ssh root@192.168.2.10 '/usr/local/bin/wifi_setup.sh "<SSID>" "<PASSWORD>"'

# 截图/录屏（受 §四 限制）
ssh root@192.168.2.10 '/usr/local/bin/screen_shot.sh /root/shot.png'
ssh root@192.168.2.10 '/usr/local/bin/screen_record.sh 3 5 /root/rec.mp4'

# 救援（启动失败时）：U-Boot 下
# tftp 0x1FFAE30 fip_rescue_med.bin; bootm 0x1FFAE30  → ~ # mount /dev/mmcblk0p1 /mnt
```

## 三、关键工程结论（复现必读）

1. **FIP/ATF 限制**：BL33/FIP > ≈11.5MB 静默失败；`mkuimage --pad-to` 必须用 Image header 的 image_size（含 BSS）；`fip_create` 不截断旧输出（脚本已先 rm）。
2. **模块铁律**：新增内核模块必须与 Image 同一次构建产出；事后单独补编模块会导致 `finit_module` 死锁（zram 实验为证）。
3. **USB2 PHY**：2p/1p PHY 调优寄存器厂商值不可省（0x408/0x474… 与 OTP trim+0x40c）；否则 U 盘枚举失败。
4. **SDIO2/WiFi**：DTS `mmc@f9c40000`（dw-mshc + CRG 0x28c）即可工作；rtw88 模块化 + firmware 部署后自动加载。
5. **HDMI TX 寄存器 CPU 不可读**（0xF8CE0000 全 0），HDMI 音频/EDID/4K 输出需 vendor 驱动（10 万行级）。
6. **启动优化**：mask rfkill、去 fstab tmpfs /tmp、禁用 snapd/cloud-init/rsyslog 等 → 24.9s → 14.3s，内存省 31MB。

## 四、已知问题

| 问题 | 影响 | 说明/后续 |
|---|---|---|
| HDMI 截图/录屏内容异常（"3 等分"假象） | 仅证据工具 | 根因疑为 weston shadow framebuffer 与简易 KMS 驱动组合 + VDP stride 语义；不影响 RDP 实际使用。修复需完整 GBM/atomic 驱动或 VDP 手册 |
| WiFi 偶发断开 | 短暂断网 | 已部署 wifi-watchdog（2 分钟检查，3 次失败自动重连）；当前稳定连接 |
| HDMI 音频 / VDEC / VENC / 4K | 功能缺失（厂商私有驱动） | 见 `feasibility-remaining-features-2026-11-01.md` |
| 蓝牙 | 硬件未启用（已知问题） | 见 `logs/p6-bt-hardware-unsupported-conclusion-2026-11-01.log`；可用 USB dongle |
| SATA | 硬件无接口 | 用户确认剔除 |
| GPU VBO 重负载 | 复杂 GL 应用可能崩 | Mesa/lima 与国产 IP 兼容性问题；桌面默认 pixman |

## 五、文档索引

- `docs/porting/runbook-build-and-boot.md`：构建/刷写/救援/优化/工具
- `docs/porting/acceptance-report-2026-11-01.md`：验收报告 + 实拍
- `docs/porting/feasibility-remaining-features-2026-11-01.md`：剩余功能可行性
- `docs/porting/driver-technical-spec.md`：寄存器/驱动技术细节
- `docs/porting/risk-register-and-decisions.md`：风险与决策
- `docs/porting/logs/`：55+ 份证据日志/截图
- `.superpowers/sdd/.../progress.md`：完整实施流水账（含灾难恢复）

## 六、自动化与自愈体系（2026-11-02 完成）

| 频率 | 机制 | 输出 |
|---|---|---|
| 开机 +3min | `hi-boot-selftest.timer`：28 项验收 + dmesg oops 扫描 | `/root/boot-selftest.log` |
| 每分钟 | `stability-monitor`：uptime/load/mem/faults/warn_alloc/wifi | `/root/stability-YYYYMMDD.log` |
| 每小时 | `hi-selftest.timer`：28 项验收 | `/root/selftest.log` |
| 每日 00:10 | `stability-report.timer`：本次启动 uptime、72h 进度、故障/服务汇总 | `/root/stability-report.txt` |
| 每日 01:35 + 开机 | `hi3798-backup.timer`：FIP + 配置 + drop-in + 脚本 → U盘 | `/mnt/usb/hi3798-backup/` |
| 每 2 分钟 | `wifi-watchdog`：断线自动重连 | journal |
| 每周 | `fstrim.timer` | — |

- 关键服务（weston / weston-terminal / stability-monitor / stability-load）均 `Restart=always` + `StartLimitIntervalSec=0`，崩溃无限自愈（实测 kill 后 4s 恢复）。
- 验收：`/usr/local/bin/acceptance_check.sh` **28 项，PASS=28 WARN=0 FAIL=0**。
