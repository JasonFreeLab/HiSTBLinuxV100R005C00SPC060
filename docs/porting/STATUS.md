# 系统状态仪表盘（最后更新 2026-11-10；**当前状态以 [闭环矩阵](ROADMAP-CLOSURE-MATRIX-2026-11-08.md)、[能力矩阵](CAPABILITY-MATRIX.md)、[路线图 §0.0](HARDWARE-ACCELERATION-FIXLIST-ROADMAP-2026-11-08.md) 为准**）

## 固件/系统
| 项 | 值 |
|---|---|
| p6 FIP | `fip_hrt_pad` sha1 **2dea80c52b4aee1c4be4c644c20f5fac4b5ce844**（2026-11-10 DRM-02：驱动 patch 0002 + `HIGH_RES_TIMERS=y`；旧 `fip_uinput` md5 cd7a04a2… 已被替换） |
| 内核 | Linux 7.3.0 **#188** aarch64（Image `deaa3146`，config `38eacf2d`；`drm_crtc_vblank_on()` 对称修复 + `HIGH_RES_TIMERS=y`） |
| rootfs | Ubuntu 26.04.1（6.9G，已用 6.1G / 94%，剩约 400 MB） |
| Swap | 内建 zram0 **768MB**（lzo-rle，开机自动） |
| 稳定性 soak | stability-load（mpv 1080p 软解 `--vo=null` 无窗口，~77% CPU）+ monitor 每分钟记录 |
| 启动 | kernel 2.6s + userspace 13.3s ≈ **16s**（SSH 20–40s） |

## 服务
weston(pixman) / weston-terminal / ssh / smbd / systemd-networkd /
stability-monitor / stability-load —— 全部 active

## 外设与接口
| 接口 | 状态 |
|---|---|
| eMMC | ✅ /dev/mmcblk0（p1 rootfs 6.9G） |
| USB2 | ✅ EHCI 双口；U盘 sda1 exfat 自动挂载 /mnt/usb |
| 以太网 | ✅ eth0 192.168.2.10/24（ping 0% loss） |
| WiFi | ✅ RTL8822BS **已连接 SSID wifi**（192.168.2.27 DHCP，互联网可用，power_save off；**SSH/RDP/Samba 经 WiFi IP 均可访问**） |
| I2C | ✅ /dev/i2c-0..2（hix5hd2） |
| GPIO | ✅ /dev/gpiochip0..9（PL061） |
| WDT | ✅ /dev/watchdog0（systemd RuntimeWatchdogSec=30s 喂狗） |
| SPI | ✅ spi0 master（PL022） |
| 显示 | ✅ hi3798-drm VDP G0，1920x1080@60；**桌面截图可用**（weston-screenshooter，--debug 已启用） |
| 浏览器 | ✅ WebKitGTK GUI 浏览器（地址栏/导航/F11 全屏/缩放/下载到 ~/Downloads；快照实测渲染正确；WebM 可播；H.264 页内不支持） |
| PDF | ✅ hi-pdf.py（poppler 渲染 + GTK3 翻页；已关联 .pdf） |
| 图片 | ✅ hi-image.py（缩放/全屏；已关联 png/jpg/gif/webp/bmp） |
| 文件关联 | ✅ pdf→hi-pdf、图片→hi-image、文本→mousepad、视频→mpv、目录→pcmanfm |
| 桌面体验 | ✅ 壁纸 + 空闲不黑屏（weston idle-time=0）；鼠标/键盘可用；桌面 5 个启动器 |
| 办公 | ✅ LibreOffice 26.2 Writer/Calc（headless 转换验证通过，GUI 启动正常） |
| 音频 | ⚠️ AIAO 上电（ver=0x20130516）；HDMI 音频未通 |
| GPU | ⚠️ lima Mali450 可用（GL 可选）；多窗口 soak 会 pp 复位 → 默认 pixman |

