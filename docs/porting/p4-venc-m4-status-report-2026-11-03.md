# P4 / M4（VENC 硬件编码）移植状态报告

- 日期：2026-11-03
- 目标板：Hi3798MV300（4×A53 / 1GB DDR3 / eMMC）
- 内核：Linux 7.3.0 mainline（自建）
- 结论：**M4 未验收**。硬件链路（时钟/复位/SMMU/IRQ/MMIO）已全部打通并逐项验证；
  数据面（DDR 寄存器配置镜像 + DMA 地址域）仍有未解问题，会导致系统内存被 VEDU DMA 破坏。

---

## 1. 已达成的验证项（有实机证据）

| 项 | 结果 | 证据 |
|---|---|---|
| 内核模块编译 | ✅ | `port/venc/hi_venc.ko`（约 183 KB），13 个 C/S 源 + omxvenc |
| 模块加载 | ✅ | `insmod rc=0`，`lsmod` 可见 |
| 字符设备 | ✅ | `/dev/hi_venc`（major 246/247，class `himedia_venc`） |
| `HI_UNF_VENC_Init` | ✅ | `Init rc=0x0`（open + EflOpenVedu 成功） |
| `HI_UNF_VENC_Create` | ✅ | `Create rc=0x0`（CheckConfig / EflCreateVenc / RcAttrInit / ProcAdd 均 ret=0） |
| `HI_UNF_VENC_Start` | ✅ | `Start rc=0x0` |
| VEDU 时钟 | ✅ | `CRG35 write=0x3 read=0x3`（venc_core_cken/axi_cken/clk_sel=250MHz） |
| VEDU SMMU 时钟/复位 | ✅ | `CRG203(0x32C)=0x1`，复位位 bit4 已释放 |
| VEDU SMMU 旁路 | ✅ | `SCR(0x00)=0x1`，SMMU 寄存器页可读（0xF8C8F000） |
| 中断注册 | ✅ | `request irq 133 -> virq 38`，`/proc/interrupts`: `GIC-0 133 Level venc` |
| 中断真实触发 | ✅ | 曾观测 `ISR readback: timeout=0 bufffull=0 slice0=45080` |
| 硬件生成码流 | ⚠️ 曾达成一次 | 上述 `slice0=45080`（约 45 KB slice）证明 VEDU 确实完成了一次编码 |
| 用户态 API | ✅ | `port/vencuser/venc_test`（mpi_venc.c + unf_venc.c + MMZ shim）静态链接通过 |

---

## 2. 已定位并修复的根因（累计）

1. **SMMU 长期处于复位**
   `PERI_CRG203` 实际偏移 **0x32C**（不是 0x334，后者是 CRG205），bit4 = `venc_smmu_srst_req`。
   修复前 SMMU 寄存器读回恒为 0，VEDU 访问 SMMU 即总线 hang。

2. **HAL 全局未初始化（误判已纠正）**
   厂商 64 位 HAL `DRV_VENC_HAL_V500R001_Init` 的 `.L143` 分支是**自初始化路径**：
   - `ioremap(0xF8C80000, 0xF700)` → `g_pRegBase`（页对齐后覆盖 VEDU 寄存器 + SMMU 页）
   - `vmalloc(4480)` → `g_pHalRegInfo`（独立软件 scratch 缓冲）
   **不要再覆盖该函数**：曾把 `g_pHalRegInfo` 指向寄存器基址，
   导致 `CfgReg` 把 696 字节软件结构直接写进 VEDU 寄存器 → 寄存器乱码 → 总线 hang。

3. **HAL 汇编全局符号需导出**
   `g_pRegBase` / `g_pHalRegInfo` 在 `.S` 中未 `.global`，C 侧引用会 modpost 失败。

4. **中断上下文违规（vmalloc in hardirq）**
   `kernel BUG at mm/vmalloc.c:3228` = `BUG_ON(in_nmi() || in_hardirq())`。
   任何 `ioremap`（含日志里的懒加载）都必须在进程上下文完成；ISR 内只能访问已映射地址。

5. **ISR 内禁止 printk / 文件 IO**
   - ISR 内 `kernel_write` + `vfs_fsync` 会在块设备层触发 oops
   - ISR 内 `dump_stack()`/`printk` 可能死锁控制台
   正确做法：ISR 只写内存环形缓冲，由任务线程落盘。

6. **`die_notifier` 取参错误**
   arm64 的 die notifier `data` 是 `struct die_args`，不是 `struct pt_regs`；
   且 arm64 `pt_regs` 无 `esr_el1/far_el1` 字段。

7. **64 位内核虚拟地址被写进 VEDU 可见区（关键，未完全解决）**
   `VENC_HAL_EXT_S.DdrRegCfgVirAddr` 位于 `VENC_HAL_CFG_S` **offset 688**。
   - 厂商 32 位系统：该字段 4 字节，其低 32 位恰好 == 物理地址
   - mainline 64 位：字段 8 字节，值为 `0xffff8000_81281000` 类内核 VA
   - HAL 会把该结构写进 VEDU 可见的镜像 → VEDU 32 位地址总线截断成 `0x81281000`
     （超出 1GB RAM）→ 总线 hang
   - 对照：厂商 **32 位** HAL 该字段偏移 676、`memcpy` 长度 **680**（天然跳过该字段）

---

## 3. 当前未解问题

### 3.1 现象
`CfgReg` 返回后约 0.3–1 s，系统出现**与 VENC 无关的子系统**内存破坏 oops：
- `queued_spin_lock_slowpath` / slab 分配器内部
- `enqueue_timer` / `__mod_timer`
- MMC worker（`dw_mci_start_command`）

即：VEDU DMA 正在写**合法物理地址范围内的错误位置**，破坏内核内存。

### 3.2 已排除
| 假设 | 结论 |
|---|---|
| wait_queue 被 `wake_up` 破坏 | ❌ 禁用 `wake_up` 后依旧崩溃 |
| `VENC_HAL_READ_S` 结构溢出 | ❌ 结构 176 字节，HAL 最大写 offset 172+4=176，正好吻合 |
| RegCfg 中存在越界地址（>1GB） | 仅 offset 688 一处（已定位） |
| RegCfg 中地址未指向已分配缓冲 | RcnY/RcnC/Tmv/Pme/TunlCell 均落在 VENC_SteamBuf 内；SrcY/SrcC 落在用户 CMA 输入缓冲内 |

### 3.3 关键新增实验：跳过 CfgReg 硬件启动后仍然崩溃

为孤立 DMA 影响，在 `DRV_VENC_HAL_V500R001_CfgReg` 入口加入调试开关，
令其直接返回（完全不写寄存器、不启动 VEDU）。结果：

- VEDU 完全没有被启动（无寄存器写、无 DMA）
- 约 50 s 后系统仍出现同一签名的内存破坏 oops：
  `pc = queued_read_lock_slowpath+0x264`，`nmbd[419] exited with irqs disabled`，
  `Fixing recursive fault but reboot is needed!`

→ **结论修正：内核内存破坏与本次 VEDU DMA 无直接因果关系**（至少不是唯一原因）。
嫌疑范围应扩大到：

1. `hi_mmz_shim` 的"任意物理地址 4 MB 窗口 remap 回退"
   （`HI_MPI_MMZ_Map` 对未知 phys 用 4 MB 映射；如果该 phys 实际属于内核，
   用户态写入会直接破坏内核内存）
2. `hi_venc` 的 `dma_alloc_coherent` platform_device 生命周期（未注销）
3. VDEC/JPEG 模块在同一次启动中留下的 MMZ/CMA 状态

这一点必须先用"只加载模块、不跑任何测试"的长时间空跑验证（soak），
再决定是否继续怀疑 VENC 数据面。

### 3.4 两个方向的实验对比
| 缓冲来源 | 现象 |
|---|---|
| reserved-memory @0x34000000（线性 cacheable，未 flush） | `CFG done` 成功、系统稳定，但**无 IRQ、无码流**（VEDU 读到 cache 中未回写的旧配置） |
| `dma_alloc_coherent`（非缓存，物理地址有效） | `CfgReg` 后崩溃（VEDU 真的开始 DMA，但写到错误位置） |

