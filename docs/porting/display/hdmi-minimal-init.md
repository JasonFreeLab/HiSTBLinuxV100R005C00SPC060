# Hi3798MV300 HDMI 2.0 TX 最小 1080p60 初始化序列

本文从厂商 4.4 内核源码提取海思自研 HDMI 2.0 TX（`0xf8ce0000`）在 **1920x1080p60、8bit、RGB（或 YCbCr444）、无 HDCP、无 CEC、无音频** 条件下的最小初始化序列，供 mainline 移植时逐段对照。

- 参考源码：`source/msp/drv/hdmi/hdmi_2_0/`
- 参考 PHY 地址：`source/msp/drv/hdmi/hdmi_1_4/drv_reg_proc.h`
- 厂商 DTS 中断：HDMI `88`，HDMI CEC `147`
- 本文只描述寄存器/时钟/序列，不修改内核，不做板卡操作。文中标 **【需实测确认】** 的条目表示仅凭源码无法完全确定，必须上板用只读方式核对。

---

## 0. 结论速览

1. **PHY 是 MMIO，不是 I2C。** 2.0 HAL 用 `ioremap_nocache()` 映射 PHY，再用 `HDMI_RegRead/Write()` 读写；DDC/EDID 才是片内 I2C master（且与 PHY 无关）。
2. **地址需要纠偏：** 任务给出的 `0xf8ce1800` 在 2.0 源码里是 **HDMITX 数字子块**（包/编码器/AFIFO），不是模拟 PHY。2.0 HAL 的 APHY/DPHY 基址是 **`0xf8d30000`**（`product/hisiv100/hdmi_product_define.h:89`）。`0xf8ce1800` 是 1.4 旧 IP 的 `HDMI_TX_PHY_ADDR`，不能把 1.4 的 PHY 序列套到 2.0 IP 上。**【需实测确认】**
3. 1080p60 8bit 的 TMDS 时钟为 148.5 MHz，低于 340 MHz，走 **HDMI 1.4 TMDS 模式**：不启用 HDMI 2.0 编码、不启用 SCDC/scramble。
4. 像素时钟链：VDP/HPLL → `clk_vid_pxl` → CRG 门控/分频 → PHY PLL。1080p60 厂商表项 HPLL 为 `0x12000000/0x00001063`；PHY 参数为 `pixDiv=4`、`sscBypDiv=10`、`tmdsNxDiv=2`、`loopDiv=25`、`1:10`、2X 插值。
5. 最小序列分 8 段：**VDP 前置 → CRG 门控/复位 → PHY 上电/分频/模拟参数 → 视频路径 → TMDS/包/AVI → 音频关闭 → 等 TMDS 稳定 → PHY 输出使能**。
6. 第一版可以 **不读 EDID**，但必须处理 HPD；否则可能对着空气输出，或电视端显示无信号。
7. 最大风险：**PHY 基址/序列错误**、**VDP 没有真正输出 1080p60 时序/像素时钟**、**跳过 EDID 导致 sink 不支持固定模式**、**PHY 模拟参数依赖板级 SI**。

---

## 1. 地址空间与访问方式

### 1.1 基址与子块

| 地址 | 含义 | 源码依据 |
|---|---|---|
| `0xf8ce0000` | HDMI TX 总基址 / control 子块 | `product/hisiv100/hdmi_platform.h` `HDMI_CTRL_BASE_ADDR` |
| `0xf8ce0000 + 0x0000` | control（复位、中断、DDC PWD） | `HDMI_TX_BASE_ADDR_CTRL 0x0000` |
| `0xf8ce0000 + 0x0800` | video path（CSC/dither/polarity） | `HDMI_TX_BASE_ADDR_AIDEO 0x0800` |
| `0xf8ce0000 + 0x1000` | audio path | `HDMI_TX_BASE_ADDR_AUDIO 0x1000` |
| `0xf8ce0000 + 0x1800` | **HDMITX 数字子块**（包 FIFO、AVI、编码器） | `HDMI_TX_BASE_ADDR_HDMITX 0x1800` |
| `0xf8ce0000 + 0x2000` | HDCP 1.x（本文跳过） | `HDMI_TX_BASE_ADDR_HDCP1X 0x2000` |
| `0xf8ce0000 + 0x4000` | AON（HPD、DDC master、AON 中断） | `HDMI_TX_BASE_ADDR_AON 0x4000` |
| `0xf8ce0000 + 0x4800` | CEC（本文跳过） | `HDMI_TX_BASE_ADDR_CEC 0x4800` |
| `0xf8d30000` | **HDMI APHY/DPHY**（模拟 PHY + TXPLL + SSC） | `product/hisiv100/hdmi_product_define.h:89` `BASE_ADDR_tx_dphy` |
| `0xf8a22000` | CRG（PLL/分频/门控/复位） | `product/hisiv100/regs/hdmi_reg_crg.c:22` `HDMI_ADDR_CRG` |
| `0xf8000044` | HDMI IO 复用配置（MV300） | `hdmi_product_define.c` `HDMI_ADDR_BASE_IO_CFG` |
| `0xf8000048` | `SC_CLKGATE_SRST_CTRL`（HDMI APB/OSC/CEC 门控与复位） | `hdmi_reg_crg.c:23` `HDMI_ADDR_CLKGATESRST` |

### 1.2 关于 “PHY 0xf8ce1800” 的核对

这是本文最重要的发现：

| 地址 | 实际含义 | 证据 |
|---|---|---|
| `0xf8ce1800` | HDMI 2.0 的 **HDMITX 数字子块**，第一个寄存器是 `TX_PACK_FIFO_CTRL`（偏移 `0x1800`） | `hdmi_reg_tx.h` 中 `U_TX_PACK_FIFO_CTRL,ADDR:1800`；`BASE_ADDR_tx_hdmi_reg = 0xf8ce0000 \| 0x1800` |
| `0xf8d30000` | **APHY/DPHY 模拟 PHY**，含 `HDMITX_INSSC_SET`、`APHY_TOP_PD`、`APHY_TXPLL_CTRL`、`FBSSC_*` | `hdmi_reg_dphy.c:32` `HDMI_IO_MAP(BASE_ADDR_tx_dphy, 4)` |
| `0xf8ce1800` | 1.4 旧驱动的 `HDMI_TX_PHY_ADDR`（SiliconImage 风格 PHY 寄存器窗口） | `hdmi_1_4/drv_reg_proc.h:29` |

**结论：** 写 2.0 PHY 时不要用 `0xf8ce1800`，用 `0xf8d30000`。如果板卡实测 `0xf8d30000` 读回全 0/全 F，再回头核对是否该板卡把 APHY 放在别的窗口；**不要直接照搬 1.4 的 `si_phy.c` 寄存器索引**。

只读核对方法（不改板卡）：

1. 读 `0xf8ce1800`，复位后应接近 `TX_PACK_FIFO_CTRL` 的 `0x00000004`。
2. 读 `0xf8d30000`，复位后应接近 `HDMITX_INSSC_SET` 的 `0xC0000000`。
3. 读 `0xf8ce4000`，应为 AON 的 `TX_HW_INFO`，可与 `0xf8ce4004` 版本寄存器交叉验证。
4. 若 `0xf8d30000` 不可访问，记录 fault 地址后再决定，不要盲写。

### 1.3 访问方式

```c
/* 2.0 HAL 的实际做法（MMIO） */
HDMI_IO_MAP(addr, len)   -> ioremap_nocache(addr, len)
HDMI_RegRead(p)          -> *(volatile u32 *)p
HDMI_RegWrite(p, v)      -> *(volatile u32 *)p = v
```

- control/video/audio/HDMITX/AON：`ioremap` 后按 32bit 读写。
- PHY：`BASE_ADDR_tx_dphy` 单独 `ioremap`，按 32bit 读写；**不是 I2C，也不是 SPI**。厂商 `HDMI_IO_MAP(BASE_ADDR_tx_dphy, 4)` 虽然只传 4 字节，但 `ioremap_nocache` 按页映射，后续访问到 `0xBC` 仍然有效；移植时建议显式映射 `0x1000`，不要依赖这个巧合。
- DDC/EDID：HDMI 内部的 I2C master（PWD 或 AON），不是 CPU 的 I2C 控制器；本文第一版不读 EDID，详见 §6。
- 所有寄存器都是 32bit 对齐；下文的偏移均以各子块基址为基准。

