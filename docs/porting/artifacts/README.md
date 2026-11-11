# P0 产物清单与板卡验证说明（历史文档 ⚠）

> **2026-11-11 清理**：本文为 2026-10-30 P0 阶段历史说明。其中 `artifacts/uImage`、`artifacts/uImage_p1` 已于本次清理归档删除（归档：`/home/jason/cleanup-archive-20261111/workspace/docs/hwtest-intermediate-and-legacy-kernels-20261111.tar.xz`）；现网启动走 eMMC FIP（sha1 `2dea80c5…`，见 [FINAL-STATUS-2026-11-10.md](../FINAL-STATUS-2026-11-10.md)）。

生成时间：2026-10-30
内核：Linux 7.3.0 mainline（arm64）
工具链：Ubuntu 26.04 cross gcc 15.2.0（`/home/jason/bringup-7.3/toolchain`）
构建目录：`/home/jason/bringup-7.3/{src/linux-7.3,out}`

## 1. 产物

| 文件 | 大小 | sha256 | 说明 |
|---|---|---|---|
| `artifacts/uImage` | 4,972,013 B (4.8M) | `1e9429693287c247b6ba45191278f160f3d595caa30eb8c733baa3079cbab8c5` | 烧录到 kernel 分区；uImage(Image+DTB) |
| `artifacts/dtb/hi3798mv300-poc.dtb` | 1,445 B | `329162db736f4df128a36eb57632655341aa922819cc4958e98d8ee8f6c97c57` | 已追加在 uImage 尾部；单独保留供校验 |
| `artifacts/dts/hi3798mv300-poc.dts` | — | — | DTS 源码（与内核树同源） |

> 中间产物 `out/Image`（4,970,504 B，sha256 `e5a7d559255ccd1b067ccaaed93c390e99991b2f34e352a0f562c1e22fc30010`）未入库。

## 2. uImage 布局（fastboot bootm 约定）

```
[64B uImage header: magic 0x27051956, arch=ARM64(22), comp=none,
 load=0x2000000, ep=0x2000000, size=len(Image)=4970504]
[Image 4,970,504 B]
[hi3798mv300-poc.dtb 1,445 B]   ← fastboot 用 image_get_image_end() 定位
```
校验命令：
```sh
python3 docs/porting/scripts/mkuimage.py --verify /home/jason/bringup-7.3/out/uImage
```

## 3. 板卡验证步骤（P0，用户执行）

1. HiTool 连接板卡；按 `configs/hi3798mv300/prebuilts/emmc_partitions.xml` 的分区，将 `uImage` 烧到 **kernel 分区**（起始 14M，长 32M，对应 `hi_kernel.bin`）。
2. bootargs（P0 可无 rootfs）：
   ```
   console=ttyAMA0,115200 earlycon=pl011,0xf8b00000 keep_bootcon cma=256M
   ```
   若使用 ubuntu 启动文件，则按 runbook 使用 `root=/dev/mmcblk0p8 rootfstype=ext4 rootwait rw`（P1 才需要）。
3. 串口 115200-8N1，上电；fastboot 执行 `bootm 0x1FFFFC0`（现有 `emmc_bootargs_ubuntu.txt` 的 bootcmd 即此地址）。
4. 预期串口输出（关键行）：
   - `Booting Linux on physical CPU 0x0000000000 [0x410fd034]`
   - `Linux version 7.3.0 ... aarch64`
   - `earlycon: pl011 at MMIO 0x00000000f8b00000 (options '115200')`
   - `Kernel command line: console=ttyAMA0,115200 earlycon=pl011,0xf8b00000 keep_bootcon cma=256M`

## 4. 失败判据与下一步

| 现象 | 判定 | 下一步 |
|---|---|---|
| 完全无内核输出（fastboot 正常） | fastboot 未进入 arm64 启动路径（TEE/ATF 分支未启用） | 触发 D3：预案 A 移植 ATF / 预案 B 给 fastboot 加非 TEE arm64 启动 |
| 有 U-Boot 输出后无内核输出 | uImage 头/DTB 追加错误或 load 地址错 | 复核 `mkuimage --verify` 输出与 flash 偏移 |
| 打印 earlycon 后 panic/重启 | DTS 中断/定时器/内存描述问题 | 抓完整串口日志，按 runbook 排障 |

**请把串口完整日志（或前 200 行 + 最后 panic）发回，作为 P0 gate 的输入。**
