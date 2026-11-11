# Hi3798MV300 Linux 7.x + Ubuntu 单板电脑 — 实施计划（v1.0）

> **执行说明（2026-11-01）**：本文件是规划阶段的 TDD 任务分解（含 checkbox）。实际实施以真实硬件 bring-up 为主，
> 部分步骤（如先写失败测试）被更直接的硬件验证替代；完整实施记录见 `.superpowers/sdd/2026-10-30-hi3798mv300-linux7x-ubuntu-implementation-plan/progress.md`
> 与 `docs/porting/logs/`（90+ 证据文件）。本文件末尾附《As-Built 执行状态对照》。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpower-subagent-driven-development (recommended) or superpower-executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Hi3798MV300 板卡上完成 mainline Linux 7.3 arm64 + Ubuntu 26.04 的移植，实现 4K60 硬解、HDMI 输出/音频、Mesa/lima Wayland 桌面、1080p60 硬编码录屏与 RTL8822BS WiFi/BT。

**Architecture:** 沿用板载 32 位 fastboot 从 eMMC kernel 分区加载 uImage（mainline arm64 Image + 追加 DTB）；内核统一走标准子系统（V4L2 M2M / DRM KMS / ASoC / mac80211 / Bluetooth）；用户态为 Ubuntu 26.04 arm64 + Wayland + Mesa/lima；不使用任何厂商 msp 用户态与安全组件。

**Tech Stack:** Linux 7.3（arm64）、U-Boot 风格 uImage、DTS、V4L2 stateful mem2mem、DRM/KMS、ASoC、rtw88（8822BS SDIO）、btrtl/hci_uart、Ubuntu 26.04 glibc、Mesa/lima、Weston/labwc、GStreamer/mpv、PipeWire。

**Spec:** `docs/superpowers/specs/2026-10-30-hi3798mv300-linux7x-ubuntu-design.md`

## Global Constraints

- 内核基线：v7.3 mainline；后续冻结到 7.x LTS（7.x 目前无 LTS，最近 LTS 为 6.18）。
- 架构：arm64（A53）；用户态 Ubuntu arm64，不使用 armhf，不使用 32 位厂商用户态。
- 启动镜像：uImage = mainline `Image` + 追加 DTB；总大小必须 ≤32MB（kernel 分区）；`Image` 建议裁剪至 ≤28MB。
- bootargs 必须位于 DTS `/chosen/bootargs`；不得包含 `mmz=ddr`；必须包含 `console=ttyAMA0,115200 earlycon=pl011,0xf8b00000`、`root=/dev/mmcblk0p8 rootfstype=ext4 rootwait rw`。
- 所有驱动必须接入标准内核子系统，不得引入厂商私有 ioctl/UAPI（mmz、hifb、vo、msp 均禁止）。
- 安全相关组件（TEE/CA/advca/klad/cipher/OTP/DRM/HDCP/安全启动）一律不实现。
- 硬件范围严格按 Spec 第 1/2 节：保留 H.264/H.265 4K60 硬解、VENC 硬编、HDMI 2.0 + HDMI 音频、Mali-450/lima、RTL8822BS WiFi/BT、eMMC/USB/SATA/以太网/GPIO/I2C/SPI/PWM/RTC/WDT/thermal；不保留 HDR/PQ/CEC/IR/LED/模拟音频/DVB/CA。
- 构建环境：交叉工具链位于 `/home/jason/bringup-7.3/toolchain`（Ubuntu 26.04 cross gcc 15），内核源码位于 `/home/jason/bringup-7.3/src/linux-7.3`；运行 make 前必须 `export PATH=/home/jason/bringup-7.3/toolchain/usr/bin:$PATH` 与 `export LD_LIBRARY_PATH=/home/jason/bringup-7.3/toolchain/usr/lib/x86_64-linux-gnu`。
- 文档/脚本产物回写到 SDK 仓库 `docs/porting/`，二进制产物留在 `/home/jason/bringup-7.3/out/`。
- 提交策略：当前阶段不自动向 git 提交（用户未授权）；每个任务以“产物 + 验证命令输出”作为完成证据，记录在 ledger。

## Review Focus

- 启动镜像布局是否与板载 fastboot 的 arm64 启动路径兼容（尤其 TEE/ATF 分支）；不兼容时是否明确给出预案并验证。
- 裁剪后的内核是否仍具备 earlycon、GIC、timer、串口控制台驱动；bootargs 是否被 DTS 正确携带。
- 4K60/1080p60 下 CMA/内存预算是否与实际驱动需求一致（1GB DDR3 约束）。
- WiFi/BT 使能脚、32k 时钟、SDIO/UART 引脚在 DTS 中的描述是否与板级原理图一致（避免“驱动 OK 但无线不工作”）。
- 录屏链路是否真正走 VENC 硬编且零拷贝，避免 CPU 软编导致 1080p60 掉帧。
- 每个阶段是否在真实板卡上验证；未经板卡验证的“驱动完成”不得标记完成。

