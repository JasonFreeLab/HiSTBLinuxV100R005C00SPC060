# 板卡恢复指引（2026-11-11 07:45 事故）

## 事件

- 在 TDE 真实 IRQ 实验（v16m，跳过 dummy-domain 映射）后系统不稳定（疑 IRQ 风暴）；经串口把 `/root/m2/hi_tde.ko` 恢复为 v16l（sha1 `cd6b1b7e…`，串口输出已验证），执行 `systemctl reboot` 后板卡失去响应：
  - ssh：No route to host；ping 192.168.2.10：100% loss（板卡不在 Linux/网络未起）；
  - 串口：`/dev/ttyUSB0` 可打开但**读 0 字节**；`/dev/ttyUSB1` 停留在 Nov 10 时间戳（FTDI urb -32），RTS 复位通道失效。
  - 结论：**WSL USB 串口适配器失联**（host dmesg 有 WSL getaddrinfo/connect 错误），无法远程判断/恢复。

## 已确认的持久状态（最后一次串口/ssh 成功证据）

- eMMC FIP@0x7000：**原生产 FIP `2dea80c5…`（cma=256M）**（本次已恢复并 sha1 复核；cma384+TDE-node 候选已不在 active）。
- eMMC 空闲区：0x30000 = `fip_tde_cma384_pad.bin` `22af0bf4…`；0x40000 = rescue FIP `rescue-pad3.fip` `1327bec5…`（内置 rescue initramfs + env 备份恢复）；0x20000/0x26000 为早期 rescue kernel/uInitrd（可覆盖）。
- U-Boot env：原始（`bootcmd=mmc read 0 0x1FFAE30 0x7000 0x5D34; bootm 0x1FFAE30`，白名单 sha1 `712af710…` 备份在 host `/tmp/board-env.bin`、`work/rescue/`）。
- `/root/m2`：r7 载荷（PNG v17 `74f9c681…`、tool A2 `fd7b63cc…`、**TDE v16l `cd6b1b7e…`**、其余 r7 件）；`hi_tde.ko.v16l.bak` 存在。
- rootfs：已 e2fsck 修复（clean、无 bitmap 错误、250MB 落盘测试通过）；r6/r7 磁盘安装均成功过。
- 最后完整 PASS 记录：r7 磁盘安装后 `state=PASS`、`warmup=ok(3879ms)`、6 模块、`tde_test PASS`、restart PASS；恢复原 FIP 后 64MP rc=0/sha1 `d0ce2b24…` ✓。

## 恢复步骤（需先把串口适配器重新枚举）

1. 物理重插 USB 串口/开发板电源（或 WSL `usbipd detach/attach`），确认 `/dev/ttyUSB0/1` 重新出现且 `python -c "import serial; print(serial.Serial('/dev/ttyUSB0',115200).read(100))"` 有输出。
2. RTS 复位（`/dev/ttyUSB1`）→ 串口应见 U-Boot banner；**长按 Ctrl+C 到 `fastboot#`**（bootdelay=1，成功率约 50%，可多试）。
3. 若正常启动：`ssh root@192.168.2.10` → 验证 `sha1sum /root/m2/hi_tde.ko`=`cd6b1b7e…`、`cat /run/hi-accel/status`、`/root/m2/tde_test`。
4. 若 boot 卡住/循环：`fastboot#` 下 `mmc read 0 0x1FFAE30 0x40000 <blocks>; bootm 0x1FFAE30` 启动 rescue FIP（内置 initramfs，会自动 e2fsck+恢复 env+重启），或从 host 重新 dd 原 FIP `2dea80c5…` 到 0x7000。
5. 若 U-Boot 不可达：用 `loady`（YMODEM，12.2MB ≈20min）传原 FIP 到 0x1FFAE30 → `mmc write 0 0x1FFAE30 0x7000 0x5D34`；serial 参考 `docs/porting/artifacts/png-hw/fip-*/`。
6. 恢复后建议先 `e2fsck -f -y /dev/mmcblk0p1`（可用已备好的 rescue FIP），再 `systemctl start hi-accel` 验证。

## 待办

- TDE 真实 IRQ（v16m 失败）需在串口稳定后重新尝试：IRQ ack 序列 + 风暴保护 + `/proc/interrupts` 计数验证；v16m 源码改动未发布（port/tde/tde_port_stubs.c 有备份 `/tmp/tde_port_stubs.c.bak`）。

## 更新（2026-11-11 07:55）：板卡已恢复并最终验证

- RTS 复位（ttyUSB1 脉冲）后板卡正常启动；串口/网络恢复。
- 最终状态（ssh 实测）：
  - `/root/m2` = r7 载荷：`hi_tde.ko` **v16l `cd6b1b7e…`**、`hi_png_reload.ko` PNG v17 `74f9c681…`、`hi_png_hw` tool A2 `fd7b63cc…`
  - `state=PASS`、`warmup=ok(5431ms)`、6 模块全 ok、`tde_test PASS`、**restart 5/5 PASS**
  - `CmaTotal=262144kB`（原生产 FIP cma=256M，已回退）
- 此前“失联”原因是板卡 halt（非变砖）+ WSL 串口偶发无数据；RTS 复位即可恢复，`BOARD-RECOVERY` 步骤有效。

## 紧急配置注意（2026-11-11 08:10）

- 为做 TDE IRQ 干净映射对照，最后一次操作把 `/etc/hi-accel.conf` 设为 **`HI_LOAD_TDE=0`** 并重启；此后板卡 WiFi（rtw88 h2c 报错）/WSL USB 串口反复失联，**未能恢复 `HI_LOAD_TDE=1`**。
- 板卡恢复后**必须执行**（否则 TDE 不会被加载）：
```sh
sed -i 's/^HI_LOAD_TDE=.*/HI_LOAD_TDE=1/' /etc/hi-accel.conf
grep HI_LOAD_TDE /etc/hi-accel.conf
systemctl restart hi-accel
cat /run/hi-accel/status
/root/m2/tde_test
sha1sum /root/m2/hi_tde.ko   # 应 cd6b1b7e… (v16l)
```
- 其它持久状态不变：eMMC FIP=原生产 `2dea80c5…`、`/root/m2`=r7 载荷、rescue FIP 在 0x40000、U-Boot env=原始。

## 阻塞升级（2026-11-11 08:20，目标轮 3–5 连续）

- 板卡自 08:00 起连续 3 个目标轮次（round 3/4/5）**无法通过 ssh（refused/no route/timeout）、ping（间歇 50–100% loss）或串口（读 0 字节）稳定访问**，无法完成：
  1) `/etc/hi-accel.conf` 的 `HI_LOAD_TDE=1` 恢复与 r7 复核；
  2) TDE IRQ 修复候选 v16n 的干净启动对照验证。
- 结论：**需要物理介入**——给板卡断电重上电 + 重插 USB 串口适配器（WSL `usbipd detach/attach` 或重插 CH340/FT232 设备）。
- 恢复后执行（详见上方“紧急配置注意”）：恢复 HI_LOAD_TDE=1 → restart hi-accel → 验证 r7；随后按 FIP 实验文档验证 v16n。
