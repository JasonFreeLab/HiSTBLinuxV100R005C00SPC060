ifeq ($(WIFI_MODE),)
RT28xx_MODE = STA
else
RT28xx_MODE = $(WIFI_MODE)
endif

ifeq ($(TARGET),)
TARGET = LINUX
endif

# HIF_TYPE: USB or PCI
ifeq ($(HIF_TYPE),)
HIF_TYPE = PCI
endif

ifeq ($(CHIPSET),)
ifeq ($(HIF_TYPE),USB)
CHIPSET = mt7662u mt7632u mt7612u mt7662tu mt7632tu mt7612tu
else
CHIPSET = mt7662e mt7632e mt7612e mt7662te mt7632te mt7612te
endif
endif

MODULE = $(word 1, $(CHIPSET))

ifeq ($(HIF_TYPE),USB)
PREALLOC=YES
else
PREALLOC=NO
endif

RT28xx_DIR = $(shell pwd)

include $(RT28xx_DIR)/os/linux/config.mk

OUT_STA_KO = $(RT28xx_DIR)/os/linux/$(MODULE)_sta.ko

#PLATFORM: Target platform
#PLATFORM = PC
PLATFORM = Hisilicon
#PLATFORM = MT85XX_AUDIO
#PLATFORM = MT85XX_BDP
#PLATFORM = MT53XX
#PLATFORM = WEBOS
#PLATFORM = MSTAR
#PLATFORM = MSTAR_LINUX
#PLATFORM = ALPS_MT8173

MAKE = make

ifeq ($(PLATFORM),PC)
LINUX_SRC = /lib/modules/$(shell uname -r)/build
LINUX_SRC_MODULE = /lib/modules/$(shell uname -r)/kernel/drivers/net/wireless/
CROSS_COMPILE = 
endif

ifeq ($(PLATFORM),MSTAR)
# 3.10.23
LINUX_SRC =
# arm-2012.09
CROSS_COMPILE =
endif

ifeq ($(PLATFORM),MSTAR_LINUX)
# 3.1.10
LINUX_SRC =
# arm-2012.09
CROSS_COMPILE =
endif

ifeq ($(PLATFORM),Hisilicon)
# 3.1.10
LINUX_SRC =
# arm-2012.09
CROSS_COMPILE =
endif

ifeq ($(PLATFORM),ALPS_MT8173)
# 3.10.23
LINUX_SRC =
# arm-2012.09
CROSS_COMPILE =
endif

ifeq ($(PLATFORM),MT53XX)
MOD_PREALLOC = mtprealloc
TARGET = LINUX
#****** For system auto build ******
LINUX_SRC=$(KERNEL_OBJ_ROOT)/$(KERNEL_VER)/$(KERNEL_CONFIG)_modules
#****** For local build ******
# uncomment the following lines
#VM_LINUX_ROOT ?= $(word 1, $(subst /vm_linux/,/vm_linux /, $(shell pwd)))
#LINUX_ROOT ?= $(VM_LINUX_ROOT)
#LINUX_SRC=$(VM_LINUX_ROOT)/../../../out/mediatek_linux/output/sony/Sakura_EU/rel/obj/kernel/linux_core/kernel/linux-3.10/mt5890_android_smp_mod_defconfig_modules
#OBJ_ROOT ?= $(VM_LINUX_ROOT)/../../../out/mediatek_linux/output/sony/Sakura_EU/rel/obj
#export KERNEL_OBJ_ROOT=$(LINUX_SRC)/../..
include $(LINUX_ROOT)/linux_mts/mak/toolchain.mak
ifeq ($(CROSS_COMPILE),)
CROSS_COMPILE=/mtkoss/gnuarm/vfp_4.5.1_2.6.27_cortex-a9-rhel4/i686/bin/armv7a-mediatek451_001_vfp-linux-gnueabi-
endif
ifeq "$(CC)" "gcc"
CC ?= $(CROSS_COMPILE)gcc
endif
WIFI_TARGET := mt7662_cfg80211
export WIFI_TARGET
$(warning =============================================)
$(warning CC=$(CC) for wifi driver LINUX_SRC=$(LINUX_SRC))
$(warning TARGET=$(TARGET))
$(warning =============================================)

