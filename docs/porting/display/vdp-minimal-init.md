# Hi3798MV300 VDP v4.0 最小 1080p60 单图层初始化序列

本文从厂商 4.4 内核源码（`source/msp/drv/vo/vdp_v4_0/`，mv200 变体，MV300 复用）提取 VDP 显示控制器在
**复位后 → 固定 1920x1080p60 → RGB888 或 ARGB8888 单图层全屏扫描输出** 所需的最小寄存器写序列，
供 mainline DRM/KMS 驱动移植时逐段对照。

- 参考源码：`source/msp/drv/vo/vdp_v4_0/hal/98mv200/`、`hal/common/`、`source/msp/drv/hifb/adp/hal_v1_0/`
- 本文范围：**只覆盖 VDP 侧出图**。HDMI 2.0 TX 的初始化见同目录
  [hdmi-minimal-init.md](hdmi-minimal-init.md)，但其像素时钟/时序必须与本文一致。
- 不覆盖：PQ、HDR、CSC 管理、缩放（ZME）、多图层/多 region、4K、WBC、SMMU 页表、VDAC/模拟输出。
- 已核对 `source/msp/drv/dbe/`：它只是 dma-buf 分配/导出器（`hi_dbe.c`：misc device + dma_buf ops），
  不做图层合成；本路径的合成完全在 VDP 的 MIXG0/CBM 内完成，因此不涉及 DBE 寄存器。
- 标记约定：
  - **【源码确定】**：源码里有明确写入值或可直接推导。
  - **【推断】**：从源码行为推导，但未经硬件验证。
  - **【需实测确认】**：仅凭源码无法确定，必须上板只读核对/试写。

> 只读核对原则：先把 VDP 版本、CRG 状态、DHD0 状态读出来，再动写操作；任何“写下去没反应”的步骤，
> 先怀疑时钟/复位没开，而不是怀疑寄存器值。

---

## 0. 结论速览

| 项 | 结论 | 依据 |
|---|---|---|
| VDP 基址 | `0xf8cc0000`，寄存器窗口 64 KiB | `vdp_ip_define.h:118` `VDP_BASE_ADDR`；`vdp_fpga_define.h:6` `DISP_BASE_ADDRESS` |
| 复位释放标志 | `VDPVERSION1/2`（`0x20/0x24`）非 0；MV300 实测 `0x8380000b / 0x03000177` | 板卡实测 + `VDP_CheckResetFinished()` |
| 单图层数据通路 | `G0 → MIXG0 → GP0 → CBM_MIX1(prio1) → DHD0 → VO_MUX(hdmi_sel=0) → HDMI TX` | 见 §1、§4 |
| 1080p60 时序 | 2200 x 1125 @ 148.5 MHz；Hact=1920/Hbb=192/Vfb=88/Hpw=44；Vact=1080/Vbb=41/Vfb=4/Vpw=5 | `vdp_hal_chn.c:507`；`hal_specific_config.c:477` |
| 像素时钟链 | HPLL 594 MHz → VDP `vdp_clk_div=1`（/2）=297 MHz → `vo_hd_clk_div=0`（/2）=148.5 MHz | 【推断】`hal_specific_config.c` PLL 表 + 分频函数 |
| 最小步骤 | 8 个 stage，约 **51 次寄存器写**（走 GP0 CSC 约 60 次） | 见 §4 汇总 |
| 最大不确定点 | `DHD0_CTRL.hdmi_mode` 与 GP0 CSC / HDMI TX 输入色彩域的配对关系 | 见 §7 |

---

## 1. 寄存器空间与偏移

### 1.1 基址

| 空间 | 地址 | 说明 |
|---|---|---|
| VDP / DISP | `0xf8cc0000` | 本文全部偏移都相对此地址；`ioremap` 大小 64 KiB |
| CRG | `0xf8a22000` | `source/common/drv/include/hi_reg_common.h:71` `HI_CRG_BASE_ADDR` |
| HDMI TX（外部 IP） | `0xf8ce0000` | `hdmi_2_0/product/hisiv100/hdmi_product_define.h:65` |
| HDMI APHY（外部 IP） | `0xf8d30000` | 见 [hdmi-minimal-init.md](hdmi-minimal-init.md) |

访问约定：VDP 寄存器均为 32-bit、4 字节对齐；CRG/复位类写后建议加屏障（厂商 `Local_SyncRegisterOperation()` 是 `mb()` + 10µs 延时，
mainline 可用 `mb()`/`wmb()` + `udelay(10)` 等价实现）。

### 1.2 子模块基址与索引步长

来自 `vdp_ip_define.h:79-108`（`VID_OFFSET/VP_OFFSET/GFX_OFFSET/GP_OFFSET/MIX_OFFSET/CHN_OFFSET/INTF_OFFSET`）
和 `vdp_reg.h` 的 `S_VDP_REGS_TYPE` 注释：

| 子模块 | 基偏移 | 层间步长 | 说明 |
|---|---|---|---|
| TOP / 全局 | `0x0000` | - | `VOCTRL`、`VO_MUX`、AXI、版本、中断 |
| 输出选择 `VO_MUX` | `0x0100` | - | DHD0/DHD1 → HDMI/VGA/LCD/BT1120 选择 |
| 视频层 V0/V1 | `0x0800` | `0x800` | 本文不用 |
| 视频处理 VP0 | `0x6000` | `0x800` | 本文不用 |
| 图形层 G0..G5 | `0x7000` | `0x200` | 单图层用 G0 |
| 图形处理 GP0/GP1 | `0x8000` | `0x800` | G0 必须经 GP0 |
| 视频混音 MIXV0 | `0xb000` | - | `MIXV0_BKG 0xb000`、`MIXV0_MIX 0xb008` |
| 图形混音 MIXG0 | `0xb200` | - | `MIXG0_BKG 0xb200`、`BKALPHA 0xb204`、`MIX 0xb208`、`MIX_BYPASS 0xb20c` |
| CBM（DHD 前级混合） | `0xb400` | - | `CBM_BKG1 0xb400`/`CBM_MIX1 0xb408`（DHD0）；`0xb500/0xb508`（DHD1） |
| DHD 通道（timing+输出） | `0xc000` | `0x400` | DHD0=0xc000，DHD1=0xc400 |
| INTF 校验/统计 | `0xc368` | - | 只读校验，非出图必需 |
| HDMI buffer | `0xd000` | - | 厂商常规路径未用 |
| SMMU | `0xf000` | - | `SMMU_SCR 0xf000`；层旁路在 G0/V0 块内 |

