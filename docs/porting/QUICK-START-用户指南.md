# Hi3798MV300 Ubuntu 单板电脑 — 快速上手指南

## 一、开机前

1. HDMI 接电视（建议选 1080p 兼容的 HDMI 口），USB 键鼠可选，网线接路由器/电脑（板卡固定 IP `192.168.2.10`）。
2. 通电即自动从 eMMC 启动 Ubuntu（约 14 秒到登录界面）。

## 二、登录方式（三选一）

| 方式 | 操作 |
|---|---|
| **HDMI 桌面** | 电视上看到桌面（Weston），可直接用鼠标/键盘（需 USB 键鼠）或 Weston 终端 |
| **SSH** | `ssh root@192.168.2.10`（密码 `root`，或使用已配置的免密钥） |
| **RDP 远程桌面** | Windows 打开 `mstsc`，连接 `192.168.2.10:3389`，用户名 `root` 密码 `root` |
| **串口** | 115200 8N1 接 ttyAMA0，已配置 root 自动登录 |

## 三、常用功能

### U 盘
- 插入后自动挂载到 `/mnt/usb`（访问时按需挂载）；Samba 里也能看到。
- 查看：`ls /mnt/usb`

### 文件共享（Windows）
- 资源管理器输入 `\\192.168.2.10\usb`（U 盘）或 `\\192.168.2.10\rootfs`（板卡 /root，免密）

### WiFi
```sh
# 扫描
iw dev wlan0 scan | grep SSID
# 连接（把 SSID/密码换成你的）
/usr/local/bin/wifi_setup.sh "你的SSID" "你的密码"
```
> 需要先在板子上 `ip link set wlan0 up`（已在 networkd 配置中）

### 上网（GUI 浏览器）
桌面左上角第 5 个图标（地球）即浏览器（地址栏/前进后退/刷新/主页，`F11` 全屏，`Ctrl +/-` 缩放，下载文件保存到 `/root/Downloads`）；或命令行：
```sh
/usr/local/bin/hi-browser.sh https://www.baidu.com
```
。> 使用 WebKitGTK + 软件渲染（适配 pixman 桌面）。已实测：百度、必应正常（WebKit 快照可完整正确渲染页面）；WebM(VP8/VP9) 视频可播放；H.264/MP4 页内播放不支持（Ubuntu 仓库缺 gst-libav 插件，请用 mpv 播放本地视频）；重页面（如 ubuntu.com）在 1GB 内存下较慢，配合 512MB zram swap 可运行。

### 办公（LibreOffice）
```sh
libreoffice --writer    # 写文档
libreoffice --calc      # 表格
libreoffice --headless --convert-to pdf 文件.docx   # 批量转 PDF
```
桌面应用菜单里也可直接找到 LibreOffice。

### 看图片
```sh
/usr/local/bin/hi-image.py 图片.png      # 滚轮缩放，q 退出
```
文件管理器里双击图片自动用查看器打开。

### 看 PDF
```sh
/usr/local/bin/hi-pdf.py 你的文件.pdf     # 窗口内 ← → 翻页，q 退出
```
或在文件管理器（PCManFM）里双击 PDF（已默认关联）。

### 播放视频
```sh
mpv /mnt/usb/xxxx.mp4            # 1080p H.264 软解约 25fps
# 或桌面里双击（PCManFM）
```

### 截图/录屏
```sh
/usr/local/bin/screen_shot.sh /root/shot.png   # 桌面截图（weston-screenshooter，已验证）
/usr/local/bin/screen_record.sh 3 5 /root/rec.mp4   # 3fps 5秒
```

### 备份固件（重要！）
```sh
/usr/local/bin/backup-fw.sh      # 备份 FIP+配置到 /mnt/usb/hi3798-backup
```
> 另有每日自动备份定时器。

### 系统自检
```sh
/usr/local/bin/acceptance_check.sh    # 28 项自检
```

### 实用工具
`htop`（资源监控）、`tmux`（会话保持）、`ncdu`（磁盘分析）、`i2cdetect`（I2C）、`dillo`（浏览器）、`pcmanfm`（文件管理器）、`mousepad`（编辑器）

## 四、自动维护（无需干预）

| 机制 | 说明 |
|---|---|
| 看门狗 | SP805 + systemd 30s 喂狗，系统死机自动重启 |
| WiFi 自愈 | 每 2 分钟检查，断网自动重连（`/var/log/wifi-watchdog.log`） |
| 自动自检 | 每小时 `acceptance_check.sh` → `/root/selftest.log` |
| 自动备份 | 开机 3min + 每日 → `/mnt/usb/hi3798-backup/` |
| 安全更新 | unattended-upgrades 自动安装安全补丁（内核为自编译不受影响） |
| 日志 | persistent journal（限额 64M）+ 稳定性每分钟记录 |

## 五、注意事项

1. **不要随意断电**（无 RTC，断电后时间会丢失；且写 eMMC 时断电可能损坏文件系统）。
2. 首次/异常启动失败时：U-Boot 串口下 `tftp 0x1FFAE30 fip_rescue_med.bin; bootm 0x1FFAE30` 进入救援 shell。
3. 系统看门狗由 systemd 托管（30 秒），系统真死会自动重启。
4. 已知限制：无 HDMI 音频、无 4K 硬解/硬编、BT 不可用（vendor 驱动缺失）。
5. 修改内核/固件请参考 `docs/porting/runbook-build-and-boot.md`。

## 六、恢复固件

板卡保留了两级恢复：
1. `/mnt/usb/hi3798-backup/fip-p6.bin`（自动备份的最新固件）
2. PC 上 `C:\Users\yujia\Desktop\hi3798_boot\` 中的历史固件（可 U-Boot tftp 到 RAM 启动）

刷回：
```sh
dd if=/mnt/usb/hi3798-backup/fip-p6.bin of=/dev/mmcblk0 bs=512 seek=$((0x7000)) conv=fsync
```

## 已知问题（硬件限制，购买/使用前请知悉）

| 功能 | 状态 | 说明 |
|---|---|---|
| **蓝牙** | ❌ 不支持（硬件未启用） | FCS850R 引脚电平正常但芯片无响应；原厂固件亦禁用 BT；**插 USB 蓝牙适配器即可用** |
| SATA | ❌ 无接口 | 本板未引出 |
| HDMI 音频 | ❌ 不支持 | 厂商私有驱动限制，电视无声音输出 |
| 4K 输出 / 4K 硬解 / 硬件编码 | ❌ 不支持 | 厂商私有驱动限制；1080p 软解可用 |
| PWM / RTC / thermal | ❌ 不支持 | 无 mainline 驱动（时间靠 NTP 校准） |