→ 两者合起来说明：**地址字段正确性 + cache 一致性必须同时满足**。

---

### 3.5 分段隔离实验结果（本轮新增）

| 测试内容 | 系统稳定性 | 结果 |
|---|---|---|
| 只 insmod 两个模块，空跑 180 s+ | ✅ 无 oops | 模块加载本身无害 |
| `venc_test 0`（Init/Create/Start/Stop/Destroy，0 帧） | ✅ 无 oops，Create/Start 均 rc=0 | Create/Start/Destroy 路径正常 |
| `venc_test 1`（1 帧，触发 CfgReg + 硬件启动） | ✅ 无 oops | 但 AcquireStream=BUF_EMPTY，无码流 |
| rmmod 后再 insmod（重载） | ❌ 板子复位 | **模块退出路径不干净** |

结论：
1. 「内核内存破坏」此前多次观测到，但本轮在 0 帧/1 帧路径下**均未复现**；
   说明之前的破坏大概率与当时的多帧连续编码 + 缓存/地址组合有关，
   而非模块加载或单帧配置路径。
2. **新增明确缺陷**：模块 reload 会导致系统复位 —— 退出路径需补齐
   （平台设备注销、proc 删除、IRQ 释放、DMA 缓冲释放、class 生命周期）。

### 3.6 关键 A/B：shadow 地址字段补丁的效果

| 配置 | 结果 |
|---|---|
| 补丁启用（shadow[688] 覆盖为 32 位物理地址） | `CFG called` 后**无** `CFG done` → 板子复位（HAL CfgReg 内部挂死） |
| 补丁禁用（保留 64 位 VA 原样写入镜像） | 同样 `CFG called` 后无 `CFG done` → 复位 |

结论：**该字段不是当前挂死的唯一原因**；`CfgReg` 内部还有别的地址/值问题。
另外注意：C 侧 `RegCfg` 里该字段被扫描打印为 `0x8123b000 <<OUT_OF_RAM`
（64 位 VA 低 32 位），说明 HAL 是在 `CfgReg` 内部把配置展开成
"寄存器直接写 + DDR 镜像"两条路径，补丁只影响其中一条。

## 4. 复现方法

```bash
# 板上
insmod /root/hi_mmz_shim.ko
insmod /root/hi_venc.ko
dmesg -C
/root/venc_test 5          # 320x240 NV12，5 帧
cat /root/venc_trace.log   # 内核侧文件追踪（fsync 落盘）
grep -aE "CFGW|CFG |ISR" /root/venc_trace.log
ls -l /root/out_venc.h264  # 期望非零，当前为 0
```

构建：
```bash
cd /home/jason/bringup-7.3/src/linux-7.3
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=/home/jason/bringup-7.3/port/venc modules
```

---

## 5. 下一步建议（按优先级）

1. **让 VEDU 不启动，纯静态检查镜像**
   找到 `CfgReg` 末尾"启动硬件"的那一条寄存器写并跳过它，然后完整转储
   `g_pHalRegInfo`(4480 B) 与 `DdrRegCfgBuf`(4 KB) 两个镜像，与已知缓冲地址逐字段比对。
   —— 这是唯一能一次性看清"哪些字段被 VEDU 当地址用"的方法。

2. **确认 VEDU 实际使用的配置来源**
   `VENC_REG_CONFIG_MODE=1` 表示 DDR 模式：需确认 VEDU 是从 `DdrRegCfgPhyAddr`
   指向的 4 KB 缓冲读取全部配置，还是只读部分。若只读部分，则该缓冲内容必须由
   HAL 之外的代码填充完整。

3. **不要继续用"猜测 + 补丁"推进**
   本轮已证明多次基于推断的修补都会引入新症状（覆盖 HAL Init、拆指针、截断 memcpy 等）。
   应先完成第 1 步的静态镜像审查，再一次性修补。

4. VEDU 地址域假设需验证：
   VEDU 是否只接受 <1GB 物理地址、是否要求 4 KB/特定对齐、SMMU bypass 是否为唯一可行模式。

---

## 6. 文件清单

| 路径 | 说明 |
|---|---|
| `port/venc/Kbuild` | VENC 模块构建（-DCHIP_TYPE_hi3798mv200、HI_SMMU_SUPPORT、96MV200_CONFIG 等） |
| `port/venc/inc/venc_port_inc.h` | 预包含头（register/PQ 前向声明、printk 适配） |
| `port/venc/src/port_stubs.c` | 桩：SMMU bypass、UMAP 设备注册、UserCopy、MMZ 分配器、文件日志、die_notifier |
| `port/venc/src/drv_venc_osal.c` | OSAL 适配（`kernel_write` 替代 `set_fs`、`_printk` 包装、`DEFINE_SEMAPHORE(n,1)`、`timer_setup`） |
| `port/venc/src/drv_venc_hal.S` | 厂商 64 位 HAL（含 1 处 port patch：shadow[688] 改物理地址） |
| `port/vencuser/venc_test.c` | 最小编码测试（320×240 NV12，N 帧） |
| `port/vencuser/venc_stubs.c` | 用户态桩（HI_MMZ_Map / WIN / DISP attach） |
| DTS `hi3798mv300-poc.dts` | `venc@f8c80000`（IRQ GIC_SPI 101）+ `venc-mmz@34000000`(32MB) + `panic_on_oops=1` |

## 2026-11-04 最新进展（Round 231-233）

### 已修复的两个真实根因（有寄存器级证据）

1. **配置镜像中的 64 位内核 VA 被截断**
   - `RegCfg.ExtCfg.DdrRegCfgVirAddr`(offset 688) 在 64 位下是 `0xffff8000_81xxxxxx`
   - HAL 会 `memcpy(结构 → VEDU 寄存器空间)`（结构布局 == 寄存器布局）
   - VEDU 地址总线只有 32 位 → 截断成 `0x81xxxxxx`（超出 1GB RAM）→ DMA 越界 → 总线挂死
   - 该字段后续还被 HAL 当指针用，**不能**直接改成物理地址
   - **修复**：仅在 memcpy 期间临时换成 32 位物理地址，memcpy 后立即恢复内核 VA

2. **HAL 覆盖 SMMU bypass**
   - HAL `CfgReg` 内部按 `SmmuCfg` 重写 SMMU SCR 为 `0x00030000`（启用 SMMU）
   - 我们未为 VEDU 建立页表（TTBR=0）→ DMA 转换失败
   - **修复**：在 HAL 写完 SMMU 配置后强制 `SCR=1`（bypass / identity）

### 修复效果（实测）

| 指标 | 修复前 | 修复后 |
|---|---|---|
| `CfgReg` 返回 | ❌ 挂死/复位 | ✅ `cfg_done=1` |
| 内核 oops | ❌ 多次 | ✅ 0（连续多帧配置稳定） |
| SMMU SCR | `0x00030000`（启用+空页表） | ✅ `0x00000001`（bypass） |
| VEDU reg 0x2B0/0x1E4 | 截断 VA（越界） | ✅ 已是合法 32 位物理地址 |

### 仍未解决

- **硬件未被真正 kick**：手动使能中断（`REG[0x004]=0xFFFFFFFF`）后仍无 ISR
- **mode=1（DDR 配置模式）仍挂死**：即使修正镜像地址字段，DDR 握手仍不成立
- 结论：`mode=0`（直接寄存器模式）是当前唯一稳定路径，但缺少厂商在 DDR 模式下才有的启动握手

### 关键实验记录

| 配置 | 结果 |
|---|---|
| mode=0 + 全部补丁 | ✅ `cfg_done=1`、`oops=0`、SMMU bypass 生效、无 ISR |
| mode=1 + 全部补丁 | ❌ `CFG called` 后挂死 |
| mode=1 + 停用补丁（复现 45080B 形态） | ❌ 同样挂死（无法复现） |

