# 构建与启动 Runbook（P0/P1）

## 1. 环境

| 项 | 值 |
|---|---|
| Host | Ubuntu 26.04.1 LTS x86_64，GCC 15.2（仅 host 用） |
| 交叉工具链 | `/home/jason/bringup-7.3/toolchain`（从 TUNA 下载的 Ubuntu 26.04 cross gcc 15 deb 解包，无 sudo） |
| 内核源码 | `/home/jason/bringup-7.3/src/linux-7.3` |
| 产物目录 | `/home/jason/bringup-7.3/out` |
| SDK 仓库 | `/home/jason/HiSTBLinuxV100R005C00SPC060`（文档/脚本回写 `docs/porting/`） |

**每次编译前必须执行：**
```sh
export PATH=/home/jason/bringup-7.3/toolchain/usr/bin:$PATH
export LD_LIBRARY_PATH=/home/jason/bringup-7.3/toolchain/usr/lib/x86_64-linux-gnu
# 自检
aarch64-linux-gnu-gcc --version
ldd /home/jason/bringup-7.3/toolchain/usr/bin/aarch64-linux-gnu-as | grep 'not found' || echo toolchain-ok
```

## 2. 内核配置（P0 最小 earlycon）

```sh
cd /home/jason/bringup-7.3/src/linux-7.3
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- allnoconfig
scripts/config --file .config -e PRINTK -e TTY -e OF -e OF_FLATTREE \
  -e SERIAL_AMBA_PL011 -e SERIAL_AMBA_PL011_CONSOLE -e SERIAL_EARLYCON \
  -e ARM_ARCH_TIMER -e ARM_GIC -d EFI -d ACPI
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
grep -E 'CONFIG_(SERIAL_AMBA_PL011|SERIAL_EARLYCON|ARM_ARCH_TIMER|ARM_GIC|OF)=' .config
```
P0 用 allnoconfig 是为了让 `Image` 足够小（<28MB），便于塞进 32MB kernel 分区。P2 起换成裁剪版 defconfig（保留 DRM/V4L2/ASoC/网络）。

## 3. 构建

```sh
cd /home/jason/bringup-7.3/src/linux-7.3
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image -j16
cp arch/arm64/boot/Image /home/jason/bringup-7.3/out/Image
# DTB（dtc 使用内核自带脚本）
scripts/dtc/dtc -I dts -O dtb \
  -o /home/jason/bringup-7.3/out/hi3798mv300-poc.dtb \
  arch/arm64/boot/dts/hisilicon/hi3798mv300-poc.dts
```

## 4. uImage 打包

```sh
python3 docs/porting/scripts/mkuimage.py --pack \
  --image /home/jason/bringup-7.3/out/Image \
  --dtb /home/jason/bringup-7.3/out/hi3798mv300-poc.dtb \
  --out /home/jason/bringup-7.3/out/uImage
python3 docs/porting/scripts/mkuimage.py --verify /home/jason/bringup-7.3/out/uImage
```
- 头格式：U-Boot legacy uImage（64B 大端），arch=22（arm64），comp=0，load=ep=0x2000000。
- DTB 追加在 payload 之后（不计入 header.size），与 fastboot `bootm` 的 `image_get_image_end` 校验约定一致。
- 要求：`uImage` ≤ 32MB（kernel 分区大小）。

## 5. 烧录与启动

1. 用 HiTool 按 `configs/hi3798mv300/prebuilts/emmc_partitions.xml` 烧录；把 `uImage` 作为 `hi_kernel.bin` 烧到 kernel 分区（起始 14M，长 32M）。
2. bootargs 使用 `configs/hi3798mv300/prebuilts/emmc_bootargs_ubuntu.txt` 修改版：
   ```
   console=ttyAMA0,115200 root=/dev/mmcblk0p8 rootfstype=ext4 rootwait rw cma=256M
   ```
   （P0 阶段可先用 `console=ttyAMA0,115200 earlycon=pl011,0xf8b00000` 验证内核启动，无 rootfs 也可看到日志。）
3. 串口 115200-8N1；上电后 fastboot `bootm 0x1FFFFC0`。
4. 预期日志：`Booting Linux on physical CPU 0x0`、`Linux version 7.3.0`、`earlycon: pl011`、`Kernel command line: ...`。

## 6. 排障