> 注意：`vdp_ip_define.h` 里的 `HDDATE_BASE_ADDR (VDP_BASE+0xf000)` 与 `SMMU_SCR` 同偏移，两者不可能同时成立；
> HDATE 寄存器实际在 `0xcc00`（`HDATE_VERSION`），该宏疑似历史遗留/笔误，不要用它。

### 1.3 本文用到的关键寄存器偏移

| 寄存器 | 偏移 | 绝对地址 | 作用 |
|---|---|---|---|
| `VOCTRL` | `0x0000` | `0xf8cc0000` | 双通道模式、时钟门控 |
| `VOINTMSK` | `0x000c` | `0xf8cc000c` | 中断屏蔽（出图不必需） |
| `VDPVERSION1/2` | `0x0020/0x0024` | `0xf8cc0020` | 复位状态/芯片 ID（只读） |
| `VOMIDORDER` | `0x0028` | `0xf8cc0028` | AXI MID 使能 |
| `VOAXICTRL` | `0x0030` | `0xf8cc0030` | master0/1 读写 outstanding |
| `VOAXICTRL1` | `0x0034` | `0xf8cc0034` | master2/3 读写 outstanding |
| `VO_MUX` | `0x0100` | `0xf8cc0100` | `hdmi_sel[3]` |
| `SMMU_SCR` | `0xf000` | `0xf8ccf000` | `glb_bypass[0]`、`ptw_pf[19:16]` |
| `G0_CTRL` | `0x7000` | `0xf8cc7000` | `ifmt[7:0]`、`surface_en[31]` |
| `G0_UPD` | `0x7004` | `0xf8cc7004` | `regup[0]` 生效 |
| `G0_ADDR` | `0x7010` | `0xf8cc7010` | 帧地址（SMMU 关闭时=物理地址） |
| `G0_STRIDE` | `0x701c` | `0xf8cc701c` | `surface_stride[15:0]`，**单位 16 字节** |
| `G0_IRESO` | `0x7020` | `0xf8cc7020` | 输入宽高-1 |
| `G0_SFPOS` | `0x7024` | `0xf8cc7024` | 源起始 X |
| `G0_SMMU_BYPASS0` | `0x7028` | `0xf8cc7028` | `bypass_2d[0]`、`r_bypass_3d[1]` |
| `G0_CBMPARA` | `0x7030` | `0xf8cc7030` | `galpha[7:0]`、`palpha_en[12]`、`premult_en[13]` |
| `G0_DFPOS/DLPOS` | `0x7080/0x7084` | `0xf8cc7080` | 显示起止坐标 |
| `G0_VFPOS/VLPOS` | `0x7088/0x708c` | `0xf8cc7088` | 视频起止坐标（须与显示坐标一致） |
| `G0_BK` | `0x7090` | `0xf8cc7090` | 图层背景色 |
| `G0_ALPHA` | `0x7094` | `0xf8cc7094` | `vbk_alpha[7:0]` |
| `GP0_CTRL` | `0x8000` | `0xf8cc8000` | IP 顺序（CSC/ZME/直通）、mute |
| `GP0_UPD` | `0x8004` | `0xf8cc8004` | `regup[0]` |
| `GP0_ORESO/IRESO` | `0x8008/0x800c` | `0xf8cc8008` | 输出/输入宽高-1 |
| `GP0_DFPOS/DLPOS` | `0x8100/0x8104` | `0xf8cc8100` | 显示起止坐标 |
| `GP0_VFPOS/VLPOS` | `0x8108/0x810c` | `0xf8cc8108` | 视频起止坐标 |
| `GP0_ALPHA` | `0x8114` | `0xf8cc8114` | `vbk_alpha` |
| `GP0_CSC_IDC/ODC/IODC` | `0x8120/0x8124/0x8128` | `0xf8cc8120` | CSC 输入/输出 DC、使能 |
| `GP0_CSC_P0..P4` | `0x812c..0x813c` | `0xf8cc812c` | CSC 3x3 系数 |
| `MIXG0_BKG/BKALPHA/MIX` | `0xb200/0xb204/0xb208` | `0xf8ccb200` | 图形混合 |
| `CBM_BKG1/MIX1` | `0xb400/0xb408` | `0xf8ccb400` | DHD0 前级混合 |
| `DHD0_CTRL` | `0xc000` | `0xf8ccc000` | `regup[0]`、`iop[4]`、`hdmi_mode[14]`、`twochn_debug[15]`、`intf_en[31]` |
| `DHD0_VSYNC` | `0xc004` | `0xf8ccc004` | `vact[11:0]`、`vbb[21:12]`、`vfb[31:22]` |
| `DHD0_HSYNC1` | `0xc008` | `0xf8ccc008` | `hact[15:0]`、`hbb[31:16]` |
| `DHD0_HSYNC2` | `0xc00c` | `0xf8ccc00c` | `hfb[15:0]`、`hmid[31:16]` |
| `DHD0_VPLUS` | `0xc010` | `0xf8ccc010` | 隔行下半场（逐行无效） |
| `DHD0_PWR` | `0xc014` | `0xf8ccc014` | `hpw[15:0]`、`vpw[23:16]` |
| `DHD0_SYNC_INV` | `0xc020` | `0xf8ccc020` | 同步/数据极性反转 |
| `DHD0_DATA_SEL` | `0xc02c` | `0xf8ccc02c` | 输出数据源选择 |
| `DHD0_DITHER0_CTRL` | `0xc060` | `0xf8ccc060` | 10→8bit dither（可关） |
| `DHD0_STATE` | `0xc0f0` | `0xf8ccc0f0` | `vcnt[15:3]` 当前行（调试） |

