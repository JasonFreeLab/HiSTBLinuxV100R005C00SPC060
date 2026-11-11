# REF-ARCHAEOLOGY：原厂 PNGD（PGD）用法考古与"整幅硬件解码"可行性定档

> 任务：T1 / task-1（owner: ref-arch），2026-11-10。
> 写范围：`ref/**`、本文件。**不涉及板卡操作**（板卡由 board-eng 独占）。
> 关联前文：[`../artifacts/hwtest-2026-11-07/fixes/png-08/PNG-08-SPIKE-2026-11-10.md`](../artifacts/hwtest-2026-11-07/fixes/png-08/PNG-08-SPIKE-2026-11-10.md)（本报告修正其 §1.2 "vendor 栈全为软件" 的表述）、[`../artifacts/hwtest-2026-11-07/fixes/png-01/FIX-REPORT.md`](../artifacts/hwtest-2026-11-07/fixes/png-01/FIX-REPORT.md)（E0–E8 矩阵）。

---

## 0. TL;DR（先回答 Lead 的 5 个问题）

| # | 问题 | 结论（证据见正文） |
|---|---|---|
| 1 | **原厂到底怎么用这块 PNGD？** | 原厂唯一的用户态实现 = 一个**改造过的 libpng**（固件实机里是 libpng **1.2.46**，`/lib/libpng.so`，sha1 `df34612a…`，ARM32），内含 `HIPNG_*` 硬件加速层、字符串 `/dev/hi_png`、导出 26 个 `HIPNG`/`HI_PNG_*` 符号。**使用模型：把 PNG 文件里所有连续 IDAT 块按 `[u32 len]["IDAT"][payload][u32 crc]` 伪帧格式一次性拷入 1..N 个 ≥128 KB 的 MMZ 缓冲链（每段 `PNG_ALLOC_BUF`+`PNG_SET_STREAMLEN`），全部挂好后只发一次 `PNG_DECODE`（阻塞，内核侧 2 s 超时）；硬件每耗尽一段发 `RESUME(0x2)`，内核 ISR 取链上下一段、重写 `BitBufSt/End`+`BitStreamSt/End` 并写 `ResumeStart=1`；`FINISH(0x1)` 才算完。**不存在"整文件一次 DMA 直接出整幅"的另一条路径**。 |
| 2 | **有没有可整幅成功的实现？** | **有代码、无证据**：可整幅的代码路径就是上述 HIPNG libpng（`hipng_read_stream`→`HI_PNG_Decode`→`HI_PNG_GetResult`），但**原厂固件里没有 PNG 内核驱动**（`kernel_emmc.bin`/ramdisk/recovery 全部无 `hi_png`/`PNG_REG` 符号，无 `.ko`，`/lib/modules` 不存在）→ 该固件上加速 libpng 打开 `/dev/hi_png` 必然失败并回退软件。**未找到任何"原厂真机跑通整幅硬件 PNG"的二进制/日志证据**。 |
| 3 | **更新版 SDK 是否修过我们手上的 bug？** | **没有**。两个 Linux SDK tarball（R005C00SPC050 / R006C00SPC050）的 `drv/png` 都是 **2010/2014 老实现**；本地 SPC060 是 **2018 重写**，但把注释/空行/日志归一化后，**流控、RESUME、寄存器序列、ioctl 语义逐行同构**（仅 config 宏改名、日志、NULL 防御、IRQ 返回值适配）。Android SDK（R001C00SPC065，2016）里的 HAL 是同一份代码移植到 libpng 1.6.25，同样无流控修复。**无可移植修复。** |
| 4 | **正确寄存器序列是什么？** | 见 §4（含 `HalOpen` 一次性配置、每次 decode 的 `Size/Type/Transform/Flt/Tgt/BitBuf/BitStream→DecStart`、resume 的 4 地址寄存器 + `ResumeStart`）。关键语义：**`BitBuf`=分配缓冲物理区间，`BitStream`=其中有效码流区间**，两者同基址不同长度；RESUME 时**两个区间一起改到下一段**。 |
| 5 | **有寄存器文档吗？** | **没有 PGD 寄存器级字段文档**（已查 HiRegBin `hi3798mv300_reg_base_v1.5.0.xlsm` 45 个 sheet、doc/Hi3798mv300 全部 md/PDF、地址空间对表、SDK 头/注释）。只确认：地址映射 `PGD 0xF8C70000–0xF8C7EFFF(60K)` + `PGD MMU 0xF8C7F000–0xF8C7FFFF(4K)`；时钟/复位在 `PERI_CRG33`（`pgd_cken`/`pgd_srst_req`，CRG 偏移 0x84 = `0xF8A22084`）与 `PERI_CRG210`（`pgd_smmu_cken`/`pgd_smmu_srst_req`，偏移 0x348）。 |

> **与同目录 T2 `CODE-ANALYSIS.md` 的对齐（重要）**：T2 的板上证据（IDAT-only、单缓冲 215,622 B、1920×1080 RGB8）显示：**整条码流都在一个节点里**时，仍出现 `Int=0x2`（RESUME）且停在行 15（≈只消费 0.9–1 KB zlib 输入）。⇒ **"链上第 2 段没供上"不是本次停止的必要原因**；RESUME 更像是**早发的 re-arm/脉冲请求**（T2 §4 的结论）。本报告 §4.3/§6 据此补充：**原厂驱动在 `RESUME` 且无下一节点时连 `ResumeStart` 脉冲都不发**（`png_osi.c:1169-1187` 的 `if(next && len)` 整块被跳过）——即 vendor 代码结构里**没有"同段续跑"路径**；如果本硅片的 RESUME 是早发 re-arm，那么**原厂自己的驱动在结构上也无法整幅完成**，这与本报告 §3（原厂无成功证据）一致，也意味着 board-eng 的"RESUME 无 next 时 pulse `ResumeStart=1`、不改地址"变体（T2 的 P1）是一条**原厂从未实现的合理路径**，值得优先验证。