| 现象 | 可能原因 | 处理 |
|---|---|---|
| 无任何输出 | fastboot 未走 arm64 路径 / uImage 头错误 / DTB 未追加 | `mkuimage --verify`；检查 fastboot 是否用 TEE/ATF 分支；见 D3 预案 |
| 有 U-Boot 输出但内核不启动 | Image 未按 0x2000000 对齐或压缩格式不匹配 | 确认 payload 为未压缩 Image、ep/load=0x2000000 |
| 启动后停在 `Kernel command line` 前 | DTB 校验失败（DTB 位置错误） | 确认 DTB 追加在 image end |
| earlycon 有输出但无 console | pl011 driver/clk 缺失 | DTS 中 uart clocks（uartclk/apb_pclk）补齐 |
| 多核起不来 | 无 PSCI/ATF | P0 单核；P2 前完成 D3 决策 |

## 7. known issue（P0 未解决）

- 板载 fastboot 的 arm64 启动路径位于 `CONFIG_TEE_SUPPORT`/`CONFIG_TEE_ATF_SUPPORT`/`CONFIG_SBL_VXX_UXX` 条件编译内；当前 32 位产品配置未开启 TEE。若实测无法启动 arm64 内核：
  - 预案 A：移植 ATF（`source/kernel/arm-trusted-firmware/plat/hisilicon` 下 hi3798mv200 平台为起点）提供 PSCI + arm64 启动；
  - 预案 B：给 fastboot 增加非 TEE 的 arm64 启动路径（设置 EL1、x0=DTB、跳转），需要板级调试；
  - 预案 C：退回 armhf Ubuntu + 32 位内核（不推荐，生态/性能受限）。
  该决策在 P0 实测后写入 ledger 并更新计划。

## P1：Ubuntu 26.04 arm64 启动（eMMC）

产物（P1 最小内核）：
| 文件 | 大小/说明 |
|---|---|
| `/home/jason/bringup-7.3/out/fip_noroot.bin` | 9,325,556 B，无 root=（只验证 4 核/eMMC），base `0x1FFBE30` |
| `/home/jason/bringup-7.3/out/fip_root.bin` | 9,325,604 B，bootargs 含 `root=/dev/mmcblk0p8 rootfstype=ext4 rootwait rw`，base `0x1FFBE30` |
| `/home/jason/bringup-7.3/out/ubuntu-26.04.1-arm64.ext4` | 2 GB Ubuntu 26.04.1 arm64 cloud rootfs（含 systemd；sha256 `4e97c9d9…`） |

步骤：
1. U-Boot 里 `tftp 0x1FFBE30 fip_noroot.bin; bootm 0x1FFBE30`，Expected：`smp: Brought up 4 CPUs`，且 `mmc0: ...`/`mmcblk0` 出现。
2. 写 rootfs 到 eMMC p8（start block `0x97000`）：
   `bash docs/porting/scripts/flash_image_emmc.sh /home/jason/bringup-7.3/out/ubuntu-26.04.1-arm64.ext4 0x97000 33554432`
   （分块 TFTP→mmc write→回读 CRC；中断可用第 4 个参数续传。）
3. 写 P1 rootfs FIP 到 p6 并设 bootcmd：
   ```
   tftp 0x1FFBE30 fip_root.bin
   mmc write 0 0x1FFBE30 0x7000 0x47A7
   setenv bootcmd 'mmc read 0 0x1FFBE30 0x7000 0x47A7; bootm 0x1FFBE30'
   saveenv
   ```
4. 复位，Expected：Ubuntu 26.04 启动到 `hi3798mv300 login:`（root/root，串口 ttyAMA0 115200）。

---

# 当前可用固件构建/刷写 Runbook（2026-11-01 更新，Round 41–56）

## A. 构建桌面/全功能固件

```sh
bash docs/porting/scripts/build_desktop_fip.sh
# 产物：/tmp/fip_desk_pad.bin（12,216,320 B，固定 0x5D34 块）
```

