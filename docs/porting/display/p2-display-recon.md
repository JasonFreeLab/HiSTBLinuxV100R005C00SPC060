# P2 显示（DRM/KMS + HDMI）侦察与任务分解

日期：2026-10-31。目标：mainline Linux 7.3 上驱动 Hi3798MV300 的 VDP/DBE + HDMI 2.0，实现 modetest/4K60 输出与 HDMI 音频。

## 1. 硬件寄存器（来自厂商 MSP 源码）

| 模块 | 基地址 | 来源/说明 |
|---|---|---|
| VDP / DISP（VO+DBE） | `0xf8cc0000` | `source/msp/drv/vo/.../vdp_define.h`，`DISP_BASE_ADDRESS`；板卡实测 ID=`0x8380000b 0x03000177`（P2 stub 已读出） |
| HDMI TX（HDMI 2.0 IP） | `0xf8ce0000` | `source/msp/drv/hdmi/hdmi_2_0/hal/...`（HiSilicon hisiv100 HDMI 2.0，**非 DW-HDMI**） |
| HDMI PHY | `0xf8ce1800` | `hdmi_1_4/drv_reg_proc.h` HDMI_TX_PHY_ADDR（核对 2.0 是否同址） |
| VDP DHD 控制 | `0xf8ccc000/0xf8ccc400` | 同上 |
| GPU（Mali-450，P3 用） | `0xf9200000` | 厂商 DTS `gpu:gpu@0xf9200000`，IRQ 94；mainline 可用 lima |
| 中断 | VDP IRQ 90，HDMI IRQ 88，HDMI CEC IRQ 147 | 厂商 DTS 中断表 |

CRG（`0xf8a22000`）提供显示相关时钟/复位；VDP PLL 相关寄存器位于 `0xf8a22028/0x2c/0xd8`（`vdp_fpga_define.h`）。

## 2. 厂商驱动参考（4.4.y）

- `source/msp/drv/vo/vdp_v4_0/`（VDP 版本 v4.0，mv200 变体）：显示时序、图层、DHD/HDMI 对接。
- `source/msp/drv/dbe/`：DBE（显示后端）寄存器与图层合成。
- `source/msp/drv/hdmi/hdmi_2_0/`：HDMI 2.0 IP 驱动（HAL + EDID/DDC + infoframe + audio）。
- `source/msp/drv/hifb/`、`source/msp/drv/gfx2d/`、`source/msp/drv/tde/`：framebuffer/2D 加速（可后续做 fbdev 兼容或 DRM dumb buffer 后端）。
- 厂商 4.4 DTS 仅给出中断号，寄存器地址硬编码在 MSP 驱动中。

## 3. Mainline 策略

主line **没有** Hi3798MV300 显示驱动；KiSilicon Kirin DRM 只覆盖 Kirin SoC 且 HDMI 为 DW-HDMI，不可直接复用（本板 HDMI 是海思自研 2.0 IP）。

分阶段：

1. **P2.1 探测骨架（已完成）**：DT 节点 `display@f8cc0000` + `hi3798_drm` 平台驱动，已读取 VDP ID（板卡实测）。
2. **P2.2 KMS 最小可显示**：实现 DRM/KMS 驱动（crtc/plane/connector + dumb buffer），VDP 配置一个固定模式（先 1080p60，后 4K60），通过 DBE 扫描输出；用 `modetest -s` 出测试图案。HDMI 仅做“上电默认模式”初始化（参考厂商 hdmi_2_0 的寄存器序列）。
3. **P2.3 HDMI 完整模式/EDID**：DDC/EDID 读取、模式集、HPD 中断、4K60、颜色格式；HDMI infoframe/audio 配置。
4. **P2.4 HDMI 音频 ASoC**：HDMI PCM（I2S/SPDIF 到 HDMI TX），simple-audio-card 或自定义 card。
5. **P2.5 验证与收尾**：`modetest` 4K60、电视出图、`aplay -D hw:...` 出声、CMA/reserved-memory 大小核算。

## 4. 风险与注意

- HDMI 2.0 IP 为海思私有，寄存器序列长；先以厂商 4.4 驱动为蓝本逐段移植，用板卡实测迭代。
- VDP/DBE 时钟、复位、PLL 配置必须与厂商 CRG 一致；否则无输出或花屏。
- 需要 reserved-memory/CMA 存放 framebuffer（当前 CMA=256M 足够 4K 双缓冲）。
- 4K60 需要 HDMI 2.0 模式与足够带宽；先 1080p60 验证通路。
- DDC/EDID 需 I2C 控制器；mainline 需启用 I2C + pinctrl（HDMI DDC 引脚）。

## 5. 板卡实测记录

- 2026-10-31：`hi3798_drm` stub probe 成功：
  `hi3798-drm f8cc0000.display: VDP [mem 0xf8cc0000-0xf8ccffff] mapped, ID=8380000b 03000177 00000000 00000000`
  Ubuntu 同时正常启动到 login（单核、25MHz eMMC）。
