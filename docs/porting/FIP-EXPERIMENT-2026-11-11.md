# FIP 验证与刷写实验（2026-11-11 夜间维护窗口）

## 结论（最终状态）

- **现网 FIP 已恢复为原生产 FIP**：`2dea80c52b4aee1c4be4c644c20f5fac4b5ce844`（12,216,320B = 0x5D34 块，cma=256M，无 TDE 节点）。
- 原始备份：host `docs/porting/artifacts/png-hw/rootfs-rescue-20261111-025848/fip-current-0x7000.bin`；板上 `/dev/shm/fip-orig.bin`（重启清除）。
- 刷写方法：`dd if=<fip> of=/dev/mmcblk0 bs=512 seek=$((0x7000)) conv=fsync; sync`；恢复通道 = U-Boot Ctrl+C（"Press Ctrl+C to stop autoboot" → `fastboot#`）+ `mmc read/bootm`（本次多次实测可用），或 eMMC 空闲区预置 rescue FIP（0x40000，`rescue-pad3.fip`）。

## 已验证的候选 FIP

| 候选 | sha1 | 内容 | 结果 |
|---|---|---|---|
| `fip_tde_cma384_pad.bin` | `22af0bf4…` | cma=384M + TDE DTS 节点（`/tde@f8c10000`、compat `hisilicon,hi3798mv300-tde`、reg `0xf8c10000 0x40a4`、interrupts `<0 0x5b 4>`=SPI91） | **刷入 0x7000 后成功启动**：`CmaTotal=393216kB`、DTB 节点存在、`state=PASS`、6 模块、`tde_test PASS`、tde_test ×5 5/5、service 10× restart 5/5 |
| `fip_tde_cma256_pad.bin` | `1faa264d…` | cma=256M + TDE DTS 节点（在 22af0bf4 基础上仅改 cma 字符串） | 启动成功（串口见 Ubuntu login），但两次网络/串口观测不稳定；未完成 64MP 回归 |
| 生产原 FIP | `2dea80c5…` | cma=256M，无 TDE 节点 | 已知稳定基线；64MP 3/3 PASS 历史记录 |

## 为什么未保留 TDE-node FIP

1. **TDE 真实 IRQ 未生效**：即使 DTB 有 `/tde@f8c10000`，mainline 7.3 下驱动 `tde_test` 仍走 2ms 轮询兜底：
   `TDEDBG: irq fwspec(91): virq=59 hwirq=123 chip=none domain=:interrupt-controller@f1001000` →
   `no requestable TDE IRQ candidate -> load WITHOUT IRQ (safe)`。SPI91 的映射落在 `no_irq_chip` 的 dummy domain，
   与 vdec/JPEG 的可用 IRQ（真实 GIC chip）不同；需要单独修 IRQ 映射（延后映射/`irq_dispose_mapping` 重试等），不在本次窗口完成。
2. **cma=384M 对 64MP 无收益**：384M FIP 启动后 CmaFree 仅 ~161–213MB（boot 期 DRM/其它 coherent 分配吃掉更多），
   64MP 需 204MB 预算 → `rc=7` 保护性拒绝；256M 基线 clean boot CmaFree ~245MB，64MP 3/3 PASS。
3. 因此回退到生产原 FIP：`rootfs` 已修复、r6/r7 功能已在原 FIP + cma=256M 下验证。

## 保留件（供后续维护窗口）

- `work/rescue/`：rescue initramfs（静态 busybox + e2fsck，内置 env 备份恢复）、`rescue-pad3.fip`（内置 initramfs 内核的 rescue FIP）、kernel uImage 提取/打包脚本用法。
- DTS 补丁：`work/tde/dts/0001-hi3798mv300-poc-add-tde-node.patch`、`0002-sdk-hi3798mv300-add-tde-node.patch`。
- TDE IRQ 改进方向：把 `tde_port_map_irq()` 延后到首次 job（GIC 域就绪后）或对 dummy domain 先 `irq_dispose_mapping()` 再重映射；实测重载 hi_tde 仍因映射缓存失败。

## 风险与恢复记录