> 注：早期那次 `slice0=45080` 的硬件输出是在 MMZ 使用 `__get_free_pages` 线性缓存页 + 自有 HAL Init 的组合下出现的，
> 之后为修正 cache 一致性改用 `dma_alloc_coherent` 和厂商 HAL 路径，该组合已不可复现。

### 硬件活动性判定（Round 234，决定性）

在 `CfgReg` 返回后立即调用 `VENC_HAL_ReadReg()` 读回硬件状态：

```
RB timeout=0 endpic=0 buffull=0 pbover=0 picbits=0 meanqp=0 slice0=0
```

→ **硬件完全没有开始编码**（EndOfPic=0、PicBits=0、SliceLength=0）。

同时 dump 疑似 kick 寄存器（HAL 末尾 `str w0,[x22,1220/1224/1228]` → 寄存器 0x4C4/0x4C8/0x4CC）：

```
KICK[0x4b0]=0x45  KICK[0x4b4]=0x56  KICK[0x4b8]=0x6d  KICK[0x4bc]=0x89
KICK[0x4c0]=0x20  KICK[0x4c4]=0xda  KICK[0x4c8]=0x07  KICK[0x4cc]=0x00
```

这些更像是状态/计数寄存器而非启动手环。

**最终判定**：
- `mode=0`（直接寄存器模式）下，HAL 只写配置、不执行厂商在 `mode=1` 下的启动握手，
  因此 VEDU 永远不会跑起来 → 无中断、无码流
- `mode=1`（DDR 配置模式）下，VEDU 会尝试启动，但我们的 DDR 配置镜像/握手仍不满足，
  立刻总线挂死（即使已修正镜像中的 VA 截断问题）
- 结论：**M4 需要按厂商 32 位 HAL 的 DDR 配置协议逐字段复刻镜像与启动序列**，
  这需要逆向 HAL 汇编（约 8000 行）或获取 VEDU 寄存器手册，超出本次预算

### Round 235 补充实验：修复两处地址字段后仍未启动

新增补丁：memcpy 之后把寄存器镜像里 **两处** DDR 配置地址字段
（结构 offset 484 ↔ VEDU 寄存器 0x1E4，offset 688 ↔ 0x2B0）都改写为 32 位物理地址。

| 配置 | 结果 |
|---|---|
| mode=0 + 两处地址字段修复 | `cfg_done=1`、`oops=0`，但 `RB: endpic=0 picbits=0` → **硬件仍未启动** |
| mode=1 + 两处地址字段修复 | 仍在 `CFG called` 后挂死（板子复位） |

结论不变：**mode=0 缺少启动握手；mode=1 的 DDR 配置协议仍未满足**。

## 2026-11-04 用原厂固件实测（决定性对照）

为确认"硬件本身是否可用"，把板卡刷回原厂固件做了实测（Ubuntu 已完整备份，可恢复）。

### 原厂固件恢复过程
- 备份：`F:\design\Hi3798\FW\restore-20261104\board-boot-32M.bin` + `ubuntu-p1.img.zst`
  （解压校验 7,503,413,248 字节 = p1 精确大小）
- 写入：厂商 fastboot/bootargs/kernel(Linux 3.18.24 32 位)/system(Android 700MB)，
  并用空 ext4 重建 cache(600MB)/userdata(5.49GB)，清 misc BCB
- 结果：**原厂 Android 在本板成功启动**（system/data/cache 全部挂载，zygote/system_server 运行）

### 厂商 VENC 实测结果（关键）
通过修改 `/system/etc/init.bigfish.sh` 在开机时自动执行厂商 `sample_venc`：

```
/system/bin/sample_venc /cache/venc_in.yuv 320 240 H264   # 输入 I420 320x240 x10 帧
```

实测输出：
- `/cache/venc_in_chn00.h264` = 946,176 字节（第一次）/ 706,859 字节（第二次）
- 码流头部（hexdump）：
  ```
  00 00 00 01 67 64 00 14 ...   # SPS（profile 0x64 High）
  00 00 00 01 68 ee 3c b0 ...   # PPS
  00 00 00 01 65 b8 40 bf ...   # IDR slice
  ```
  → **标准合法的 H.264 Annex-B 码流**
- md5：`4cd99f2b9fa97bb7ed30d7b79d5a7401`

结论：**Hi3798MV300 的 VENC 硬件在本板上完全可用**，厂商栈可正常编码输出。

### 尝试在厂商固件上抓寄存器（未成功）
- 用 busybox `devmem` 在编码过程中读取 VEDU/CRG 寄存器：
  - `0xf8c80000..0xf8c80010` 读到 **0**
  - `0xf8c801e4/0x2b0/0x4c4` 等 → `devmem: mmap: Invalid argument`
  - `0xf8a2208c`(CRG35) / `0xf8a2232c`(CRG203) 读到 **0**；`0xf8a22334`=0x10
- 说明厂商内核的 `/dev/mem` 不允许访问这些设备寄存器区（或返回伪零），
  **无法通过 /dev/mem 抽取厂商启动序列**
- 厂商驱动 dmesg 默认不含 VENC 寄存器日志（`dmesg` 仅 1471 字节通用信息）

### 对 mainline 移植的意义
1. 硬件没问题 → M4 的剩余问题确定在**驱动/启动序列**，不是硬件或供电
2. 我们此前的分析（缺"启动握手"）方向正确
3. 无法用原厂固件直接读出寄存器值，下一步只能：
   - 继续逆向厂商 32 位 HAL 汇编里的 CfgReg 尾部（无需硬件）
   - 或给厂商内核加打印（需重编厂商内核，工具链不匹配，成本高）

## 2026-11-04 深挖记录（厂商固件侧取证）

### 1. 已证实：厂商 VENC 可输出合法 H.264
- `/cache/venc_in_chn00.h264`：946,176 B / 706,859 B（两次）
- 头部 `00 00 00 01 67 64 00 14` (SPS High) / `...68` (PPS) / `...65` (IDR)
- md5 `4cd99f2b9fa97bb7ed30d7b79d5a7401`

### 2. 厂商驱动调试级别可打开（重要）
`/proc/msp/log` 支持按模块设置日志级别（示例 `echo hi_avplay=2 > /proc/msp/log`）：
- 模块表：`HI_VENC  0x00000028  1: ERROR`
- `echo hi_venc=7 > /proc/msp/log` 后，编码时输出完整调用链：
  ```
  H264e_MakeSPS[405]:VENC h264 profile_id:100,level_id:20,num_ref_frames: 1
  VENC_DRV_CreateChn[1408]:create OK, Chn:0/0xe2a5a000.
  VENC_DRV_StartReceivePic[2028]:start Chn 0/0xe2a5a000. OK
  GetStrmBufInfoForSlice[635]:TargetBits=187245, u32Size=202432, CurStrmBufSize=351104
  PutFrameWriteBuffer[2132]:Current Buffer Size=1920 Output PicSize=1865 ...
  ```
- 但**级别 7/9 均无寄存器/CRG/HAL 打印** → release 编译把 HI_DBG_HAL 关掉了

### 3. 寄存器读取通道全部受限
| 通道 | 结果 |
|---|---|
| `/dev/mem` (busybox devmem) | 设备区读 0；高偏移 `mmap: Invalid argument` |
| `/sys/kernel/debug` | 只有 hid/himci0，无 himedia 节点 |
| `/proc/hisi/msp/*` | 有大量模块 proc 接口，但**无 venc** 条目 |
| 厂商 dmesg | 无 VENC 寄存器日志 |

### 4. 已建立的取证工具链（下一步用）
- SDK 自带 32 位交叉工具链：`tools/linux/toolchains/arm-histbv320-linux`（可用）
- 已编译 `kread.c` → arm32 静态工具：解析 `/proc/kcore` ELF，按虚拟地址读取内核内存
- `/proc/kallsyms` 可用（89,817 条），`echo 0 > /proc/sys/kernel/kptr_restrict` 后可显示真实地址，
  能看到 `DRV_VENC_HAL_V500R001_CfgReg/Init/ReadReg` 与 `VENC_DRV_EflCfgRegVenc` 等符号