---

## 2. 时钟与复位（CRG）

### 2.1 相关 CRG 寄存器

CRG 基址 `0xf8a22000`。MV300 使用 `hi3798mv200/hi_reg_crg.h`（`hi_reg_common.h` 中
`CHIP_TYPE_hi3798mv300` 与 mv200 共用该头文件）。

| 寄存器 | 偏移 | 绝对地址 | 关键位（MV300） |
|---|---|---|---|
| `PERI_CRG_PLL10` | `0x0028` | `0xf8a22028` | `hpll_ctrl0[30:0]`（HPLL 参数 0） |
| `PERI_CRG_PLL11` | `0x002c` | `0xf8a2202c` | `hpll_ctrl1`（MV300 为 `[26:0]`） |
| `PERI_CRG54` | `0x00d8` | `0xf8a220d8` | `vo_bus_cken[0]`、`vo_sd_cken[2]`、`vo_sdate_cken[3]`、`vo_sd_clk_sel[12]`、`vo_sd_clk_div[15:14]`、`vo_hd_clk_sel[16]`、`vo_hd_clk_div[19:18]`、`hdmi_clk_sel[25]`、`vo_sd_hdmi_clk_sel[26]`、`vdp_clk_sel[27]`、`vo_hd_hdmi_clk_sel[29]`、`vou_srst_req[30]`、`vdp_cfg_cken[31]` |
| `PERI_CRG211` | `0x034c` | `0xf8a2234c` | `vo_bp_cken[0]`、`vdp_g4[1]`、`vdp_v3[2]`、`vdp_sd[3]`、`vdp_wbc_vp[6]`、`vdp_wbc_gp[7]`、`vdp_wbc_hd[8]`、`vdp_g3[9]`、`vdp_g1[10]`、`vdp_g0[11]`、`vdp_v1[12]`、`vdp_v0[13]`、`vdp_hd[14]`、`vdp_hd_clk_div1[17]`、`vdp_hd_clk_div0[20]`、`vdp_ini_cksel1[21]`、`vdp_ini_cksel0[22]`、`vdp_clk_div[28:24]`、`vdp_srst_req[29]` |
| `PERI_CRG67` | `0x010c` | `0xf8a2210c` | HDMI TX：`hdmitx_ctrl_os_cken[4]`、`hdmitx_ctrl_srst_req[7]`；MV300 另有 `hdmitx_pxl_cken[16]`（`bits_mv300`） |
| `PERI_CRG68` | `0x0110` | `0xf8a22110` | HDMI PHY：`phy_tmds_cken[0]`、`hdmitx_phy_srst_req[4]`、`phy_tmds_srst_req[5]`、`tmds_clk_div[8:6]` |

> `hi3798mv200-clock.h` 的 DT clock ID 就是 CRG 偏移：`PERI_CRG10_HPLL_1=0x28`、`PERI_CRG11_HPLL_2=0x2c`、
> `PERI_CRG54_VDP=0xd8`、`PERI_CRG67_HDMITX_CTRL=0x10c`、`PERI_CRG68_HDMITX_PHY=0x110`。
> **`PERI_CRG211` 没有出现在该 4.4 DT 头里**（列表到 0x390 但不含 0x34c），mainline 若走 clk 框架需自行补 ID。

### 2.2 复位/释复位顺序

厂商顺序来自 `VDP_CloseClkResetModule()`（`vdp_software_selfdefine.c:520`）和
`VDP_OpenClkAndInitCrgConfig()`（同文件 `:218`）：

**断言复位（冷启动可跳过，热复位/重配时使用）：**

1. `PERI_CRG54.vou_srst_req = 1`。
2. 轮询 `VDPVERSION1/V2`（`0xf8cc0020/0x24`）直到两者都读到 0（最长约 80 ms；厂商每 2 ms 一次、40 次超时）。
3. 清 `PERI_CRG54` 的 `vdac_ch0_cken/vo_sdate_cken/vo_sd_cken/vo_bus_cken/vdp_cfg_cken`。
4. 清 `PERI_CRG211` 的 `vdp_ini_cksel0/1`、`vdp_hd_clk_div0/1`、`vdp_hd_cken`、`vdp_v0/v1/g0/g1/g3_cken`、
   `vdp_wbc_*`、`vdp_sd_cken`、`vdp_v3_cken`、`vdp_g4_cken`、`vo_bp_cken`。
5. `PERI_CRG211.vdp_srst_req = 1`。

**释复位（按厂商顺序）：**

1. `PERI_CRG211.vdp_srst_req = 0`（`VDP_OpenClkAndInitCrgConfig` 第一步）。
2. 写 `PERI_CRG54`：开 `vo_bus_cken/vo_sd_cken/vo_sdate_cken/vdp_cfg_cken`，设 `vo_hd_clk_sel=1`、
   `hdmi_clk_sel=1`、`vdp_clk_sel=0`、`vo_sd_hdmi_clk_sel=0`、`vo_hd_hdmi_clk_sel=0`、
   `vo_sd_clk_div=2`、`vo_hd_clk_div=0`（1080p60）。
3. 写 `PERI_CRG211`：开全部 VDP 模块时钟，`vdp_hd_clk_div0/1=1`、`vdp_ini_cksel0/1=1`、
   `vdp_clk_div=1`、`vdp_srst_req=0`。
   > 注意：这只是厂商 `VDP_OpenClkAndInitCrgConfig` 的临时值（=QUARTER 档）。模式设置阶段
   > `ConfigVdpWorkClk()` 会覆盖成最终值：HD=`ALL`（`vdp_ini_cksel0=0, vdp_hd_clk_div0=1`）、
   > SD=`HALF`（`vdp_ini_cksel1=1, vdp_hd_clk_div1=0`）。本文 Stage 0 直接写最终值。
4. 写 `PERI_CRG54.vou_srst_req = 0`。
5. 轮询 `VDPVERSION1/V2` 非 0（MV300 实测 `0x8380000b` / `0x03000177`）。