> **对 board-eng 最重要的一条（#188 现象的新解释）**：内核驱动在 `PngOsiAllocBuf` / `PngOsiSetStreamLen` 里**硬性要求 `eState==NOSTART`**（`source/msp/drv/png/src/png_osi.c:328-331`、`:460-464`，否则返回 `HI_ERR_PNG_DEV_BUSY`）。因此"先解第一段、收到 RESUME 再喂下一段"的**按需供给设计在驱动层是不可能的**；必须在 `PNG_DECODE` 之前把**整条链**（≥2 段时）全部 `AllocBuf`+`SetStreamLen` 好。若工具是"解一段→轮询→再 alloc/append"，第 1 段耗尽后 ISR 拿不到 `u32NextPhyaddr`（或 next 的 `u32StreamLen==0`），驱动**静默不动作**（`png_osi.c:1169-1187`），硬件停在等码流，2 s 后 `PngOsiDecode` 超时置 `ERR`/state=3——与 #188 现象逐字吻合。

---

## 1. 证据来源与指纹

### 1.1 原厂 eMMC（`/mnt/f/design/Hi3798/FW/BK/BK/`）

| 文件 | 指纹 | 结论 |
|---|---|---|
| `system_emmc.img` | ext4 700 MiB；sha1 `f8bbc1fc7b24fe9c111cbae18e5c207567d7022f` | **Android** 系统（`/app /framework /priv-app /vendor /xbin`），非 Linux |
| ├ `/lib/libpng.so` | 103,712 B，ELF32 ARM EABI5 stripped；sha1 `df34612a913c71a630c75c45e62c2615f1e1dafa`；内含 `/dev/hi_png`、`HI_PNG`×11、26 个 HIPNG 符号 | **原厂硬件加速 libpng（libpng 1.2.46）**，本报告 §2 的逆向对象；已导出到 `ref/vendor-bk-android/vendor-libpng.so` |
| ├ `/bin/pngtest` | 17,740 B，ELF32 ARM；sha1 `b74efd30de95cac288fa9ca09344c8b96ca878ca` | **标准 libpng pngtest**（只 import `png_create_read_struct`/`png_read_rows`/`png_write_*` 等软件 API），不是硬件测试工具；已导出到 `ref/vendor-bk-android/vendor-pngtest` |
| ├ `/vendor/lib` | 仅 `libbt-vendor_uart.so`、`libhi_sample_common.so` | **无 libpng.so、无 libhigo/higoadp、无 PNG 插件** |
| ├ `/vendor/bin` | 仅 `sample_cc` | 无 png 工具 |
| `kernel_emmc.bin` | Android bootimg（kernel 0x8ac131@0x3008000, ramdisk 0x64f37）；uImage `Linux-3.18.24_hi3798mv2x`；sha1 `ec8d5121e760a56a6677a6fb0ca79801d36a0012` | 反汇编/字符串：**无 `hi_png`/`PNG_REG`/`PngHal` 符号**（全文件小写 `png` 仅 3 处，均为无关字符串）；ramdisk 解开无 `.ko` |
| `recovery_emmc.bin` | uImage 3.18.24，payload 4,942,873 B zImage；sha1 `d5fda410c2520bd5b92b28a93fbf45ccef47785c` | 同样无 `hi_png`/`PNG_REG`（payload 中 `png` 仅 3 处） |
| `fastplay_emmc.bin` | 头部全 0 的 40 MiB 稀疏/空分区（`file`=data），无内核/无 PNG | 无驱动 |
| `userdata_emmc.img` | 5.2 GiB ext4；全镜像 `grep -a hi_png` **0 命中** | 无 PNG 驱动/测试工具残留 |

> 说明：`chunks/sys00..sys09` 是 `system_emmc.img` 的 10 段拆分副本，不额外包含驱动。

### 1.2 SDK 包（`/mnt/f/design/Hi3798/SDK/`）