---

## 阶段与任务总览

| 阶段 | 内容 | 完成标志 | 估算 |
|---|---|---|---|
| P0 | 构建基线 + 最小 DTS + uImage + earlycon 启动 | 串口打印 mainline 内核启动日志 | 1–2 周 |
| P1 | Ubuntu rootfs（eMMC 启动到 shell/SSH） | Ubuntu 登录、网络可用 | 1–2 月 |
| P2 | 显示 DRM/KMS（1080p60/4K60、HDMI 音频骨架） | 电视出画面 + 音频 | 2–4 月 |
| P3 | GPU lima + Wayland 桌面 | Weston/labwc 桌面 GLES2 | 1–2 月 |
| P4 | VDEC/VFMw + VPSS（V4L2 M2M） | mpv/GStreamer 硬解 | 2–4 月 |
| P5 | VENC + 录屏管线 | 1080p60 录屏 | 1–2 月 |
| P6 | WiFi/BT + 外设完善 + 稳定性/性能 | 验收矩阵通过 | 2–3 月 |

> 说明：P2–P6 的详细任务在各自阶段启动时按照本计划格式细化；细化依据是 P0/P1 的实测结果（fastboot 启动路径、DTS 地址、内存预算）。本文件先给出验收标准与任务清单，避免过早锁定未知寄存器细节。

---

## P0：构建基线 + 最小 DTS + uImage + earlycon（详细任务）

### Task 0.1: 最小 arm64 DTS（earlycon 验证版）

**Files:**
- Create: `/home/jason/bringup-7.3/src/linux-7.3/arch/arm64/boot/dts/hisilicon/hi3798mv300-poc.dts`
- Create（回写）: `docs/porting/artifacts/dts/hi3798mv300-poc.dts`
- Verify: `docs/porting/scripts/check_dts.sh`

**Interfaces:**
- Consumes: 无（阶段起点）
- Produces: DTS 节点 `memory@0`（1GB）、`cpu@0`（cortex-a53）、GIC-400（0xf1001000/0xf1002000/0xf1004000/0xf1006000）、`timer`（armv8-timer）、`serial@f8b00000`（arm,pl011，SPI 49）、`chosen/bootargs`。

- [ ] **Step 1: 写验证脚本（先失败）**
  `docs/porting/scripts/check_dts.sh`：用内核 `scripts/dtc/dtc -I dts -O dtb` 编译指定 DTS，失败则退出码非 0；对不存在的 DTS 运行，应失败。
- [ ] **Step 2: 运行验证脚本确认失败**
  Run: `bash docs/porting/scripts/check_dts.sh /home/jason/bringup-7.3/src/linux-7.3/arch/arm64/boot/dts/hisilicon/hi3798mv300-poc.dts`
  Expected: FAIL（文件不存在 / dtc 报错）
- [ ] **Step 3: 编写 DTS**
  节点按 Interfaces 定义；数值采用 mainline `hi3798cv200.dtsi` 的地址（GIC、timer、PL011），`/chosen/bootargs` 按 Global Constraints；单 CPU（PSCI 未就绪前不启用 SMP）。
- [ ] **Step 4: 运行验证脚本确认通过**
  Run: 同 Step 2
  Expected: PASS，输出 dtb 路径与大小（>0）
- [ ] **Step 5: 回写产物**
  复制到 `docs/porting/artifacts/dts/`；记录 DTS 中各地址来源（vendor dts/代码文件:行号）到任务 0.1 的 ledger 行。

### Task 0.2: 最小内核构建（earlycon 可用）

**Files:**
- Modify: `/home/jason/bringup-7.3/src/linux-7.3/.config`（已配置：PRINTK/TTY/OF/SERIAL_AMBA_PL011(+CONSOLE)/SERIAL_EARLYCON/ARM_ARCH_TIMER/ARM_GIC）
- Create: `docs/porting/scripts/build_kernel.sh`
- Output: `/home/jason/bringup-7.3/out/Image`

- [ ] **Step 1: 写构建脚本（先失败）**
  脚本导出 PATH/LD_LIBRARY_PATH，执行 `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image`，并把产物复制到 out/；对不存在的 kernel 目录运行应失败。
- [ ] **Step 2: 运行确认失败**
  Run: `bash docs/porting/scripts/build_kernel.sh /nonexistent/linux`
  Expected: FAIL（目录不存在）
- [ ] **Step 3: 用真实内核目录运行构建**
  Run: `bash docs/porting/scripts/build_kernel.sh /home/jason/bringup-7.3/src/linux-7.3`
  Expected: PASS；`out/Image` 存在且 `file` 显示 ARM aarch64。
- [ ] **Step 4: 验证 Image 大小 ≤28MB 且包含 earlycon 符号**
  Run: `ls -lh /home/jason/bringup-7.3/out/Image; grep -c "earlycon" /home/jason/bringup-7.3/src/linux-7.3/.config`
  Expected: 文件存在、大小在限制内；配置中含 CONFIG_SERIAL_EARLYCON=y。