> 厂商“先清 srst 再开时钟”的顺序看起来反直觉，但这是 `VDP_OpenClkAndInitCrgConfig` 的原始顺序；
> 若按常规“先时钟后复位”改动，需实测确认。

### 2.3 1080p60 的时钟树

| 节点 | 设置 | 依据 |
|---|---|---|
| HPLL | `PLL10=0x11800000`、`PLL11=0x00001031`；4K60 行注释为 594.000 MHz，1080p60 复用同一 HPLL | `hal_specific_config.c:477`（MV300 表）、`:822`（4K60） |
| PLL 源选择 | `PERI_CRG54.vo_hd_clk_sel=1`（HD0/HPLL）；`hdmi_clk_sel=1`（HD 通道） | `SelectChannelPllSource()`、`VDP_DISP_SetHdmiClk()` |
| VDP 内核时钟 | `PERI_CRG211.vdp_clk_div=1`（1080p；4K 为 0） | `ConfigExternalTopPLLDivider()`、`DISP_TimingFixSpreadSpectrum()` |
| VDP 内部工作时钟 | `vdp_ini_cksel0=0`、`vdp_hd_clk_div0=1`（HD 全速档，`ConfigVdpWorkClk` 的最终覆盖值） | `hal_specific_config.c:1531` |
| DHD 像素时钟 | `PERI_CRG54.vo_hd_clk_div=0`（厂商 1080p 值；4K 为 3） | `ConfigInternalTopPLLDivider()` |
| HDMI/VDP 时钟比 | `vo_hd_hdmi_clk_sel=0`（1:1） | `ConfigVdpAndHdmiPLLDivider()` |

**【推断】** 由“594 MHz HPLL + `vdp_clk_div=1`(/2) + `vo_hd_clk_div=0`(/2)”得到 148.5 MHz。
`vo_hd_clk_div` 的 2 bit 编码（0=/2、3=/1）是反推的，**需实测确认**。

> ⚠️ **两张格式表**：`hal_specific_config.c` 第 18 行 `#if (!defined CHIP_TYPE_hi3798mv300) ...` 分出两张表。
> MV300 走 **第二张**（从第 470 行 `#else` 开始）：1080p60 的 PLL 是 `0x11800000/0x00001031`。
> 第一张表（第 27/34 行）的 `0x12000000/0x0001063` **不是 MV300 的值**，不要混用（两张表的行场参数相同）。
> 本仓库板级配置 `configs/hi3798mv300/hi3798mv3dmw_hi3798mv300_cfg.mak:26` 为 `CFG_HI_CHIP_TYPE=hi3798mv300`，
> `base.mak:348/424` 会加 `-DCHIP_TYPE_hi3798mv300`，因此确定走第二张表。
> 这同时意味着 [hdmi-minimal-init.md](hdmi-minimal-init.md) 里引用的 HPLL `0x12000000/0x00001063` 对 MV300 不适用，
> 需要以 `0x11800000/0x00001031` 为准（建议以板级实测像素时钟做最终裁决）。

---

## 3. 1080p60 时序参数

### 3.1 参数与编码

来自 `vdp_hal_chn.c:507` 的 `VDP_DISP_DIGFMT_1080P60` 分支，并与 `hal_specific_config.c:477`
的 MV300 格式表交叉核对（两处完全一致）：

| 参数 | 值 | 寄存器字段 | 写入值（字段） | 说明 |
|---|---|---|---|---|
| Hact | 1920 | `DHD0_HSYNC1.hact[15:0]` | 1919 | 有效像素 |
| Hbb | 192 | `DHD0_HSYNC1.hbb[31:16]` | 191 | **含同步**的后沿：44+148 |
| Hfb | 88 | `DHD0_HSYNC2.hfb[15:0]` | 87 | 前沿 |
| Hmid | 0 | `DHD0_HSYNC2.hmid[31:16]` | 0 | 厂商 `(x==0)?0:x-1` |
| Hpw | 44 | `DHD0_PWR.hpw[15:0]` | 43 | 同步宽 |
| Vact | 1080 | `DHD0_VSYNC.vact[11:0]` | 1079 | 有效行 |
| Vbb | 41 | `DHD0_VSYNC.vbb[21:12]` | 40 | **含同步**的后沿：5+36 |
| Vfb | 4 | `DHD0_VSYNC.vfb[31:22]` | 3 | 前沿 |
| Vpw | 5 | `DHD0_PWR.vpw[23:16]` | 4 | 同步宽 |
| Htotal | 2200 | - | - | 1920+88+192 |
| Vtotal | 1125 | - | - | 1080+4+41 |
| PixClk | 148.5 MHz | - | - | 2200*1125*60 |

**可直接写的整字值（复位后其余位为 0 时）：**

| 寄存器 | 值 | 计算 |
|---|---|---|
| `DHD0_HSYNC1` | `0x00BF077F` | `1919 | (191<<16)` |
| `DHD0_HSYNC2` | `0x00000057` | `87 | (0<<16)` |
| `DHD0_VSYNC` | `0x00C28437` | `1079 | (40<<12) | (3<<22)` |
| `DHD0_PWR` | `0x0004002B` | `43 | (4<<16)` |
| `DHD0_VPLUS` | `0x00000000`（推荐） | 逐行模式无效；见下 |

### 3.2 两个易错点

1. **`Hbb`/`Vbb` 是“从同步前沿算起的后沿总长”，不是纯 back porch。**
   192 = Hpw 44 + Hbp 148；41 = Vpw 5 + Vbp 36。若按纯 porch 填（148/36），总行/场数会少 44/5，
   表现为行频/场频偏高、电视不锁。
2. **`VPLUS` 在逐行模式被厂商代码“下溢”写入。**
   `VDP_DISP_OpenIntf()` 对 `u32Bvact/Bvbb/Bvfb`（均为 0）做 `-1` 再塞进 12/10 bit 字段，得到
   `0xFFCFFFFF`。逐行模式该寄存器无效，写 0 更安全；如果照抄厂商值也不影响（需实测确认）。