| 包 | sha1 | PNG 相关内容 | 处理 |
|---|---|---|---|
| `HiSTBLinuxV100R005C00SPC050.tar.gz`（1.96 GB） | `2b75e1ad2efbc966037f50f4e0ad713ffb893e` | `source/msp/drv/png/**`（2010/2014 老驱动：`png_hal.c`、`png_hal.h`、`png_osi.c`、`png_osires.c`、`png_osr.c`、`png_proc.c`、`png_define.h`）、`source/msp/api/png/**`（`inc/`、`src/src_hard/{hi_png_api.c,png_accelerate.c,hipng*.h}`、`libpng patch`）、`sample/png/**`、`drv/include/hi_drv_png.h`；higo 库（含 `libhigo_png.so`） | 已解 → `ref/HiSTBLinuxV100R005C00SPC050/`（2.7 MB） |
| `HiSTBLinuxV100R006C00SPC050.tar.gz`（1.79 GB） | `9cb7ac3ae9c673965686aeca54d3fd39481ef9bb` | 同上但 api 打成 `api/png/libpng-1.4.16/`、`libpng-1.6.16/`（`hi_png_api.c` 内嵌），另 `bak/readme.txt`="保持和X5HD一致，没有实现也没有用" | 已解 → `ref/HiSTBLinuxV100R006C00SPC050/`（5.6 MB） |
| `HiSTBAndroidV600R001C00SPC065.rar`（1.87 GB） | `3986e17d4df55e59189820f1c04453d45f37dc2a` | 外层=文档包（362 文件，无 png 源码）；**内含 `software/HiSTBAndroidV600R001C00SPC065.tar.gz`（888 MB）Android 源码 SDK**，其中 `device/hisilicon/bigfish/sdk/source/msp/drv/png/src/{png_osi,png_osr,png_proc}.c`（2016/2014，**缺 hal/osires 头与 HAL 源**）+ `api/png/libpng-1.6.25/{hi_png_api.c,png_accelerate.c,hipng*.h}` | Android SDK png 子树已解 → `ref/android-v600r001c00spc065/`（5.2 MB）；888 MB tarball 留在 `/tmp/andsdk/`（未入 ref，太大） |

### 1.3 寄存器/文档

| 资料 | 结论 |
|---|---|
| `regs/Hi3798mv300/sysreg/hi3798mv300_reg_base_v1.5.0.xlsm`（HiRegBin v1.5.0，45 sheets） | 无 PGD/PNG 寄存器 sheet；只有 `crg_ctrl` 的 3 行 PGD 相关：`PGD Clock Off and reset`（offset 0x84）、`PGD SMMU`（offset 0x348），与驱动 `PERI_CRG33`/`PERI_CRG210` 一致 |
| `doc/Hi3798mv300/hardware/Hi3798M V300/MV300 地址空间映射_对表.md` | 第 164/165/412–416 行：`PGD 0xF8C70000–0xF8C7EFFF 60K`、`PGD MMU 0xF8C7F000–0xF8C7FFFF 4K`；并注明 MV300 DTS 无该块 MMIO 节点，"仅 MV200 表"有地址级信息 |
| `doc/Hi3798mv300/**` md/PDF/HiRegBin 指南 | 无 BitBuf/BitStream/RESUME/RDC/FLT 字段说明；PDF 为 book118 预览图转写，不含寄存器章节 |
| SDK 头/注释（三个版本） | 只有寄存器结构体字段名与中文一句话注释（"续码流中断""rdc 模块写 buf 越界"等），无时序/字段语义 |

---

## 2. 原厂用户态实现的逆向（`/lib/libpng.so`）

产物：`ref/vendor-bk-android/`（原文件 + 完整/关键区反汇编 + 从 R005 取出的 uapi 头）。

### 2.1 它确实是"原厂硬件客户端"

- `readelf -s`：`HI_PNG_Open/Close/CreateDecoder/DestroyDecoder/AllocBuf/ReleaseBuf/SetStreamLen/GetStreamLen/Decode/GetResult/GetReadPtr` + `hipng_read_stream/read_rows/set_transform/select_decmode/copy_rows/prepare_switch/get_result/get_readfn/read_chunk_header/read_fn/create_read_struct_hw/destroy_read_struct_hw/set_outfmt/read_transform_info/finish_switch`（26 个）。
- `HI_PNG_Open` 反汇编（`vendor-libpng-hipng-disasm.txt` @ `0x14910`）：`open(path, 0x1002)`，path 字符串即 `/dev/hi_png`（文件内偏移 100,159 = `/dev/hi_png\0Internal Err!`）。
- `NEEDED`：`liblog, libz, libcutils, libutils, libc`（Android bionic），libpng 版本串 `libpng version 1.2.46 - July 9, 2011`。

### 2.2 ioctl 清单与 ABI 对照（关键：**与原厂 ABI 完全一致，无额外 PNG ioctl**）

原厂 `.so` 里 `ioctl@plt=0x4be4`（`.rel.plt` 第 27 项），全文件仅 11 处调用：`png_read_destroy`×2、`HI_PNG_CreateDecoder`、`HI_PNG_DestroyDecoder`、`HI_PNG_AllocBuf`、`HI_PNG_ReleaseBuf`、`HI_PNG_SetStreamLen`、`HI_PNG_GetStreamLen`、`HI_PNG_Decode`、`HI_PNG_GetResult`、`hipng_read_fn`。字面量池取值与本仓库 uapi（`ref/HiSTBLinuxV100R005C00SPC050/source/msp/drv/include/hi_drv_png.h:87-94`，原 `source/msp/drv/include/hi_drv_png.h`）逐一对齐：

| ioctl | 原厂 `.so` 字面量 | 本仓库头计算 | 一致 |
|---|---|---|---|
| `PNG_CREATE_DECODER` = `_IOR('s',1,handle)` | `0x80047301` | `0x80047301` | ✅ |
| `PNG_DESTROY_DECODER` = `_IOW('s',2,handle)` | `0x40047302` | `0x40047302` | ✅ |
| `PNG_ALLOC_BUF` = `_IOWR('s',3,PNG_GETBUF_CMD_S)` | `0xc0187303`（size 0x18=24，`HI_U64` 8 字节对齐） | 24 | ✅ |
| `PNG_RELEASE_BUF` = `_IOW('s',4,handle)` | `0x40047304` | `0x40047304` | ✅ |
| `PNG_SET_STREAMLEN` = `_IOW('s',5,PNG_SETSTREAM_CMD_S)` | `0x400c7305`（12B） | 12B | ✅ |
| `PNG_GET_STREAMLEN` = `_IOWR('s',6,...)` | `0xc00c7306` | `0xc00c7306` | ✅ |
| `PNG_DECODE` = `_IOW('s',7,PNG_DECODE_CMD_S)` | `0x404c7307`（size 0x4c=76 → `sizeof(HI_PNG_DECINFO_S)=72`） | 72（`bSync`4+3res+`Phyaddr`/`Stride`8+`INFO`16+`TRANSFORM`40） | ✅ |
| `PNG_GET_DECRESULT` = `_IOR('s',8,...)` | `0x800c7308` | `0x800c7308` | ✅ |

