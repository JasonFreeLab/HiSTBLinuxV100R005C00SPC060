#!/bin/bash
# 构建桌面用完整内核固件（无 initramfs，全功能配置）并填充到固定 0x5D34 块
set -e
BD=/home/jason/bringup-7.3; R=/home/jason/HiSTBLinuxV100R005C00SPC060
KD=$BD/src/linux-7.3; OUT=$BD/out
export PATH=$BD/toolchain/usr/bin:$PATH
export LD_LIBRARY_PATH=$BD/toolchain/usr/lib/x86_64-linux-gnu
cd $KD
# 恢复完整桌面配置（来自 round34 保存）
CFG=/tmp/config_full_rd2
[ -f "$CFG" ] || CFG=/home/jason/bringup-7.3/out/config_full_rd2.backup
[ -f "$CFG" ] || { echo "config_full_rd2 missing (both /tmp and out backup)"; exit 1; }
cp "$CFG" .config
# 保存一份持久备份，避免 /tmp 清理导致配置丢失
cp .config /home/jason/bringup-7.3/out/config_full_rd2.backup
# 关闭 IPv6 节省 Image 体积（ATF FIP 大小限制），本机只用静态 IPv4
scripts/config -d IPV6
scripts/config -d IPV6_SIT
scripts/config --set-str INITRAMFS_SOURCE ""
scripts/config -d BLK_DEV_INITRD
scripts/config -d INITRAMFS_COMPRESSION_GZIP
scripts/config -d INITRAMFS_COMPRESSION_NONE
# USB 存储 + 常用文件系统（U 盘/移动硬盘）
scripts/config -e I2C
scripts/config -e I2C_HIX5HD2
scripts/config -e I2C_CHARDEV
scripts/config -e SWAP
scripts/config -e HWMON
scripts/config -e ZSTD_DECOMPRESS
scripts/config -e FW_LOADER_COMPRESS_ZSTD
scripts/config -e RTW88_8822CS
scripts/config -e RTW88_8822C
scripts/config -e HI3798_THERMAL
scripts/config -e INPUT_MISC
scripts/config -e BT
scripts/config -m BT_HCIBTUSB
scripts/config -m BT_HCIUART
scripts/config -m BT_HCIUART_H4
scripts/config -e SERIAL_DEV_BUS
scripts/config -e SERIAL_DEV_CTRL_TTYPORT
scripts/config -e BT_HCIUART_SERDEV
scripts/config -e BT_HCIUART_3WIRE
scripts/config -m BT_HCIUART_H5
scripts/config -e BT_HCIUART_RTL
scripts/config -e BT_HCIUART_BCM
scripts/config -e BT_HCIUART_INTEL
scripts/config -e BT_HCIUART_QCA
scripts/config -e BT_HCIUART_ATH3K
scripts/config -m BT_HCIBTUSB

scripts/config -m INPUT_UINPUT
scripts/config -m USB_OHCI_HCD
scripts/config -e INPUT_MISC
scripts/config -e BT
scripts/config -m BT_HCIBTUSB
scripts/config -m BT_HCIUART
scripts/config -m BT_HCIUART_H4
scripts/config -m BT_HCIUART_RTL
scripts/config -m INPUT_UINPUT
scripts/config -m USB_OHCI_HCD_PLATFORM
scripts/config -e ZRAM
scripts/config -e SWAP
scripts/config -e HWMON
scripts/config -e ZSTD_DECOMPRESS
scripts/config -e FW_LOADER_COMPRESS_ZSTD
scripts/config -e RTW88_8822CS
scripts/config -e RTW88_8822C
scripts/config -e HI3798_THERMAL
scripts/config -e INPUT_MISC
scripts/config -e BT
scripts/config -m BT_HCIBTUSB
scripts/config -m BT_HCIUART
scripts/config -m BT_HCIUART_H4
scripts/config -m BT_HCIUART_RTL
scripts/config -m INPUT_UINPUT
scripts/config -m USB_OHCI_HCD
scripts/config -e INPUT_MISC
scripts/config -e BT
scripts/config -m BT_HCIBTUSB
scripts/config -m BT_HCIUART
scripts/config -m BT_HCIUART_H4
scripts/config -m BT_HCIUART_RTL
scripts/config -m INPUT_UINPUT
scripts/config -m USB_OHCI_HCD_PLATFORM
scripts/config -e ZRAM_BACKEND_LZO
scripts/config -e GPIOLIB
scripts/config -e GPIO_PL061
scripts/config -e WATCHDOG
scripts/config -e ARM_SP805_WATCHDOG
scripts/config -e SPI
scripts/config -e SPI_PL022
for opt in FAT_FS VFAT_FS MSDOS_FS EXFAT_FS; do
  scripts/config -e $opt 2>/dev/null || true