---

## 4. 最小初始化序列

链路固定为：**G0 → MIXG0 → GP0 → CBM_MIX1 → DHD0 → VO_MUX → HDMI**。
所有多字段寄存器建议 **读-改-写（RMW）**；下表“整字值”按复位后其余字段为 0 计算。

### Stage 0：复位释放 + 时钟（5 次写）

| # | 寄存器 | 值 | 说明 |
|---|---|---|---|
| S0-1 | `PERI_CRG211` | `vdp_srst_req=0`，其余保持 | 释放 VDP 复位 |
| S0-2 | `PERI_CRG_PLL10` | `0x11800000` | HPLL ctrl0（MV300 表） |
| S0-3 | `PERI_CRG_PLL11` | `0x00001031` | HPLL ctrl1 |
| S0-4 | `PERI_CRG54` | 建议整字 `0x8201800D`，或 RMW 设：`vo_bus_cken=1, vo_sd_cken=1, vo_sdate_cken=1, vo_sd_clk_div=2, vo_hd_clk_sel=1, vo_hd_clk_div=0, hdmi_clk_sel=1, vo_sd_hdmi_clk_sel=0, vdp_clk_sel=0, vo_hd_hdmi_clk_sel=0, vdp_cfg_cken=1, vou_srst_req=0` | VDP/HDMI 时钟门控与分频 |
| S0-5 | `PERI_CRG211` | 建议整字 `0x01307FCF`，或 RMW 设：`vo_bp/vdp_g4/vdp_v3/vdp_sd/vdp_wbc_vp/gp/hd/vdp_g3/g1/g0/v1/v0/hd_cken=1, vdp_hd_clk_div0=1, vdp_ini_cksel0=0`（HD=ALL）、`vdp_hd_clk_div1=0, vdp_ini_cksel1=1`（SD=HALF）、`vdp_clk_div=1`、`vdp_srst_req=0` | VDP 模块时钟；1080p 用 297MHz 内核时钟（HPLL/2），DHD 再 /2 得 148.5MHz |

然后读 `0xf8cc0020/0x24`，应得到非 0（实测 `0x8380000b/0x03000177`）。
**若为 0，后面所有写都不会生效。**

### Stage 1：VDP 全局默认（8 次写）

| # | 寄存器（偏移） | 值 | 说明/来源 |
|---|---|---|---|
| S1-1 | `SMMU_SCR` (`0xf000`) | `0x00000001`（`glb_bypass=1`；可再加 `ptw_pf=3` → `0x00030001`） | 关闭全局 SMMU，层地址用物理地址 |
| S1-2 | `VOCTRL` (`0x0000`) | `0x03000000`（`twochn_en=1, twochn_mode=1`） | 厂商默认双通道；可先置 0 试单通道，见 §7 |
| S1-3 | `VOAXICTRL` (`0x0030`) | `0x83FF83FF` | m0/m1: rd r0/r1=0xF、wr=0x3、multi-id=1 |
| S1-4 | `VOAXICTRL1` (`0x0034`) | `0x03FF03FF` | m2/m3: rd=0xF、wr=0x3 |
| S1-5 | `VOMIDORDER` (`0x0028`) | `0x00000008`（`mid_enable=1`） | AXI MID |
| S1-6 | `DHD0_CTRL` (`0xc000`) | `0x0000C011` | `regup=1, iop=1, hdmi_mode=1, twochn_debug=1, intf_en=0` |
| S1-7 | `DHD0_SYNC_INV` (`0xc020`) | `0x00002000` | 厂商默认；HDMI 相关位均为 0（bit13 是 DATE，不影响 HDMI） |
| S1-8 | `DHD0_DATA_SEL` (`0xc02c`) | `0x00000000` | 输出数据源默认 |

> `twochn_debug` 不是随便设的：厂商断言要求 `twochn_mode=1 && hdmi420_en=0` 时 `twochn_debug=1`
> （`vdp_assert.c:648`）。若 Stage 1 关掉双通道（VOCTRL=0），这里应改成 `0x00004011`。

### Stage 2：GFX 图层 G0（14 次写）

| # | 寄存器（偏移） | 值 / 公式 | 说明 |
|---|---|---|---|
| S2-1 | `G0_CTRL` (`0x7000`) | RGB888：`0x80000050`；ARGB8888：`0x80000068` | `ifmt=0x50/0x68`，`surface_en=1` |
| S2-2 | `G0_ADDR` (`0x7010`) | `FB_PHYS` | SMMU 旁路时=物理地址 |
| S2-3 | `G0_STRIDE` (`0x701c`) | `FB_STRIDE_BYTES / 16`：RGB888 `360 (0x168)`，ARGB8888 `480 (0x1E0)` | **单位 16 字节**，见 §5 |
| S2-4 | `G0_IRESO` (`0x7020`) | `0x0043777F` | `1919 | (1079<<12)` |
| S2-5 | `G0_SFPOS` (`0x7024`) | `0x00000000` | 源起始 X |
| S2-6 | `G0_VFPOS` (`0x7088`) | `0x00000000` | 视频起点 |
| S2-7 | `G0_VLPOS` (`0x708c`) | `0x0043777F` | 视频终点 |
| S2-8 | `G0_DFPOS` (`0x7080`) | `0x00000000` | 显示起点，须与 VFPOS 相同 |
| S2-9 | `G0_DLPOS` (`0x7084`) | `0x0043777F` | 显示终点，须与 VLPOS 相同 |
| S2-10 | `G0_BK` (`0x7090`) | `0x00000000` | 图层背景（YUV 0/0/0） |
| S2-11 | `G0_ALPHA` (`0x7094`) | `0x000000FF` | 背景 alpha；全屏时无影响 |
| S2-12 | `G0_CBMPARA` (`0x7030`) | RGB888：`0x000000FF`；ARGB8888：`0x000010FF` | `galpha=0xFF`；ARGB 需 `palpha_en=1` |
| S2-13 | `G0_SMMU_BYPASS0` (`0x7028`) | `0x00000003` | `bypass_2d=1, r_bypass_3d=1` |
| S2-14 | `G0_UPD` (`0x7004`) | `0x00000001` | 触发 G0 寄存器生效 |