其余 5 处（`0xc0044901`、`0xc0084902`、`0xc0084907`、`0xc0144900`、`0xc0204909/0xa`，magic `'I'`）是 **MMZ/ION 式内存分配器 ioctl**（在 `HI_PNG_AllocBuf` 内联的 alloc/map/free 辅助函数里），**不是 PNG 控制 ioctl**。⇒ 原厂客户端**没有任何我们没有的 PNG reset/continue/set-end-addr ioctl**；`FinalEndAddr` 在用户态根本不存在。

### 2.3 关键行为（带地址的伪代码，ARM32 Thumb-2）

`hipng_read_stream`（`0x14ee8`，对应本地 `source/msp/api/png/png-hal/src_hard/png_accelerate.c:252-402`）：
```
idat_size = png_ptr->idat_size;                       // 0x1d0
if (idat_size==0 || idat_size > UINT_MAX-8) fail;     // 0x14f28-0x14f3c
idat_total = idat_size + 8 + 4;                       // [len][IDAT][payload][CRC]
chunk_head[0..3]=BE32(idat_size); chunk_head[4..7]="IDAT";
loop:
  if (stBuf.u32Size==0 && stTempBuf.u32Size==0):
      stBuf.u32Size = idat_total;                     // 0x14f44: 首块请求 = 首个 IDAT 大小+12
      HI_PNG_AllocBuf(handle,&stBuf);                 // 0x14f84 -> 实际分配到 >=128KB（见 2.4）
  else if (stBuf.u32Size==0): 用 stTempBuf 顶上
  copy chunk_head[8-u8ReadHeadCount ..] 到 buf;       // 先写 4B 长度+4B "IDAT"
  copy min(idat_total, stBuf.u32Size) 字节 payload(含CRC) 到 buf;
  if buf 满: HI_PNG_SetStreamLen(handle, phy, written);// 0x150dc
  if 下一个 chunk 头为 "IDAT": 重置 chunk_head 继续；
  else: HI_PNG_SetStreamLen(最后一段) 并保存 idat_size/crc/chunk_name; end
```
要点：**缓冲链在 `hipng_read_stream` 内就已全部挂好**（`AllocBuf`+`SetStreamLen` 多次），函数返回后 `hipng_read_rows` 才 `HI_PNG_Decode`（见下）——即"全链预挂、单次启动"。

补充（Lead 问）：原厂 `.so` **只导出 `hipng_read_stream`，没有 `hipng_push_stream`/`hipng_push_decode`**（`-T` 符号表 26 个里无此二者）。`push_*` 是后续为 libpng 1.6 progressive/分块读适配新增的变体（本地 `png_accelerate.c:619` 起），其语义仍是把 IDAT 塞进同一套 `AllocBuf/SetStreamLen` 链；不是原厂固件里的路径。

分段数量示例（按公式）：若一幅图的所有 IDAT 帧合计 1.5 MB，`ALLOC_BUF` 每次把请求量抬到 ≥128 KB，则约 `ceil(1.5MB/128KB)=12` 段 ⇒ 阻塞 Decode 期间应看到 **11 次 RESUME**；若合计 ≤128 KB（多数小图）⇒ **1 段、0 次 RESUME**。原厂代码对"段数"没有任何上限配置项，只受 MMZ 总量约束。

`hipng_read_rows`（`0x15474`，本地 `png_accelerate.c:1677-1783`）：
```
select_decmode();                        // HW/HWCOPY/SW 选择（见 2.5）
if HW/HWCOPY:
  hipng_read_stream();                   // 全 IDAT 入链
  set_transform();                       // 填 HI_PNG_DECINFO_S（bSync = pstHwStruct->bSyncDec）
  HI_PNG_Decode(handle,&stInfo);         // 单次 ioctl，阻塞
  if bSync: eState=FINISH; if HWCOPY: hipng_copy_rows(...)
  else:     eState=DECING; pstHwStruct->image=row;
```
`bSyncDec` 在 `hipng_create_read_struct_hw` 里硬编码 **`HI_TRUE`**（本地 `png_accelerate.c:146`；原厂 `.so` 同一函数 `0x14be2` 同款初始化）⇒ **原厂就是阻塞式单次 Decode + 内核 2 s 超时**，没有轮询/重试/分段续喂逻辑。

### 2.4 分段与缓冲常量（Lead 重点）