### Task 0.3: uImage 打包与校验工具

**Files:**
- Create: `docs/porting/scripts/mkuimage.py`
- Test: `docs/porting/scripts/test_mkuimage.py`
- Output: `/home/jason/bringup-7.3/out/uImage`

- [ ] **Step 1: 写失败测试（RED）**
  `test_mkuimage.py`：构造 64 字节头 + payload + dtb 输入，调用 `mkuimage.py --verify` 前先断言“未生成 uImage 时 verify 失败”；随后打包并断言 magic=0x27051956、size=len(payload)、arch=22(ARM64)、crc 正确、DTB 位于 payload 之后。
- [ ] **Step 2: 运行测试确认失败**
  Run: `python3 docs/porting/scripts/test_mkuimage.py`
  Expected: FAIL（mkuimage.py 不存在）
- [ ] **Step 3: 实现 `mkuimage.py`（--pack/--verify）**
  遵循 U-Boot legacy uImage 64 字节大端头；arch=22；comp=0；load=0x2000000；ep=0x2000000；payload 为 Image；DTB 追加在 payload 之后（不计入 header size）。
- [ ] **Step 4: 运行测试确认通过**
  Run: 同 Step 2
  Expected: PASS（含 crc 校验）。
- [ ] **Step 5: 生成真实 uImage 并校验**
  Run: `python3 docs/porting/scripts/mkuimage.py --pack --image out/Image --dtb out/hi3798mv300-poc.dtb --out out/uImage && python3 docs/porting/scripts/mkuimage.py --verify out/uImage`
  Expected: PASS；`out/uImage` ≤32MB。

### Task 0.4: 板卡启动验证（用户执行，agent 出说明）

**Files:**
- Create: `docs/porting/runbook-build-and-boot.md`（启动/烧录/排障）
- Create: `docs/porting/artifacts/README.md`（产物清单与校验和）

- [ ] **Step 1: 编写板卡启动说明**（HiTool/分区、fastboot bootargs、串口 115200、预期日志行）
- [ ] **Step 2: 生成产物清单（sha256）** 并写入 artifacts/README.md
- [ ] **Step 3: 用户实测**：烧录 `uImage` 到 kernel 分区，串口观察；若 fastboot 不走 arm64 路径，记录现象并触发 D3 预案评估（ATF 移植 vs fastboot 补丁）。

---

## P1：Ubuntu rootfs（详细任务）

### Task 1.1: Ubuntu base 镜像生成脚本
- [ ] 写 `docs/porting/scripts/build_rootfs.sh`：解包 `third_party/open_source/ubuntu-base-26.04.1-base-arm64.tar.gz` → chroot（proot/qemu 可选）安装 systemd/openssh/NetworkManager/GStreamer/mpv/mesa/weston/xdg-desktop-portal-wlr/pipewire/bluez/wpa_supplicant → 生成 ext4（4–7G）→ 产物 `out/ubuntu-rootfs_7168M.ext4`。
- [ ] 验证：`e2fsck -fn` 通过；镜像内 `/etc/os-release` 为 Ubuntu 26.04。

### Task 1.2: 内核模块与固件打包
- [ ] 安装 `modules_install` 到 rootfs 的 `/lib/modules/7.3.0`；拷贝 rtw88/rtl_bt 固件到 `/lib/firmware`；校验 `modinfo rtw88_8822bs`。

### Task 1.3: 分区表与启动参数更新
- [ ] 更新 `configs/hi3798mv300/prebuilts/emmc_partitions.xml`：ubuntu 分区 Sel=1、Length≈7G、文件 `ubuntu-rootfs_7168M.ext4`；bootargs 指向 `/dev/mmcblk0p8` 并按 Global Constraints 修改；产物回写 docs/porting/artifacts/。

### Task 1.4: 启动验证
- [ ] 烧录 rootfs 与 uImage；串口登录；`ip a` 获取地址；`ssh` 连通；`uname -a` 为 7.3 arm64。

---

## P2–P6：阶段任务与验收（启动时细化）

| 阶段 | 任务 | 验收 |
|---|---|---|
| P2 显示 | DRM/KMS 驱动：VO+HDMI，EDID/模式/4K60；HDMI audio ASoC 骨架；CMA/DT reserved-memory | `modetest` 4K60 模式，电视出画面；HDMI PCM 出声 |
| P3 GPU/桌面 | lima DT 节点（GPU 寄存器/时钟/电源）；Mesa lima；Weston/labwc 会话；直接 scanout | `glxinfo`/`es2_info` 显示 lima；4K 视频全屏直出无 GPU 合成瓶颈 |
| P4 解码 | VDEC V4L2 M2M + VFMw v5.0 固件加载；VPSS 缩放/去隔行；DMA-BUF 到 KMS | mpv/GStreamer 4K60 H.265 硬解，CPU<30%，掉帧<1% |
| P5 编码 | VENC V4L2 M2M；PipeWire 录屏管线 | 1080p60 录屏 10 分钟，文件正常、CPU 可接受 |
| P6 无线/外设 | rtw88 8822cs SDIO + 固件 + 使能 GPIO/32k；btrtl hci_uart；BT/bluez；SATA/USB/RTC/WDT/thermal | WiFi iperf、BT 配对、外设全通过；72h 稳定 |