### 5. 下一步（可直接执行）
用 `kread` + kallsyms 在厂商内核上：
1. 读 `DRV_VENC_HAL_V500R001_CfgReg` 代码 → 反汇编（arm-histbv320-objdump）→
   找出 HAL 的 `g_pRegBase` / `g_pHalRegInfo` 的静态地址
2. 编码过程中按该地址读 4480 字节寄存器影子结构 → **得到厂商实际编程的寄存器值序列**
3. 与 mainline 移植代码逐字段对比 → 定位缺失的启动位/配置字段
（本轮 phase2 脚本因 Android 侧未执行成功而中断，需先确认 misc 引导标志与 hook 是否生效）

### 2026-11-04 phase2 取证结果（决定性）

#### 成功项：拿到厂商 HAL 函数真实地址
`echo 0 > /proc/sys/kernel/kptr_restrict` 后在厂商 Android 上读取 `/proc/kallsyms`：

```
c0a11230 t VENC_DRV_Open
c0a12ac0 T VENC_DRV_BoardInit
c0a17c88 t VENC_DRV_EflCfgRegVenc
c0a18a18 t VENC_DRV_EflStartOneFrameVenc
c0a1e36c T VENC_DRV_EflOpenVedu
c0a24ea8 T DRV_VENC_HAL_V500R001_ClrInt
c0a24f10 T DRV_VENC_HAL_V500R001_DisableInt
c0a24f78 T DRV_VENC_HAL_V500R001_ReadReg_Smmu
c0a25028 T DRV_VENC_HAL_V500R001_ReadReg
c0a2536c T DRV_VENC_HAL_V500R001_CfgReg
c0a272c4 T DRV_VENC_HAL_V500R001_Init
c0a27924 T DRV_VENC_HAL_V500R001_Deinit
```

#### 失败项 1：厂商内核没有 /proc/kcore
`kread` 报 `open /proc/kcore: No such file or directory` → **无法读取运行时内存**
（寄存器影子结构、DDR 配置镜像都读不到）

#### 失败项 2：内核 text 是压缩 zImage，离线反汇编不可行
启动日志：`.text : 0xc0008000 - 0xc11dd814 (18263 kB)`，而 bootimg 里 kernel 字段仅 9.09MB
（uImage 内含 zImage，需先解压才能按虚拟地址取码）

#### 失败项 3：HAL 寄存器打印在 release 编译中被裁掉
- SDK `hi_debug.h`：日志级别 0=FATAL 1=ERROR 2=WARN 3=INFO 4=DBG，
  `HI_LOG_LEVEL = HI_TRACE_LEVEL_INFO` → `HI_DBG_PRINT` **编译为空**
- `HI_DBG_VENC → HI_DBG_PRINT`，因此所有 DBG 级打印都不存在
- HAL 本身是汇编（`drv_venc_hal.S`），无任何打印语句
- 实测 `hi_venc` 调到 7/9 只得到 INFO 级驱动日志

### 结论：厂商固件侧取证路线到此为止
厂商寄存器编程序列**无法从出货固件中提取**（无 kcore、无 /dev/mem 设备区、无 HAL 打印）。

### 新发现的可行路线（M4 下一步）
SDK 内 **`venc_v1.0` 是纯 C HAL**：
- `venc_v1.0/hal_venc.c`（1097 行，C 语言，`S_VEDU_REGS_TYPE` 结构体直写寄存器）
- `hal_venc.h` 中同时存在 `VEDU_REG_BASE_ADDR 0xf8c80000`（与本板一致）的配置分支
- 相比 v2.0 的 8000 行汇编 HAL，**可读性和可调试性高一个数量级**

建议：把 mainline 移植从 v2.0(asm HAL) 切换到 **v1.0(纯 C HAL)** 重新驱动 VEDU，
按 v1.0 的寄存器序列逐字段核对，定位 v2.0 路径缺的启动位。

### 关于「切换到 v1.0 纯 C HAL」的可行性核查（结论：本项目不适用）

| 项 | v1.0 | v2.0 |
|---|---|---|
| HAL 形态 | `hal_venc.c`（1097 行 C，结构体直写寄存器） | `drv_venc_hal.S`（约 8000 行汇编） |
| 支持芯片 | **仅 Hi3798CV200 / Hi3798MV100**（`firmware/product/` 只有这两个） | Hi3798MV200 / Hi3796MV200 / Hi3798MV310（V500R001） |
| 本板 VEDU | — | **V500R001**（厂商内核实测符号 `DRV_VENC_HAL_V500R001_*`） |

→ **v1.0 的寄存器布局是 CV200/MV100 的 VEDU，不是本板的 V500R001**，
直接切换会写错寄存器，不可行。

**可借鉴的部分（已提取）**：
- v1.0 `VENC_HAL_CfgReg` 展示清晰启动时序：
  1. `VEDU_INTMASK`：先屏蔽 EndOfPic/BufFull/PbitOverflow（对应本板寄存器 0x004）
  2. `VEDU_MODE`：置 `vencEn=1`、`stdmod`、`lowDlyMod`、`clkGateEn` 等（对应 0x000）
  3. 依次写 PICCFG/CSC/RC/STRM 等配置
- `venc_v2.0/firmware/core/include/venc_hal_ext.h` 给了 V500 HAL 的 C 侧结构定义
  （`VENC_HAL_CTRL_S` 里有 `RegConfigMode /*0: Reg; 1:ddr*/`），可作为写 C 版 V500 HAL 的接口蓝本

### 新假设（待验证）：之前的 mode=1 挂死可能由"诊断代码"造成
我们此前在 `VENC_HAL_CfgReg` 返回后立刻用 `VENC_HAL_ReadReg` 读硬件状态。
若 mode=1 下硬件会立即启动，**对正在运行的 VEDU 读寄存器可能挂总线**，从而伪装成"CfgReg 挂死"。

已做的准备：
- 删除 CfgReg 之后的全部寄存器读取诊断（保留 `CFG done` 日志）
- Kbuild 改回 `-DVENC_REG_CONFIG_MODE=1`
- 模块已编译（183,296 B，md5 5c882b703b23612e30f803d24fa60426）
→ 待 Ubuntu 恢复完成后立即上板验证

### 恢复 Ubuntu + mode=1 新假设验证（2026-11-04 晚）

#### Ubuntu 已完整恢复并验证
- 备份通过「整盘单流」方式写回：32MB 引导区 + 间隙零 + 7GB rootfs 镜像（一次 7.82GB 流）
- 恢复后实测：SSH 正常、`Linux 7.3.0`、`weston/ssh/smbd` 全部 active、eth0 = 192.168.2.10

#### mode=1（DDR 配置模式）新假设：已被证伪
假设：此前 mode=1 的"挂死"是我们在 `VENC_HAL_CfgReg` 返回后立即读 VEDU 寄存器造成的。

验证：删除全部 CfgReg 后的寄存器读取诊断，仅保留 `CFG done` 日志，重新以
`-DVENC_REG_CONFIG_MODE=1` 编译（183,296 B，md5 5c882b703b23612e30f803d24fa60426）上板测试：

```
trace: HAL StrmBuf=... DdrReg=0xa5eb000 ...
       CFG called ddrregvir=0xffff800081261000 ...
       （无 CFG done）
isr=0，板子随后复位（uptime 归零），dmesg 无 oops
```

→ **删除诊断后仍然挂死/复位，假设被证伪**：mode=1 下 HAL 在 CfgReg 内部就触发了硬件总线异常，
不是我们的诊断代码引起。

#### v1.0 纯 C HAL 可行性结论
- v1.0 `firmware/product/` 仅 **Hi3798CV200 / Hi3798MV100**，不含 MV300
- 本板 VEDU 为 **V500R001**（厂商内核符号证实），与 v1.0 的寄存器布局不同
- 因此 **不能直接切换到 v1.0**；只能借鉴其 C 语言的启动时序写法，为 V500 重写 C HAL（工作量较大）