- `HI_PNG_AllocBuf`（`.so` `0x14c60`）：
  ```
  size = stBuf.u32Size;                 // 调用方给的首个 IDAT+12
  if (size < 0x20000) size = 0x20000;   // 0x14cb2-0x14cb8：最小 128KB
  if (size+16 溢出) fail;
  size = (size+15) & ~15;               // 0x14cc4-0x14cc6：16B 对齐
  phy = AllocMem(size, 16, "iommu|NULL", "HIPNG_STREAM_BUF");   // 内部 'I' magic ioctl
  vir = MapCached(phy);
  ioctl(PNG_ALLOC_BUF, {handle, phy, size, vir});
  ```
  本地同源：`source/msp/api/png/png-hal/src_hard/hi_png_api.c:81`（`PNG_BUF_DEFAULTSIZE (128*1024)`）、`:364-402`。
- 因此：**段数 = ceil(总 IDAT 伪帧码流 / 实际段容量)**；每段容量 = max(首个 IDAT+12, 128KB)（后续可能因 HAL 对剩余空间再 Alloc 而增长）。一张 1080p RGB PNG 的 IDAT 总量通常 >128KB ⇒ **2 段及以上 ⇒ 会出现 ≥1 次 RESUME**；≤128KB 的图 ⇒ 单段 ⇒ **0 次 RESUME，start→finish**。这与"head 正确、第 1 个 RESUME 后静默"完全自洽（= 链上第 2 段没供上）。
- 其它相关常量：`HIPNG_MAX_WIDTH/HIPNG_MAX_HEIGHT = 4096`、`HIPNG_MIN_HEIGHT = 1`、`HIPNG_MAX_MEM = 100 MB`、`PNG_INFLEXION_SIZE = 40*40 = 1600`（像素数小于此且软硬都可用时**强制软件**）、`HIPNG_MAX_WIDTH/HEIGHT` 用 `>=` 判断。
- 没有除 128KB 之外的"分段大小"常量；`PNG_CHUNK=32384/1600` 之类是测试工具自定义切分，不是原厂概念。

### 2.5 硬件/软件选择与回退

`hipng_select_decmode`（`.so` `0x14614`；本地 `png_accelerate.c:1423-1509`）：`HW_DEC=0x2`、`HWCOPY_DEC=0x4`、`SW_DEC=0x1`。`HIPNG_ACCELERATE_SUPPORT`（本地 `png_accelerate.c:1263-1312`）拒绝：隔行 PNG、`PNG_PACK/SHIFT/SWAP_BYTES/INVERT_MONO/BACKGROUND_EXPAND/GAMMA/INVERT_ALPHA/USER_TRANSFORM/RGB_TO_GRAY*`、`width>=4096`、`height>=4096 或 <=1`、调色板（当 `CONFIG_GFX_MMU_SUPPORT`）、`read_row_fn!=NULL` 等。**⇒ 7 个 interlace pass 地址/`Pass0..6Stride` 在原厂代码里从未被写过（`PngHalSetImgInfo` 强制 `u32InterlaceType=0`，`source/msp/drv/png/src/png_hal.c:349`），隔行 PNG 一定走软件。**
失败路径：`hipng_push_switch_start`/`hipng_prepare_switch` 把已推码流回送给软件 inflate 继续解（`HIPNG_STATE_PUSHSTREAM_FAILED/DECODE_FAILED`）——**原厂把硬件当"机会加速"，设计上就允许回退软件**，"全硬件不可回退"从来不是原厂目标。
`HI_PNG_GetReadPtr`（`.so` `0x15370`）= 返回软件回退的 `HI_PNG_READ_FN` 回调（分配 8B 上下文），与本地 `hi_png_api.h` 语义一致。

---

## 3. 原厂固件是否存在"跑通 PNGD"的证据：**否**

1. **内核无驱动**（§1.1）：`kernel_emmc.bin`（Android bootimg，kernel+ramdisk 全查）、`recovery_emmc.bin`、`fastplay_emmc.bin`、`userdata_emmc.img` 均无 `hi_png`/`PNG_REG`/`PngHal` 符号；`/lib/modules`、`/vendor/lib/modules` 都不存在；root 下无 `.ko`。
2. **用户态无其他消费者**：全镜像 `/dev/hi_png` 字符串**只出现在 `/lib/libpng.so`**；`/vendor/lib`、`/vendor/bin` 无 libpng/higo/PNG 插件；`/bin/pngtest` 是标准 libpng 测试程序。
3. **结论**：该量产 Android 上加速 libpng 会在 `HI_PNG_Open()` 打开 `/dev/hi_png` 失败 → `hipng_create_read_struct_hw` 返回 NULL → 回落软件 libpng。**因此这份固件反而证明"原厂产品发布了带硬件 PNG 代码的 libpng，但没带驱动"**，不能作为"整幅硬件解码可用"的证据。

> 对 png-08 的修正：png-08 §1.2 用 `libhigo_png.so` 的导入符号推出"vendor PNG 全是软件"——该结论只对 **HIGO 插件**成立（HIGO 的 PNG 解码插件确实是软件 libpng）。**原厂用户态另有一条独立的、真正硬件的 `libpng.so`（本报告对象）**，两者是不同组件。因此"vendor 栈为软件"不应再作为 NA 的理由；NA 的真正依据是"原厂无驱动、无成功证据 + 驱动流控无文档"。

---

## 4. 原厂硬件整幅解码的权威序列（寄存器级）

来源：`ref/HiSTBLinuxV100R005C00SPC050/source/msp/drv/png/**`（2010 版）与本地 `source/msp/drv/png/**`（2018 版）逐函数比对（§5 证明语义一致）。

### 4.1 一次性配置（每次 `HI_PNG_Open`/`PngHalOpen`）