> 注意：`hdmi_reg_dphy.h` 里部分 `ADDR:` 注释是自动生成时留下的旧值。例如 `HDMITX_DPHY_RST` 注释写 `ADDR:C`，但结构体里 `INSSC_TUNE` 占 `0xC`，`DPHY_RST` 实际在 **`0x10`**。**以结构体偏移/代码为准**。**【需实测确认】**

---

## 2. 寄存器表

### 2.1 HDMI control 子块（`H = 0xf8ce0000`）

| 偏移 | 名称 | 复位值 | 用途 |
|---|---|---|---|
| `0x0010` | `TX_PWD_RST_CTRL` | `0x00000400` | TX 各子模块软复位；bit10 为 MCU 复位 |
| `0x010C` | `TXSYS_INTR_STATE` | - | TX 系统中断状态 |
| `0x0110` | `TXSYS_INTR_MASK` | - | TX 系统中断屏蔽 |
| `0x0124` | `TXHDMI_INTR_STATE` | - | HDMITX 中断状态 |
| `0x0128` | `TXHDMI_INTR_MASK` | - | HDMITX 中断屏蔽 |

`TX_PWD_RST_CTRL` 位定义（`hdmi_reg_ctrl.h`）：

| 位 | 名称 | 说明 |
|---|---|---|
| 0 | `tx_pwd_srst_req` | 整个 TX 电源域软复位（厂商在停止时脉冲） |
| 1 | `tx_sys_srst_req` | 系统 |
| 2 | `tx_vid_srst_req` | 视频 |
| 3 | `tx_hdmi_srst_req` | HDMI 包/FIFO |
| 4 | `tx_hdcp1x_srst_req` | HDCP1.x（跳过） |
| 5 | `tx_phy_srst_req` | PHY |
| 6 | `tx_aud_srst_req` | 音频 |
| 7 | `tx_acr_srst_req` | ACR |
| 8 | `tx_afifo_srst_req` | AFIFO |
| 9 | `tx_hdcp2x_srst_req` | HDCP2.x（跳过） |
| 10 | `tx_mcu_srst_req` | HDCP MCU；不用 HDCP 时保持 1 |

### 2.2 video path 子块（`H + 0x0800`）

| 偏移 | 名称 | 复位值 | 1080p60 用法 |
|---|---|---|---|
| `0x0800` | `TIMING_GEN_CTRL` | `0x00000000` | **保持 0**：时序由 VDP 提供，不用内部 timing generator |
| `0x0804` | `HSYNC_TIMING_CONFIG0` | `0x00638359` | 内部 timing gen 用，本文不写 |
| `0x0808` | `HSYNC_TIMING_CONFIG1` | `0x000202E0` | 同上 |
| `0x080C` | `HSYNC_TIMING_CONFIG2` | `0x00000000` | 同上 |
| `0x0810` | `VSYNC_TIMING_CONFIG0` | `0x0000620C` | 同上 |
| `0x0814` | `VSYNC_TIMING_CONFIG1` | `0x0000F1EF` | 同上 |
| `0x0818` | `VSYNC_TIMING_CONFIG2` | `0x00000000` | 同上 |
| `0x0830` | `VIDEO_PATH_CTRL` | `0x00000000` | `reg_video_blank_en=0`：不替换为黑场 |
| `0x0840` | `PATTERN_GEN_CTRL` | `0x00000000` | 测试图案关闭 |
| `0x0850` | `CBAR_PATTERN_A0` | `0x00000000` | 厂商在 CRG 初始化时写 0（TEE/REE mute sync） |
| `0x08EC` | `DITHER_CONFIG` | `0x00000001` | `dither_rnd_byp=1`：8bit 直通 |
| `0x0934` | `MULTI_CSC_CTRL` | `0x00000000` | CSC 关闭；`csc_mode` 按 RGB/YCbCr 和量化范围设置（见 §4.3） |
| `0x0980` | `VIDEO_DWSM_CTRL` | `0x00000008` | `dwsm_vert_byp=1`：不做 420 下采样 |
| `0x098C` | `DATA_ALIGN_CTRL` | `0x00000000` | 不做 420、不做像素分频、不做 YC mux |
| `0x09A8` | `VIDEO_DMUX_CTRL` | `0x00000088` | Y/Cb/Cr 通道映射 + H/V/DE 极性 |

`VIDEO_DMUX_CTRL` 关键位：

| 位 | 名称 | 1080p60 值 |
|---|---|---|
| 2:0 | `reg_vmux_y_sel` | `0`（Y） |
| 5:3 | `reg_vmux_cb_sel` | `1`（Cb） |
| 8:6 | `reg_vmux_cr_sel` | `2`（Cr） |
| 25 | `reg_inver_sync[0]`（V） | `0`（正极性） |
| 26 | `reg_inver_sync[1]`（H） | `0`（正极性） |
| 28 | `reg_inver_sync[3]`（DE） | `0`（正极性） |

> 若 VDP 实际输出负极性 H/V/DE，则要置对应 bit；1080p60 CEA 时序通常 H+/V+。**【需实测确认】**

`MULTI_CSC_CTRL` 关键位：

| 位 | 名称 | 说明 |
|---|---|---|
| 0 | `reg_csc_en` | 0：CSC 旁路 |
| 3 | `reg_csc_saturate_en` | 0 |
| 11:4 | `reg_csc_mode` | bit3=RGB out、bit7=RGB in、bit0-1=out colorimetry、bit4-5=in colorimetry、bit2=out quantization、bit6=in quantization |

### 2.3 audio path 子块（`H + 0x1000`）

| 偏移 | 名称 | 复位值 | 本文用法 |
|---|---|---|---|
| `0x1000` | `TX_AUDIO_CTRL` | `0x000E4001` | 写 `0`：`aud_in_en=0`、`i2s_en=0`、`spdif_en=0` |
| `0x1004` | `AUD_I2S_CTRL` | `0x00000B00` | 不写 |
| `0x100C` | `AUD_CHST_CFG0` | `0x00000000` | 不写 |
| `0x1040` | `AUD_ACR_CTRL` | `0x00000005` | 不写 |
| `0x1048` | `ACR_N_VAL_SW` | - | 不写 |
| `0x104C` | `ACR_CTS_VAL_SW` | - | 不写 |

### 2.4 HDMITX 数字子块（`H + 0x1800`）

| 偏移 | 名称 | 复位值 | 1080p60 用法 |
|---|---|---|---|
| `0x1800` | `TX_PACK_FIFO_CTRL` | `0x00000004` | `tmds_pack_mode=0`（24bit）、`fifo_auto_rst_en=1` |
| `0x1804` | `TX_PACK_FIFO_ST` | `0x00000000` | bit0 `pclk2tclk_stable`：输出使能前轮询 |
| `0x1808` | `PCLK_REFER_CNT` | `0x000003FF` | 保持默认 |
| `0x180C` | `TCLK_LOWER_THRESHOLD` | `0x000003F8` | 保持默认 |
| `0x1810` | `TCLK_UPPER_THRESHOLD` | `0x00000408` | 保持默认 |
| `0x1818` | `AVI_PKT_HEADER` | `0` | AVI 头 3 字节（type/version/length） |
| `0x181C` | `AVI_SUB_PKT0_L` | `0` | checksum + payload[0..2] |
| `0x1820` | `AVI_SUB_PKT0_H` | `0` | payload[3..5] |
| `0x1824` | `AVI_SUB_PKT1_L` | `0` | payload[6..9] |
| `0x1828` | `AVI_SUB_PKT1_H` | `0` | payload[10..12] |
| `0x182C` | `AVI_SUB_PKT2_L` | `0` | 其余补 0 |
| `0x1830` | `AVI_SUB_PKT2_H` | `0` | 其余补 0 |
| `0x1834` | `AVI_SUB_PKT3_L` | `0` | 其余补 0 |
| `0x1838` | `AVI_SUB_PKT3_H` | `0` | 其余补 0 |
| `0x19A4` | `CEA_AVI_CFG` | `0` | bit0 `cea_avi_en=1`、bit1 `cea_avi_rpt_en=1` |
| `0x19AC` | `CEA_AUD_CFG` | `0` | 保持 0：不发 Audio InfoFrame |
| `0x19B8` | `CEA_CP_CFG` | `0` | 不用 AVMute 时保持 0 |
| `0x1A08` | `AVMIXER_CONFIG` | `0` | `hdmi_mode=1`、`null_pkt_en=1` |
| `0x1A0C` | `CP_PKT_AVMUTE` | `0` | 不用 AVMute 时保持 0 |
| `0x1A10` | `VIDEO_BLANK_CFG` | `0` | 保持 0 |
| `0x1A54` | `TMDS_BIST_CTRL` | `0` | 测试关闭 |
| `0x1A60` | `HDMI_ENC_CTRL` | `0` | 1080p60 用 HDMI 1.4 编码：`enc_hdmi2_on=0`、`enc_ck_div_sel=0`、`enc_scr_on=0` |