### 当前 M4 状态
- 配置链路（时钟/复位/SMMU/中断/MMIO）已验证可用
- `CfgReg` 在 mode=0 能返回但硬件不启动；mode=1 在 CfgReg 内部总线挂死
- 下一步可选：
  1. 用 C 重写 V500 HAL（以 v2.0 汇编为规范、v1.0 C 为风格），逐步二分定位启动位
  2. 或在 mode=0 下继续二分 CfgReg：把 696 字节配置分批写入再读回状态，找出导致不启动的最小字段集

## 2026-11-04 逆向原厂固件：取得 V500 HAL 的寄存器配置（关键突破）

### 方法
1. 从原厂 bootimg 取出 uImage → payload 是 zImage（自解压）
2. 扫描发现 gzip 流 @18552 → 解压得到**完整内核 Image = 20,240,332 字节**
3. 用 `/proc/kallsyms`（kptr_restrict=0）拿到的真实地址定位：
   - `DRV_VENC_HAL_V500R001_CfgReg = 0xc0a2536c`
   - 换算文件偏移 = vaddr - 0xC0008000 → `0xA1D36C`
4. 用 SDK 的 `arm-histbv320-linux-objdump` 反汇编 7808 字节
   → 完整反汇编已存档：`docs/porting/vendor-venc-cfgreg-disasm.asm`

### 关键结论 1：厂商是 32 位布局
```
c0a25388: mov  r2, #680        ; memcpy 长度 680（32 位结构）
c0a25394: ldr  r5, [r7, #676]  ; DDR 配置镜像指针在结构偏移 676
```
（我们的 64 位结构是 696 字节、指针在 688 —— 这就是布局错位的根源）

### 关键结论 2：真正的硬件寄存器写入只有 ~10 个，其余全部走 DDR 镜像
基址 r9 = VEDU 寄存器基址（0xF8C80000）：

| 寄存器偏移 | 写入值/来源 |
|---|---|
| `0x000` (MODE) | **0xCF**（`mov r2,#0xCF` → `str r2,[r9]`） |
| `0x010` | `[r4,#0xDB4]`（HAL scratch） |
| `0x014` | 0 |
| `0x018` | 0 |
| `0x034` | 0 |
| `0x044` | 0 |
| `0x080` | 0 |
| `0x118` | `[r7,#672]`（RegCfg 字段） |
| `0x250` | `[r7,...]` |
| `0x004` (INTMASK) | **0**（清/放开中断） |
| **`0x008`** | **1 ← 函数最后一条写（启动位 / kick）** |

SMMU 块（基址 = VEDU 基址 + 0xF000）：

| 偏移 | 内容 |
|---|---|
| `0x000` (SCR) | `(3<<16) | bit0=[r8+264]&1 | bit3=[r8+268]&1` → 实测值 **0x00030000**（=使能 SMMU，**不是 bypass**） |
| `0x008/0x010/0x01C/0x020/0x02C` | 0 |
| `0x530` | `(9<<24)|(7<<16)|0|1` = 0x09070001 |
| `0x208 / 0x20C` | TTBR ← `[r7,#556]`（SmmuCfg 页表基址） |
| `0x2F0 / 0x2F4 / 0x304 / 0x308` | ← `[r7,#560] / [r7,#564]`（页表相关字段） |

### 关键结论 3：我们与厂商的差异（可解释所有现象）
| 项 | 原厂 | 我们的移植 |
|---|---|---|
| 配置结构 | 680 字节，指针 @676 | 696 字节，指针 @688（8 字节字段） |
| 硬件寄存器写入 | 只写 ~10 个 + DDR 镜像 | mode=0 把 696 字节结构**整体 memcpy 进寄存器**（错位） |
| SMMU | **使能**（SCR=0x30000）+ **真实页表 TTBR** | 我们强制 **bypass（SCR=1）**，TTBR=0 |
| 启动位 | 最后写 `0x008 = 1` | 结构 memcpy 恰好也写了（0x008=1）但其余全错 |

→ **我们 mode=0 时看到 `REG[0]=0xCF`、`REG[8]=1` 与厂商一致，但其它寄存器全因 64 位布局错位而写错**，
所以硬件不启动；mode=1 时 DDR 镜像布局同样错位，导致 VEDU 读到非法内容 → 总线挂死。
→ 另外**SMMU 不该 bypass**：厂商明确是"使能 + 页表"。

### 下一步实现方案（已明确）
1. 按 32 位布局（680 字节）在 C 里重建配置结构，替换掉 64 位结构直写
2. 只写上述 ~10 个寄存器 + 构建 DDR 镜像（布局必须以 32 位汇编为准）
3. 为 VEDU SMMU 建立**真实 identity 页表**并填入 `SmmuCfg` 字段，恢复 SCR=0x30000
4. 最后一步照厂商写 `0x008 = 1` 启动

### 2026-11-04 晚：按逆向结果重写驱动（32 位布局 + 真实 SMMU 页表）

#### 已完成的代码改造（mainline 侧）
1. **强制 32 位配置布局**：新增 `port/venc/inc/venc_hal_ext.h` 覆盖 SDK 头，
   - `VIRT_ADDR` → `HI_U32`
   - `pRegBase` 指针 → `HI_U32`
   → 实测 `sizeof(VENC_HAL_CFG_S) = 680`，与厂商 32 位 ABI 完全一致
   （此前是 696/688，整个配置从偏移 0 起就错位）
2. **驱动侧语义修正**：`ExtCfg.DdrRegCfgVirAddr` 改为填**物理地址**（硬件字段），
   CPU 侧镜像虚拟地址通过全局 `g_venc_ddr_cfg_va` 传递
3. **SMMU 真实页表**（依据 SDK `hisi-iommu.c`）：
   - 4MB 平坦 identity 页表（1M 项 × 4B，项 = `(pa & 0xFFFFF000) | 1`）
   - TTBR 写 0x208/0x20C，错误缓冲写 0x304/0x308
   - SCR 写 `0x00030001`（此前我们是 bypass=1）
   - 实测：`ptable phys=0x33400000, SCR=0x30001, TTBR=0x33400000`
4. **C 版 CfgReg**（按反汇编的寄存器清单）：MODE(0x000)=0xCF、0x118=镜像物理地址、
   0x010/014/018/034/044/080/250=0、INTMASK(0x004)=0、最后 0x008=1 启动
5. 修复 MMZ stub 重启后 `hi_venc_dma` 设备 EEXIST（模块退出时注销）

#### 实测结果
- `C32: sizeof=680`、`C32: kick done reg008=0x1`、`CFG done`、`oops=0`（板子稳定）
- 但 **ISR=0，无码流**；状态回读：`MODE=0xCF, INTMASK=0, 0x008=1`，
  其它寄存器全 0；SMMU `SCR=0x30001`、无 fault（0x300=0）→ **VEDU 完全没有发起 DMA**
- 结论：**寄存器写入与 SMMU 环境已正确，但 DDR 配置镜像内容无效**，
  硬件在读取镜像前就放弃执行（0x008 读回仍为 1，说明启动位未被硬件消费）

#### 剩余唯一缺口：DDR 配置镜像的"寄存器文件打包"
厂商 HAL 会把 C 结构体按 **bitfield 打包**成 VEDU 的寄存器文件镜像（680 字节窗口），
而我们目前只是把结构体原样 memcpy 过去 —— 字段顺序/位域不对，VEDU 无法解析。

来源已具备：
- 厂商 64 位 HAL 汇编（`port/venc/src/drv_venc_hal.S`，SDK 原版）
- 厂商 32 位 HAL 汇编源（`venc_v2.0/32bit/3796mv200/drv_venc_hal.S`）
- 原厂内核 CfgReg 完整反汇编（`docs/porting/vendor-venc-cfgreg-disasm.asm`）

下一步（机械可执行）：从 32 位 HAL 汇编中提取 `str rX,[r5,#off]` 序列与 `bfi` 位域拼装，
生成 C 版镜像构建表 → 替换当前的结构体原样拷贝。