---

## 执行方式与 gate

- 执行方式：inline（superpower-executing-plans），用户已明确“开始执行”，不再逐任务请求确认。
- 每任务执行前创建 ledger（`.superpowers/sdd/<plan-slug>/progress.md`），记录 BASE、RED/GREEN 输出、Ruling。
- 板卡相关验证（Task 0.4/1.4）由用户在本机执行，agent 提供产物与操作说明；用户反馈后继续。
- 不自动 commit/push（未授权）；ledger 为唯一执行记录。

---

## 执行状态（2026-10-30）

| 任务 | 状态 | 证据 |
|---|---|---|
| Task 0.1 最小 DTS | ✅ 完成 | `check_dts.sh` RED(缺文件) → GREEN(dtb 1445B)；`docs/porting/artifacts/dts/hi3798mv300-poc.dts` |
| Task 0.2 内核构建 | ✅ 完成 | `out/Image` 4,970,504B，ARM64；`build_kernel.sh` PASS |
| Task 0.3 uImage 打包 | ✅ 完成 | `test_mkuimage.py` ALL TESTS PASSED；真包 4,972,013B，verify PASS |
| Task 0.4 板卡启动验证 | ⏳ 等硬件 | `docs/porting/artifacts/README.md` 已给烧录/串口判据 |
| P1 Ubuntu rootfs | ⏳ 未开始 | 依赖 P0 gate |

Rulings：见 `.superpowers/sdd/2026-10-30-hi3798mv300-linux7x-ubuntu-implementation-plan/progress.md`（cpp 预处理、uImage 头格式、file 检查字符串）。

### P0 阻塞与决策（2026-10-30 更新）

- 板载 **Fastboot 3.3.0 为 32 位构建**：`help go64` 不存在；源码确认 `CONFIG_ARM64_SUPPORT` 仅在 `CFG_HI_CPU_ARCH=arm64` 时定义；`CONFIG_TEE_SUPPORT` 关闭；`bootm` 无 arm64 启动路径。
- 结论：**现有 bootloader 无法启动 arm64 mainline 内核**。D3 预案触发，需在以下路线中选择：
  - **A（64 位）**：重建 fastboot（CFG_HI_CPU_ARCH=arm64 + TEE/ATF）+ 移植 ATF `plat/hisilicon/hi3798mv200` → mv300 + 刷写 bootloader；保留 arm64 内核产物；风险：刷机失败/砖，需 HiTool 恢复。
  - **B（32 位，推荐先做）**：mainline 7.3 arm32（A53 以 AArch32 运行，主 line 有 bcm2837 等先例）+ 新增 `arch/arm/mach-hi3798` 与 DTS + 现有 fastboot 启动 zImage/uImage；Ubuntu armhf 26.04（tarball 已有）。不刷 bootloader，P0 预计 1–2 周。
  - **C**：向海思索取 64 位 bootloader/ATF 交付物后走 A 捷径。
- 等待用户选择；arm64 产物（Image/uImage/dtb）仍保留可用。

---

## P1：Ubuntu rootfs（eMMC 启动到 shell/SSH）— 详细任务

> P1 在 P0 实测基础上细化（见 ledger 与 docs/porting/logs/p0-*.log）。每个任务以真实板卡输出为验证证据。

### Task P1.1: 内核基线升级（arm64 defconfig + Ubuntu/存储/CMA 必需项）

**Files:**
- Create: `docs/porting/scripts/kernel_config_p1.sh`
- Create（产物）: `/home/jason/bringup-7.3/out/config-p1`、`/home/jason/bringup-7.3/out/Image-p1`

**Interfaces:**
- Consumes: P0 的构建环境与 `build_kernel.sh`；内核源码 `/home/jason/bringup-7.3/src/linux-7.3`
- Produces: 可启动的 P1 `Image`（含 EXT4/MMC/CMA/PSCI 所需驱动）；uImage 总大小（Image+补零+DTB）≤32MB