`source/msp/drv/png/src/png_hal.c:81-101`（老版同名函数一致）：
```
CRG: PERI_CRG33.pgd_cken=1; pgd_srst_req=1; 等 u32RstBusy&&1 清零; pgd_srst_req=0; udelay(1); SMMU init
RDC   = g_u32RdcBufPhyaddr            // 32KB，PngOsiInit 里 AllocMem("PNG_RdcBuf",32*1024,16)
AXIConfig = 0x20441
TimeOut   = 0x80008
IntMask   = 0xffffffff               // 原厂"开所有中断"写法（1=使能）
ErrMode   = 0xffff0000
SMMU: MapSmmuReg(base+0xf000); InitSmmu
```

### 4.2 每次解码（`PngOsiDecode` → `PngHal*`）

`source/msp/drv/png/src/png_osi.c:708-935` + `png_hal.c:335-620`：
```
FltSt  = flt_phy;  FltEnd = flt_phy + rowbytes_aligned16 - 1     // 单行 filter buf（用户/驱动分配）
FinalStAddr = out_phy;  Stride = stride_aligned16
BitBufStAddr    = seg_phy; BitBufEndAddr    = seg_phy + alloc_size - 1      // 分配区间
BitStreamStAddr = seg_phy; BitStreamEndAddr = seg_phy + valid_len - 1      // 有效码流区间
Size  = {Width[12:0],Height[25:13]}；Type = {BitDepth[4:0],ColorFmt[7:5],InterlaceType=0,...}
Transform / TransColor0/1 = 格式转换（见 png_hal.c:365-477）
DecStart = 0x1
wait_event_interruptible_timeout(..., 2000ms)    // png_osi.c:892
```

### 4.3 RESUME 续传（ISR，`png_osi.c:1096-1191`）

```
int = uInt; uInt &= int;                 // 读+写回清零（png_hal.c:639）
if int & FINISH(0x1): eState=FINISH; 关时钟; wakeup; return
if int & ERR(0x4):    eState=ERR;    wakeup; return
if int & RESUME(0x2):
    cur = cur->u32NextPhyaddr; vir = cur->pNextViraddr;
    if (cur != 0 && ((PNG_BUF_HEAD_S*)vir)->u32StreamLen):
        BitBufSt/End    = cur, alloc_size 区间
        BitStreamSt/End = cur, StreamLen 区间
        ResumeStart = 0x1
    // 否则：什么都没做（无日志、无错误、无超时定时器）
```
**关键结论**：vendor 的"续传"是**内核 ISR 自动切换已预挂的链**，用户态不参与。`ResumeStart` 是"我给了下一段，继续"的握手，不是"重新开始"。

**结构性缺口（本报告新结论）**：原厂 ISR 的 `if (next_phy && next->StreamLen)` 是**唯一**的 resume 动作；条件不满足时**既不切地址、也不 pulse `ResumeStart`**，没有"同段 re-arm 继续"的分支。若实际硅片的 RESUME 早于窗口耗尽（T2 板上证据：215 KB 码流、~0.9 KB 处即 RESUME），则 **vendor 自身这套驱动在结构上也无法完成整幅**；这解释了"原厂有完整客户端代码但无成功记录"的矛盾，并把 board-eng 的最短路径指向"无 next 时保持地址不变、只 pulse `ResumeStart=1`"（对照 `png_osi.c:1169-1187`）。

### 4.4 硬件能力/边界（原厂代码里的硬约束）

- 最大 4096×4096，单幅输出 ≤100 MB；不支持隔行（interlace 永远 SW）；调色板在 SMMU 开启时走 SW/CLUT 后处理。
- 输出缓冲需 16B 对齐 stride（`PngHalSetTgt` 只写 `FinalStAddr`+`Stride`；**`FinalEndAddr`(0x54) 原厂两版都从不写**）。
- `RDC` 32 KB、`FLT` 单行（rowbytes 16B 对齐）必须由调用方提供有效物理地址；`BitBuf/BitStream` 均为物理地址（SMMU 关闭时 bypass，开启时须 IOMMU 映射）。
- `uIntMask=0xffffffff` 表示全使能（老/新一致）；`ErrMode=0xffff0000` 表示错误只上报不停机（低 16 位 stop 策略全 0）。

---

## 5. 与本地 SPC060 / 参考 SDK 的差异清单

### 5.1 各参考版本的年代（证据：文件头 Copyright/Created）

| 来源 | drv/png | api HAL | libpng | 备注 |
|---|---|---|---|---|
| `ref/HiSTBLinuxV100R005C00SPC050` | 2010/2014（`png_hal.c` Created 2010/10/12） | `src/src_hard/png_accelerate.c` Created 2010/10/18 | `patch_1.6.29` + `inc_soft` | 老实现完整 |
| `ref/HiSTBLinuxV100R006C00SPC050` | 2010/2014（同上，Copyright 2014） | 内嵌 `libpng-1.4.16/`、`libpng-1.6.16/` | 1.4.16/1.6.16 | 老实现，另带 `bak/readme.txt`："保持和X5HD一致，没有实现也没有用，请用其它代替" |
| `ref/android-v600r001c00spc065`（Android SDK，2016 打包） | 2014（Copyright 2014，Created 2010）⚠ 只发 `png_osi.c/png_osr.c/png_proc.c`，**无 hal/osires/define/头** | `api/png/libpng-1.6.25/{hi_png_api.c,png_accelerate.c,hipng*.h}` Created 2010 | 1.6.25 | Android 分支适配 |
| 本地 `HiSTBLinuxV100R005C00SPC060` | **2018 重写**（Copyright 2018, Created 2018/01/01） | `png-hal/src_hard/*` | `component/png/patch/patch_linux_1.6.32`（`-DHIPNG_ACCELERATE`） | 当前主线 |