## 2026-11-04 深夜：qemu 模拟执行厂商 32 位 HAL —— 拿到镜像与寄存器 ground truth

### 方法（重大工具突破）
1. 下载 `qemu-user-static` 的 deb，解包出 `qemu-arm-static`（无需 root）
2. 用 SDK 的 32 位软浮点工具链（`arm-histbv310-linux` 的 `arm-gcc49-linux-gnueabi-*`）
   把 **厂商 32 位 HAL 汇编** `venc_v2.0/32bit/3796mv200/drv_venc_hal.S` 直接编译成
   可执行文件，配合自写 `harness.c`（提供 OSAL 表 + 假寄存器区 + 假配置）：
   ```
   arm-gcc49-linux-gnueabi-gcc -march=armv7-a -static -O1 -o hal_harness harness.c drv_venc_hal.S
   qemu-arm-static ./hal_harness
   ```
3. 成功在 x86 主机上跑通厂商 HAL，**直接拿到它构建的 DDR 配置镜像和全部寄存器写入**

### 拿到的 ground truth

**寄存器写入（320x240 H264 配置实测）：**

| 偏移 | 值 |
|---|---|
| VEDU 0x0000 | 0x000000CF |
| VEDU 0x0008 | 0x00000001（启动位） |
| VEDU 0x0018 | 0x02625A00 |
| VEDU 0x001C | 0x0C0300D6 |
| VEDU 0x0034 | 0x00370006 |
| VEDU 0x0038 | 0x0000007F |
| VEDU 0x0044 | 0x000091B1 |
| VEDU 0x0080 | 0x00010001 |
| VEDU 0x0118 | 镜像物理地址 |
| VEDU 0x024C | 0x000004E2 |
| VEDU 0x0250 | 0x00000003 |
| SMMU 0x0000 | **0x00030008**（此前我们写 0x30001，错误） |
| SMMU 0x0208/0x020C | 页表物理地址 |
| SMMU 0x0530 | 0x09070001 |

**DDR 镜像（688 字节）**：已保存为 `port/venc/inc/venc_img_template.h`，
并定位出运行时地址字段偏移：
`0x068 SrcY / 0x06c SrcC / 0x080 RcnY0 / 0x084 RcnC0 / 0x098 RcnY1 / 0x09c RcnC1 /
0x0e0 StrmBuf / 0x0e4 StrmWp / 0x0e8 StrmRp`

### 接入 mainline 后的实测结果
- 用镜像模板 + 上述精确寄存器程序 + SMMU 页表（SCR=0x30008）测试
- **硬件首次真正启动**：日志出现 `kernel BUG at fs/buffer.c:1199`（`find_get_block_common`）
  和 `Fatal exception in interrupt` → 说明 **VEDU 已在做 DMA**，但写入的地址落到了内核内存，
  造成内存破坏
- 即：从"完全不动作"前进到"会 DMA 但地址/镜像字段不匹配"

### 下一步（已完全可自动化）
1. 在驱动里把运行时 `VENC_HAL_CFG_S`（680 字节）dump 到文件
2. 把这份配置喂给 qemu harness（改 harness 从文件读配置）→ 生成**与该配置完全对应的镜像**
3. 用该镜像替换模板（不再需要运行时打补丁），同时在 SMMU 里只映射 VENC 实际缓冲区
   （避免错误地址破坏内核内存）

## 2026-11-04 深夜续：用 qemu 结果重建驱动并上板验证

### 已打通的能力（可复用）
- 主机端 qemu-arm 模拟执行厂商 32 位 HAL：输入任意 680 字节配置 → 输出 **精确 DDR 镜像 + 完整寄存器写入**
  - 工具：`/tmp/venchal/hal_harness`（源码 `harness.c` + 厂商 `drv_venc_hal.S`）
  - 运行：`qemu-arm-static ./hal_harness <cfg.bin>`
- 驱动侧新增 `CFGHEX:` 逐字 dump，可把运行时配置导出给主机工具
- 新增模块参数 `venc_nokick=1`（只配置不启动，便于安全采集）

### 本轮修正的三处关键错误
| 项 | 错误值 | ground truth |
|---|---|---|
| SMMU SCR | 0x00030001 | **0x00030008** |
| SMMU 0x530 | 未写 | **0x09070001** |
| VEDU 0x001C / 0x024C | 硬编码模板值 | 由配置决定（实测 0x000300D6 / 0x0000023B） |
| 镜像地址字段 | 只映射 9 个 | **实际 16 个**（含 PmeInfo/Tmv/Pme 等） |
| CfgReg 挂钩 | 错挂到 C64 路径 | 已切回 C32 |

### 镜像地址字段完整映射（实测）
```
img 0x058 <- PmeInfoAddr[1]   img 0x05C <- PmeInfoAddr[0]   img 0x060 <- PmeInfoAddr[2]
img 0x068 <- SrcYAddr         img 0x06C <- SrcCAddr
img 0x080 <- RcnYAddr[1]      img 0x084 <- RcnCAddr[1]
img 0x098 <- RcnYAddr[0]      img 0x09C <- RcnCAddr[0]
img 0x0B0 <- PmeAddr[0]       img 0x0D0 <- PmeAddr[1]
img 0x0D8 <- TmvAddr[1]       img 0x0DC <- TmvAddr[0]
img 0x0E0 <- StrmBufAddr[0]   img 0x0E4 <- StrmBufWpAddr   img 0x0E8 <- StrmBufRpAddr
```

### 当前实测状态（最新）
```
C32IMG: srcY=0x18060000 srcC=0x18072c00 rcnY0=0x192c2000 strm=0x19100040
CFG done            （CfgReg 完整返回）
oops=0  板子稳定（up 4 min）
isr=0  out_venc.h264 = 0 字节
```
即：**配置链路全部走通、无内存破坏、无总线挂死**，但硬件**仍未产生编码完成中断**。

### 下一步（收窄到中断/状态观测）
1. 增加「定时器/工作队列采样」：kick 之后 100us/1ms/10ms 读 VEDU 0x000/0x004/0x008 与
   SMMU fault/status，写入 trace（不能放在中断上下文里读，会挂总线）
2. 核对中断路由：GIC SPI 101 是否真的 unmask；INTMASK(0x004)=0 的语义（屏蔽还是使能）
3. 若 INTSTATUS 有置位但 IRQ 未到 → 中断控制器/IRQ 号问题；若 INTSTATUS 全 0
   → 镜像里某个字段仍不匹配（可用 qemu 二分：改配置字段看镜像差异）

### 2026-11-04 深夜：kick 后状态采样

新增诊断：
- `KICK0`：kick 后立即读 VEDU 0x000/0x008/0x118 与 SMMU SCR/TTBR
- `PROBE`：workqueue 延时采样（1ms/12ms/28ms），进程上下文安全读
- `WDBG`：写 MODE 前后读回校验

实测结果：
```
WDBG before: [0]=0x00000000 [8]=0x00000000
WDBG after MODE: [0]=0x000000cf
KICK0: VEDU[0]=0x000000cf [8]=0x000000cf [118]=0x000000cf SMMU SCR=0x00030008 TTBR=0x39000000
PROBE +12ms: VEDU[0]=0 [4]=0 [8]=0 [118]=0；SMMU SCR=0 TTBR0=0 TTBR1=0
CFG done，Create rc=0，Start rc=0，frame acquire rc=0x801D000D len=0，ISR=0
```

**两个重要观测：**
1. 写 MODE 后立即读回 = 0xCF（写生效）
2. 但 KICK0 里三个不同偏移（0x000/0x008/0x118）**读到同一个值 0xCF** →
   VEDU 寄存器区可能是**写触发/只读回显**，不同偏移读回相同值，说明该模块的读通路不可靠
3. 延时采样全部为 0（且 SMMU 读数也变 0，说明此驱动生命周期内 VEDU/SMMU 被 deinit 重置了）