`vdp_assert.c` 要求 G0 的 `VFPOS==DFPOS`、`VLPOS==DLPOS`（`vdp_assert.c:2312`），全屏时自然满足。

### Stage 3：GP0 图形处理（9 次写；走 CSC 再加 9 次）

G0 必须经过 GP0 才能进 CBM。GP0 的 `mux1_sel/mux2_sel/aout_sel/bout_sel` 决定 CSC/ZME 的先后或直通
（`vdp_hal_gfx.c:808`，`VDP_GP_ORDER_*`）。

| # | 寄存器（偏移） | 直通（ORDER_NULL） | 经 CSC（ORDER_CSC） | 说明 |
|---|---|---|---|---|
| S3-1 | `GP0_CTRL` (`0x8000`) | `0x00001023` | `0x00001230` | `mux1=3,mux2=2,aout=0,bout=1` / `mux1=0,mux2=3,aout=2,bout=1` |
| S3-2 | `GP0_IRESO` (`0x800c`) | `0x0043777F` | 同左 | 必须为偶数且 ≤1920x1080 |
| S3-3 | `GP0_ORESO` (`0x8008`) | `0x0043777F` | 同左 | 必须为偶数 |
| S3-4 | `GP0_VFPOS` (`0x8108`) | `0x00000000` | 同左 | |
| S3-5 | `GP0_VLPOS` (`0x810c`) | `0x0043777F` | 同左 | |
| S3-6 | `GP0_DFPOS` (`0x8100`) | `0x00000000` | 同左 | |
| S3-7 | `GP0_DLPOS` (`0x8104`) | `0x0043777F` | 同左 | |
| S3-8 | `GP0_ALPHA` (`0x8114`) | `0x00000000` | 同左 | GP 背景 alpha |
| S3-9 | `GP0_UPD` (`0x8004`) | `0x00000001` | 同左 | 生效 |
| S3-10 | `GP0_CSC_IDC` (`0x8120`) | - | `0x00400000` | `csc_en=1`，DC 0 |
| S3-11 | `GP0_CSC_ODC` (`0x8124`) | - | `0x00100040` | out_dc0=64，out_dc1=512 |
| S3-12 | `GP0_CSC_IODC` (`0x8128`) | - | `0x00100000` | in_dc2=0，out_dc2=512 |
| S3-13 | `GP0_CSC_P0` (`0x812c`) | - | `0x02DC00DA` | 0.213/0.715 |
| S3-14 | `GP0_CSC_P1` (`0x8130`) | - | `0x7F890049` | 0.072/-0.117 |
| S3-15 | `GP0_CSC_P2` (`0x8134`) | - | `0x020B7E6D` | -0.394/0.511 |
| S3-16 | `GP0_CSC_P3` (`0x8138`) | - | `0x7E25020B` | 0.511/-0.464 |
| S3-17 | `GP0_CSC_P4` (`0x813c`) | - | `0x00007FD0` | -0.047 |
| S3-18 | `GP0_UPD` (`0x8004`) | - | `0x00000001` | CSC 写完再触发一次 |

CSC 系数来自 `VDP_GP_SetCscMode(GP0, VDP_CSC_RGB2YUV_709)`（`vdp_hal_gfx.c:1175`），
10-bit 定点、15-bit 二补码。**走哪条路径取决于 DHD/HDMI 侧色彩域，见 §7。**

### Stage 4：混合器路由（6 次写）

| # | 寄存器（偏移） | 值 | 说明 |
|---|---|---|---|
| S4-1 | `MIXV0_BKG` (`0xb000`) | `0x00000000` | 视频混音背景（不用视频也清零） |
| S4-2 | `MIXG0_BKG` (`0xb200`) | `0x00000000` | 图形混音背景 |
| S4-3 | `MIXG0_BKALPHA` (`0xb204`) | `0x00000000` | 背景 alpha=0（G0 全屏覆盖） |
| S4-4 | `MIXG0_MIX` (`0xb208`) | `0x00000001` | `prio0 = GFX0+1` |
| S4-5 | `CBM_BKG1` (`0xb400`) | `0x00000000` | DHD0 前级背景 |
| S4-6 | `CBM_MIX1` (`0xb408`) | 仅 GFX：`0x00000020`；照厂商（VP0 垫底）：`0x00000021` | `prio1=GP0(2)`；`prio0=0/VP0(1)` |

> 厂商 `VDP_DRIVER_Initial` 默认 `CBM_MIX1 = prio0:VP0(1), prio1:GP0(2)`；GFX-only 时建议 `prio0=0`，
> 避免未初始化的 VP0 输出干扰。**【需实测确认】**
> `MIXG0_MIX` 的优先级字段是 `layer_id+1`，`CBM_MIX1` 是 `layer_id` 原值（两套编码不同，别抄混）。

### Stage 5：DHD0 时序（7 次写）

| # | 寄存器（偏移） | 值 | 说明 |
|---|---|---|---|
| S5-1 | `DHD0_CTRL` (`0xc000`) | 保持 `iop=1, hdmi_mode=1, twochn_debug=1, intf_en=0` | 可用 `0x0000C011` |
| S5-2 | `DHD0_HSYNC1` (`0xc008`) | `0x00BF077F` | Hact/Hbb |
| S5-3 | `DHD0_HSYNC2` (`0xc00c`) | `0x00000057` | Hfb/Hmid |
| S5-4 | `DHD0_VSYNC` (`0xc004`) | `0x00C28437` | Vact/Vbb/Vfb |
| S5-5 | `DHD0_VPLUS` (`0xc010`) | `0x00000000` | 逐行无效；厂商因下溢写 `0xFFCFFFFF` |
| S5-6 | `DHD0_PWR` (`0xc014`) | `0x0004002B` | Hpw/Vpw |
| S5-7 | `DHD0_DITHER0_CTRL` (`0xc060`) | `0x00000000`（可选） | 关 dither；需要 8bit 平滑时再开 |