### 5.2 归一化 diff（去注释/空行、压缩空白后 `difflib` 比对）

| 文件对 | 归一化行数 | 变化 hunk | 变化性质 |
|---|---|---|---|
| R005 `png_hal.c` ↔ 本地 | 436 / 467 | 11 | 配置宏改名、日志、`CHECK_PNG_*` 防御、SMMU 条件；**寄存器写入逐条一致** |
| R005 `png_osi.c` ↔ 本地 | 916 / 931 | 30 | `CONFIG_PNG_PROC_DISABLE`→`CONFIG_GFX_PROC_UNSUPPORT`、日志、初始化防御、`EXPORT_SYMBOL` 等价重排；**AllocBuf 链/SetStreamLen/RESUME/2 s 等待逐行一致** |
| R005 `png_osires.c` ↔ 本地 | 153 / 163 | 8 | `PNG_UP`→`PNG_UP_INT`（中断上下文保护）、日志 |
| R005 `png_osr.c` ↔ 本地 | 313 / 419 | 22 | 返回码从 `0/-1` 改为 `HI_SUCCESS/HI_FAILURE`、`osal_request_irq` 判定、pro 宏改名 |
| R005 `png_accelerate.c` ↔ 本地 | 1585 / 1769 | 49 | 格式/日志/`HI_GFX_Memcpy` 化、`PNG_LIBPNG_VER>=10500` 兼容、`hipng_read_chunk_header` 签名适配、NULL 防御；**`hipng_read_stream`/`hipng_push_stream`/`hipng_read_rows` 流程一致** |
| R005 `hi_png_api.c` ↔ 本地 | 620 / 586 | 29 | 宏名/初始化/`static` 化；**ioctl 编号与调用顺序一致** |
| Android 2016 `png_osi.c` ↔ R006 | 887 / 891 | 40 | 老实现之间的内核版本适配；RESUME 段完全相同（Android `png_osi.c:1074-1090`） |
| Android 2016 `png_accelerate.c` ↔ 本地 | 1441 / 1769 | 49 | 本地新增 `hipng_check_addr`/`HIPNG_ACCELERATE_SUPPORT` 拆分、`CONFIG_GFX_MEM_MMZ/ION`、防御；**无流控语义变更** |

原厂客户端 `.so` 进一步佐证 ABI 未变：8 个 PNG ioctl 常数与本仓库头文件**逐个相等**（§2.2），`sizeof(HI_PNG_DECINFO_S)=72` 一致。

### 5.3 结论

**"更新版 SDK 修过我们手上的 bug"= 否，且没有可移植的修复。** 三个参考实现（2010 Linux、2016 Android、2018 本地）在 `AllocBuf/SetStreamLen/Decode/RESUME/FINISH` 语义上完全同构；差异全是打包/宏/日志/防御/内核 API 适配。因此 **#188 的整幅失败不可能靠"换/合入新版驱动"解决**，只能是：
(a) 用户态（工具/HAL）没有按"全链预挂 + 单次 Decode"使用；或
(b) 板级（时钟/复位/SMMU/中断/DMA 一致性）使第二段之后硬件不再前进；或
(c) 硬件/固件本身在该板上的 PNGD 有我们尚未定位的缺陷（无文档可依）。

---

## 6. 给 board-eng 的判断与实验建议（主机侧结论，不含板卡操作）

1. **没有原厂 `hi_png.ko` 可"对照/加载"**：原厂固件（§1.1）不含该驱动，任何分区/ramdisk 都没有；`/lib/libpng.so` 是 **ARM32 bionic**（`NEEDED liblog/libcutils/libutils`），不能在本板 aarch64/glibc 上运行，也无法直接和本地 4.4/后续内核模块对照。可用的只有其**源码**（已在 `ref/`）与**行为**（§2）。
2. **待验证假设（按 T2 证据重排，见 `CODE-ANALYSIS.md`）**：
   - **(A，最高) RESUME 是早发 re-arm**：单缓冲整条码流仍 `Int=0x2` 停在行 15 ⇒ 停止与链长无关。驱动 `png_osi.c:1169-1187` 在无 next 时**不发任何 pulse**；原厂代码也没有"同段 re-arm"分支（§4.3）。建议验证"无 next 时保持 `BitBuf/BitStream` 不变、仅写 `ResumeStart=1`"（T2 P1 变体），并观察是否出现第 2 次 RESUME 或 FINISH；同时读 `uInt(0x100)` 全 32 位，重点看 bits16–31 的具体错误位（FltBuf/RdcBuf/FltType/Huff/Zlib*/Adler/Crc）——原厂 ISR 只判 bit2，其余被清掉后不可见（T2 §0-3）。
   - **(B，仍需排除) 链预挂**：驱动硬性要求 `eState==NOSTART` 才能 `AllocBuf/SetStreamLen`（`png_osi.c:328-331`、`:460-464`），所以"解一段→等 RESUME→再喂"在驱动层不可能；但 T2 单缓冲实验已证明**即便全链预挂正确，仍停在行 15**，故 B 不是本次停止的必要原因，只影响 >128 KB 码流的可行性。