- [x] **Step 1: 写配置脚本（先失败）**：`kernel_config_p1.sh` 从 `make ARCH=arm64 defconfig` 出发，打开 `MMC_DW_HI3798MV200/COMMON_CLK_HI3798CV200/CMA/DMA_CMA/EXT4_FS/DEVTMPFS(_MOUNT)/VA_BITS_48/PA_BITS_48/ARM_PSCI_FW`。
- [x] **Step 2: 运行脚本验证配置**：`bash docs/porting/scripts/kernel_config_p1.sh`，Expected: 退出码 0，`grep` 上述符号全部为 y、VA/PA=48。
- [x] **Step 3: 构建 Image**：`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image -j16`，Expected: rc=0，`arch/arm64/boot/Image` 存在。
- [x] **Step 4: 大小校验**：Image 大小 ≤28MB（给 BSS 补零+DTB 留余量），否则在脚本中裁剪不必要驱动；记录最终大小。
- [x] **Step 5: 回写产物**：拷贝 Image 与配置到 `/home/jason/bringup-7.3/out/`，ledger 记录大小/sha256。

### Task P1.2: DTS 启用 PSCI + 4 核

**Files:**
- Modify: `/home/jason/bringup-7.3/src/linux-7.3/arch/arm64/boot/dts/hisilicon/hi3798mv300-poc.dts`
- Create（回写）: `docs/porting/artifacts/dts/hi3798mv300-poc.dts`

**Interfaces:**
- Consumes: P0 DTS；ATF 已提供 PSCI 0.2（SMC。）
- Produces: `psci` 节点（`arm,psci-0.2`，`method = "smc"`）与 4 个 `cpu@N`（`enable-method = "psci"`）

- [x] **Step 1: 写验证脚本（先失败）**：`docs/porting/scripts/check_dts_p1.sh` 检查编译后的 DTB 含 `psci` 节点与 4 个 cpu 节点、`enable-method="psci"`。
- [x] **Step 2: 运行脚本确认失败**：Expected: FAIL（当前 DTS 只有一个 cpu 且无 psci）。
- [x] **Step 3: 修改 DTS**：添加 psci 与 cpu@0..3（cortex-a53，reg 0..3）。
- [x] **Step 4: 运行脚本确认通过**：Expected: PASS（dtb 编译成功且节点/属性齐全）。
- [ ] **Step 5: 板卡验证（需复位）**（未通过：板卡卡在 `smp: Bringing up secondary CPUs`，ATF PSCI CPU_ON 待修；单核 DTB 已可正常启动）：用 P1.1 Image 打包 FIP 启动，串口 Expected: `smp: Brought up 4 CPUs`（或 `CPU1..3`）。
- [x] **Step 6: 回写 DTS 产物与 ledger。

### Task P1.3: DTS 增加 eMMC（dw-mshc + CRG）

**Files:**
- Modify: 同上 DTS
- Create（回写）: `docs/porting/artifacts/dts/hi3798mv300-poc.dts`

**Interfaces:**
- Consumes: Task P1.2 的 DTS；mainline `hisilicon,hi3798mv200-dw-mshc` 驱动（CONFIG_MMC_DW_HI3798MV200）
- Produces: `crg@f8a22000`（`hisilicon,hi3798cv200-crg`）与 `mmc@f9830000`（eMMC，GIC SPI 35，8-bit，non-removable）

- [x] **Step 1: 写验证脚本（先失败）**：检查 DTB 含 `mmc@f9830000` 且 compatible 为 `hisilicon,hi3798mv200-dw-mshc`、`crg` 节点存在、`clocks/resets` 属性齐全。
- [x] **Step 2: 运行脚本确认失败**：Expected: FAIL。
- [x] **Step 3: 修改 DTS**：按 mainline `hi3798cv200.dtsi` 的 crg 与 MMC 节点移植（时钟 ID 用 `histb-clock.h`），eMMC 属性按 poplar dts 设置。
- [x] **Step 4: 运行脚本确认通过**：Expected: PASS。
- [x] **Step 5: 板卡验证（需复位）**：实际用 generic `snps,dw-mshc` + 25MHz（`LOW_MMC`）成功探测 `mmcblk0: DG4008 7.28GiB`；因海思私有分区表，未出现 `mmcblk0p8`，改用 `blkdevparts` 生成 `mmcblk0p1` 挂载 rootfs。
- [x] **Step 6: 回写产物与 ledger。

### Task P1.4: Ubuntu base arm64 rootfs 镜像

**Files:**
- Create: `docs/porting/scripts/build_ubuntu_rootfs.sh`
- Create（产物）: `/home/jason/bringup-7.3/out/ubuntu-base-arm64.ext4`（或 `.tar.gz` + 写入流程）

**Interfaces:**
- Consumes: 网络（TUNA 镜像）；主机工具 `mke2fs`/`debugfs` 或 `e2fsprogs`；必要时 `qemu-aarch64-static`
- Produces: 可挂载的 ext4 rootfs 镜像，含 `/etc/fstab`（root=/dev/mmcblk0p8）、`/etc/inittab`/systemd 串口 getty、root 密码/空密码策略、`/etc/resolv.conf`