### 结论
- 配置写入路径已确认生效（写后立即读回正确）
- 但读通路不可用于诊断 → 只能靠 **中断** 和 **缓冲区内容** 判断硬件是否执行
- 当前 Create/Start 均返回成功，但 ISR=0、码流为 0

### 下一步（最有信息量）
1. **直接 dump 码流缓冲区内容**（内核可访问）：`Start rc=0` 后看
   `StrmBufAddr[0]` 指向的内存是否有 VEDU 写入的 H.264 数据
   - 有数据 → VEDU 在编码，只是中断没到（IRQ/GIC 问题）
   - 无数据 → VEDU 未执行（镜像或启动位语义仍不对）
2. 核对 GIC SPI 101 中断使能/触发类型；检查 VEDU 是否有独立 interrupt enable 寄存器

### 2026-11-04 晚（目标重启后第 1 轮）：码流缓冲观测

本轮目标已更新并重新激活（goal revision 19，active），执行计划 A 步：

新增诊断：
- `efl.c` 捕获码流缓冲 VA/PHY/大小到全局
- `venc_probe_fn` 增加 `PROBE STRM`：打印缓冲头 8 字节 + 4KB 内非零字节数
- kick 后 `mdelay(2)` 同步采样一次（避免驱动 deinit 后采不到）

实测（干净重启后）：
```
KICK0: VEDU[0]=0x000000cf [8]=0x000000cf [118]=0x000000cf  SMMU SCR=0x00030008 TTBR=0x30800000
PROBE +16ms: VEDU[0]=0 [4]=0 [8]=0 [118]=0
PROBE +24ms: VEDU[0]=0 [4]=0 [8]=0 [118]=0
PROBE SMMU: SCR=0 TTBR0=0 TTBR1=0
out_venc.h264 = 0 字节；ISR=0
```

**发现一个流程问题（需先修）**：`PROBE STRM` 与同步采样行都未出现，
但本地 .ko 中确实包含这些字符串（`grep -c 'PROBE STRM' hi_venc.ko = 2`）
→ 说明**板子上运行的不是最新构建**（构建/上传链路在板子重启期间被打断）。
在确认部署一致前，不以 PROBE 结果下结论。

**已确认的独立事实**：
- `KICK0` 读回：0x000/0x008/0x118 三个偏移读到同一个值 0xCF → VEDU 读通路不可靠
- 延时采样都在驱动 deinit 之后，读到全 0 属预期
- 目前 ISR 始终为 0，码流文件始终 0 字节

### 下一轮必须先做
1. 校验部署一致性（本地/板上 md5 + 二进制内字符串），确保 `PROBE STRM`/同步采样真的在跑
2. 在模块存活窗口内拿到码流缓冲内容 → 判定 VEDU 是否写过数据
3. 在模块加载状态下检查 `/proc/interrupts` 中 VEDU 中断行是否存在、计数是否为 0

## 2026-11-05 Round 248：镜像一致性验证 + 页表一致化（重要进展）

### 1. 证明我们写的 DDR 镜像与厂商 HAL 完全一致 ✅
用最近一次运行时 dump 的 680 字节配置：
- 主机 qemu 厂商 HAL → 参考镜像
- 我们驱动逻辑（模板 + 16 地址字段补丁）→ 生成镜像
- **逐字节比较：diff = 0**（688 字节完全相同）

说明：**镜像与寄存器程序都已与厂商一致**，问题不在配置内容。

### 2. 定位探测故障：probe 在 deinit 后访问已释放缓冲
```
Unable to handle kernel paging request at virtual address ffff80008122901c
Internal error: Oops [#2] SMP
  process_one_work -> worker_thread
```
→ 延时 probe 落在驱动 deinit 之后，`g_wprp_va` 指向已释放的 MMZ 缓冲，读取即 fault。
这也解释了此前多次"probe 只打印第一行"的现象（第一行之后立刻 fault）。

### 3. 关键改进：页表改为 dma_alloc_coherent + 不再读 VEDU MMIO
- 页表用 `dma_alloc_coherent(4MB)`（CPU 侧非缓存，SMMU 直接可见，无需手工刷 cache；
  尝试 `dcache_clean_inval_poc` 因未导出而改用此方案）
- kick 之后禁止读 VEDU 寄存器（会让总线挂死 → 看门狗复位）

**效果**：本次 kick 后板子**没有再复位**（存活），只剩我们自己 probe 的 stale 指针 fault。
这是第一次在 kick 之后系统能继续运行，为下一步观测创造了稳定条件。

### 4. 当前仍未解决
- ISR 仍为 0、`out_venc.h264` 仍为 0 字节
- probe 必须在 deinit 前（同步、带边界检查）采集 Wp/Rp 与码流缓冲内容

### 下一步（Round 249）
1. probe 改为：kick 后同步 mdelay(3) 采样（内存读取 + 边界检查），**不做任何 VEDU MMIO 读**
2. 若 Wp/Rp 变化或码流缓冲非零 → 硬件在编码，转向 IRQ/GIC 排查
3. 若全零 → 用 qemu 逐字段二分镜像/寄存器（现在有 ground truth 工具，可快速定位）

## 2026-11-05 Round 249：修正 kick 时序 + 首次拿到硬件行为数据

### 修正：所有 MMIO 读必须放在 kick 之前
之前 `KICK0` 在写启动位之后立刻读 VEDU 寄存器 → 总线挂死 → 看门狗复位，
同步 probe 永远执行不到。改为：
```
PREKICK 读寄存器（安全）→ wmb → 写 0x008=1 → mdelay(3) → 只读内存的 probe
```
效果：**板子不再复位**，probe 的 WPRP/VSTRM 终于都能打印出来。

### 首次实测硬件行为（关键数据）
```
VPROBE +16ms
VWPRP [0]=0 [4]=0 [8]=0 [12]=0 [16]=0 [20]=0 [24]=0 [28]=0
VSTRM va=ffff800082add000 phy=0x19100040 size=1843136 nz4k=0 head=00 00 00 00 00 00 00 00
VPROBE +28ms（同上）
ISR=0, out_venc.h264 = 0 字节
```
→ **VEDU 完全没有写任何数据**（Wp/Rp 索引未更新、码流缓冲前 4KB 全零）

### 排除项：不是 SMMU 的问题
新增参数 `venc_smmu_off=1`（SCR=0，VEDU 直接用物理地址）后测试结果**完全相同**
（Wp/Rp 全 0、码流全零、ISR=0）→ SMMU 配置不是阻塞点。

### 已确认一致的部分
- DDR 镜像：与 qemu 厂商 HAL 输出**逐字节相同**（Round 248）
- 寄存器程序：与厂商实测表一致（MODE=0xCF、0x18/0x1C/0x34/0x38/0x44/0x80/0x118/0x24C/0x250、SMMU 0x530）
- CRG：我们的 `product_hw.c` 与厂商 `product.c` 逐行一致
  （CRG35: core_cken/axi_cken/clk_sel=0；CRG203: smmu_cken；Reset 脉冲）
- 测试中读到 CRG35=0x3、CRG203=0x1，与厂商 OpenHardware 期望值一致

### 目前唯一未排除的方向
1. 配置**语义字段**不足：我们的 driver 填的 680 字节配置有大量字段为 0，
   而厂商真实运行时这些字段由 RC/码控等模块填满 → 镜像虽"格式正确"但内容可能无效，
   硬件判定非法后静默丢弃（不产生中断、不写缓冲）。
2. VEDU 启动位语义（0x008）可能还需前置写（如 0x004 特定值或 image valid 位）。

### 下一步（Round 250）
A. 用 **qemu 逐字段实验**：从当前配置出发，逐类补字段（RC、slice、PTS、ext），
   看镜像差异；再在板上试哪些字段组合能让 Wp/Rp 变化
B. 或从厂商固件侧 dump 真实 DDR 镜像（arm32 工具 + /dev/hi_mmz），
   与我们的镜像逐字段比对，找出"应为非零但我们是 0"的字段