# overwrite $(OUT_STA_KO) for MT53XX platform
OUT_STA_KO = $(OBJ_ROOT)/third_party/source/wlan/mtk/$(WIFI_TARGET)/os/linux/$(MODULE)_sta.ko
endif # end of MT53XX

ifneq ($(findstring MT85XX,$(PLATFORM)),)
PREALLOC=NO
endif # end of MT85XX*

ifeq ($(PLATFORM),WEBOS)
LINUX_SRC = 
CROSS_COMPILE = arm-lg115x-linux-gnueabi-
TARGET = LINUX
export ARCH := arm
$(warning =============================================)
$(warning CC=$(CC) for wifi driver LINUX_SRC=$(LINUX_SRC))
$(warning =============================================) 
endif

export RT28xx_DIR RT28xx_MODE LINUX_SRC CROSS_COMPILE CROSS_COMPILE_INCLUDE PLATFORM CHIPSET MODULE LINUX_SRC_MODULE TARGET HAS_WOW_SUPPORT PREALLOC HIF_TYPE

# The targets that may be used.
PHONY += all build_tools LINUX release prerelease clean uninstall install libwapi

ifeq ($(TARGET),LINUX)
all: build_tools $(TARGET)
else
all: $(TARGET)
endif

build_tools:
	$(MAKE) -C tools
	mkdir -p $(RT28xx_DIR)/include/eeprom && $(RT28xx_DIR)/tools/bin2h

LINUX:
ifeq ($(PREALLOC), YES)
	cp -f os/linux/Makefile.6.prealloc os/linux/Makefile
	$(MAKE) -C $(LINUX_SRC) SUBDIRS=$(RT28xx_DIR)/os/linux modules
endif
	cp -f os/linux/Makefile.6 os/linux/Makefile
	$(MAKE) -C $(LINUX_SRC) SUBDIRS=$(RT28xx_DIR)/os/linux modules
	$(CROSS_COMPILE)strip --strip-unneeded $(OUT_STA_KO)
ifeq ($(PLATFORM),MT53XX)
ifneq ($(ANDROID),true)
	if [ ! -d $(THIRDPARTY_LIB_ROOT)/wlan/$(KERNEL_VER_FOR_3RD)/mtk/$(WIFI_TARGET) ]; then \
		mkdir -p $(THIRDPARTY_LIB_ROOT)/wlan/$(KERNEL_VER_FOR_3RD)/mtk/$(WIFI_TARGET)/; \
	fi
	cp -f $(OBJ_ROOT)/third_party/source/wlan/mtk/$(WIFI_TARGET)/os/linux/$(MODULE)_sta.ko $(THIRDPARTY_LIB_ROOT)/wlan/$(KERNEL_VER_FOR_3RD)/mtk/$(WIFI_TARGET)/$(MODULE)_sta.ko
	cp -f $(OBJ_ROOT)/third_party/source/wlan/mtk/$(WIFI_TARGET)/os/linux/$(MOD_PREALLOC).ko $(THIRDPARTY_LIB_ROOT)/wlan/$(KERNEL_VER_FOR_3RD)/mtk/$(WIFI_TARGET)/$(MOD_PREALLOC).ko