- [x] **Step 1: 写脚本（先失败）**：下载 `ubuntu-base-*-arm64.tar.gz`（26.04 优先，回退 24.04 LTS），校验并解包到 rootfs 目录；非空检查。
- [x] **Step 2: 运行脚本确认下载/解包成功**：Expected: rc=0，`rootfs/usr/bin/bash` 存在。
- [x] **Step 3: 生成 ext4 镜像**：`mke2fs -d` 或 loop 挂载写入；Expected: `e2fsck -fn` 通过、镜像可 `debugfs ls`。
- [x] **Step 4: 配置系统**：fstab、串口 getty（`ttyAMA0` 115200）、root 登录、ssh 可选；Expected: 配置文件存在且内容匹配。
- [x] **Step 5: 回写产物与 ledger（记录大小/sha256）。

### Task P1.5: 写入 eMMC p8 并启动 Ubuntu

**Files:**
- Modify: `docs/porting/scripts/flash_fip_p6.sh`（复用为 `flash_to_p8.sh`，分块 TFTP→eMMC）
- Create（回写）: `docs/porting/runbook-build-and-boot.md` 增加 P1 章节

**Interfaces:**
- Consumes: P1.3 eMMC 可用、P1.4 rootfs 镜像、bootcmd 机制
- Produces: eMMC p8 上可启动 Ubuntu；bootargs 含 `root=/dev/mmcblk0p8 rootfstype=ext4 rootwait rw`

- [x] **Step 1: 写脚本（先失败）**：把 rootfs 镜像按块写入 p8（block 0x57000），支持分块 TFTP + `mmc write` + 回读 CRC 校验。
- [x] **Step 2: 运行脚本确认当前失败**：Expected: FAIL（rootfs 镜像不存在或大小超 p8）。
- [x] **Step 3: 写入并校验**：Expected: 回读 CRC 与主机一致。
- [x] **Step 4: 修改 bootargs（DTS）加 `root=/dev/mmcblk0p8 rootfstype=ext4 rootwait rw`，重打包 FIP 并写入 p6。
- [x] **Step 5: 板卡验证（需复位）**：Expected: Ubuntu 启动到 login（`Ubuntu 26.04 ... ttyAMA0`），可 root 登录执行 `uname -a`。
- [x] **Step 6: 回写 runbook/ledger。

---

## P2：显示（DRM/KMS + HDMI）— 细化任务（2026-10-31）

> 侦察与寄存器/驱动参考见 `docs/porting/display/p2-display-recon.md`。每步以板卡实测输出为证据。

- [x] **P2.0 侦察**：VDP `0xf8cc0000`、HDMI TX `0xf8ce0000`、Mali `0xf9200000`；厂商 MSP vo/dbe/hdmi_2_0 源码定位；mainline 无现成驱动，需自研 DRM/KMS。
- [x] **P2.1 探测骨架**：DT `display@f8cc0000` + `drivers/gpu/drm/hisi/hi3798_drm.c`；板卡实测 `VDP ... mapped, ID=8380000b 03000177`；Ubuntu 仍可启动。
- [x] **P2.2 KMS 最小可显示**：DRM crtc/plane/connector + dumb buffer；VDP 固定 1080p60 模式扫描输出；`modetest -s` 出图案。
- [ ] **P2.3 HDMI 模式/EDID/HPD**（阻塞：HDMI TX 寄存器 CPU 不可读，见 docs/porting/feasibility-remaining-features-2026-11-01.md）：DDC/EDID、4K60 模式集、HPD；HDMI infoframe/audio 基础配置。
- [ ] **P2.4 HDMI 音频 ASoC**（阻塞：需 vendor HDMI 驱动 ~100k 行 + AIAO 子集；AIAO 已上电）：HDMI PCM 声卡，`aplay` 出声。
- [ ] **P2.5 验证收尾**（部分：1080p/桌面/GPU 已验证；4K/HDMI 音频阻塞）：modetest 4K60 出图、HDMI 出声、CMA/reserved-memory 核算、更新 runbook。


## P3 GPU/桌面 — 细化任务（2026-10-31 更新）

- [x] **P3.0 显示前提**：bootloader framebuffer + simpledrm 已在板卡点亮 1280x720 控制台（/dev/fb0、card1），电视显示 Ubuntu 登录界面。
- [x] **P3.1 lima 驱动接入**（完成，见 P3.2）：DT Mali-450 节点 + CRG GPU 时钟 + early_initcall 配 CRG73；lima probe 能读写 GPU 寄存器。
- [x] **P3.2 GPU 电源域/lima 驱动**（2026-11-01 完成：DT reg 0x40000 + xlsm 电源序列 + CRG 0xd4，renderD128 出现）：lima 报 `gpmmu dte write test fail`/`pmu timeout wait pmu cmd`。需移植 vendor `clk-higpu.c` 的 `hisi_gpu_pmc_init`（C51 PMC 协议、pmu_domain_config、freq 请求），或让 bootloader 预先上电 GPU 域。当前 GPU 节点 disabled。
- [x] **P3.3 Mesa/lima 用户态**：rootfs 安装 Mesa（lima）、验证 es2_info/glmark2。
- [x] **P3.4 桌面**（已完成：Weston pixman + Xwayland + RDP；GL 渲染器在 lima 上验证可用（GL renderer: Mali450），但重负载 VBO 会触发 pp 超时，故默认 pixman）：Weston/labwc 跑在 simpledrm（1280x720）或后续自研 KMS 上，验证窗口/终端/浏览器。
- [ ] **P3.5 4K60/HDMI 音频**（阻塞，同 P2.3/P2.4）：需要自研 VDP/HDMI DRM 驱动（P2.3/P2.4 遗留），或扩展 bootloader 固定模式方案。


