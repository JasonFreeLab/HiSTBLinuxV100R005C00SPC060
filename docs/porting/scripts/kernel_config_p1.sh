#!/usr/bin/env bash
# P1 内核配置：以 allnoconfig 为基线，打开 P1（Ubuntu rootfs + eMMC 启动）所需的最小集合。
# 用法: kernel_config_p1.sh [kernel-dir]
set -u
KD="${1:-/home/jason/bringup-7.3/src/linux-7.3}"
export PATH=/home/jason/bringup-7.3/toolchain/usr/bin:$PATH
export LD_LIBRARY_PATH=/home/jason/bringup-7.3/toolchain/usr/lib/x86_64-linux-gnu
cd "$KD" || { echo "FAIL: kernel dir not found: $KD" >&2; exit 2; }

make ARCH=arm64 allnoconfig >/dev/null || { echo "FAIL: allnoconfig" >&2; exit 1; }

ENABLE="
ARCH_HISI
ARM64_4K_PAGES
ARM64_VA_BITS_48
ARM64_PA_BITS_48
SMP
ARM_PSCI_FW
ARM_ARCH_TIMER
ARM_GIC
OF
OF_EARLY_FLATTREE
SERIAL_AMBA_PL011
SERIAL_AMBA_PL011_CONSOLE
SERIAL_EARLYCON
TTY
VT
UNIX98_PTYS
PRINTK
PRINTK_TIME
BINFMT_ELF
BINFMT_SCRIPT
ELF_CORE
MULTIUSER
POSIX_TIMERS
FUTEX
EPOLL
SIGNALFD
TIMERFD
EVENTFD
AIO
SHMEM
INOTIFY_USER
DEVTMPFS
DEVTMPFS_MOUNT
TMPFS
PROC_FS
SYSFS
BLK_DEV
BLK_DEV_INITRD
RD_GZIP
EXT4_FS
DRM
DRM_KMS_HELPER
DRM_HI3798
DRM_SIMPLEDRM
DRM_FBDEV_EMULATION
DRM_LIMA
HISI_FEMAC
MDIO_HISI_FEMAC
USB_DRM_GEM_SHMEM_HELPER
FB
FB_CORE
FRAMEBUFFER_CONSOLE
PARTITION_ADVANCED
DEVMEM
CMDLINE_PARTITION
EXT4_USE_FOR_EXT2
JBD2
CRC16
CRC32
MMC
MMC_BLOCK
MMC_DW
MMC_DW_PLTFM
MMC_DW_HI3798MV200
COMMON_CLK
COMMON_CLK_HI3798CV200
RESET_HISI
CMA
DMA_CMA
MFD_SYSCON
REGMAP
REGMAP_MMIO
USB_SUPPORT
USB
USB_EHCI_HCD
USB_EHCI_HCD_PLATFORM
USB_OHCI_HCD
USB_OHCI_HCD_PLATFORM
USB_STORAGE
HID_SUPPORT
HID
HID_GENERIC
USB_HID
INPUT_EVDEV
INPUT_KEYBOARD
INPUT_MOUSE
PHY_HISI_INNO_USB2
MMC_SDIO
FW_LOADER
FW_LOADER_USER_HELPER
NETDEVICES
ETHERNET
NET_VENDOR_HISILICON
HIX5HD2_GMAC
RESET_CONTROLLER
RESET_TI_SYSCON
CGROUP_SCHED
CGROUP_DEVICE
CGROUP_FREEZER
CGROUP_PIDS
CGROUP_CPUACCT
BLK_CGROUP
TMPFS_POSIX_ACL
TMPFS_XATTR
AUTOFS_FS
SYSVIPC
IPC_NS
NET
UNIX
INET
PACKET
IPV6
CGROUPS
SECCOMP
KEYS
NAMESPACES
UTS_NS
PID_NS
IPC_NS
NET_NS
USER_NS
MAGIC_SYSRQ
"
scripts/config -d ARM64_VA_BITS_52 2>/dev/null || true
scripts/config -d ARM64_PA_BITS_52 2>/dev/null || true
for s in $ENABLE; do scripts/config -e "$s" 2>/dev/null; done
scripts/config -e BLK_DEV_INITRD 2>/dev/null || true
scripts/config -e RD_GZIP 2>/dev/null || true
scripts/config --set-str INITRAMFS_SOURCE "/tmp/rescue-initramfs.cpio.gz" 2>/dev/null || true
scripts/config -d INITRAMFS_COMPRESSION_NONE 2>/dev/null || true
scripts/config -e INITRAMFS_COMPRESSION_GZIP 2>/dev/null || true
scripts/config -e INITRAMFS_COMPRESSION_NONE 2>/dev/null || true
scripts/config -d INITRAMFS_COMPRESSION_GZIP 2>/dev/null || true
scripts/config -d STRICT_DEVMEM 2>/dev/null || true
scripts/config --set-val CMA_SIZE_MBYTES 256 2>/dev/null || true
make ARCH=arm64 olddefconfig >/dev/null || { echo "FAIL: olddefconfig" >&2; exit 1; }

fail=0
check() {
  local sym="$1" want="$2"
  local val
  val="$(sed -n "s/^${sym}=//p" .config | head -1)"
  if [ "$val" != "$want" ]; then
    echo "FAIL: ${sym} = '${val}', want '${want}'" >&2
    fail=1
  fi
}
check CONFIG_MMC_DW_HI3798MV200 y
check CONFIG_COMMON_CLK_HI3798CV200 y
check CONFIG_EXT4_FS y
check CONFIG_DRM y
check CONFIG_DRM_HI3798 y
check CONFIG_DRM_SIMPLEDRM y
check CONFIG_DRM_LIMA y
check CONFIG_HISI_FEMAC y
check CONFIG_FRAMEBUFFER_CONSOLE y
check CONFIG_CMA y
check CONFIG_DEVTMPFS_MOUNT y
check CONFIG_ARM64_VA_BITS 48
check CONFIG_ARM64_PA_BITS 48
check CONFIG_SMP y
check CONFIG_ARM_PSCI_FW y
check CONFIG_SERIAL_AMBA_PL011_CONSOLE y
check CONFIG_SERIAL_EARLYCON y
check CONFIG_CGROUP_DEVICE y
check CONFIG_TMPFS_POSIX_ACL y
check CONFIG_AUTOFS_FS y
check CONFIG_SYSVIPC y
check CONFIG_IPC_NS y
[ "$fail" -eq 0 ] || exit 1
echo "PASS: P1 config generated (allnoconfig + $(echo $ENABLE | wc -w) options)"