- 刷写/回滚共 4 次，均通过 U-Boot Ctrl+C + `mmc read/bootm` 恢复；无变砖。
- 注意：U-Boot Ctrl+C 命中率约 50%（bootdelay=1）；到达 prompt 后勿连续发 Ctrl+C（会刷 `<INTERRUPT>`）。

## TDE 真实 IRQ 尝试（v16m，negative result）

- 变更：`tde_port_map_irq()` 跳过 jpeg-parent 候选（其在 hwirq 123 上创建 `no_irq_chip` dummy mapping），仅用 GIC 节点 fwspec 映射 SPI91；`hi_tde.ko` v16m `1d2ebe90…`。
- 结果：板端启动后系统不稳定（ssh 拒绝/网络失联、串口响应迟滞），疑似真实 IRQ 请求成功但 **TDE 中断为电平未清/风暴**（handler 未按硬件正确 ack），无有效 tde_test 证据。
- 处置：**已回滚 v16l `cd6b1b7e…`**（轮询兜底，稳定），v16m 不发布。
- 后续方向：IRQ 请求成功后需确认 TDE INT 的清除/屏蔽序列（vendor ISR 语义：读 INT→写 INTCLR 0x7→按 job 状态），并加风暴保护（如 1s 内 >N 次即禁用 IRQ 回退轮询）；建议在维护窗口用串口全程观察 `/proc/interrupts` 计数与 dmesg 再尝试。

## TDE IRQ 第二轮尝试（2026-11-11 08:00，仍未达成）

- 复测 v16m（`1d2ebe90…`，跳过 jpeg-parent、仅 GIC fwspec）在**运行时重新 insmod**：仍然
  `irq fwspec(91): virq=59 hwirq=123 chip=none domain=:interrupt-controller@f1001000` → `no requestable TDE IRQ candidate`。
- 结论：该 SoC/mainline 7.3 下 GIC 节点 `interrupt-controller@f1001000` 的 irq_domain 在 TDE（12s）首次映射时尚未绑定真实 chip，被创建为 `no_irq_chip` dummy 域；后续所有映射复用该 dummy 域（dummy 域挂在 GIC 节点上持久存在）。vdec 的可用 IRQ（virq 40/41/42，真实 GIC chip）是在其模块 open 时（>120s）通过另一路径建立。
- 未验证修复方向（需干净启动 + 串口全程观察）：`osal_request_irq` 在 init 时**延迟映射**（先判断 GIC 域是否已就绪/或 `irq_find_host` 返回真实 chip 后再创建），并避免任何早于 GIC 绑定的映射调用；或给 TDE 使用独立 irq_domain/`irq_dispose_mapping`+重建。当前实现仍在 early init 映射，故 dummy 域被固化。
- 本轮尝试“TDE 延迟加载”的对照实验受板卡 WiFi/串口反复失联影响未完成；已恢复 `HI_LOAD_TDE=1` 与 r7 载荷（TDE v16l），板端 `state=PASS`、6 模块、`tde_test PASS`。
- 结论：**TDE 真实 IRQ 暂不交付**；2ms 轮询兜底（`tde_keep_clock=1`）为稳定方案。

## TDE IRQ 修复候选件 v16n（2026-11-11 08:15，待板卡验证）

- 产物：`work/tde/out/hi_tde_v16n_deferred_irq.ko` sha1 `2a5bc10a6c7ff93aeaed791c999e531c5f1ab9b3`；
  源改动备份 `work/tde/defer-irq-v16n/tde_port_stubs.c`、补丁 `work/tde/patches/0013-tde-port-deferred-irq-v16n.patch`（97 行）。
- 思路：`osal_request_irq()` 若发现 GIC irq_domain 尚未注册（`irq_find_host(<arm,gic-400 node>)==NULL`），**不调用任何 irq_create_mapping**（避免把 `no_irq_chip` dummy 域固化到 GIC 节点），改为保存 handler/dev/name/flags，延迟 500ms ×40 重试；等域就绪后再映射并请求 IRQ，成功后停止轮询。若映射仍得到 dummy chip 则继续轮询。
- 现状：构建通过；**尚未上板验证**（板卡 WiFi/串口自 08:00 起持续失联，需物理重插/断电）。
- 验证步骤（板卡恢复后，需干净启动且 TDE 从未加载过）：
  1) 保持 `HI_LOAD_TDE=0` 启动；`insmod hi_mmz_shim.ko`；`insmod /dev/shm/hi_tde_v16n.ko tde_dbg=1`；
  2) `dmesg | grep -E "defer TDE irq|deferred|using TDE irq|no requestable"`，期望延迟后 `using TDE irq virq=… (deferred)`；
  3) `tde_test` ×10、`cat .../tde_irq_cnt` 增长、`tde_poll_ticks` 停止增长；观察 1–2 分钟无 IRQ 风暴（dmesg 速率、ssh 响应）；
  4) 通过则升级 r8（TDE v16n）并回归 service 10×/PNG/64MP；失败则 rmmod 并保持 v16l。