3. **码流格式必须带伪帧**：每段内容 = `[BE32 len][\"IDAT\"][IDAT payload][BE32 crc]` 连续拼接；**不是裸 zlib、也不是整文件**（PNG 签名/IHDR/IEND 不进硬件）。`SetStreamLen` 给的是含帧头的实际长度。工具若只喂 zlib 或只喂 payload，会 head 正常、随后 RESUME 后静默（CRC/长度对不上，硬件等下一段/报错位而 ERR 停策略为全 0 不会停）。
4. **单段对照实验**：用码流 ≤128 KB 的小 PNG（单段，0 次 RESUME）验证"start→finish 整幅"是否成立；若成立，说明驱动/寄存器/输出链路全通，问题 100% 在分段续传；再逐步放大到 2 段，观察第 2 段是否被 ISR 正确切换（`bufSt/strSt` 应等于第 2 段 phy，`ResumeStart` 写 1，随后应看到下一次 RESUME 或 FINISH）。
5. **其它可查点**：`uInt` 读回含 `0x2` 之后再无中断 → 若 `uInt` 一直是 0 且 `RstBusy` 为 0，说明硬件真的停在等下一段；若 `uFltBufErr/RdcBufErr` 等错误位出现，按 `ErrMode=0xffff0000`（不停机）会静默——需读 `uInt`(0x100) 全 32 位并打印 `ErrStatics`(0x10c)。`FinalEndAddr`(0x54) 原厂从不写，不必纠结。
6. **不要指望"回退软件"取得全硬件**：原厂自身在 push/decode 失败时会切软件（§2.5）；如果目标是"全硬件"，必须让硬件一次跑完（全链预挂 + 正确伪帧 + 段数正确）。

---

## 7. 复现命令

```bash
# 1) 固件枚举/导出（无需 mount/sudo）
cd /mnt/f/design/Hi3798/FW/BK/BK
debugfs -R "ls -l /" system_emmc.img
debugfs -R "ls -l /lib" system_emmc.img | grep -iE 'png|higo'
debugfs -R "dump /lib/libpng.so /tmp/vendor-libpng.so" system_emmc.img
debugfs -R "dump /bin/pngtest  /tmp/vendor-pngtest"  system_emmc.img
sha1sum /tmp/vendor-libpng.so /tmp/vendor-pngtest
# 2) 内核/ramdisk 检查（Android bootimg）
python3 - <<'EOF'   # 解 kernel/ramdisk 后 strings|grep hi_png; 见 §1.1 参数
EOF
# 3) 反汇编（本仓库自带交叉工具链）
T=tools/linux/toolchains/arm-histbv310-linux/bin/arm-histbv310-linux-objdump
$T -d /tmp/vendor-libpng.so > /tmp/vendor-full-disasm.txt
$T -T /tmp/vendor-libpng.so | grep -E 'HI_PNG|hipng'
$T -rW /tmp/vendor-libpng.so | awk '/\.rel.plt/{f=1;next} f&&/R_ARM_JUMP_SLOT/{print $NF}' | nl   # ioctl 为第 27 项
# 4) SDK 清单/精确解包（示例）
tar -tzf HiSTBLinuxV100R005C00SPC050.tar.gz | grep -E '/(drv|api)/png/'
tar -xzf HiSTBLinuxV100R005C00SPC050.tar.gz --wildcards '*source/msp/drv/png/*' '*source/msp/api/png/*'
# 5) 固件里 Android 源码 tarball（rar 内）
7z e HiSTBAndroidV600R001C00SPC065.rar \
  'customer/HiSTBAndroidV600R001C00SPC065/software/HiSTBAndroidV600R001C00SPC065.tar.gz' -o/tmp/andsdk
tar -tzf /tmp/andsdk/HiSTBAndroidV600R001C00SPC065.tar.gz | grep -E '/png|higo'
```

## 8. 交付物索引

| 路径 | 内容 |
|---|---|
| `ref/MANIFEST-sha1.txt` | 本次落盘全部 242 个文件的 sha1 + 路径（`ref/` 下） |
| `ref/vendor-bk-android/vendor-libpng.so` | 原厂 ARM32 硬件加速 libpng（sha1 `df34612a…`） |
| `ref/vendor-bk-android/vendor-pngtest` | 原厂 `/bin/pngtest`（sha1 `b74efd30…`，标准 libpng 测试） |
| `ref/vendor-bk-android/vendor-libpng-full-disasm.txt` | 全文件 arm objdump -d（1.1 MB，含符号） |
| `ref/vendor-bk-android/vendor-libpng-hipng-disasm.txt` | HIPNG 区（0x13f50–0x1551c）反汇编 |
| `ref/vendor-bk-android/hi_drv_png-uapi-from-r005.h` | 原厂 ioctl/结构定义（来自 R005 tarball） |
| `ref/HiSTBLinuxV100R005C00SPC050/source/msp/{drv,api}/png/**` | 2010/2014 原厂 PNG 栈 + uapi 头 |
| `ref/HiSTBLinuxV100R006C00SPC050/source/msp/{drv,api}/png/**` | 同上另一版本（libpng-1.4.16/1.6.16 内嵌） |
| `ref/android-v600r001c00spc065/device/hisilicon/bigfish/sdk/source/msp/{drv,api}/png/**` | 2016 Android 分支 PNG 栈（libpng-1.6.25 + HAL） |