脚本要点：
1. 恢复 `/tmp/config_full_rd2`（全功能配置），关闭 initramfs、IPv6（省体积）；
2. USB 存储/xHCI/NTFS 以**模块**编译（`CONFIG_*=m`），WiFi rtw88 全部模块；
3. `mkuimage.py --pad-to` **必须**用 Image header 的 `image_size`（含 BSS）；用文件大小会导致内核在 BL31 后静默失败（重要！）；
4. `fip_create` **不会截断已存在输出**，脚本先 `rm -f fip_desk.bin`；
5. ATF 限制：FIP > ≈11.5MB 静默失败（历史上 11.89/14.4/19.5MB 均失败）；当前 FIP ≈10.7–10.8MB，余量充足；
6. 模块需部署到板卡：`make modules_install INSTALL_MOD_PATH=/tmp/modroot` → 打包 → 解压到 `/lib/modules/7.3.0` → `depmod -a`。

## B. 刷写 FIP（二选一）

**方法 1（推荐，Linux 下直接写 eMMC）：**
```sh
scp /tmp/fip_desk_pad.bin root@192.168.2.10:/root/fw/fip_new.bin
ssh root@192.168.2.10 'dd if=/root/fw/fip_new.bin of=/dev/mmcblk0 bs=512 seek=$((0x7000)) conv=fsync; sync'
```
随后串口 RTS 复位（pyserial，RTS True 1.0s → False）。

**方法 2（U-Boot tftp 到 RAM 直接 bootm，不写 eMMC；用于救砖/测试）：**
```
setenv ipaddr 192.168.2.10; setenv serverip 192.168.2.100
tftp 0x1FFAE30 fip_xxx.bin
bootm 0x1FFAE30
```
tftpd 根目录：`C:\Users\yujia\Desktop\hi3798_boot`。bootcmd 必须保持：
`mmc read 0 0x1FFAE30 0x7000 0x5D34; bootm 0x1FFAE30`

## C. 救援流程（启动失败/卡死）

1. RTS 复位，连续发 Ctrl+C 停在 `fastboot#`；
2. `tftp 0x1FFAE30 fip_rescue_med.bin; bootm 0x1FFAE30` → 进 initramfs shell（提示符 `~ #`）；
3. `mount /dev/mmcblk0p1 /mnt` 后可直接编辑根分区（例：mask 服务、改 fstab、dd 固件）；`sync; umount /mnt`。
4. 若 eMMC 内容损坏，可通过 tftp 分块 + `zcat | dd` 重灌 rootfs（见 progress.md 灾难恢复流程）。

## D. 已修复的启动问题（2026-11-01）

- **偶发卡在 `tmp.mount` + `systemd-rfkill.service`**：遮蔽 `systemd-rfkill.service`、删除 `/etc/fstab` 的 `tmpfs /tmp` 行后复测两次均正常启动。
- **U 盘自动挂载**：fstab 使用 `x-systemd.automount,nofail`（USB 存储为模块，访问时按需挂载）。
- **WiFi 自动加载**：`/etc/modules-load.d/99-hi3798.conf` 列出 usb_storage/sd_mod/xhci_hcd/xhci_plat_hcd/ntfs3/rtw88_8822bs。

## E. 当前功能状态（板卡实测）

| 功能 | 状态 |
|---|---|
| 启动（Ubuntu 26.04，内核 7.3） | ✅ ~20s 到 login，两次复位复测正常 |
| HDMI 1080p60 桌面（Weston pixman + Xwayland + RDP 3389） | ✅ |
| GPU lima/Mesa：GL 渲染器 + glmark2 | ✅ 轻负载（320x240 ~308–980 FPS）；⚠️ VBO 重负载 pp 超时 |
| SSH / Samba / 静态网络 192.168.2.10 | ✅ |
| U 盘 62GB exfat（自动挂载、Samba 共享、读写 ~36/12 MB/s） | ✅ |
| USB2 主机（2 口）+ USB3 xHCI 驱动（无物理口） | ✅ |
| WiFi RTL8822BS（SDIO2 + rtw88 固件 30.20.0 + 扫描 10+ AP） | ✅（连接待 SSID/密码） |
| AIAO 音频硬件上电（ver 0x20130516） | ✅（HDMI 音频未完成） |
| HDMI 音频 / VDEC 4K / VENC / BT | ❌ 需 vendor 驱动（HDMI TX 寄存器 CPU 不可读） |

## F. 模块相关经验（2026-11-01 血泪）