## ★ TDE 真实 IRQ 达成（2026-11-11 09:20，v16p）

最终方案（无需修改 FIP：现网原生产 FIP 无 TDE 节点也可用）：
- **映射**：跳过 jpeg-parent 候选（它会把 `no_irq_chip` dummy domain 固化到 GIC 节点），只用 GIC 节点（`arm,gic-400`）fwspec 映射 SPI91 → virq/hwirq=123；
- **延迟**：若 `irq_find_host(<gic node>)==NULL`（域未注册），不调用任何 `irq_create_mapping`，改为延迟 500ms×40 重试，域就绪后再映射+`request_irq`；
- **轮询关闭**：IRQ 请求成功后不再启动 2ms poll（`init: real IRQ active -> poll NOT started`），避免 IRQ+轮询双完成。
- 成功率关键：**必须是干净启动**或模块在域就绪后首次加载；一旦早期调用过 `irq_create_mapping`，dummy 域会永久挂在 GIC 节点上（需重启才恢复）。

### 板端实测（v16p `211bb47a…`）
- 启动/重启 service 时：`using TDE irq virq=39 hwirq=123 (SPI91 expect hwirq 123)` → `request_irq(39) ret=0` → `init: real IRQ active -> poll NOT started`；
- `tde_test` **10/10 PASS**，`tde_irq_cnt` 66（=60 个 job 完成 + 6），`tde_poll_ticks` **冻结为 0**；
- `service 10× restart`：5/5 PASS（本轮抽样）；`state=PASS`、6 模块、64MP/PNG 回归随后补。
- 早期 v16o（`1306d511…`，未加 poll 关闭）也已验证 IRQ 请求成功、`tde_irq_cnt` 按 job 增长、tde_test PASS；v16p 在其上加 poll 关闭后为最终版。

### 产物
- `work/tde/out/hi_tde_v16p.ko` sha1 `211bb47ac4230dd43313d43565765213474cea75`（r8 发布件）
- 源码：`adp/tde_v2_0/tde_hal_k.c` keep_clock + `src/tde_osr_k.c` poll 关闭守卫 + `tde_port_stubs.c`（GIC-only 映射/延迟/IRQ 完成）
- 修复历程：v16m（仅跳过 jpeg-parent）→ 仍 dummy（因早期映射已固化）；v16n（加延迟，未跳 jpeg-parent）→ 无效；v16o（两者合并）→ 干净加载成功；v16p（+poll 关闭）→ 最终。
- **FIP 结论不变**：无需 TDE DTS 节点；cma=384M 版本因 64MP 预算仍回退（见上）。

### r8 最终板端验收（2026-11-11 09:35）

- `install.sh --verify`（r8 包 `7443c865…`）：**15/15 文件 OK**（含 `hi_tde.ko` v16p）。
- 启动日志：`[12.50] using TDE irq virq=39 hwirq=123` → `init: real IRQ active -> poll NOT started`；串口全量日志 `docs/porting/artifacts/png-hw/round6-v16p-boot.log`。
- `state=PASS`、6 模块、`/dev/hi_tde`；`tde_test` **10/10 PASS**；`tde_irq_cnt` 按 job 增长；`tde_poll_ticks` 恒 0。
- `service restart ×5`：5/5 PASS（v16p）。
- **64MP clean boot**：rc=0、3056.7ms、`CmaFree before=243632kB`。
- **pal8 `--clut-hw`**：`PAL8_CLUT_MATCH`（`CLUT2RGB job1 endjob rc=0`）。
