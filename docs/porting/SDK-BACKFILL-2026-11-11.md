# SDK 源码回灌记录（2026-11-11）

> 把 mainline 7.3 移植线（`work/`、`port/`）中与 SDK 侧相关的修复回灌到
> `source/`（HiSTBLinuxV100R005C00SPC060，arm32/4.4.y SDK 树），供 SDK 侧构建/维护。
> 主line 驱动（port stubs、7.3 tasklet 适配、轮询完成等）**不回灌**（那是 7.3 平台适配层）。

## 1. PNG（已回灌）

| 内容 | 文件 / 证据 |
|---|---|
| 累计 SDK 补丁（v2–v15：AXI 根因、同 boot 多次解码、ISR 错误分类、Adam7 交错、TDE CLUT 硬件化） | `work/png-hw/code/final/SDK-FINAL-FIX-v15.patch`（`0e960e36…`，754 行，git diff 生成） |
| 关键函数：`PngOsiClutToRgb`（v15 版）+ 新 helper `PngOsiClutDstBpp` | `source/msp/drv/png/src/png_osi.c`（已应用，字节级移植；SDK 侧用原生 `HI_DRV_MODULE_GetFunction(HI_ID_TDE)`，无需 `__symbol_get`） |
| 变换位定义 `HI_PNG_TRANSFORM_INTERLACE 0x80000000`、`CLUT2RGB 0x200` | `source/msp/api/png/include/hi_png_type.h`（7.3 线已加；SDK 原有 CLUT2RGB） |
| CLI 工具（`hi_png_hw --clut-hw` 等） | 属于部署件，不进 SDK 源码树；见 `work/png-hw/code/out/hi_png_hw` |

**v15 `PngOsiClutToRgb` 语义**（SDK 侧同样适用）：CLUT 只能作 source；`job1` CLUT(src, 打包 stride)→临时 MMZ RGB(dst_stride)，
`job2` 临时 RGB→用户缓冲（RGB→RGB copy，**清空 `pu8ClutPhyAddr`**，否则 TDE 会走 `TDE_CLUT_COLORCORRECT` 二次查表）；
`dst_bpp/dst_stride` 按 `g_ClutToRgbTable` 输出格式计算；成功/失败都 `pfnTdeClose()`。

## 2. TDE（无需回灌源码，仅 DTS + 说明）

- SDK 自带完整 TDE 驱动（`source/msp/drv/tde`，MV300 用 `adp/tde_v2_0`），mainline 移植的 17.1k 行驱动即源自该树；
  7.3 适配只在 `tde_osr_k.c`（tasklet 签名/导出表），**不适用于 SDK 4.4**。
- SDK 侧只需：DTS 节点 `tde@f8c10000`（`interrupts=<GIC_SPI 91>`）——
  `work/tde/dts/0002-sdk-hi3798mv300-add-tde-node.patch`（`133f29b1…`）。
- 交叉核对规格见 `work/tde/PORTING-SPEC.md`；CLUT 表格式 = 256×ARGB8888、4B 对齐、颜色扩展模式。

## 3. 未回灌 / 仅 mainline

- `port/png`、`port/tde` 的 port stubs（osal/dma/irq/mmz/class/cdev）、`png_dbg` 参数、轮询完成、DTS mainline 版补丁
  （`work/tde/dts/0001-…`）—— 属于 mainline 7.3 适配层，保留在移植线。
- 64MP/cma=384M FIP、rootfs e2fsck 等属板级运维，不进 SDK 源码。

## 4. 校验

```sh
cd /home/jason/HiSTBLinuxV100R005C00SPC060
git status --short source/msp/drv/png source/msp/api/png   # 应有 M（回灌后）
git diff source/msp/drv/png source/msp/api/png | sha1sum   # 与 SDK-FINAL-FIX-v15.patch 一致
```