- **新增内核模块必须与内核 Image 在同一配置、同一次构建中产出**；事后单独改 .config 补编模块（如 zram/lzo 实验）会导致 `finit_module` 路径 spinlock 死锁、用户态卡死。
- 当前运行内核为 `fip_clean3`（Image #142），其配套模块为当时 `modules_install` 产物（rtw88/cfg80211/mac80211/usb_storage/sd_mod/scsi_mod/xhci/ntfs3 等），可正常加载。
- zram 实验结论：不可用，已放弃（不涉入交付）。
- RTS 复位偶尔一次不生效，重试或延长脉冲（≥1s）即可。

## G. 软件录屏（无 VENC 时的替代）

```sh
screen_record.sh [fps] [秒数] [输出文件]     # 默认 5fps 5s /root/record.mp4
# 例：3fps 3s → /root/record_test.mp4（1920x1080 H.264，可 ffprobe 校验）
```
原理：`/dev/mem` 直读 VDP 扫描缓冲（地址取自 dmesg "scanout enabled"）+ python 管道 + ffmpeg libx264 编码。
限制：1080p 实际 3–5fps（CPU 软编码）；高帧率需 vendor VENC 驱动（未移植）。

## H. 启动优化（2026-11-01，Round 63）

| 指标 | 优化前 | 优化后 |
|---|---|---|
| 启动总时长 | 24.9s (kernel 2.6 + userspace 22.3) | **14.3s (kernel 2.7 + userspace 11.6)** |
| 内存 used | 180 MB | **149 MB** |
| 运行中 service | 32 | 27 |

已禁用（无对应硬件/用途）：
- `snapd.service/snapd.socket/snapd.seeded/snapd.apparmor`（不用 snap）
- `cloud-init-local/cloud-config/cloud-final/cloud-init.target` + `cloud-init-main/cloud-init-network`（非云环境）
- `apport.service` / `apport-autoreport.path`（崩溃上报）
- `networkd-dispatcher.service`（等待 7s 的元凶之一）
- `ModemManager.service`（无 modem）
- `unattended-upgrades.service`、`lxd-installer.socket`、`motd-news.timer`
- `rsyslog.service`（启动占用 14.4s；日志改由 systemd-journald 保留）
- `lvm2-monitor.service`、`open-iscsi.service`、`open-vm-tools.service`（无 LVM/iSCSI/VM）
- `bluetooth.service`（BT 驱动尚未打通，暂不启动）

另：`/etc/hosts` 增加 `127.0.1.1 hi3798mv300` 避免主机名解析延迟。

回滚：`systemctl enable <service>` 再 `systemctl daemon-reload`。

## I. 桌面实用工具/脚本（2026-11-01）

- 浏览器：`dillo`（轻量，Xwayland 下可用；`DISPLAY=:0 dillo <file>`）
- 截图：`/usr/local/bin/screen_shot.sh [out.png]`（直读 VDP 扫描缓冲）
- 录屏：`/usr/local/bin/screen_record.sh [fps] [秒] [out.mp4]`（1080p 3–5fps 软编码）
- WiFi：`/usr/local/bin/wifi_setup.sh <ssid> <pass>`（wpa_supplicant + networkd）
- 中文字体：fonts-wqy-zenhei / fonts-noto-cjk（已装）
- 待查：dillo 下中文显示方块（X core 字体问题）；抓帧画面出现 3 等分重复（疑与 VDP G0 寄存器/抓帧路径有关，待确认电视实际画面后修复）

## J. 截图/录屏（2026-11-01 更新）

- `screen_shot.sh [out.png]`：优先 weston-screenshooter（需 weston 以 `--debug` 启动，服务已加），失败回退 /dev/mem 直读。
- ⚠️ 已知问题：本驱动的 drm_simple_display_pipe + weston shadow framebuffer 组合下，截图可能得到异常尺寸/内容；**以 RDP 远程桌面或电视目视作为显示验收依据**，截图仅作辅助。
- `screen_record.sh`（/dev/mem 直读 + ffmpeg）同样受此影响，录屏内容可能不代表最终显示；如需精确录屏建议走 RDP 端。

## K. 验收自检脚本（2026-11-01）

```sh
/usr/local/bin/acceptance_check.sh      # 只读，28 项自检，输出 PASS/WARN/FAIL 汇总
```
覆盖：启动/桌面/终端/SSH/网络/Samba/RDP/U盘/WiFi 硬件+驱动+扫描/GPU/显示/AIAO/内核错误/failed 单元/稳定性监控/备份定时器/磁盘/内存。

## L. I2C / GPIO（2026-11-01 新增，已刷入）

