#!/usr/bin/env bash
# 把 eMMC baseparam 分区(2M offset, 4MB)里的 DISP1(HD)改成 1920x1080：
#   file offset 0x930  BASE_KEY_FMT   = 0  (1080P_60)
#   file offset 0xF90  BASE_KEY_VIRSCW= 1920 (0x780)
#   file offset 0xFB8  BASE_KEY_VIRSCH= 1080 (0x438)
# 用法：在 fastboot# 下执行以下命令（U-Boot 串口），然后 RTS 复位。
cat <<'UBOOT'
mmc read 0 0x10000000 0x1000 0x2000
mw.l 0x10000930 0x0
mw.l 0x10000f90 0x780
mw.l 0x10000fb8 0x438
mmc write 0 0x10000000 0x1000 0x2000
UBOOT