## 2026-11-05 Round 250：逐项排除硬件侧配置

本轮继续排除法，确认了以下事实：

| 检查项 | 结果 |
|---|---|
| `VENC_PDT_OpenHardware` 是否真的执行 | ✅ dmesg 有 `VENCCRG: CRG35 write=0x3 read=0x3 CRG203=0x1` |
| Open/Reset 顺序 | 与厂商 `BoardInit`（Open→Reset）一致，且在 CfgReg 之前执行 |
| CRG35 值 | 0x3（core_cken+axi_cken，clk_sel=250MHz），与厂商一致 |
| CRG203 值 | 0x1（smmu_cken），与厂商一致 |
| SMMU 关闭（`venc_smmu_off=1`, SCR=0） | 结果与开启时**完全相同**（Wp/Rp 全 0、码流全零）→ SMMU 不是阻塞点 |
| DDR 镜像 | 与 qemu 厂商 HAL 输出逐字节一致（Round 248） |
| 寄存器程序 | 与厂商实测表一致 |

### 排除后剩下的唯一假设
**配置语义字段不全**：我们的 680 字节配置里大量字段为 0（RC/码控/slice/PTS 等），
镜像"格式正确"但语义可能无效，硬件判定非法后静默丢弃 → 无中断、无 DMA 写。

### 下一步（若继续）
把厂商固件上**真实运行时的 DDR 镜像** dump 出来做字段比对：
- 厂商有 `HI_MPI_MMZ_Map(phys)` 用户态 API + `/proc/media-mem` 物理地址表
- 计划：arm32 工具（mmzdump）在 Android hook 里映射 MMZ 缓冲并 dump 到 /cache
- 然后与我们的镜像逐字段 diff，找出"应为非零但我们是 0"的字段

### 备选：直接判定
若没有足够预算完成厂商镜像比对，则 M4 的结论应记录为：
「配置链路、镜像格式、寄存器序列、时钟复位均已与厂商一致，但硬件仍不执行；
根因指向配置语义字段不完整，需要厂商运行时镜像做逐字段比对才能定位。」

## 2026-11-05 Round 251：诊断工具链出现部署/运行不一致（记录，未下结论）

本轮尝试用「延时回读」判断 VEDU 寄存器文件是否存活（RB5MS 探针）、
以及 `venc_nokick=1` 下不启动硬件只检查寄存器保持情况。

实测异常：
- 模块已重建并含 `RB5MS` / `PREKICK` 字符串（本地 `grep -c` 均为 1）
- 板上 `venc_nokick` 参数确认 = 1（`/sys/module/hi_venc/parameters/venc_nokick`）
- `VENCCRG`（OpenHardware）每次都执行 ✅
- `C32:`（我们 CfgReg 入口）执行 ✅
- 但 `RB5MS`（同函数后半段、nokick 分支内）**一次都没打印**

这说明「板上运行的二进制」与「本地构建」之间仍存在不一致，
或我们插入的诊断代码所在分支未被实际执行到。**在确认这一点之前，
不以 RB5MS/PREKICK 的结果下任何硬件结论。**

### 已确定有效的可靠观测（前几轮）
- `VWPRP` 全 0、`VSTRM` 前 4KB 全零（Round 249，同步 probe，内存读取，可复现）
- `venc_smmu_off=1` 与开启 SMMU 结果完全相同（Round 249/250）
- 镜像与 qemu 厂商 HAL 逐字节一致（Round 248）

### 结论（本轮）
M4 的阻塞点仍然只能归结为「配置语义字段不完整」，
但现有诊断工具存在部署一致性问题，需要先修好观测链路。

### 时间预算
目标剩余轮次有限（本轮 251/256）。若不继续，建议按以下结论收尾：
「M4 已完成逆向/仿真/一致性验证，硬件侧寄存器、镜像、时钟复位、SMMU 全部对齐，
但硬件仍不执行；根因指向配置语义字段，需要厂商运行时镜像逐字段比对才能定位。」

## 2026-11-05 Round 252：修好观测链路 + 发现 kick 后寄存器被清零

### 修好部署一致性（关键基建）
给模块加了唯一 build id（`VENCBUILD: 1104-193754` 等），insmod 时打印。
之前 RB5MS/PREKICK "不打印"的谜团解决：**板上跑的是旧模块**。
build id 之后所有观测都可追溯到确切构建。

### 用修好的链路得到的两个新事实

**事实 1（nokick，kick 前）**：延时 5ms 后寄存器仍保持：
```
RB5MS: MODE=0x000000cf R18=0x02625a00 R118=0x0e1f4000 SMMU_SCR=0x00030008 CRG35=0x3 CRG203=0x1
```
→ VEDU 寄存器文件存活、时钟已开、SMMU 已配置（写进去的值能保持）

**事实 2（有 kick，kick 后 3ms / 16ms）**：**全部寄存器读回 0**
```
VSYNC +3ms MMIO: MODE=0x0 R4=0x0 R8=0x0 R118=0x0 SCR=0x0
VPROBE +16ms MMIO: 同上
VWPRP 全 0；VSTRM 前 4KB 全零
```

### 由此产生的关键待验证假设
写 `0x008 = 1` 之后寄存器块整体清零，有两种可能：
1. 该写是**启动**：硬件消费配置后自清（但没产生码流/中断）
2. 该写实际是**复位/清零**（我们的寄存器偏移 0x008 与厂商语义不一致）

已加入 `VKICK` 探针：在 `writel(1, base+0x008)` **紧接着**回读 MODE/R8/R118/SCR，
若读到 0 → 该写就是清零/复位；若仍为 0xCF → 说明是别处清零。

### 阻塞
板上旧模块 refcount = -1（无法 rmmod），替换新构建必须重启板子。
计划：下一轮重启后立刻加载带 VKICK 的构建并跑测试。

## 2026-11-05 Round 253：VKICK 结果 —— VEDU 寄存器读通路不可靠（决定性）

干净重启后（`VENCBUILD: 1104-193813` 确认构建一致）：

```
VKICK  (writel(1, base+0x008) 之后立即回读):
        MODE=0x300f5000 R8=0x300f5000 R118=0x300f5000 SCR=0x00030008
VSYNC +3ms:
        MODE=0x0 R4=0x0 R8=0x0 R118=0x0 SCR=0x0
out_venc.h264 = 0 字节
```

### 判读
1. 三个不同偏移（0x000/0x008/0x118）**读到同一个从未写入过的值 0x300f5000**
   → 这是**总线浮空/未驱动值**，说明 **VEDU 寄存器块的读通路不可用**
2. 同一时刻 SMMU 块（base+0xF000）的 SCR 读到正确的 0x00030008
   → 映射、时钟部分没问题，问题局限在 VEDU 寄存器块
3. +3ms 后全部读 0 → 该块在数毫秒内彻底无响应

### 结论（M4 的最终定位）
- 配置链路（写）无法被验证：**读回的值是浮空值**，无法确认 VEDU 是否接受配置
- 硬件不产生中断、不写码流缓冲、Wp/Rp 不动
- 与厂商对照：镜像逐字节一致、寄存器表一致、CRG 与 product.c 逐行一致、SMMU 已排除
- **剩余差异只可能在于：VEDU 寄存器块的访问时钟/总线接入没有被正确打开**
  （CRG35 bit0/bit1 已置 1，但可能存在额外的寄存器访问时钟门控位或 NIU 侧配置，
   这些在厂商侧由未移植的模块/PM 框架完成）

### 为什么这是阻塞
- 无法用读回做任何二分（读通路本身就是坏的）
- 无法从厂商固件取得运行时寄存器/镜像（无 kcore、无 /dev/mem、HAL 打印被裁）
- 剩下唯一可行路径：从厂商固件 dump 运行时 DDR 镜像（需 arm32 工具 + /dev/hi_mmz +
  切回厂商固件），或获取 VEDU 寄存器手册 / 移植 PM 时钟框架

→ 属于「需要厂商资料或大工程」的阻塞，已超出本目标剩余轮次能做到的范围。