- I2C：mainline `i2c-hix5hd2` 驱动 + DTS i2c0/1/2（0xf8b10000/11000/12000，IRQ 38/39/40，CRG I2C 时钟）；`/dev/i2c-0..2`，`i2cdetect -l` 显示 3 个适配器。
- GPIO：ARM PL061 ×10 组（0xf8b20000 + 0x1000*n，IRQ 108+n）；`pl061_gpio ... chip registered` ×10，`/dev/gpiochip0..9`。
- 看门狗：SP805 WDT @0xf8a2c000（IRQ 29）→ `/dev/watchdog0`（mainline sp805_wdt）。**注意**：bootloader 可能已使能 WDT（约 3 分钟超时），若仅注册驱动而不喂狗会导致板卡周期性复位；已通过 `/etc/systemd/system.conf` 的 `RuntimeWatchdogSec=30s` 让 systemd 喂狗（journal 显示 "Using hardware watchdog /dev/watchdog0"）。
- SPI：PL022 @0xf8b1a000（IRQ 45）→ `/sys/class/spi_master/spi0`（mainline spi-pl022）。
- 说明：HDMI DDC/EDID 未在 i2c0-2 上发现设备（i2cdetect 全 --），可能 TV DDC 走 HDMI IP 内部 I2C 或需额外引脚配置。

## M. 系统日常配置（2026-11-01）

- 时区：`Asia/Shanghai`（`timedatectl set-timezone Asia/Shanghai`；无 RTC，重启后时间需 NTP 校准）。
- 日志：持久化到 `/var/log/journal`，限额 64M（`/etc/systemd/journald.conf.d/size.conf`）。
- 串口：`ttyAMA0` root 自动登录（`serial-getty@ttyAMA0.service.d/autologin.conf`）。
- 稳定看门狗：systemd `RuntimeWatchdogSec=30s` 喂 /dev/watchdog0。
- 控制台字体：Terminus 32x16（`/etc/default/console-setup`，`systemctl restart console-setup`）。
- 自动登录：`getty@tty1` 与 `serial-getty@ttyAMA0` 均配置 root autologin（drop-in）。

## N. 关键：fastboot 环境变量 bootargs 必须保留分区表（2026-11-01 黑屏事故）

- 现象：电视/显示器**连 bootloader logo 都没有**（全程无信号，黑屏）。
- 根因：fastboot 的 PDM（logo/显示参数管理）通过 `getenv("bootargs")` 解析
  `mtdparts=` / `blkdevparts=` 得到 flash 分区表；若 env bootargs 被改成不含分区表的字符串
  （例如仅 `mem=256M console=ttyAMA0,115200 ...`），PDM 找不到 `baseparam`/`logo` 分区
  → 显示参数无效 → 跳过 `PRODUCT_DisplayInit()` → HDMI TX/VDP 不初始化 → 黑屏。
- 证据：串口 `LOGO_DBG` 全 0（logo_data=0、G0CTRL=0、DHD=0）；eMMC 2M(baseparam)/10M(logo)
  分区数据完好（"BASE_TAB"/"LOGO_TAB" 魔数）。
- 修复（fastboot 控制台）：
```
setenv bootargs "console=ttyAMA0,115200 root=/dev/mmcblk0p7 rootfstype=ext4 rootwait blkdevparts=mmcblk0:1M(boot),1M(bootargs),4M(baseparam),4M(pqparam),4M(logo),32M(kernel),256M(rootfs),-(ubuntu)"
saveenv
```
- 修复后 LOGO_DBG 正常（logo_data=0x6147f0、G0CTRL=0xcc008368、DHD HS1=0xbf077f …），
  HDMI 恢复，Ubuntu 桌面正常显示。
- **规则**：今后任何操作都不得清空/覆盖 env bootargs；如需修改只追加，不要删除 `blkdevparts=`。
  备份：fastboot `printenv` 输出、`/root/fw/` 下固件、U 盘自动备份。

## O. USB 全速设备（鼠标/键盘）支持：OHCI 攻克记录（2026-11-01）

