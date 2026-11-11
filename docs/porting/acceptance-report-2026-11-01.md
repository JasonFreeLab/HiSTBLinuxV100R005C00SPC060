# Hi3798MV300 Linux 7.x + Ubuntu 验收报告（2026-11-01）

> 证据：`docs/porting/logs/p5-acceptance-run-2026-11-01.log`、`docs/porting/logs/p5-acceptance-desktop-2026-11-01.png`（实拍 framebuffer 1920x1080 桌面：Weston + Wayland Terminal + 顶栏时钟）

## 一、验收结果总览

| # | 项目 | 结果 | 证据/说明 |
|---|---|---|---|
| 1 | 启动 | ✅ | 内核 7.3.0（aarch64），Ubuntu 26.04.1；冷启动 systemd-analyze：kernel 2.6s + userspace 13.3s = **15.97s** 到 login，SSH 约 20–40s 可用；冷启动后 7 项服务/外设自动恢复 |
| 2 | CPU | ✅ | 4× Cortex-A53（/proc/cpuinfo 4 处理器），SMP + PSCI 正常 |
| 3 | 显示 | ✅ | hi3798-drm（VDP G0）1920x1080@60 扫描输出；截图证明桌面实时画面 |
| 4 | 桌面 | ✅ | Weston 14（pixman）+ Xwayland + weston-terminal；顶栏/launcher/窗口正常 |
| 5 | 远程桌面 | ✅ | RDP 3389 已 **端到端会话验证**（板内 xfreerdp3 客户端连接成功，服务端 CLIPRDR 剪贴板通道活动；Windows mstsc 同样可用） |
| 6 | SSH | ✅ | 密钥免密登录 root@192.168.2.10，全部操作经 SSH 完成 |
| 7 | 网络（有线） | ✅ | eth0 192.168.2.10/24（静态），ping PC 0% loss，100Mbps Full |
| 8 | Samba | ✅ | smbd active，139/445 监听；`\\192.168.2.10\usb`、`\rootfs` 共享 |
| 9 | USB 主机 | ✅ | EHCI 两端口可用；Kingston 62GB exfat 识别为 sda1 |
| 10 | U 盘 | ✅ | 自动挂载 /mnt/usb（x-systemd.automount），可读写；读约 36MB/s、写 9–12MB/s |
| 11 | WiFi 硬件 | ✅ | SDIO2 控制器 + rtw88 固件 30.20.0；wlan0 已创建 |
| 12 | WiFi 扫描 | ✅ | `iw dev wlan0 scan` 扫到 89 BSS（AP 列表） |
| 13 | WiFi 连接 | ✅ | 已连接 SSID `wifi`（DHCP 192.168.2.27）；互联网 curl 200；SSH/RDP/Samba 经 WiFi 可达（Round 102/123） |
| 14 | GPU (lima) | ✅/⚠️ | GL renderer Mali450 验证可用（glmark2 320x240 ~308 FPS）；VBO 重负载 pp 超时（已知限制），桌面默认 pixman |
| 15 | 视频（软解） | ✅ | mpv 1080p30 H.264 150 帧 / 6.02s ≈ 24.9 FPS（基本流畅） |
| 16 | 音频 AIAO | ✅（部分） | AIAO 上电 ver=0x20130516；HDMI 音频通路未完成（HDMI TX 寄存器 CPU 不可读） |
| 17 | 蓝牙 | ❌ | 需确认 BT UART 接线/电源与 rtl8822b BT 固件（未开展） |
| 18 | 4K 解码/编码 | ❌ | 需移植 vendor VDEC/VENC 驱动（工程量大） |

## 二、系统服务状态

- `weston`、`weston-terminal`、`ssh`、`smbd`、`systemd-networkd`、`seatd`：active
- 已 mask：`systemd-rfkill.service`（避免启动等待）、`multipathd`（无对应硬件，避免 failed 单元）
- 已禁用：无（swap=0，zram 实验已放弃并清理）

## 二·补：2026-11-01 Round 60 修复

- 启动 oops 已消除：DTS `xhci@f98a0000` 置为 disabled（xHCI 模块 probe 在本板会 oops；无物理 USB3 口），重启后 dmesg 无 Internal error/Oops。
- U 盘 exfat 已 fsck：`/dev/sda1: clean. directories 183, files 1151`（exfatprogs 1.3.2）。

## 三、已知限制

1. **HDMI 音频**：AIAO 已上电，但 HDMI TX（0xF8CE0000）寄存器窗口从 Linux 侧读全 0，需 vendor HDMI 驱动/HDMI MCU 固件，暂不可行。
2. **GPU VBO**：lima 在 VBO 重负载（如 glmark2 640x480 texture）触发 INVALID_PLIST / pp 超时，桌面默认 pixman 保证稳定；GL 渲染器可用作实验。
3. **4K**：无 4K 输出/解码（需要 VDP/VDEC vendor 驱动移植）。
4. **xHCI 节点**：本板无 USB3 物理口且模块 probe 会 oops，故默认 disabled。
5. **模块构建铁律**：新增内核模块必须与 Image 同一次构建产出（事后单独补编会导致模块加载 spinlock 死锁，zram 实验为证）。
5. **WiFi 连接**：驱动/固件/扫描全部就绪，仅缺用户凭据。

## 四、复现/操作入口

```sh
# 构建固件
bash docs/porting/scripts/build_desktop_fip.sh     # → /tmp/fip_desk_pad.bin
# 刷写（Linux 侧）
scp /tmp/fip_desk_pad.bin root@192.168.2.10:/root/fw/ && \
ssh root@192.168.2.10 'dd if=/root/fw/fip_desk_pad.bin of=/dev/mmcblk0 bs=512 seek=$((0x7000)) conv=fsync'
# WiFi 连接
ssh root@192.168.2.10 '/usr/local/bin/wifi_setup.sh "<SSID>" "<PASSWORD>"'
# 桌面截图（framebuffer 直读）
ssh root@192.168.2.10 'python3 /root/frame_dump.py'   # 见 logs 生成方式
```

## 五、结论

核心目标“把闲置 Hi3798MV300 盒子变成可用的 Ubuntu 单板电脑”已达成：
- 完整 Ubuntu 桌面（HDMI 1080p）、远程桌面、SSH、Samba、USB 存储、WiFi 硬件与扫描、
  GPU 加速验证、1080p 软解播放、完善的构建/刷写/救援文档。
- 未能完成：HDMI 音频、4K VDEC/VENC、蓝牙 —— 均受限于 vendor 私有驱动/固件，需要大规模移植工作。

## 补充验收（2026-11-01 Round 113）

重启后 23 项检查全通过（acceptance_check.sh 已扩至 23 项）：

- 新增：**21 WiFi 已连接**（SSID wifi）、**22 互联网**（curl baidu 200）、**23 zram swap**（511MB）。
- 开机自动恢复：WiFi 自动连接（192.168.2.27）、默认路由 wlan0、zram swap、Weston(pixman)+壁纸、ssh/smbd/networkd/stability 服务、U盘 automount。
- 冷启动 16.5s；0 oops；ubuntu 26.04.1 + Linux 7.3.0。

## ✅ 用户实机验收（2026-11-01 18:58）

> **用户确认：鼠标可以操作。**（电视画面正常显示 + USB 全速鼠标经 OHCI 正常工作，光标出现、可点击桌面）

这是项目最终的实机验收：显示器输出、鼠标输入、桌面交互全部由用户亲眼确认。