### 2.5 AON / HPD / DDC（`H + 0x4000`）

| 偏移 | 名称 | 复位值 | 用途 |
|---|---|---|---|
| `0x4000` | `TX_HW_INFO` | - | 硬件 ID |
| `0x4004` | `TX_HW_VERSION` | - | 版本 |
| `0x401C` | `TX_AON_RST_CTRL` | `0` | AON 软复位，保持 0 |
| `0x4020` | `HOTPLUG_ST_CFG` | `0x00007CF1` | HPD 滤波/极性/软件覆盖 |
| `0x4024` | `HOTPLUG_FILLTER_CFG` | `0x00090063` | HPD 去抖阈值 |
| `0x4028` | `TX_AON_STATE` | `0` | bit0 `hotplug_state`、bit1 `phy_rx_sense` |
| `0x4030` | `TX_AON_INTR_MASK` | `0` | bit0 HPD 中断屏蔽 |
| `0x4034` | `TX_AON_INTR_STATE` | `0` | bit0 HPD 中断状态 |
| `0x4040` | `DDC_MST_CTRL` | `0x000004A0` | AON DDC master 控制（调试/备用） |
| `0x4044` | `DDC_FIFO_RDATA` | `0` | DDC 读 FIFO |
| `0x4048` | `DDC_FIFO_WDATA` | `0` | DDC 写 FIFO |
| `0x404C` | `DDC_DATA_CNT` | `0` | DDC 数据长度 |
| `0x4050` | `DDC_SLAVE_CFG` | - | DDC 从地址（EDID 0x50） |
| `0x4054` | `DDC_MST_STATE` | - | DDC 状态 |
| `0x4058` | `DDC_MST_CMD` | `0` | DDC 命令 |
| `0x405C` | `DDC_MAN_CTRL` | `0x0000000C` | DDC 手动控制 |
| `0x4060` | `DDC_STATE_CLR` | `0` | DDC 状态清除 |

### 2.6 PHY（`P = 0xf8d30000`）

| 偏移 | 名称 | 复位值 | 用途 |
|---|---|---|---|
| `0x00` | `HDMITX_INSSC_SET` | `0xC0000000` | 输入 SSC 旁路、MASH111 |
| `0x04` | `HDMITX_INSSC_FIFO` | `0x01C01001` | 输入 SSC FIFO，保持默认 |
| `0x08` | `HDMITX_INSSC_STEP` | `0` | 输入 SSC 步进，SSC 关闭时 0 |
| `0x0C` | `HDMITX_INSSC_TUNE` | `0` | 输入 SSC 调谐，保持 0 |
| `0x10` | `HDMITX_DPHY_RST` | `0` | **DPHY 软复位（注意不是 0xC）** |
| `0x14` | `HDMITX_SSC_HK` | `0` | SSC HK，保持 0 |
| `0x50` | `HDMITX_AFIFO_DATA_SEL` | `0x00003E00` | AFIFO 数据选择/1:10 比例 |
| `0x54` | `HDMITX_AFIFO_CLK` | `0x01F07C1F` | AFIFO 时钟比例 |
| `0x60` | `APHY_STATUS0` | `0` | bit2 `ad_txpll_lock` |
| `0x64` | `APHY_TOP_PD` | `0x0017FFFF` | PHY 上电/输出使能/分频模式 |
| `0x68` | `APHY_DRIVER_IMAIN` | `0x00C71C60` | 主电流/D E 电流 |
| `0x6C` | `APHY_DRIVER_IPRE` | `0x18180000` | 预加重电流 |
| `0x70` | `APHY_DRIVER_IPREDE` | `0x00000618` | 预加重/去加重 |
| `0x74` | `APHY_DRIVER_RPRE` | `0x0001B780` | 预加重电阻 |
| `0x78` | `APHY_RTERM_CTRL` | `0x60606060` | 终端电阻 |
| `0x7C` | `APHY_MISC_CTRL` | `0` | LDO/RX sense，保持默认 |
| `0x80` | `APHY_TEST_CTRL` | `0` | VCM 选择 |
| `0x8C` | `APHY_TXPLL_CTRL` | `0x0000C400` | TXPLL ICP/loop/ SSC |
| `0x90` | `APHY_TXPLL_TEST` | `0` | TXPLL 测试，SSC 关闭时 0 |
| `0x94` | `PLL_LOCK_CTRL` | `0x0288080F` | 锁检测窗口，保持默认 |
| `0x98` | `PLL_LOCK_STATUS` | `0` | bit20 `hdmi_clk_lock` |
| `0xB0` | `HDMITX_FBSSC_SET` | `0x01640000` | 反馈 SSC 设置 / loop divider |
| `0xB4` | `HDMITX_FBSSC_FIFO` | `0x01C01001` | 反馈 SSC FIFO，保持默认 |
| `0xB8` | `HDMITX_FBSSC_STEP` | `0x00074046` | 反馈 SSC 步进/span，SSC 关闭时 0 |
| `0xBC` | `HDMITX_FBSSC_TUNE` | `0` | 反馈 SSC 调谐，保持 0 |

`APHY_TOP_PD` 关键位：

| 位 | 名称 | 上电/OE 说明 |
|---|---|---|
| 3:0 | `reg_gc_pd` | 0 = 输出使能；0xF = 输出关闭 |
| 4 | `reg_gc_pd_bist` | 1 = BIST 掉电（厂商总是置 1） |
| 8:5 | `reg_gc_pd_de` | 1 = 对应 lane 去加重掉电；1080p60 的 DE 电流=3（非 0），OE 时 D0/D1/D2 上电、CLK 保持掉电，最终为 0x1 |
| 10:9 | `reg_gc_pd_ldo` | 0 = LDO 上电 |
| 18:11 | `reg_gc_pd_rterm` | 终端电阻模式掩码（厂商按表写 `0x01`） |
| 19 | `reg_gc_pd_rxsense` | 0 = RX sense 上电 |
| 20 | `reg_gc_txpll_pd` | 0 = TXPLL 上电 |
| 22:21 | `reg_divsel` | 0=1X、1=2X、2=4X、3=8X；1080p60 用 **1（2X）** |

### 2.7 CRG / SYSCTRL

| 地址 | 名称 | 关键字段 |
|---|---|---|
| `0xf8a22028` | `PERI_CRG_PLL10` | `hpll_ctrl0`（bits30:0） |
| `0xf8a2202c` | `PERI_CRG_PLL11` | `hpll_ctrl1`（bits27:0） |
| `0xf8a220d8` | `PERI_CRG54` | bit25 `hdmi_clk_sel`、bit29 `vo_hd_hdmi_clk_sel` |
| `0xf8a2210c` | `PERI_CRG67` | HDMI 门控/复位/`ssc_clk_div`/`hdmitx_pxl_cken` |
| `0xf8a22110` | `PERI_CRG68` | `phy_tmds_cken`、PHY/TMDS 复位、`tmds_clk_div` |
| `0xf8a2234c` | `PERI_CRG211` | `vdp_clk_div`（VDP 内部，HDMI 不直接写） |
| `0xf8000044` | HDMI IO 复用 | MV300：清 bits24:21（`0x01e00000`） |
| `0xf8000048` | `SC_CLKGATE_SRST_CTRL` | bit19 CEC、bit20 CEC 复位、bit21 OSC、bit22 APB、bit23 bus 复位、bit24 srst |

`PERI_CRG67` 位定义：