done
# USB 存储/xHCI/NTFS 以模块编译（裁剪 Image 通过 ATF FIP 限制）
for mopt2 in USB_XHCI_HCD USB_XHCI_PLATFORM SCSI BLK_DEV_SD USB_STORAGE NTFS3_FS; do
  scripts/config -m $mopt2 2>/dev/null || true
done
# WiFi (rtw88) 以模块编译，避免 Image 增大超过 ATF FIP 限制
scripts/config -e MODULES
scripts/config -e BT_HCIUART_H4
scripts/config -e MODULE_UNLOAD
scripts/config -e MMC_SDIO
for mopt in BT BT_BREDR BT_LE BT_HCIUART CFG80211 MAC80211 RFKILL RTW88 RTW88_SDIO RTW88_8822B RTW88_8822BS; do
  scripts/config -m $mopt 2>/dev/null || true
done
# === 最终权威配置（避免前面 -m 对 bool 选项的破坏） ===
scripts/config -e BT
scripts/config -e BT_BREDR
scripts/config -e BT_LE
scripts/config -m BT_HCIUART
scripts/config -e BT_HCIUART_H4
scripts/config -e BT_HCIUART_3WIRE
scripts/config -e BT_HCIUART_SERDEV
scripts/config -e BT_HCIUART_RTL
scripts/config -m BT_HCIBTUSB
scripts/config -e FW_LOADER_COMPRESS_ZSTD
scripts/config -e ZSTD_DECOMPRESS
scripts/config -m RTW88
scripts/config -m RTW88_CORE
scripts/config -m RTW88_SDIO
scripts/config -m RTW88_8822B
scripts/config -m RTW88_8822BS
scripts/config -m RTW88_8822C
scripts/config -m RTW88_8822CS
scripts/config -e HWMON
scripts/config -e HI3798_THERMAL
chmod +x $KD/scripts/config 2>/dev/null || true
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig >/dev/null
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image -j16
# 必须使用 Image header 的 image_size（含 BSS）：用文件大小会导致内核静默失败！
ISIZE=$(python3 -c "import struct;d=open('$KD/arch/arm64/boot/Image','rb').read(64);print('0x%X'%struct.unpack('<Q',d[16:24])[0])")
cpp -nostdinc -undef -D__DTS__ -DROOTFS_BOOT -DGENERIC_MMC -DLOW_MMC -x assembler-with-cpp \
  -I $KD/include -I $KD/arch/arm64/boot/dts -o /tmp/desk.pre.dts $KD/arch/arm64/boot/dts/hisilicon/hi3798mv300-poc.dts
$KD/scripts/dtc/dtc -I dts -O dtb -o $OUT/desk.dtb /tmp/desk.pre.dts 2>/dev/null
python3 $R/docs/porting/scripts/mkuimage.py --pack --image $KD/arch/arm64/boot/Image --dtb $OUT/desk.dtb \
  --out $OUT/uImage_desk --load 0x2000000 --ep 0x2000000 --pad-to $ISIZE >/dev/null
rm -f $OUT/fip_desk.bin
$R/source/kernel/arm-trusted-firmware/tools/fip_create/fip_create --bl31 $OUT/bl31_smp_fixed.bin \
  --bl33 $OUT/uImage_desk $OUT/fip_desk.bin >/dev/null 2>&1
python3 - "$OUT/fip_desk.bin" <<'PY'
import sys,os
d=open(sys.argv[1],'rb').read(); target=0x5D34*512
assert len(d)<=target, "FIP too big: %d"%len(d)
open('/tmp/fip_desk_pad.bin','wb').write(d+b'\x00'*(target-len(d)))
print("FIP %d -> padded %d"%(len(d),target))
PY
cp -f /tmp/fip_desk_pad.bin $OUT/fip_desk_pad.bin
echo OK