## P6 外设/网络 — 状态（2026-11-01）

- [x] **P6.0 显示控制台日志**：bootargs 增加 console=tty0，电视可显示内核启动日志（用户确认）。
- [x] **P6.1 网络完成（内部 FEPHY）**：hisi_femac + mdio-hisi-femac，PHY addr=2，sysctrl eth_phy_cfg + FEPHY 上电 early init；静态 IP 192.168.2.10 持久化，ping PC 0% loss，SSH 可登录。
- [x] **P6.1a MDIO/PHY 初始化**：已完成（mainline hisi-femac-mdio + 内部 FEPHY early init + sysctrl 0xA8 配置）。
- [x] **P6.2 USB2 Host**（已完成：USB2 PHY 调优修正 + U盘枚举/存储/自动挂载）：EHCI/OHCI 控制器可注册，但端口扫描挂死；需厂商 USB2 PHY 上电时序。硬件仅 2× USB2.0（无 USB3）。
- [x] **P6.3 无线 RTL8822BS**（已完成：SDIO2+rtw88 固件+扫描；连接待用户提供 SSID/密码）：SDIO/PCIe 接口、供电、rtw88 驱动与固件。
- [x] **P6.4 远程访问**：SSH 免密登录已可用（WSL ↔ 192.168.2.10）。


## 参考：hi3798mv2dma xlsm 寄存器表（2026-11-01）

已解析并保存到 `docs/porting/refs/xlsm-*.txt`（main/hardware_key_info/sysclk/sysctrl/crg_ctrl/peri_cfg/eth_phy_cfg/pin_mux_drv/readme）。

关键可复用配置：
- GPU 上电：`PMC_CTRL 0xf8a220c8=1`、EPLL `0x12ED9169/0x0800207c`(749.568M)、`Vgpu PWM 0xf8a23020=0x006900DD`(0.99V)、`PWM_EN 0xf8a23024=0x915`、GPU CRG `0xd4` bit0/8/9 clk + bit4 reset、`0x124[2:0]` 频率选择。
- FEPHY（已用于网络）：CRG `0x388=0x10` 复位值、`0xd0` SF clk、`0xf8a20118` PHY addr、LDO `0xf8a20844`。
- HDMI：HPLL 594M（`0x28=0x12000000`/`0x2c=0x0A102063/0x0A002063`）、HDMITX CTRL/PHY CRG `0x10c/0x110`、VDP1/VDP2 CRG `0xd8/0x34c`。
- 其它 IP 的默认 clock-off/reset 值可用于后续 VDEC/VPSS/VENC/TDE 驱动初始化。

## 2026-11-01 进展汇总（Round 41–53，与上文任务对应）

已完成并验证：
- **P2.2 KMS 最小显示**：自研 `hi3798-drm`（VDP G0 扫描输出），Weston 在 1080p60 桌面运行；`/dev/dri/card0` 为 hi3798-drm。
- **P3.3/P3.4 Mesa/lima + 桌面**：Mesa 26 + lima（Mali450）可用，GL 轻负载 980 FPS 零 fault；Weston(pixman)+Xwayland+RDP 远程桌面+PCManFM/mpv/终端。
- **P6.2 USB2 Host**：修正 vendor USB2 PHY 调优寄存器（2p/1p PHY 基址与 OTP trim）；Kingston U盘 62GB exfat 正常枚举、读写（读 36MB/s）、自动挂载、Samba 共享。另实现 USB3 xHCI(5Gbps) 控制器驱动（板上无物理 USB3 口）。
- **P6.3 WiFi RTL8822BS**：SDIO2(dw-mshc@f9c40000, CRG0x28c) + rtw88 模块（cfg80211/mac80211/8822bs）+ rtw8822b_fw.bin；开机自动加载，`wlan0` 扫描到 10+ AP。连接配置待 SSID/密码。
- **新增能力**：RDP 远程桌面（3389）、Xwayland、Samba（\\192.168.2.10\usb）、静态网络、SSH key、根文件系统恢复/刷机流程文档化。
- **未完成/受限**：HDMI 音频（AIAO 已上电，但 HDMI TX 由 bootloader vendor 固件管理，CPU 侧窗口读不到，需移植 vendor HDMI 驱动，体量过大）；VDEC 4K/VENC（需移植 vendor 视频驱动）；4K 输出与 EDID；GPU VBO 重负载 INVALID_PLIST；BT。