| 位 | 名称 | 本文值 |
|---|---|---|
| 0 | `ssc_in_cken` | 1 |
| 1 | `ssc_bypass_cken` | 1 |
| 2 | `hdmitx_ctrl_osc_24m_cken` | 1 |
| 3 | `hdmitx_ctrl_cec_cken` | 0（无 CEC；厂商置 1） |
| 4 | `hdmitx_ctrl_os_cken` | 1 |
| 5 | `hdmitx_ctrl_as_cken` | 0（无音频；厂商置 1） |
| 6 | `hdmitx_ctrl_bus_srst_req` | 0 |
| 7 | `hdmitx_ctrl_srst_req` | 0 |
| 8 | `hdmitx_ctrl_cec_srst_req` | 0 |
| 9 | `hdmitx_ssc_srst_req` | 0 |
| 13:10 | `ssc_clk_div` | **9**（÷10） |
| 14 | `hdmitx_ctrl_cec_clk_sel` | 0 |
| 16 | `hdmitx_pxl_cken` | 1 |
| 19 | `ssc_bypass_clk_sel` | 0 |

`PERI_CRG68` 位定义：

| 位 | 名称 | 本文值 |
|---|---|---|
| 0 | `phy_tmds_cken` | 1 |
| 4 | `hdmitx_phy_srst_req` | 0 |
| 5 | `phy_tmds_srst_req` | 0 |
| 8:6 | `tmds_clk_div` | **1**（÷2） |

---

## 3. 1080p60 参数与时钟

### 3.1 视频时序（CEA-861 VIC 16，参考值）

| 参数 | 值 |
|---|---|
| 像素率 | 148.5 MHz |
| H active / front / sync / back / total | 1920 / 88 / 44 / 148 / 2200 |
| V active / front / sync / back / total | 1080 / 4 / 5 / 36 / 1125 |
| H/V 极性 | 正 / 正 |
| 帧率 | 60 Hz |
| 颜色 | RGB 8bit 或 YCbCr444 8bit |
| TMDS 字符时钟 | 148.5 MHz |
| TMDS bit rate/lane | 1.485 Gbps（1:10） |

> 上述时序必须由 **VDP/DHD** 真正输出（DE/HS/VS + 像素），HDMI TX 只做打包/编码。HDMI 内部 `TIMING_GEN_CTRL` 保持关闭。

### 3.2 像素时钟从哪来（HPLL / VDP 时钟树）

厂商 MV300 的 1080p60 表项（`source/msp/drv/vo/vdp_v4_0/hal/98mv200/hal_specific/hal_specific_config.c`）：

```c
/* 1920x1080@60Hz@148.500 MHz */
{0x12000000, 0x0001063}
```

`PERI_CRG_PLL10/11` 编码规则（`vdp_v4_0/hal/common/drv_disp_hal.c` `DISP_TimingCalcClockRegistor`）：

```
ClkPara0 = (POSTDIV1 << 24) | (POSTDIV2 << 28) | FRAC
ClkPara1 = (REFDIV  << 12) | FBDIV
```

对 `0x12000000 / 0x00001063`：

| 字段 | 值 |
|---|---|
| POSTDIV1 | 2 |
| POSTDIV2 | 1 |
| FRAC | 0 |
| REFDIV | 1 |
| FBDIV | 0x63 = 99 |

```
Fout = 24MHz * FBDIV / (REFDIV * FOUT_DIV * POSTDIV1)
     = 24 * 99 / (1 * 2 * 2)
     = 594 MHz
```

VDP 侧再按 `DISP_TimingFixSpreadSpectrum()` 的 `FixPixelDiv=4` 得到 148.5 MHz 像素率。也就是说：

- **HPLL 输出 594 MHz**；
- **像素率 148.5 MHz**（4 pixel/clock 的总线时钟即 594 MHz，推断）；
- **CRG54** 选择 HD 通道、1:1 送 HDMI；
- **CRG67 `hdmitx_pxl_cken`** 把 `clk_vid_pxl` 门控给 HDMI；
- **CRG67 `ssc_clk_div` 分频值 10（字段=9）** 得到 PHY 参考 `594/10 = 59.4 MHz`（或等价地 `148.5*4/10`）；
- **PHY loop divider=25** 得到 `59.4*25 = 1485 MHz` TMDS bit clock；
- **CRG68 `tmds_clk_div` 分频值 2（字段=1）** 得到 297 MHz（HDMI 核心的 2 pixel/clock 时钟，推断）。**【需实测确认】**

### 3.3 PHY 分频参数（`PhyDivCfgGet`，1080p60 / 24bit）

| 参数 | 值 | 说明 |
|---|---|---|
| `u32PixelClk` | 148500 kHz | 像素率 |
| `u32TmdsClk` | 148500 kHz | TMDS 字符时钟 |
| `enDeepColor` | 24bit | 8bit/通道 |
| `u32PixelClkDiv` | 4 | PHY 内部 pixel divider |
| `u32SscBypDiv` | 10 | CRG `ssc_clk_div=9` |
| `u32TmdsNxdiv` | 2 | CRG `tmds_clk_div=1` |
| `u32LoopDiv` | `0x640000` | 25×4=100，即 ×25 |
| `enClkRatio` | 1:10 | 8bit TMDS |
| `enPhyDivMode` | 2X | `APHY_TOP_PD.reg_divsel=1` |
| SSC | 关闭 | `bEmiEnable=0` |
| HW spec 行 | 100001–165000 kHz | MV300 表 |

### 3.4 PHY 模拟参数（MV300，TMDS 148.5 MHz）

来自 `s_stPhyHWSpecTab_98mv300` 第二行（`100001..165000`）：

| 字段 | 原始值 | 写入编码 |
|---|---|---|
| `IDeMainClk/D0/D1/D2` | 0 / 3 / 3 / 3 | `0/3/3/3`（`PhyTransferCur2Hex`，<16 直接映射） |
| `IMainClk/D0/D1/D2` | 22 / 29 / 29 / 29 | `26/45/45/45` |
| `FeedThruCapEn` | 全 false | 不置 bit2 |
| `FeedThruCapDelay` | 18ps | enum 值 0（`PHY_FEEDTHRU_CAP_DELAY_18PS`） |
| `RTermClkMode` | LOAD | 掩码 `0x01` |
| `RTermD0..D2Mode` | SRC_LD | 掩码 `0x00` |
| `RTermClk` | `0x60` | - |
| `RTermD0..D2` | `0x20` | - |
| `VCMSel` | `0x51` | 写 `APHY_TEST_CTRL.reg_test` |

> 这些是厂商表值，不是板级 SI 优化值；不同 PCB/连接器可能需要微调。**【需实测确认】**

> 注意：MV300 走 `PhyHWEnhanceSpecSet()`，它只写 `APHY_DRIVER_IMAIN`、`APHY_DRIVER_IPRE`、`APHY_DRIVER_RPRE.rsel_pre_*`、`APHY_RTERM_CTRL`、`APHY_TOP_PD.gc_pd_rterm` 和 `APHY_TEST_CTRL`；**不写 `APHY_DRIVER_IPREDE`**，也不写 `RPRE.isel_pre_de_d2`。不要直接套用非 MV300 的 `PhyHWSpecSet()` 值。

---

## 4. 按 stage 的初始化序列

约定：

- `H = 0xf8ce0000`，`P = 0xf8d30000`，`C = 0xf8a22000`。
- “RMW” = 读-改-写，只改列出的字段，保留其他位。
- 所有延时单位：`udelay` 微秒、`msleep` 毫秒。
- “依赖”列：`VDP` = 需要 VDP 先输出时序/时钟；`HPD` = 需要 HPD 为高；`EDID` = 固定模式可跳过。

### Stage 0：前置条件（VDP 时序/时钟、IO 复用）

| # | 地址 | 寄存器/字段 | 值/公式 | 依赖 | 说明 |
|---|---|---|---|---|---|
| 0.1 | `C+0x28` | `PERI_CRG_PLL10.hpll_ctrl0` | `0x12000000` | VDP | 1080p60 HPLL；由 VDP 配置，HDMI 不单独改 |
| 0.2 | `C+0x2C` | `PERI_CRG_PLL11.hpll_ctrl1` | `0x00001063` | VDP | 同上 |
| 0.3 | `C+0xD8` | `PERI_CRG54` bit25 / bit29 | `hdmi_clk_sel=1`、`vo_hd_hdmi_clk_sel=0` | VDP | 选 HD 通道，1:1 到 HDMI |
| 0.4 | `0xf8a2234c` | `PERI_CRG211.vdp_clk_div` | `1`（100–200M 档） | VDP | VDP 内部 /4 关系；HDMI 不直接写 |
| 0.5 | `0xf8000044` | HDMI IO cfg | `val &= ~0x01e00000` | 无 | MV300 的 HDMI IO 复用；厂商 `DRV_HDMI_ProdIoCfgSet` |
| 0.6 | - | VDP DHD | 1920x1080p60，DE/HS/VS 正极性 | VDP | **必须真实输出**；否则 HDMI 无像素时钟 |

