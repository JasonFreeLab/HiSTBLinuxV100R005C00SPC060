# 72h 混合负载 soak 进度检查点（2026-11-02 起）

负载：`stability-load.sh` 三相循环（A 视频软解 120s / B CPU 满载 60s / C 网络吞吐 30s）
记录：`/root/stability-2026*.log`（每分钟）、`/root/stability-load.log`（相位）、`/root/selftest.log`（每小时）、`/root/boot-selftest.log`（开机）
说明：72h 要求连续运行；重启会重置计时，本表仅记录"本次启动"累计。

| 检查点时刻 | uptime | faults | warn_alloc | mem | load(1m) | WiFi | 备注 |
|---|---|---|---|---|---|---|---|
| 2026-11-02 00:51 | 12min | 0 | 0 | 226-299MB | 0.8-1.2 | Connected | 三相混合负载运转正常；A=120s/B=60s/C=30s 实测节拍正确 |
| 2026-11-02 00:52 | 13min | 0 | 0 | 299MB | 0.82/1.11/0.88 | Connected | 跨主机验证：PC 侧 22/3389/445/139 均 OPEN，SSH banner OpenSSH_10.2p1；板端 smbclient 列出 usb/rootfs |
| 2026-11-02 00:53 | 14min | 0 | 0 | 299-331MB | ~0.8/1.1/0.9 | Connected | 子系统核查：zram 在用(786M, 用3.4M)、WDT sp805 30s 生效、FS 错误 0、内核告警仅 2 条良性 |
| 2026-11-02 00:53 | 14min | 0 | 0 | 126-507MB（avg 285） | ~0.8-1.2 | Connected | 内存趋势分析：斜率 -1.79 MB/min（无泄漏，随负载波动），faults 采样 0 |

> 注：2026-11-02 00:55~01:03 期间为加入温度传感器驱动连续刷写固件 6 次，每次重启使 72h 计时归零；01:03 后为最终固件（md5 310cc74e…），soak 从该时刻重新累计。