- 现象：U 盘（高速 480Mbps）正常，鼠标/键盘（全速 12Mbps）不识别；bootloader `usb start` 报 `cannot reset port 1!?`。
- 根因：由于历史原因，**EHCI 初始化完成后 CRG46(0xf8a22000+0xb8) 的 bit1/bit2（OHCI48M/OHCI12M 时钟）被清掉**（读回 0x71，应为 0x7f）。
  此时任何对 OHCI 寄存器（0xf9880000）的访问都会**硬挂 AXI 总线**（串口无输出、看门狗复位）——这正是历次"开 OHCI 必挂"的原因。
- 验证：先写 CRG46 |= 0x7f（并清 bit12-17 控制器复位），再读 `HcRevision(0x00)` → 返回 `0x00000110`（OHCI 1.1），系统稳定。
- 根治（2026-11-01 Round 133，内核驱动层）：
  `drivers/clk/hisilicon/crg-hi3798cv200.c` 给 `HISTB_USB2_12M_CLK`/`48M_CLK`/`OTG_UTMI_CLK` 加 **CLK_IGNORE_UNUSED**，
  避免 `clk_disable_unused` 在启动后期关闭它们。修复后 CRG46 保持 0x7f，OHCI 不再挂死，且**无需任何补丁模块**。
  1. （历史/备选）补丁模块 `ohci_clk.ko` 已从 ohci-usb.sh 移除，保留作应急回退。
  2. 内核模块 `ohci-hcd.ko`/`ohci-platform.ko`（内核对应用 `CONFIG_USB_OHCI_HCD=m` + `_PLATFORM=m`，DTS ohci 节点 `status="okay"`）。
  3. `/usr/local/bin/ohci-usb.sh` + `ohci-usb.service`（oneshot，开机按序 insmod 三者）。
- 验证结果：`ohci-platform f9880000.usb` 注册 bus 2，`usb 2-1: new full-speed USB device`，`input: Logitech USB Receiver ... Mouse`，
  weston libinput 自动接管 event0/event1 并关联 HDMI-A-1，鼠标光标出现、可操作。
- 注意：**任何 eMMC 写入后必须 `sync`**（曾因掉电导致 unit/模块文件 0 字节或损坏，`Invalid ELF header`）。

## P. 桌面应用环境问题（视频/PDF/图片/办公打不开）——2026-11-01

- 现象：从桌面面板或文件管理器打开视频失败（mpv 报 "Error opening/initializing the selected video_out"）。
- 根因：weston 桌面/PCManFM 启动的应用环境被"净化"（`XDG_RUNTIME_DIR=/run/user/0`，无 `WAYLAND_DISPLAY`/`DISPLAY`），
  而 mpv 配置 `vo=wlshm` 需要 Wayland 环境。
- 修复：为桌面应用提供显式环境包装脚本（导出 `XDG_RUNTIME_DIR=/run/weston WAYLAND_DISPLAY=wayland-1 DISPLAY=:0`）：
  - `/usr/local/bin/hi-mpv.sh` → `mpv.desktop` 的 Exec
  - `/usr/local/bin/hi-pdf-run.sh`、`hi-image-run.sh` → 对应 .desktop
  - `/usr/local/bin/lo-run.sh` + `/usr/local/share/applications/libreoffice-*.desktop` 覆盖
- 验证：在净化环境下 `hi-mpv.sh` 播放成功、纯 mpv 失败；PDF/图片/LibreOffice 包装后均正常。

## Q. 72h 稳定性证据与日报（2026-11-02）

- 每小时自检：`hi-selftest.timer` → `/root/selftest.log`（28 项）
- 开机自检：`hi-boot-selftest.timer`（OnBootSec=3min）→ `/root/boot-selftest.log`（28 项验收 + dmesg oops 扫描）
- 每分钟稳定性采样：`stability-monitor` → `/root/stability-YYYYMMDD.log`（uptime/load/mem/faults/warn_alloc/wifi）
- 日报生成：`/usr/local/bin/stability-report.sh` + `stability-report.timer`（每日 00:10）
  - 输出 `/root/stability-report.txt`：本次启动 uptime、72h 进度百分比、本次启动 faults 统计、历史累计、最近自检、服务状态
- 说明：72h 计时需真实 3 天连续运行；当前固件全天 soak（mpv `--vo=null` 1080p 软解）持续运行，重启会重置"本次启动"进度。

## R. 备份与恢复验证（2026-11-02）