**检查点：** 如果 VDP 没跑起来，后面 `TX_PACK_FIFO_ST.pclk2tclk_stable` 很可能永远为 0，PHY 也不会锁定。

### Stage 1：CRG 门控/复位（先让寄存器可写）

| # | 地址 | 寄存器/字段 | 值/公式 | 依赖 | 说明 |
|---|---|---|---|---|---|
| 1.1 | `0xf8000048` | `SC_CLKGATE_SRST_CTRL` | RMW：bit22=1、bit21=1、bit19=0、bit20=0、bit23=0、bit24=0 | 无 | APB/OSC 开，CEC 关，HDMI 出复位 |
| 1.2 | `C+0x10C` | `PERI_CRG67` | RMW：按 §2.7 写 `0x00012417`（无 CEC/音频） | 无 | 门控 + `ssc_clk_div=9` + pxl gate |
| 1.3 | `C+0x110` | `PERI_CRG68` | RMW：`phy_tmds_cken=1`、PHY/TMDS 复位=0、`tmds_clk_div=1` → `0x00000041` | 无 | TMDS 门控/÷2 |
| 1.4 | `H+0x10` | `TX_PWD_RST_CTRL` | `0x00000400` | 无 | 保持 HDCP MCU 复位；数据通路释放 |
| 1.5 | `H+0x10` | `TX_PWD_RST_CTRL.tx_hdmi_srst_req` | 置 1 → `udelay(5)` → 置 0 | 无 | 清包 FIFO；也可用厂商 `DataReset` |
| 1.6 | `H+0x850` | `CBAR_PATTERN_A0` | `0` | 无 | 厂商 CRG 初始化固定写 0 |

> 全复位脉冲（可选）：把 `0xf8000048` bit23/24、`C+0x10C` bit6/7/9、`C+0x110` bit4/5 先置 1，`udelay(5)` 后再写回 0。厂商 `DRV_HDMI_ProdCrgAllResetSet(HI_TRUE)` 内部就是这样一置一清。
>
> **顺序差异：** 厂商原流程在 `HAL_HDMI_PhyInit()` 里先写 PHY 寄存器，之后才 `DRV_HDMI_ProdCrgInit()` 开门控；这依赖 bootloader 已开 HDMI 时钟。冷启动建议按本文 **先 Stage 1 再 Stage 2**。**【需实测确认】**

### Stage 2：PHY 初始化/上电/分频/模拟参数

| # | 地址 | 寄存器/字段 | 值/公式 | 依赖 | 说明 |
|---|---|---|---|---|---|
| 2.1 | `P+0x00` | `HDMITX_INSSC_SET` | `0xC0000000` | 无 | `sscin_bypass_en=1`、`pllfbmash111_en=1` |
| 2.2 | `P+0x8C` | `APHY_TXPLL_CTRL` | `0x0000C400` | 无 | `icp_ictrl=3`、`divsel_loop=0x20`、SSC div 关 |
| 2.3 | `P+0x64` | `APHY_TOP_PD` | RMW 上电：`gc_pd=0xF`（OE 仍关）、`gc_pd_de=0xF`、`gc_pd_bist=1`、`gc_pd_ldo=0`、`gc_pd_rxsense=0`、`gc_txpll_pd=0` | 无 | 上电但不出图 |
| 2.4 | `P+0x64` | `APHY_TOP_PD.reg_divsel` | `1`（2X） | 无 | 1080p60 24bit |
| 2.5 | `P+0x10` | `HDMITX_DPHY_RST.reg_dphy_srst_req` | 1 → `udelay(5)` → 0 | 无 | DPHY 软复位；**偏移 0x10，不是 0x0C** |
| 2.6 | `P+0x50` | `HDMITX_AFIFO_DATA_SEL.reg_aphy_data_clk_h` | `0x1F` | 无 | 1:10 比例 |
| 2.7 | `P+0x54` | `HDMITX_AFIFO_CLK.reg_aphy_data_clk_l` | `0x1F07C1F` | 无 | 1:10 比例 |
| 2.8 | `P+0xB0` | `HDMITX_FBSSC_SET.reg_set_fb` | `0x640000`（×25），`reg_set_load_fb=1` → 等效 `0x01640000` | 无 | 主 loop divider |
| 2.9 | `P+0xB8` | `HDMITX_FBSSC_STEP` | `0x00000000` | 无 | SSC 关闭：step/span=0 |
| 2.10 | `P+0x90` | `APHY_TXPLL_TEST` | `0x00000000` | 无 | TXPLL 测试关 |
| 2.11 | `P+0x8C` | `APHY_TXPLL_CTRL.reg_gc_txpll_en_sscdiv` | `0` | 无 | SSC 关闭 |
| 2.12 | `P+0x68` | `APHY_DRIVER_IMAIN` | `0x0B6DB5A` | 无 | IMain/DeIMain 编码 |
| 2.13 | `P+0x6C` | `APHY_DRIVER_IPRE` | `0x2D6830C3` | 无 | IPre/DeIPre 编码 |
| 2.14 | `P+0x70` | `APHY_DRIVER_IPREDE` | `0x00000618`（保持复位值） | 无 | **MV300 增强表不写该寄存器**；不要照搬非 MV300 的 `PhyHWSpecSet` |
| 2.15 | `P+0x74` | `APHY_DRIVER_RPRE` | `0x00000000`（rsel_*=0） | 无 | 只写 feed-through rsel；复位 `isel_pre_de_d2=0`，故最终为 0 |
| 2.16 | `P+0x78` | `APHY_RTERM_CTRL` | `0x20202060` | 无 | clk=0x60，data=0x20 |
| 2.17 | `P+0x64` | `APHY_TOP_PD.reg_gc_pd_rterm` | `0x01` | 无 | LOAD 模式；此时等效 `0x2009FF`（OE 关闭、`gc_pd_de=0xF`） |
| 2.18 | `P+0x80` | `APHY_TEST_CTRL.reg_test` | `0x51` | 无 | VCMSel |
| 2.19 | `P+0x94` | `PLL_LOCK_CTRL` | `0x0288080F`（保持默认） | 无 | 锁检测窗口 |
| 2.20 | `P+0x60` | `APHY_STATUS0.ad_txpll_lock` | 轮询 bit2=1，最多 10ms | VDP | 可选；失败不要立刻 OE |
| 2.21 | `P+0x98` | `PLL_LOCK_STATUS.hdmi_clk_lock` | 轮询 bit20=1，最多 10ms | VDP | 可选，与 2.20 二选一/都查 |

> 2.17 的 `0x2009FF` 是按字段推导的等效值：`divsel=1`、`gc_pd=0xF`、`gc_pd_bist=1`、`gc_pd_de=0xF`、`gc_pd_rterm=0x01`。实际建议按字段 RMW，避免覆盖保留位。

### Stage 3：视频路径（格式/CSC/极性）

| # | 地址 | 寄存器 | 值（RGB full） | 值（YCbCr444 limited） | 依赖 | 说明 |
|---|---|---|---|---|---|---|
| 3.1 | `H+0x800` | `TIMING_GEN_CTRL` | `0x00000000` | `0x00000000` | VDP | 用外部 VDP 时序 |
| 3.2 | `H+0x830` | `VIDEO_PATH_CTRL` | `0x00000000` | `0x00000000` | 无 | 不黑场 |
| 3.3 | `H+0x8EC` | `DITHER_CONFIG` | `0x00000001` | `0x00000001` | 无 | 8bit 直通 |
| 3.4 | `H+0x934` | `MULTI_CSC_CTRL` | `0x00000EE0` | `0x00000220` | EDID 可选 | CSC 关；`csc_mode` 按格式/量化 |
| 3.5 | `H+0x98C` | `DATA_ALIGN_CTRL` | `0x00000000` | `0x00000000` | 无 | 无 420/分频 |
| 3.6 | `H+0x9A8` | `VIDEO_DMUX_CTRL` | `0x00000088` | `0x00000088` | 无 | Y/Cb/Cr + 正极性 |
| 3.7 | `H+0x980` | `VIDEO_DWSM_CTRL` | `0x00000008` | `0x00000008` | 无 | 垂直 bypass |
| 3.8 | `H+0x1800` | `TX_PACK_FIFO_CTRL` | `0x00000004` | `0x00000004` | 无 | 24bit + FIFO 自动复位 |