### Stage 6：输出选择 + 使能（2 次写）

| # | 寄存器（偏移） | 值 | 说明 |
|---|---|---|---|
| S6-1 | `VO_MUX` (`0x0100`) | `0x00000000` | `hdmi_sel=0`（DHD0 → HDMI） |
| S6-2 | `DHD0_CTRL` (`0xc000`) | `0x8000C011` | 置 `intf_en=1`（并保持 `regup=1`） |

### Stage 7：HDMI TX（VDP 之外，必须）

VDP 只负责把 1080p60 + 像素数据送到 HDMI 接口；TMDS 输出、AVI infoframe、HPD/EDID、PHY 上电
必须由 HDMI 2.0 驱动完成，否则示波器上也没有 TMDS。最小依赖：

1. `PERI_CRG67`：`hdmitx_ctrl_srst_req=0`、`hdmitx_ctrl_os_cken=1`；MV300 还要
   `hdmitx_pxl_cken=1`（`bits_mv300` bit16）。
2. `PERI_CRG68`：`hdmitx_phy_srst_req=0`、`phy_tmds_srst_req=0`、`phy_tmds_cken=1`、
   `tmds_clk_div` 按 1080p 设置。
3. HDMI 输入格式必须与 VDP 输出色彩域一致（见 §7）。
4. 具体寄存器序列见 [hdmi-minimal-init.md](hdmi-minimal-init.md)。

### 汇总：最小写次数

| Stage | 内容 | 写次数 |
|---|---|---|
| S0 | CRG 复位/时钟/PLL | 5 |
| S1 | VDP 全局（SMMU/双通道/AXI/DHD 默认） | 8 |
| S2 | G0 图层 | 14 |
| S3 | GP0（不含 CSC） | 9 |
| S4 | 混合器 | 6 |
| S5 | DHD0 时序 | 7 |
| S6 | 输出选择 + intf_en | 2 |
| **合计** | 不含 GP0 CSC | **约 51 次** |
| S3' | 追加 GP0 CSC | +9 → 约 60 次 |

其中 **S0、S1-1、S2、S4、S5、S6 是硬性必需**；S1-3..5（AXI 调优）、S1-2（双通道）、
S2-10..12（背景/alpha）、S5-7（dither）可在第一版先省略或后补。

---

## 5. Framebuffer 地址 / stride / 格式

### 5.1 格式与字段

| 格式 | `G0_CTRL.ifmt` | bpp | stride（字节） | `G0_STRIDE` 写入值 | 1080p 帧大小 |
|---|---|---|---|---|---|
| RGB888 | `0x50` | 24 | 1920*3 = 5760 (`0x1680`) | `5760/16 = 360 (0x168)` | 6,220,800 B |
| ARGB8888 | `0x68` | 32 | 1920*4 = 7680 (`0x1E00`) | `7680/16 = 480 (0x1E0)` | 8,294,400 B |

### 5.2 写入顺序

1. `G0_ADDR = FB 物理地址`（SMMU 全局旁路时；地址至少 16B 对齐，建议 4 KiB 对齐）。
2. `G0_STRIDE = stride_bytes / 16`。
3. `G0_IRESO = (w-1) | ((h-1)<<12)`；`G0_CTRL.ifmt` + `surface_en=1`。
4. 写完 `G0_UPD.regup=1`，硬件在下一个帧边界生效。

### 5.3 关键坑：stride 单位是 16 字节

- `hifb` 的 MV300 HAL（`hifb/adp/hal_v1_0/drv_hifb_hal.c:632`）明确做：
  `G0_STRIDE.surface_stride = u32Stride / STRIDE_ALIGN`（`STRIDE_ALIGN=16`），读回时 `*16`。
- 但 `vdp_hal_gfx.c:265` 的 `VDP_GFX_SetLayerAddr(u32LAddr, u32Stride)` 是**原样写入**，
  不做 `/16`。因此调用者必须自己先除 16，否则图像会按 16 倍行距撕裂/花屏。
- `vdp_assert.c` 中 `G0_STRIDE <= 0x400` 的旧约束也只有在 SMMU 开启时才成立，
  1920*4/16=480 (`0x1E0`) 恰好满足。

### 5.4 像素字节序

`VDP_GFX_IFMT_RGB_888=0x50`、`ARGB_8888=0x68` 只说明打包方式，**没有说明内存里是 R,G,B 还是 B,G,R**
（不同 SDK/面板常见 BGR 打包）。第一版用纯红/纯绿/纯蓝三帧验证；若红蓝互换，在软件侧调整打包，
不要先去怀疑 CSC。**【需实测确认】**

---

## 6. 验证与调试

| 检查点 | 方法 | 期望 |
|---|---|---|
| 复位释放 | 读 `0xf8cc0020/0x24` | `0x8380000b / 0x03000177` |
| 时钟 | 读 `PERI_CRG54/211` 回读 | 与写入一致，`vou_srst_req=0`、`vdp_srst_req=0` |
| 时序在跑 | 读 `DHD0_STATE`（`0xc0f0`）`vcnt[15:3]` | 在 0..1124 循环 |
| 中断状态 | 读 `DHD0_STATE.count_int[23:16]` | 每场递增（即使不开中断） |
| 图层使能 | 读 `G0_CTRL`、`G0_UPD` | `surface_en=1`、`regup` 已自清 |
| SMMU 无 fault | 读 `SMMU_ERR_RDADDR`（`0xf304`）等 | 不为异常地址 |
| 输出黑屏 | 先看 `DHD0_STATE.vcnt` 是否在动，再看 `intf_en`、`VO_MUX.hdmi_sel` | 逐级缩小 |

常见现象与首查项：