- 备份内容：`/mnt/usb/hi3798-backup/`
  - `fip-p6.bin` + `fip-p6.md5`（当前 p6 固件，12MB）
  - `board-config.tgz`：`/etc/fstab`、`/etc/systemd/network`、`weston.ini`、`weston.service`、
    全部自定义 `*.service`/`*.timer`、`/usr/local/bin/*`（含 acceptance/ohci-usb/stability-report 等）、
    OHCI 三个内核模块、Samba 配置、桌面 .desktop 覆盖
  - `dmesg.txt`、`lsmod.txt`、`uname.txt`、`selftest.log`、`stability-*.log`
- 验证方法：`tar xzf board-config.tgz -C /tmp/rt3` 后逐项检查；`md5sum fip-p6.bin` 与当前 p6 比对。
- 恢复流程：fastboot 下 `tftp` 拷 fip-p6.bin → `mmc write` 回 p6；rootfs 侧解包 board-config.tgz 到 `/` 后 `systemctl daemon-reload`。
- 关键服务 restart 策略：weston / weston-terminal / stability-monitor / stability-load 均 `Restart=always` + `StartLimitIntervalSec=0`（无限自愈）。
- 自愈实测：kill weston-terminal 后 4s 内 systemd 重启，状态 active。
- soak 负载：`stability-load.sh` 三相循环（视频软解 120s → CPU 满载 60s → 网络吞吐 30s），日志 `/root/stability-load.log`（滚动 500 行）。
## S. 温度传感器（hi3798-thermal，2026-11-02）

- 驱动：`drivers/hwmon/hi3798_thermal.c`（mainline，built-in），DTS 节点 `thermal@f8a23000`，compatible `hisilicon,hi3798-thermal`。
- 算法来源：vendor `drivers/hisilicon/thermal/hi3798cvx-thermal.c`：写 PMC 0xF8A23000+0x28=0x6005 启动，延时 20ms，读 +0x30..+0x3C 的 8 个 10bit 采样，写 0 停止；`temp(mC)=((code-125)*165/806-40)*1000`。
- 实测注意：8 个采样槽并非全部有效（部分返回 16/82/178 等异常值），驱动只保留 400~900 的合理码值取中位数；首次读需预热（probe 内已做一次）。
- 使用：`cat /sys/class/hwmon/hwmon0/temp1_input`（≈63000 = 63°C），验收项 27 已纳入。
- 配置：需 `CONFIG_HWMON=y`（drivers/hwmon 目录受 HWMON 门控）+ `CONFIG_HI3798_THERMAL=y`。
## T. 无线模组 FCS850R(RTL8822CS) 适配（2026-11-03）

板子无线模组已更换为 **Quectel FCS850R（RTL8822CS）**，旧 RTL8822BS 模组保留兼容。

### WiFi
- 内核配置：`CONFIG_RTW88=m`、`RTW88_CORE/SDIO=m`、`RTW88_8822C=m`、`RTW88_8822CS=m`（旧模组保留 `RTW88_8822B/8822BS=m`）
- 驱动：`rtw88_8822cs.ko` + `rtw88_8822c.ko`（部署到 `/lib/modules/7.3.0/...`，`depmod -a`）
- 固件：`/lib/firmware/rtw88/rtw8822c_fw.bin`、`rtw8822c_wow_fw.bin`（Ubuntu 自带为 .zst，本内核未启用压缩固件，已手工解压）
- 实测：Firmware version 9.9.15，SDIO device id `0xc822`，wlan0 正常连接

### 蓝牙（进行中）
- 模组 BT：UART2 四线（GPIO3_1..3_4），H5/H4 协议，115200/1500000
- 已确认：BT_EN(GPIO4_2) 可控、UART2 环回通过、SoC TX→模组 RX、模组 TX→SoC RX 均通
- 未通：芯片对 HCI Reset / H5 sync 无响应；怀疑 HOST_WAKE_BT(pin49) 需上拉或 32.768kHz 时钟缺失（参考设计含 XO25E32K768）
- 资料：`docs/fcs850r/`（规格书/硬件手册/参考设计/Linux BT 指导）

### 备份
`backup-fw.sh` 已纳入：rtw88_8822c/8822cs.ko、hci_uart.ko、rtl8822cs_fw/config、rtw8822c_fw/wow_fw。
- 视频播放：`/etc/mpv/mpv.conf` 必须设 `vo=wlshm` + `hwdec=no`（pixman Wayland 桌面下默认 vo=gpu 会黑屏）；`hi-mpv.sh` 已显式传参。