`MULTI_CSC_CTRL` 取值表（`csc_mode << 4`）：

| 输出格式 | 量化 | `csc_mode` | `MULTI_CSC_CTRL` |
|---|---|---|---|
| RGB | full | `0xEE` | `0x00000EE0` |
| RGB | limited | `0xAA` | `0x00000AA0` |
| YCbCr444 | full | `0x66` | `0x00000660` |
| YCbCr444 | limited | `0x22` | `0x00000220` |

> `csc_en=0`，这些模式位在旁路时是否完全无效没有在源码中明确；建议按厂商值写。**【需实测确认】**

> **前提：** 本表假设 VDP 输出的颜色空间与 HDMI 输出一致（都 RGB，或都 YCbCr444），这样 `csc_en=0` 才是真正的旁路。若 VDP 输出 YCbCr444、HDMI 要 RGB（或反过来），必须打开 CSC 并写 `MULTI_CSC_COEFF*`/`INOFFSET`/`OUTOFFSET`，这不属于“最小序列”；第一版建议让 VDP 与 HDMI 同格式。
>
> 厂商 `HdmiVOAttrInit()` 默认把 `enInColorSpace` 设为 `YCbCr444`，而 1080p60 格式表用 `HI_DRV_CS_BT709_RGB_FULL`；实际 VDP 输出格式需要跟 VDP/DHD 配置一起确认。**【需实测确认】**

### Stage 4：TMDS 模式 / 包 / AVI InfoFrame

| # | 地址 | 寄存器 | 值 | 依赖 | 说明 |
|---|---|---|---|---|---|
| 4.1 | `H+0x1A60` | `HDMI_ENC_CTRL` | `0x00000000` | 无 | HDMI 1.4 编码，1:10，无 scramble |
| 4.2 | `H+0x1A08` | `AVMIXER_CONFIG` | `0x00000005` | 无 | `hdmi_mode=1`、`null_pkt_en=1` |
| 4.3 | `H+0x1A10` | `VIDEO_BLANK_CFG` | `0x00000000` | 无 | - |
| 4.4 | `H+0x1A54` | `TMDS_BIST_CTRL` | `0x00000000` | 无 | 测试关 |
| 4.5 | `H+0x1818` | `AVI_PKT_HEADER` | `0x000D0282` | EDID 可选 | type=0x82, ver=2, len=13 |
| 4.6 | `H+0x181C` | `AVI_SUB_PKT0_L` | 见下表 | EDID 可选 | checksum + payload[0..2] |
| 4.7 | `H+0x1820` | `AVI_SUB_PKT0_H` | `0x00000010` | EDID 可选 | payload[3..5]，VIC=16 |
| 4.8 | `H+0x1824`~`0x1838` | `AVI_SUB_PKT1..3` | `0x00000000` | - | 补 0 |
| 4.9 | `H+0x19A4` | `CEA_AVI_CFG` | `0x00000003` | 无 | 使能 + 每帧重复 |
| 4.10 | `H+0x19AC` | `CEA_AUD_CFG` | `0x00000000` | 无 | 不发 Audio InfoFrame |
| 4.11 | `H+0x19B8` | `CEA_CP_CFG` | `0x00000000` | 无 | 不用 AVMute |

AVI 包字节（payload = `buffer[4..16]`）：

```
buffer[0..3] = 82 02 0D CS
buffer[4]    = (colorspace << 5) | (scan_mode & 3) | (active_info_valid ? 0x10 : 0)
buffer[5]    = (colorimetry << 6) | (picture_aspect << 4) | (active_aspect & 0xF)
buffer[6]    = (extended_colorimetry << 4) | (quantization_range << 2) | nups
buffer[7]    = VIC
buffer[8]    = (ycc_quantization_range << 6) | (content_type << 4) | ((pixel_repeat - 1) & 0xF)
buffer[9..16]= 0
CS = 0x100 - (sum(buffer[0..16]) & 0xFF)   /* 实际实现按 8bit 累加 */
```

1080p60 的常用组合：

| 格式 | `buffer[4]` | `buffer[5]` | `buffer[6]` | `buffer[7]` | `buffer[8]` | `CS` | `0x181C` | `0x1820` |
|---|---|---|---|---|---|---|---|---|
| RGB default | `0x10` | `0xAA` | `0x00` | `0x10` | `0x00` | `0xA5` | `0x00AA10A5` | `0x00000010` |
| RGB full | `0x10` | `0xAA` | `0x08` | `0x10` | `0x00` | `0x9D` | `0x08AA109D` | `0x00000010` |
| RGB limited | `0x10` | `0xAA` | `0x04` | `0x10` | `0x00` | `0xA1` | `0x04AA10A1` | `0x00000010` |
| YCbCr444 limited | `0x50` | `0xAA` | `0x00` | `0x10` | `0x00` | `0x65` | `0x00AA5065` | `0x00000010` |
| YCbCr444 full | `0x50` | `0xAA` | `0x00` | `0x10` | `0x40` | `0x25` | `0x00AA5025` | `0x00000010` |

字段取值：

| 字段 | 值 |
|---|---|
| `colorspace` | RGB=0，YCbCr444=2 |
| `scan_mode` | 0（无信息） |
| `colorimetry` | BT.709=2 |
| `picture_aspect` | 16:9=2 |
| `active_aspect` | 16:9=10（0xA） |
| `quantization_range` | RGB limited=1，full=2 |
| `ycc_quantization_range` | limited=0，full=1 |
| `nups` | 0 |
| `content_type` | 0 |
| `pixel_repeat` | 1（8bit） |

> AVI 的时延/量化策略在厂商驱动里是 EDID/应用属性驱动的；第一版固定模式直接写表值。**【需实测确认】**（某些 sink 只认 limited）。

### Stage 5：音频关闭

| # | 地址 | 寄存器 | 值 | 说明 |
|---|---|---|---|---|
| 5.1 | `H+0x1000` | `TX_AUDIO_CTRL` | `0x00000000` | 关 `aud_in_en`、I2S、SPDIF |
| 5.2 | `H+0x19AC` | `CEA_AUD_CFG` | `0x00000000` | 关 Audio InfoFrame |
| 5.3 | `H+0x10` | `TX_PWD_RST_CTRL` bits 6/7/8 | 置 1 → `udelay(500)` → 0 | 可选：复位 audio/acr/afifo |
| 5.4 | `H+0x1A08` | `AVMIXER_CONFIG.null_pkt_en` | `1` | Stage 4 已置，保持 |

> 无音频时让 null packet 持续发送，避免 TMDS 空闲；如果后续接 ASoC，再把 `null_pkt_en` 清 0 并打开 audio path。

### Stage 6：输出使能

| # | 地址 | 寄存器/字段 | 值/公式 | 依赖 | 说明 |
|---|---|---|---|---|---|
| 6.1 | `H+0x4028` | `TX_AON_STATE.hotplug_state` | 读 bit0；极性由 `0x4020.bit2` 决定 | HPD | 低则先不要 OE；见 §6 |
| 6.2 | `H+0x1804` | `TX_PACK_FIFO_ST.pclk2tclk_stable` | 轮询 bit0=1，最多 20ms | VDP | 厂商在 OE 前等 TMDS 稳定 |
| 6.3 | `P+0x64` | `APHY_TOP_PD` | `0x200830`（等效：`gc_pd=0`、`gc_pd_de=0x1`、`divsel=1`） | 无 | PHY 输出使能 |
| 6.4 | `P+0x60` | `APHY_STATUS0.ad_txpll_lock` | 轮询 bit2=1（可选） | VDP | 失败则记录并重试 |
| 6.5 | `P+0x98` | `PLL_LOCK_STATUS.hdmi_clk_lock` | 轮询 bit20=1（可选） | VDP | 与 6.4 二选一/都查 |

`APHY_TOP_PD` 两个关键等效值：

| 状态 | 值 | 组成 |
|---|---|---|
| 上电、OE 关闭 | `0x2009FF` | `gc_pd=0xF`、`bist=1`、`de=0xF`、`rterm=0x01`、`divsel=1` |
| 上电、OE 打开 | `0x200830` | `gc_pd=0`，`gc_pd_de=0x1`（CLK 的 DE 掉电，D0-D2 的 DE 上电），其余同上 |