关键工程结论（详见 .superpowers/sdd/.../progress.md）：
- FIP `--pad-to` 必须使用 Image header 的 image_size（含 BSS），否则内核静默失败；`fip_create` 不截断已有输出文件。
- ATF 对 FIP/BL33 大小敏感（>~11.5MB 静默失败），可通过模块化驱动 + 正确 pad 控制。
- USB2 PHY 调优寄存器必须按 vendor 精确基址/偏移写入。

## P6.5 外设补充（2026-11-01 完成，mainline 驱动）

- [x] **I2C**：DTS i2c0/1/2（0xf8b10000/11000/12000）+ `i2c-hix5hd2` → /dev/i2c-0..2。
- [x] **GPIO**：10× ARM PL061（0xf8b20000+0x1000*n）+ `gpio-pl061` → /dev/gpiochip0..9。
- [x] **WDT**：ARM SP805（0xf8a2c000）+ `sp805_wdt`；systemd `RuntimeWatchdogSec=30s` 喂狗（否则 bootloader 已启用的 WDT 会 ~3min 复位）。
- [x] **SPI**：ARM PL022（0xf8b1a000）+ `spi-pl022` → spi0 master。
- [x] **SATA 评估**：COMBPHY1 mux 实测 = 3（非 SATA），本板未路由 SATA → 不做。
- [ ] PWM / RTC / thermal：vendor 私有 IP，无 mainline 等价驱动，未做。
## P7.5 桌面应用与体验（联网后补充，2026-11-01）

- [x] 在线安装 WebKitGTK（gir1.2-webkit2-4.1 + libwebkit2gtk-4.1-0 + python3-cairo + python3-gi-cairo）。
- [x] 自研 GUI 浏览器 `hi-browser.sh` / `webkit-browser.py`：地址栏/前进后退/刷新/主页、F11 全屏、Ctrl+/- 缩放、下载到 /root/Downloads、`--snapshot` 页面快照；实测百度/必应正确渲染，WebM(VP8/VP9) 视频可播。
- [x] 自研 PDF 阅读器 `hi-pdf.py`（poppler 渲染 + GTK3 翻页），已关联 application/pdf。
- [x] 自研图片查看器 `hi-image.py`（缩放/全屏），已关联常见图片格式。
- [x] 文件关联全套：pdf→hi-pdf、图片→hi-image、文本→mousepad、视频→mpv、目录→pcmanfm。
- [x] 桌面壁纸（/usr/share/backgrounds/hi3798-wallpaper.png）+ 禁止空闲黑屏（weston idle-time=0）。
- [x] 在线安装 poppler-utils；验证 mousepad、pcmanfm 正常。
- [x] LibreOffice 26.2.6.3（writer + calc + gtk3）已安装：headless 转换 t.txt→t.pdf 验证通过；GUI 约 5s 出窗口；磁盘占用增至 4.0G/6.9G。

---

## As-Built 执行状态对照（2026-11-01 最终）

| 计划阶段 | 状态 | 说明/证据 |
|---|---|---|
| P0 启动链（ATF+FIP+mainline arm64） | ✅ 完成 | ATF BL31 + fastboot，bootm 启动 Linux 7.3；`docs/porting/logs/p0-*.log` |
| P1 内核/DTS/串口/网络/存储 | ✅ 完成 | eMMC、以太网、USB2；`p1-*.log` |
| P2 显示（VDP/DRM/HDMI） | ✅ 1080p 完成；4K/音频阻塞 | `p2-*.log`；HDMI TX 不可 CPU 访问（feasibility §1.1） |
| P3 桌面（Weston/GL/RDP） | ✅ 完成 | pixman 桌面 + RDP；GL 可选；`p3-*.log` |
| P4 媒体（软解/录屏） | ✅ 软解完成；VENC 阻塞 | H.264 1080p ≈25fps；`p4-*.log` |
| P5 应用/网络/共享 | ✅ 完成 | 浏览器/LibreOffice/PDF/Samba/RDP；`p5-*.log` |
| P6 无线/外设 | ✅ WiFi 完成；I2C/GPIO/SPI/WDT 完成 | `p6-*.log` |
| P7 交付/优化/稳定性 | ✅ 完成 | zram/自愈/自检/备份/文档；`p7-*.log` |
| USB 全速设备（鼠标/键盘） | ✅ 完成 | OHCI 内核级根治（CLK_IGNORE_UNUSED）；runbook §O；`p4-usb-ohci-*.log` |
| 蓝牙（内部模组） | ❌ 硬件未启用（已知问题） | 原厂固件无 UART BT 初始化/hci0；本板 UART2 全链路正常但模组无响应；BlueZ 栈就绪，可用 USB dongle；`p6-bt-*.log` |
| SATA | ➖ 硬件无接口（已剔除） | 用户确认 |
| 验收 | ✅ 28/28 PASS | `/usr/local/bin/acceptance_check.sh` |