## 稳定性（72h 测试，进行中）
- 监控日志：`/root/stability-*.log`，每分钟一条：uptime/负载/内存/faults(Oops/BUG)/warn_alloc/GPU错误/服务
- 观察窗口内：**faults=0，gpu_err=0，服务始终 active**（另有 1 次 `page allocation failure` 警告：rtw88 SDIO 在内存高压下 GFP_ATOMIC 分配失败，非致命；已设 `vm.min_free_kbytes=16384` 缓解）
- 计时基准：`/proc/uptime`（板卡无 RTC，时钟每次启动跳变）

## 自动维护
- WiFi 自愈：`wifi-watchdog.timer` 每 2 分钟检查，连续 3 次 ping 失败自动重启 wpa_supplicant + networkd（已验证可从断线恢复）
- 自动安全更新：`unattended-upgrades` 已启用（仅安全/更新仓库，不会换内核；已验证升级后服务正常）
- U盘备份：`hi3798-backup.timer`（开机 3min + 每日）→ `/mnt/usb/hi3798-backup/`（FIP md5/配置/journalctl dmesg/**自检与稳定性日志**）
- 自动自检：`hi-selftest.timer` 每小时运行 acceptance_check → `/root/selftest.log`（保留最近 2000 行）
- eMMC trim：`fstrim.timer`（每周）
- 日志：persistent journal，限额 64M


## 硬件加速最新入口（2026-11-08 更新）

当前现状及后续验收路线见[硬件加速现状与路线图（2026-11-07）](HARDWARE-ACCELERATION-STATUS-ROADMAP-2026-11-07.md)。

**修复进展（滚动）**：已闭环 INF-02/03/04（7 阶段全上板 PASS）、VENC-01/03/04/05/06/07、JPEG-01、PNG-01/02、DOC-01..06；**VDEC-01 已闭环**（HEVC head_w1 模块 7/7 PASS，抓帧 bit-exact）；**VDEC-03 已闭环**（1080p/4K 抓帧像素验证，HEVC 4K 20/20 bit-exact）；部分：PNG-04；VDEC-02（模式 A，boot 状态依赖，重试兜底）未根治。待攻坚：VDEC-02/04/05/07、VENC 间歇崩溃、PNG-03、GPU/DRM/MISS。详见[修复进度表](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md)。

> **2026-11-08 Round 7 更新（增量）**：**VDEC-01 已完全闭环**——验收对 `hi_vdec_hevc_head_w1.ko`(`047cad9b`)+`vdec_spec_hevc_head`(`6ada1250`) 全矩阵 **7/7 PASS**（HEVC 1080p/4K60 8bit/Main10/20M/100M + H.264 控制），抓帧像素 bit-exact；**VDEC-03 的 4K 抓帧缺口同时闭环**（`vdec_no_vcmp=1`，1080p/4K 抓帧 20/20）。证据：[VDEC-01 上板验证](artifacts/hwtest-2026-11-07/fixes/vdec-01/BOARD-VERIFY-H1.md) §3/§4、[VDEC-03](artifacts/hwtest-2026-11-07/fixes/vdec-03/FIX-REPORT.md) §7；当前验收配对见[配对 §1.5/§1.8](TOOL-MODULE-PAIRING.md)。

> **2026-11-08 Round 8–14 摘要（04:00–06:30，增量；详见[修复进度表](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md) 与[配对 §1.9](TOOL-MODULE-PAIRING.md)）**
> - **验收模块变更**：VDEC 当前验收对 = **`hi_vdec_reloadfix.ko`（`e8859791`）+ `vdec_spec_hevc_head`（`6ada1250`）**；head_w1（`047cad9b`）7/7 降为历史记录。
> - **VDEC-02 修复链**：v1 `9005a9d5`（4K 回归 + rmmod Oops，退回）→ v2 `b62e5504`（**SCD ISR NULL panic 已修**、kill-race 100 次 0 panic）→ devfix `079b733f`（class 名 Oops 修复，reload 仍 EEXIST）→ **reloadfix `e8859791`**（`0007` exit inverse；rmmod/insmod ×10 PASS、taint 4096、0 WARN/Oops）；**交付间歇仍在**（部分 boot 4K 0/20、尾帧 28/30），按重试 3 次判定、非回归。
> - **VDEC-01/03**：reloadfix 矩阵两 boot 4/7+5/7（VDEC-02 间歇）；**抓帧像素 bit-exact 已用 reloadfix 复核 PASS**（1080p pts0：`y_identical=True`/`max_diff=0`，[RMMOD-RELOADFIX-VERIFY §5](artifacts/hwtest-2026-11-07/fixes/vdec-02/RMMOD-RELOADFIX-VERIFY.md)）。
> - **VDEC-04**：1080p 多 slice（2/4 slices、含 B 帧、360p）**全 PASS**；HEVC 1080p s4/wppon **30/30**；4K 单/多 slice 单用例 **20/20**；此前长序列失联根因=SCD panic（已修），4K 长序列待复测（[BOARD-VDEC0405-RESULTS](artifacts/hwtest-2026-11-07/fixes/vdec-04/BOARD-VDEC0405-RESULTS.md)）。
> - **VDEC-05**：4K cold **20/20 可用**但吞吐≈0.24×steady；steady 12/12 全 PASS；consecutive 2/10 尾帧 90 s 超时；判据：cold 可用≠达标、**预热仍有益**；`mmz_used` 漂移待查。
> - **VENC-02**：4K 编码=**NA（硬件不支持）**（`0x801d0002`；VENC 最大 `1920×1088`，宏上限与硬件能力一致；2048×1080 也拒；**非编译开关，换 SDK 不可解**）；**VENC 间歇崩溃** crash-repro 首轮 **22 次无崩溃**（1 例噪声 `completed=18` = VENC-07 预期丢帧）。
> - **INF-04**：**8/8 阶段上板 PASS**（4K 阶段改 decode-only + 2 帧抓帧、Y sha1 一致）。
> - **GPU/DRM**：GPU-01 轻载 PASS（Mali450）、重载 pp 复位 PARTIAL；GPU-02 200 MHz 定频；GPU-03 headless GL 可用、生产 pixman→llvmpipe；DRM-01/03/04 限制确认、DRM-02 无 atomic props（运行级待测）。**MISS-01..04 全部 NA**（VPSS/TDE/SEC/音频未移植）；**OPS-01** soak 设计+脚本就绪、未真跑。
> - **剩余工作**：VDEC-02 交付间歇/mmz 漂移、VDEC-04 4K 长序列复测、VDEC-05 预热判据定档、VENC-07 `--drift 101` 判别、VENC 崩溃长时、GPU-01 重载稳定性/GPU-04、DRM-02 运行级、OPS-01 真跑、PNG-03/PNG-04。

> **2026-11-08 Round 15–16 摘要（07:35–08:00，增量；详见[修复进度表](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md) 与[闭环矩阵](ROADMAP-CLOSURE-MATRIX-2026-11-08.md)）**
> - **JPEG-02 🟡**：整缓冲 memset 优化（`JPEG_POISON=none` 默认；预期 1080p 全周期 200→~6ms、64MP 4188→~163ms；新 `jpeg_test` `ff1e15f6`），待 soak 后上板 `verify-jpeg-cost.sh`。
> - **JPEG-03 🟡**：**HW 色度=NV21（非 planar，旧报告漏色度）**；`yuvdiff`/compare 判据 **mean≤1/max≤1**（Y 有效 w×h、色度 ceil(w/2)×ceil(h/2)；样本 420/422/444/gray/64mp），待上板 `verify-jpeg-colors.sh`。
> - **JPEG-04 🟡**：**Plan A 去重导出已实现**（jpeg 删 4 行 + png 删 24 行 `EXPORT_SYMBOL`、定义保留；`hi_jpeg_noext`(8f39ceb0, 29,768B)/`hi_png_noext`(7159f862, 47,872B)）；A1–A6 待上板，**若通过则"JPEG+VDEC 同 boot"阻断可解除**。
> - **VDEC-06/07 🟡**：并发脚本就绪（10×60s、success≥9/10/退化<10%/oops=0/CmaFree≥40MB）；VDEC-07 盘点唯一常开热打印=**SPITAG（22 处热路径无门控）**、FILEDBG/PUTBM/VTSTAT/M2DIAG 默认 0、P/D A/B 脚本就绪。
> - **PNG-03/PNG-04 🟡**：PNG-03 同 boot 5 次独立进程脚本就绪；PNG-04 结论=**硬件整幅 NA（vendor 流控）/软件路径唯一交付**（1080p 0.73–1.01s、64MP 11.08s、md5 bit-exact；峰值内存待实测）。
> - **OPS-01 🟡 方法变更**：phased/bundle 因板卡 clean-boot 不可靠不可行 ⇒ **soak-lite**（8h=4 blocks×2h，A=VDEC+GPU+PNG-SW、B=VENC+JPEG+GPU）；blockA 预验证 VDEC 30/30、4K 19→20/20、Mali450 PASS、oops=0；**07:56 启动 8h（block1 运行中）**；24h 未跑。
> - **闭环矩阵统计**：⏳ 6→0（6 项转 🟡 待上板复验），✅23 / 🟡14 / ⏳0 / NA9（46 条口径见 [ROADMAP-CLOSURE-MATRIX-2026-11-08.md](ROADMAP-CLOSURE-MATRIX-2026-11-08.md)）。

> **2026-11-08 定档（最新口径，覆盖上文）**：① 长稳改为 **1h ×3 boot**，**8h/24h 取消**（soak-lite 981 迭代 0 oops 已超目标）；② **4K 编码确认硬件不支持**（VENC 最大 1920×1088，非编译开关）；③ **PNG 与 JPEG 统一解码栈**（PNG-07/08，硬件仍为独立 PNGD）。最新路线图见 [FIXLIST-ROADMAP-2026-11-08](HARDWARE-ACCELERATION-FIXLIST-ROADMAP-2026-11-08.md)。

**2026-11-07 全量实测（历史节点）**：见[综合测试报告](artifacts/hwtest-2026-11-07/REPORT.md)与[修复清单与路线图](HARDWARE-ACCELERATION-FIXLIST-ROADMAP-2026-11-07.md)。实测判定：JPEG 单帧、H.264 编码、GPU 基础能力可交付；H.264 解码不稳定（PARTIAL）；HEVC 解码本次 0 帧（FAIL）、HEVC 编码 SPS level=0（PARTIAL）；PNG 硬件本次无输出（软件可用）；4K 编码为平台边界。**历史 PASS ≠ 当前保证**，以本次报告为准。

> **2026-11-08 修复阶段更正（增量，不覆盖上述 11-07 判定）**：HEVC 0 帧=**部署对落后一 commit**（已修复，`047cad9b` 7/7 PASS）；HEVC 编码 `level=0` 已由 VENC-01 修为 `120`；PNG "本次无输出"=**工具误用**（整文件 vs IDAT 组帧），head 像素可复现、整幅仍不可达。见[修复进度表](artifacts/hwtest-2026-11-07/fixes/PROGRESS.md)。

**工具-模块配对登记**：见[TOOL-MODULE-PAIRING.md](TOOL-MODULE-PAIRING.md)（模块 sha1 × 工具 sha1 × 输入流 × 期望 × 证据，含"错配症状"与配对规则；**修复阶段新增 §1.5 VDEC HEVC 当前验收对、§1.6 VENC 模块演进、§1.7 实验模块、§1.8 抓帧配对**）。**依据**：综合报告 §4.1/§4.2、[matrix/harnesses.csv](artifacts/hwtest-2026-11-07/matrix/harnesses.csv)、[matrix/gaps.md](artifacts/hwtest-2026-11-07/matrix/gaps.md)。

> 历史（2026-11-07 前）规格级验收结论：JPEG（1080p/6400万像素）已通过；HEVC/H.264 1080p 8bit 解码达到与软件参考逐像素一致；编码侧 H.264 BP/MP/HP@L4.1 1080p30 CBR 误差约3%、HEVC level 已修复合规；4K 像素、60fps 吞吐、MPEG1/2/4、VBR、MJPEG/PNG 仍未通过或未实现，详见[汇总报告](CODEC-SPEC-ACCEPTANCE-REPORT-2026-11-07.md)。（**依据**：该段为历史口径，当前实测见上方综合测试报告；DOC-01/DOC-05。）

**以下2026-11-03表格为历史快照，M2/M4状态已被上述最新证据覆盖；本页其他系统信息未在本次重新验证。**

## 硬件加速移植（P4/M1–M4）历史状态（2026-11-03）

| 里程碑 | 状态 | 验收证据 |
|---|---|---|
| **M1 JPEG 硬解** | ✅ **通过** | `/dev/jpeg` 可用；1080p 单帧 5.3 ms（189 fps）；PSNR 66.16 dB |
| **M2 VDEC H.264** | ⚠️ **功能验证通过，稳定性未达标** | 320×240 与 1080p 解码 **bit-exact**（Y 通道 PSNR≈99 dB / MSE=0）；但 2026-11-03 复核：连续多次运行会硬挂死复位，单次出帧 0~1 帧 |
| **M3 V4L2 播放器** | ⏸ 未开始 | 依赖 M2 稳定性 |
| **M4 VENC H.264** | 🚧 **未验收（进行中）** | 硬件链路全通：时钟/复位/SMMU/IRQ/MMIO；曾实际产出 `slice0=45080` 字节/帧；当前在多帧 `CfgReg` 阶段总线挂死 |
| **M5（可选）GPU 调压/TDE** | ⏸ 未开始 | — |

详细报告：
- **总报告**：`docs/porting/p4-hardware-acceleration-final-report-2026-11-04.md`（M1–M5 全量状态、根因清单、复现命令、下一步）
- M2：`docs/porting/p4-vdec-m2-status-report-2026-11-03.md`
- M4：`docs/porting/p4-venc-m4-status-report-2026-11-03.md`（含 7 个已定位根因、分段隔离实验、A/B 对比、复现命令）

已知限制：
- 硬件加速模块为**外挂独立 .ko**（`hi_jpeg.ko` / `hi_vdec.ko` / `hi_venc.ko`），未合入内核树
- DTS 需包含 `vdec@f8c30000` / `venc@f8c80000` / `mmz@28000000` / `venc-mmz@34000000` 节点
- 用户态需静态链接 SDK MPI + MMZ shim（见 `port/*user/`）

## 已知问题/限制
1. WiFi 已连接可用；BT 为 vendor SDK 不支持
2. HDMI 音频 / 4K VDEC/VENC / SATA / PWM / RTC / thermal：vendor 私有驱动，未做
   - 蓝牙：vendor cfg.mak 关闭 BT 且仅有 USB BT 驱动 → 硬件/SDK 不支持
3. GPU VBO 重负载会触发 lima 复位；桌面默认 pixman 保稳定
4. 截图工具（/dev/mem 直读）在 weston shadow 路径下不可靠；以 RDP/电视目视为准
5. 无 RTC，时间需 NTP/手动校准

## 快速验证
```sh
ssh root@192.168.2.10
/usr/local/bin/acceptance_check.sh      # 28 项自检
/usr/local/bin/backup-fw.sh             # 手动备份
tail -n 5 /root/stability-*.log         # 稳定性
```

## 交接文档
- 新会话接手硬件加速任务请先读：`docs/porting/HANDOFF-hardware-acceleration-2026-11-04.md`