> 如果 6.2 一直为 0，先查 VDP 像素时钟、CRG 门控、`tmds_clk_div`，不要盲目置 OE。
>
> `gc_pd_de=0x1` 的由来：`PhyOeSet()` 从 `0xF` 开始，DE 电流非 0 的 lane 会清对应 bit。CLK 的 `IDeMainClk=0`，bit0 保留；D0/D1/D2 的 `IDeMainD* = 3`，bit1/2/3 被清，最终 `0x1`。

### Stage 7：验证/失败处理

| 检查 | 寄存器 | 期望 |
|---|---|---|
| PHY 上电 | `P+0x64` | `gc_txpll_pd=0`、`gc_pd_ldo=0`、`gc_pd_rxsense=0` |
| PHY OE | `P+0x64` | `gc_pd=0` |
| TXPLL 锁 | `P+0x60` bit2 | 1 |
| HDMI 时钟锁 | `P+0x98` bit20 | 1 |
| TMDS 稳定 | `H+0x1804` bit0 | 1 |
| AVI 使能 | `H+0x19A4` | bit0=1、bit1=1 |
| 音频关闭 | `H+0x1000` | `aud_in_en=0` |
| HPD | `H+0x4028` bit0 | 按极性为“已连接” |

失败顺序建议：先看 HPD → 再看 VDP 时钟/时序 → 再看 PHY 锁 → 再看 TMDS 稳定 → 最后看 AVI/格式。

---

## 5. 最小伪代码

```c
/* 仅表达顺序，不是可直接编译的内核代码 */
#define H 0xf8ce0000u
#define P 0xf8d30000u
#define C 0xf8a22000u

static void hdmi_1080p60_min_init(void)
{
    u32 v;

    /* Stage 0: VDP must already output 1080p60 (DE/HS/VS/pixel). */
    /* HPLL = 0x12000000 / 0x00001063, CRG54 HD 1:1, IO mux. */
    v = readl(0xf8000044); writel(v & ~0x01e00000u, 0xf8000044);

    /* Stage 1: CRG gates/resets. */
    v = readl(0xf8000048);
    v |= (1u << 22) | (1u << 21);          /* APB, OSC */
    v &= ~((1u << 19) | (1u << 20) | (1u << 23) | (1u << 24));
    writel(v, 0xf8000048);

    v = readl(C + 0x10c);
    v &= ~0x00007fc0u;                     /* bus/srst/cec/ssc resets = 0 */
    v &= ~((1u << 3) | (1u << 5) | (1u << 19)); /* CEC/audio gate, bypass sel = 0 */
    v |= (1u << 0) | (1u << 1) | (1u << 2) | (1u << 4) | (1u << 16);
    v = (v & ~(0xfu << 10)) | (9u << 10);  /* ssc_clk_div = 9 (divide by 10) */
    writel(v, C + 0x10c);

    v = readl(C + 0x110);
    v |= (1u << 0);                        /* phy_tmds_cken */
    v &= ~((1u << 4) | (1u << 5));         /* phy/tmds resets = 0 */
    v = (v & ~(7u << 6)) | (1u << 6);      /* tmds_clk_div = 1 */
    writel(v, C + 0x110);

    writel(0x00000400u, H + 0x0010);       /* MCU reset kept */
    writel(0x00000000u, H + 0x0850);

    /* Stage 2: PHY. */
    writel(0xC0000000u, P + 0x00);
    writel(0x0000C400u, P + 0x8C);

    v = readl(P + 0x64);
    v &= ~((1u << 20) | (1u << 19) | (3u << 9));  /* txpll/rxsense/ldo on */
    v |= (1u << 4);                               /* BIST power down (vendor always 1) */
    v = (v & ~0xfu) | 0xfu;                       /* OE still off */
    v = (v & ~(0xfu << 5)) | (0xfu << 5);         /* DE power down while OE is off */
    v = (v & ~(3u << 21)) | (1u << 21);           /* divsel = 2X */
    writel(v, P + 0x64);

    writel(1u, P + 0x10); udelay(5); writel(0u, P + 0x10);

    v = readl(P + 0x50); v = (v & ~(0x3ffu << 9)) | (0x1fu << 9); writel(v, P + 0x50);
    writel(0x01F07C1Fu, P + 0x54);
    writel(0x01640000u, P + 0xB0);
    writel(0x00000000u, P + 0xB8);
    writel(0x00000000u, P + 0x90);

    writel(0x0B6DB5Au, P + 0x68);
    writel(0x2D6830C3u, P + 0x6C);
    writel(0x00000618u, P + 0x70);       /* enhanced path: keep reset */
    writel(0x00000000u, P + 0x74);       /* rsel_pre_* = 0 */
    writel(0x20202060u, P + 0x78);

    v = readl(P + 0x64);
    v = (v & ~(0xffu << 11)) | (0x01u << 11);     /* rterm = 0x01 */
    writel(v, P + 0x64);
    writel(0x00000051u, P + 0x80);
    writel(0x0288080Fu, P + 0x94);

    /* Stage 3: video path. */
    writel(0x00000000u, H + 0x0800);
    writel(0x00000000u, H + 0x0830);
    writel(0x00000001u, H + 0x08EC);
    writel(0x00000EE0u, H + 0x0934);       /* RGB full; YCbCr444 limited -> 0x220 */
    writel(0x00000000u, H + 0x098C);
    writel(0x00000088u, H + 0x09A8);
    writel(0x00000008u, H + 0x0980);
    writel(0x00000004u, H + 0x1800);

    /* Stage 4: TMDS/packets/AVI. */
    writel(0x00000000u, H + 0x1A60);
    writel(0x00000005u, H + 0x1A08);
    writel(0x00000000u, H + 0x1A10);
    writel(0x00000000u, H + 0x1A54);
    writel(0x000D0282u, H + 0x1818);
    writel(0x08AA109Du, H + 0x181C);       /* RGB full */
    writel(0x00000010u, H + 0x1820);
    writel(0x00000000u, H + 0x1824);
    writel(0x00000000u, H + 0x1828);
    writel(0x00000000u, H + 0x182C);
    writel(0x00000000u, H + 0x1830);
    writel(0x00000000u, H + 0x1834);
    writel(0x00000000u, H + 0x1838);
    writel(0x00000003u, H + 0x19A4);
    writel(0x00000000u, H + 0x19AC);
    writel(0x00000000u, H + 0x19B8);

    /* Stage 5: audio off. */
    writel(0x00000000u, H + 0x1000);

    /* Stage 6: wait stable then PHY OE. */
    for (int i = 0; i < 20; i++) {
        if (readl(H + 0x1804) & 1u) break;
        msleep(1);
    }
    writel(0x200830u, P + 0x64);           /* OE on; gc_pd_de=0x1 (CLK DE off, data DE on) */
}
```

> 这段伪代码省略了 HPD 判断、错误处理和 RMW 的完整掩码；实际移植时按 §2 的字段表补全。

---

## 6. HPD / EDID 最小处理

### 6.1 HPD（第一版必须做）

| 项目 | 寄存器/字段 | 说明 |
|---|---|---|
| HPD 状态 | `H+0x4028` bit0 `hotplug_state` | 原始电平 |
| HPD 极性 | `H+0x4020` bit2 `hpd_polarity_ctl` | 为 1 时状态取反 |
| RX sense | `H+0x4028` bit1 `phy_rx_sense` | DDC 之前检查 |
| 去抖 | `H+0x4020`/`0x4024` | 默认 `0x7CF1` / `0x00090063`，可沿用 |
| HPD 中断 | `H+0x4030` bit0 / `H+0x4034` bit0 | 对应 IRQ 88；轮询也可 |
| CEC 中断 | IRQ 147 | **本文不使用** |

建议逻辑：

```c
bool hpd_connected(void)
{
    u32 st = readl(H + 0x4028);
    u32 cfg = readl(H + 0x4020);
    bool raw = st & 1u;
    return (cfg & (1u << 2)) ? !raw : raw;
}

/* 上电初始化可以照常做，但 OE 前必须确认 HPD。 */
if (!hpd_connected()) {
    /* 保持 APHY_TOP_PD.gc_pd = 0xF，等 HPD 中断/轮询 */
}
```