else
ifeq "$(BUILD_CFG)" "debug"
	echo "ANDROID_VERSION=$(ANDROID_VERSION)"
	if [ ! -d $(LINUX_ROOT)/../android/$(ANDROID_VERSION)/vendor/mediatek/open/hardware/prebuilt/wifi/$(ANDROID_IC_SETTING)/dbg ]; then \
		mkdir -p $(LINUX_ROOT)/../android/$(ANDROID_VERSION)/vendor/mediatek/open/hardware/prebuilt/wifi/$(ANDROID_IC_SETTING)/dbg; \
	fi
	cp -f $(OBJ_ROOT)/third_party/source/wlan/mtk/$(WIFI_TARGET)/os/linux/$(MODULE)_sta.ko $(LINUX_ROOT)/../android/$(ANDROID_VERSION)/vendor/mediatek/open/hardware/prebuilt/wifi/$(ANDROID_IC_SETTING)/dbg/$(MODULE)_sta.ko
	cp -f $(OBJ_ROOT)/third_party/source/wlan/mtk/$(WIFI_TARGET)/os/linux/$(MOD_PREALLOC).ko $(LINUX_ROOT)/../android/$(ANDROID_VERSION)/vendor/mediatek/open/hardware/prebuilt/wifi/$(ANDROID_IC_SETTING)/dbg/$(MOD_PREALLOC).ko
	
	if [ -d $(OUTPUT_ROOT)/basic/modules ]; then \
                cp -f $(OBJ_ROOT)/third_party/source/wlan/mtk/$(WIFI_TARGET)/os/linux/$(MODULE)_sta.ko $(OUTPUT_ROOT)/basic/modules/wlan.ko; \
                cp -f $(OBJ_ROOT)/third_party/source/wlan/mtk/$(WIFI_TARGET)/os/linux/$(MOD_PREALLOC).ko $(OUTPUT_ROOT)/basic/modules/$(MOD_PREALLOC).ko; \
        fi
else
	if [ ! -d $(LINUX_ROOT)/../android/$(ANDROID_VERSION)/vendor/mediatek/open/hardware/prebuilt/wifi/$(ANDROID_IC_SETTING) ]; then \
		mkdir -p $(LINUX_ROOT)/../android/$(ANDROID_VERSION)/vendor/mediatek/open/hardware/prebuilt/wifi/$(ANDROID_IC_SETTING); \
	fi
	cp -f $(OBJ_ROOT)/third_party/source/wlan/mtk/$(WIFI_TARGET)/os/linux/$(MODULE)_sta.ko $(LINUX_ROOT)/../android/$(ANDROID_VERSION)/vendor/mediatek/open/hardware/prebuilt/wifi/$(ANDROID_IC_SETTING)/$(MODULE)_sta.ko
	cp -f $(OBJ_ROOT)/third_party/source/wlan/mtk/$(WIFI_TARGET)/os/linux/$(MOD_PREALLOC).ko $(LINUX_ROOT)/../android/$(ANDROID_VERSION)/vendor/mediatek/open/hardware/prebuilt/wifi/$(ANDROID_IC_SETTING)/$(MOD_PREALLOC).ko
	
	if [ -d $(OUTPUT_ROOT)/basic/modules ]; then \
                cp -f $(OBJ_ROOT)/third_party/source/wlan/mtk/$(WIFI_TARGET)/os/linux/$(MODULE)_sta.ko $(OUTPUT_ROOT)/basic/modules/wlan.ko; \
                cp -f $(OBJ_ROOT)/third_party/source/wlan/mtk/$(WIFI_TARGET)/os/linux/$(MOD_PREALLOC).ko $(OUTPUT_ROOT)/basic/modules/$(MOD_PREALLOC).ko; \
        fi
endif # ifeq "$(BUILD_CFG)" "debug"
endif # ifneq ($(ANDROID),true)
endif # ifeq ($(PLATFORM),MT53XX)

clean:
ifeq ($(TARGET), LINUX)
	cp -f os/linux/Makefile.clean os/linux/Makefile
	$(MAKE) -C os/linux clean
	rm -rf os/linux/Makefile
	rm -rf include/mcu/mt7662*.h include/eeprom tools/bin2h
endif	

uninstall:
ifeq ($(TARGET), LINUX)
	$(MAKE) -C $(RT28xx_DIR)/os/linux -f Makefile.6 uninstall
endif

install:
ifeq ($(TARGET), LINUX)
	$(MAKE) -C $(RT28xx_DIR)/os/linux -f Makefile.6 install
endif

libwapi:
	cp -f os/linux/Makefile.libwapi.6 $(RT28xx_DIR)/os/linux/Makefile	
	$(MAKE) -C  $(LINUX_SRC) SUBDIRS=$(RT28xx_DIR)/os/linux modules	

# Declare the contents of the .PHONY variable as phony.  We keep that information in a variable
.PHONY: $(PHONY)

