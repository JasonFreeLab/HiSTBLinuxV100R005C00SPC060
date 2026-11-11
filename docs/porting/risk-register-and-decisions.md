# 风险登记与决策记录（v1.0）

## 1. 决策记录（Decision Log）

| ID | 决策 | 理由 | 代价/风险 |
|---|---|---|---|
| D1 | 内核基线 v7.3 mainline，开发期跟 7.3.y，产品冻结切最近的 7.x LTS | 7.x 满足“至少 6.x”；7.3 是最新主线，生命周期最长 | 7.x 暂无 LTS（最近 LTS 6.18）；冻结前需持续跟 stable |
| D2 | arm64 内核 + Ubuntu arm64 | A53 支持 64 位；Ubuntu arm64 生态完整；避免 armhf 生态萎缩 | 启动链需 arm64 支持（见 D3） |
| D3 | 优先复用 fastboot 既有 arm64/TEE 路径；不支持时预案 A（移植 ATF）或 B（fastboot 非 TEE 补丁） | 不重写 bootloader，最快验证 | ATF 无 mv300 平台；fastboot 补丁需板级调试 |
| D4 | 显示走 DRM/KMS，重写；simpledrm/fbdev 仅早期点亮 | 标准框架、Wayland/Mesa 需要 KMS；fbdev 无法长期满足 | 驱动工作量大（8–15 人月） |
| D5 | 音频只做 HDMI PCM | 用户确认无模拟/耳机需求 | 无 SPDIF/模拟/麦克风 |
| D6 | 录屏只录屏幕、1080p60，VENC + PipeWire | 用户确认；1080p60 对 VENC/内存压力小 | 无 4K 录制、无外部输入 |
| D7 | WiFi/BT 走 mainline rtw88/btrtl，厂商驱动仅参考 | 主线已支持 RTL8822CS SDIO/BT；避免 4.4 驱动移植 | 需确认使能脚/32k 时钟/固件 |
| D8 | CMA 256M（可调 384M）+ zram 256M；桌面 1080p60，4K60 全屏直出 | 1GB DDR3-1866 带宽/内存限制 | 4K60 桌面合成不可行 |
| D9 | 沿用现有分区偏移，ubuntu 分区扩到 ~7G，Sel=1 | 8GB eMMC 容量足够；改动最小 | 需更新 HiTool 分区 XML/烧录脚本 |
| D10 | 无 sudo 环境下用 TUNA 下载 Ubuntu cross 工具链 deb 解包使用 | 主机无 sudo；国际下载过慢（30KB/s），TUNA 快（4MB/s） | 需 set PATH + LD_LIBRARY_PATH；升级需重复下载 |
| D11 | 工作区：`/home/jason/bringup-7.3` 用于内核/产物；SDK 仓库只放 docs/scripts | SDK 曾两次被移动/清空；隔离构建目录降低丢失风险 | 两处路径需在 runbook 中明确 |
| D12 | 不自动 git commit/push | 用户未授权提交；仓库含用户改动 | 以 ledger+产物为记录，用户自行提交 |

## 2. 风险登记（Risk Register）

| ID | 风险 | 概率/影响 | 缓解 |
|---|---|---|---|
| R1 | 板载 fastboot 不支持 arm64 直接启动（依赖 TEE/ATF） | 高/极高 | P0 实测；预案 A 移植 ATF（hi3798mv200 平台为起点）或 B 补 fastboot；必要时临时 armhf |
| R2 | VO/HDMI 无主线驱动，重写周期长 | 高/高 | 先 simpledrm/fbdev 点亮；同时用 vendor hifb/HDMI 初始化序列做参考；分阶段（先 1080p60→4K60） |
| R3 | VDEC/VFMw 固件与 V4L2 适配复杂 | 高/高 | 固件源码已有（vfmw_v5.0）；参考社区 v4l2-hisi（cv200）；先 1080p H.264 再 4K HEVC |
| R4 | 1GB DDR3-1866 + 4K60 内存/带宽不足 | 中/高 | KMS 直出 + DMA-BUF 零拷贝；CMA 调整；4K 仅视频全屏；1080p60 桌面 |
| R5 | VPSS 缩放/去隔行重写 | 中/高 | 优先实现缩放（1080p→4K）；去隔行后置；必要时 GPU 缩放 |
| R6 | rtw88 SDIO 与板级使能脚/32k 时钟不匹配 | 中/中 | 先抓原理图确认 GPIO/时钟；固件用 linux-firmware；失败则移植 vendor 驱动 |
| R7 | 无 TRM/寄存器手册 | 中/高 | 以 vendor 4.4 源码为寄存器参考；逐项对照 mainline 驱动；增加联调时间 |
| R8 | 内存紧张导致 OOM/卡顿 | 中/中 | zram、轻量桌面（labwc/cage）、限制并发应用 |
| R9 | 内核裁剪导致 missing driver/panic | 中/中 | P2 起用 defconfig 裁剪而非 allnoconfig；保留 GIC/timer/serial/DRM/V4L2/ASoC |
| R10 | 工具链/环境丢失（目录被移动） | 中/中 | 产物与脚本均回写仓库 docs/porting；runbook 记录恢复步骤 |

## 3. 变更控制

- 任何偏离本规格/计划的决定，写入执行 ledger 的 `Ruling:` 行，格式：`<任务>: Ruling: <决定> — <原因> — <错误代价>`。
- 规格变更需同步更新 `docs/superpowers/specs/...design.md` 与本文档 D 表。

## 4. 2026-10-30 新增决策（P0 阻塞）

| ID | 决策/发现 | 理由 | 代价/风险 |
|---|---|---|---|
| D13 | 板载 Fastboot 3.3.0 为 32 位构建（无 go64/TEE/ATF），无法启动 arm64 内核 | 串口实测 + 源码确认（`fastboot.mak:56` 仅在 arm64 架构下定义 ARM64_SUPPORT） | 需要 D3 预案 A（刷 bootloader）或 B（arm32/armhf） |
| D14 | 推荐先走 B：mainline arm32 + Ubuntu armhf，保留现有 bootloader | 不刷 bootloader，P0 快速可用；主 line 已支持 A53 的 AArch32（bcm2837 等先例） | 32 位用户态；Ubuntu armhf 长期支持需评估 |
| D15 | 不改动 eMMC/bootloader（截至本次） | 避免砖机；仅内存加载尝试 | arm64 路线需后续刷写 fastboot/ATF |

## 2026-11-01 新增决策/风险

1. **FIP 大小与 pad 规则（已缓解）**：ATF 对 BL33/FIP 大小敏感（>≈11.5MB 静默失败）；`mkuimage --pad-to` 必须用 header image_size（含 BSS）。缓解：模块化驱动 + 正确 pad + 构建脚本自动 rm fip_create 输出。
2. **systemd-rfkill 启动卡死（已修复）**：WiFi/rfkill 模块晚加载导致设备单元等待链；缓解：mask systemd-rfkill.service、去掉 fstab tmpfs /tmp。
3. **HDMI TX CPU 不可读（接受）**：HDMI 音频/EDID/4K 输出需 vendor HDMI 驱动移植，超出当前范围；当前画面由 bootloader 固定 1080p 输出。
4. **lima VBO 重负载 pp 超时（接受，记录）**：GL 桌面/轻负载可用，VBO 重负载会触发 INVALID_PLIST/超时；桌面默认 pixman 确保稳定。
5. **无物理 USB3 口**：xHCI 驱动就绪但板卡只有 2×USB2，USB3 仅作能力储备。