> 如果 HPD 为低仍强行 OE，通常不会损坏，但电视端无信号；某些 sink 会在 HPD 低时拉低 DDC，导致后续 EDID 读取失败。

### 6.2 EDID（第一版可以跳过）

第一版固定 1080p60 不读 EDID 的前提：

- 假定 sink 支持 1080p60 RGB/YCbCr444（绝大多数电视/显示器支持）；
- 不根据 sink 能力选择 VIC/颜色/量化/深色；
- 不做 SCDC/scramble（1080p60 不需要）；
- 不做 HDCP（本文范围外）。

不读 EDID 的风险：

- sink 只支持 1080i/720p 或只支持 limited range 时可能黑屏/偏色；
- 无法知道 sink 的 max TMDS clock、HDR、音频能力；
- 无法做热插拔后的模式重配。

如果后续要读 EDID，源码里有内部 DDC master：

| 方式 | 寄存器 | 说明 |
|---|---|---|
| PWD DDC master | `H+0x0038..0x006C` | 厂商默认 `DDC_MASTER_MODE_PWD` |
| AON DDC master | `H+0x4040..0x4060` | 调试/备用；`HDMI_TX_BASE_ADDR_AON` |

最小 EDID 读流程（厂商 `HAL_HDMI_DdcEdidRawGet`）：

1. 检查 HPD/RSEN；
2. 配 `DDC_SLAVE_CFG` 为 0x50（7bit）；
3. 配 `DDC_DATA_CNT=128`；
4. 发 `DDC_MST_CMD` 读命令；
5. 等 `DDC_MST_STATE` 完成；
6. 从 `DDC_FIFO_RDATA`/DMA 取 128 字节；
7. 解析 EDID，找 VIC 16 / RGB / 444 / range。

> 第一版建议 **只实现 HPD，不实现 DDC**；等 HDMI 通路出图后再补 EDID，避免同时引入两个不确定因素。

---

## 7. 不确定项（必须实测确认）

| # | 项目 | 现状 | 建议 |
|---|---|---|---|
| 1 | PHY 基址 `0xf8d30000` vs 任务给的 `0xf8ce1800` | 源码明确 `0xf8d30000`；`0xf8ce1800` 是 HDMITX 数字块 | 只读回读 `P+0x00`/`H+0x1800` 对照 |
| 2 | `HDMITX_DPHY_RST` 偏移 | 头文件注释 `0xC`，结构体实际 `0x10` | 以 `0x10` 为准；回读验证 |
| 3 | HPLL 594 MHz / FixPixelDiv=4 / 像素率 148.5 的关系 | 由厂商表 + `DISP_TimingFixSpreadSpectrum` 推断 | 测 `clk_vid_pxl` 或读 VDP 时钟状态 |
| 4 | `tmds_clk_div=2` 的实际作用 | 推断为 594/2=297 MHz 核心时钟 | 测 TMDS 眼图/时钟 |
| 5 | `pclk2tclk_stable` 是否依赖 `reg_clock_det_en` | 厂商默认 `reg_clock_det_en=0`，但仍轮询该位 | 若一直 0，试置 bit4 再测 |
| 6 | PHY 模拟参数（IMAIN/IPRE/RTERM/VCM） | 厂商表值，非板级优化 | 不同 PCB 可能需微调；先照抄 |
| 7 | AVI 量化/colorimetry | 固定 full RGB；sink 可能只认 limited | 电视偏色/黑屏时改 limited 表 |
| 8 | `MULTI_CSC_CTRL.csc_mode` 在 `csc_en=0` 时是否必要 | 厂商写，本文照抄 | 可做 A/B 测试 |
| 9 | HPD 极性/IO 复用 | `0xf8000044` 清 bits24:21；极性由 `0x4020.bit2` | 读回确认 |
| 10 | `0xf8ce0850` 写入语义 | 厂商注释“tee & ree dhd0 sync” | 保留写 0，观察是否影响出图 |
| 11 | CRG 初始化顺序（PHY 写 vs 门控） | 厂商先 PHY 后 CRG，依赖 boot | 冷启动按本文先 CRG |
| 12 | 是否需要 `TX_PWD_RST_CTRL` bit0 全复位 | 厂商 stop 时脉冲，start 不脉冲 | 首次 bring-up 可加一次 |

---

## 8. 风险与调试建议

### 8.1 最大风险

1. **PHY 基址/寄存器序列错误**：把 `0xf8ce1800` 当 PHY 会写到 HDMITX 数字块，表现为“寄存器能写但 TMDS 无输出”。这是第一风险。
2. **VDP 没有真正输出 1080p60**：HDMI 只负责打包/编码，没有像素时钟就没有 TMDS。先确认 VDP 的 DE/HS/VS 和像素时钟。
3. **时钟树/分频不对**：HPLL、CRG54、CRG67 `ssc_clk_div`、CRG68 `tmds_clk_div`、PHY loop divider 任一错，都会导致无锁/黑屏/闪烁。
4. **跳过 EDID**：固定模式与 sink 能力不匹配时可能黑屏；这不是 HDMI TX 初始化错误，但会被误判。
5. **PHY 模拟参数板级差异**：厂商表值可出图，但不同 PCB 的 SI/连接器可能需要微调预加重/终端电阻。
6. **HDCP 完全跳过**：普通 framebuffer/测试图案没问题；受保护内容会黑屏，这是预期行为。

### 8.2 调试顺序

1. 只读回读 `0xf8ce4000`/`0xf8ce4004`，确认 HDMI 块可访问。
2. 只读回读 `P+0x00`，确认 PHY 窗口（`0xC0000000` 附近）。
3. 配 VDP 1080p60，读 `H+0x1804` bit0，确认 TMDS 稳定。
4. 配 CRG/PHY，读 `P+0x60` bit2、`P+0x98` bit20，确认 PLL 锁。
5. 写视频路径 + AVI，最后 OE；用示波器/分析仪看 TMDS 是否有 148.5 MHz 字符时钟。
6. 电视无图时，先改 AVI limited/full，再改 `MULTI_CSC_CTRL`，最后怀疑 PHY 模拟参数。

### 8.3 最小出图判据

- `P+0x64.gc_pd == 0`
- `P+0x60.bit2 == 1` 或 `P+0x98.bit20 == 1`
- `H+0x1804.bit0 == 1`
- `H+0x19A4 == 0x3`
- `H+0x1000 == 0`
- 电视端识别为 1920x1080p60，RGB/YCbCr444，无 HDCP。

---

## 9. 参考源码索引

| 内容 | 文件 |
|---|---|
| PHY 基址/芯片枚举 | `source/msp/drv/hdmi/hdmi_2_0/product/hisiv100/hdmi_product_define.h` |
| PHY 寄存器/读写 | `source/msp/drv/hdmi/hdmi_2_0/hal/phy/hisiv100/regs/hdmi_reg_dphy.c` |
| PHY 初始化/分频/上电 | `source/msp/drv/hdmi/hdmi_2_0/hal/phy/hisiv100/hdmi_hal_phy.c` |
| 视频路径/CSC/AVI | `source/msp/drv/hdmi/hdmi_2_0/hal/ctrl/hisiv100/hdmi_hal_ctrl.c` |
| HAL 高层顺序 | `source/msp/drv/hdmi/hdmi_2_0/hal/ctrl/hisiv100/hdmi_hal_intf.c` |
| DRV 层 Start/Open | `source/msp/drv/hdmi/hdmi_2_0/drv_hdmi_intf.c` |
| AVI 打包 | `source/msp/drv/hdmi/hdmi_2_0/drv_hdmi_infoframe.c` |
| CRG 寄存器 | `source/msp/drv/hdmi/hdmi_2_0/product/hisiv100/regs/hdmi_reg_crg.c` |
| 1.4 PHY 地址 | `source/msp/drv/hdmi/hdmi_1_4/drv_reg_proc.h` |
| VDP HPLL/时钟 | `source/msp/drv/vo/vdp_v4_0/hal/98mv200/hal_specific/hal_specific_config.c`、`hal/common/drv_disp_hal.c` |
| VDP CRG 位定义 | `source/common/drv/include/hi3798mv200/hi_reg_crg.h` |

---

**文档版本：** 2026-10-31，基于厂商 4.4 源码静态分析；未上板验证。所有“需实测确认”项必须在目标板只读核对后再定稿。