| 现象 | 优先检查 |
|---|---|
| 完全无信号 | CRG 复位/时钟、`DHD0_CTRL.intf_en`、HDMI TX 是否初始化 |
| 有信号但黑屏 | `G0_ADDR`/`G0_STRIDE`、`surface_en`、`CBM_MIX1` 是否选到 GP0 |
| 花屏/斜条纹 | stride 是否忘了 `/16`、地址是否物理地址（SMMU 旁路） |
| 颜色错/红蓝反 | 像素打包、GP0 CSC 是否该开、HDMI 输入色彩域 |
| 场频不对/电视不锁 | Hbb/Vbb 是否误填成纯 porch（应为含 sync 的总和） |

---

## 7. 不确定点（需实测确认）

1. **`DHD0_CTRL.hdmi_mode` 的语义（最大风险）。**
   厂商对 1080p 设 1（`PF_DispIntfHdmi0Reset`），HDR 代码注释却写“1: no swap”，
   而 HDMI 驱动默认输入色彩域是 YCbCr444。三种可能必须上板排除：
   - A：`hdmi_mode=1` + GP0 不转（直通）+ HDMI 输入 RGB444；
   - B：`hdmi_mode=1` + GP0 CSC RGB→YUV709 + HDMI 输入 YCbCr444（厂商 hifb/PQ 的常态）；
   - C：`hdmi_mode=0` + GP0 CSC + HDMI 输入 YCbCr444。
   建议先按 B 点屏，若颜色明显发灰/发绿再试 A/C。
2. **`vo_hd_clk_div` 的 2-bit 编码。** 从 594 MHz HPLL 反推 0=/2、3=/1，源码无字段说明；
   需用示波器/频率计核对像素时钟。
3. **双通道模式是否必需。** 厂商无条件置 `twochn_en=1/twochn_mode=1`，并依赖 `twochn_debug=1`
   的断言。若单通道置 0 后能出图，可简化。
4. **`CBM_MIX1.prio0` 是否必须保留 VP0。** GFX-only 时建议 0；若黑屏可改回厂商 `0x21`。
5. **GP0 CSC 系数/符号位。** 本文按 `VDP_GP_SetCscMode` 的 10-bit 定点、15-bit 二补码计算；
   `csc_sign_mode`（`GP0_CSC_ODC` bit22）厂商未显式设置，若颜色异常需核对符号处理。
6. **像素字节序**（RGB vs BGR）与 ARGB 的 alpha 位置（ARGB/BGRA）。
7. **`G0_STRIDE` 单位 16B。** 证据来自 hifb HAL；`vdp_hal_gfx.c` 原样写，存在两种调用约定，
   必须以实际出图验证。
8. **VPLUS 下溢值。** 逐行无效，写 0 还是照抄 `0xFFCFFFFF` 未验证。
9. **HDMI 侧 CRG67 的 MV300 专属位。** `bits_mv300` 的 `hdmitx_pxl_cken[16]` 与 mv200 布局不同，
   若用公共 `bits` 会漏开像素时钟。
10. **DHD 输出位宽/dither。** 1080p 8bit 输出默认走 10→8 截断还是 dither 关闭，未确认；
    出现明显 banding 时再开 `DHD0_DITHER0_CTRL`。

---

## 8. 源码索引

| 内容 | 文件:行 |
|---|---|
| VDP 基址 | `hal/98mv200/inc/vdp_ip_define.h:118` |
| 子模块 offset | `hal/98mv200/inc/vdp_ip_define.h:95-108` |
| 寄存器结构/偏移 | `hal/98mv200/inc/vdp_reg.h`（`S_VDP_REGS_TYPE`，DHD0 见 37636，G0 见 37133，GP0 见 37189） |
| 复位/时钟初始化 | `hal/98mv200/hal_specific/vdp_software_selfdefine.c:218`（`VDP_OpenClkAndInitCrgConfig`）、`:519`（`VDP_CloseClkResetModule`） |
| 全局默认 | `hal/98mv200/hal_specific/vdp_software_selfdefine.c:399`（`VDP_DRIVER_Initial`）、`:319`（`VDP_DHD_DEFAULT`） |
| DHD 复位 | `hal/98mv200/hal_specific/vdp_software_selfdefine.c:586`（`VDP_DHD_Reset`） |
| 1080p60 时序 | `hal/98mv200/vdp_hal_chn.c:507`（`VDP_DISP_DIGFMT_1080P60`）、`:263`（`VDP_DISP_OpenIntf`） |
| MV300 格式/PLL 表 | `hal/98mv200/hal_specific/hal_specific_config.c:470`（表开始）、`:477`（1080p60） |
| 时钟分频 | `hal/98mv200/hal_specific/hal_specific_config.c:1306/1361/1465/1531/1658` |
| HPLL 写入 | `hal/98mv200/hal_specific/hal_specific_config.c:1505` |
| CRG 开关时钟 | `hal/98mv200/hal_specific/hal_specific_config.c:1810`（`Chip_Specific_DISP_OpenClock`） |
| GFX 层 HAL | `hal/98mv200/vdp_hal_gfx.c:23/163/265/282` |
| GP0 顺序/CSC | `hal/98mv200/vdp_hal_gfx.c:808`（`VDP_GP_SetIpOrder`）、`:1175`（`VDP_GP_SetCscMode`） |
| CBM 混合 | `hal/98mv200/vdp_hal_comm.c:670`（`VDP_CBM_SetMixerBkg`）、`:845`（`VDP_CBM_SetMixerPrio`） |
| SMMU 旁路 | `hal/common/drv_vdp_smmu.c:266`（`VDP_Hal_SetSmmuEnable`）、`hal/98mv200/vdp_hal_mmu.c:243` |
| hifb stride/图层 | `source/msp/drv/hifb/adp/hal_v1_0/drv_hifb_hal.c:632`（stride/16）、`:1001`（矩形）、`:1140`（背景 alpha） |
| DHD 初始化调用链 | `hal/common/drv_disp_hal.c:303`（`PF_ResetVdpHardware`）、`:447`（`PF_ResetChn`）、`:3752`（`DISP_HAL_Init`） |
| HDMI 输入色彩域 | `source/msp/drv/hdmi/hdmi_2_0/hal/ctrl/hisiv100/hdmi_hal_intf.c:717`（`HAL_HDMI_DispFmtGet`） |
