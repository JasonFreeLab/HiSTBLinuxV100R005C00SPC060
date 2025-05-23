#===============================================================================
# export variables
#===============================================================================
ifeq ($(CFG_HI_EXPORT_FLAG),)
    ifneq ($(srctree),)
    KERNEL_DIR := $(srctree)

    SDK_DIR := $(shell cd $(KERNEL_DIR)/../../.. && /bin/pwd)
    else
    SDK_DIR := $(shell cd $(CURDIR)/../../../.. && /bin/pwd)
    endif

    include $(SDK_DIR)/base.mak
endif

#===============================================================================
# local variables
#===============================================================================
EXTRA_CFLAGS += -I$(COMMON_UNF_INCLUDE)                 \
                -I$(COMMON_API_INCLUDE)                 \
                -I$(COMMON_DRV_INCLUDE)                 \
                -I$(MSP_UNF_INCLUDE)                    \
                -I$(MSP_API_INCLUDE)                    \
                -I$(MSP_DRV_INCLUDE)                    \
                -I$(MSP_DIR)/drv/hifb/include	        \
                -I$(MSP_DIR)/drv/hifb/inc               \
                -I$(MSP_DIR)/drv/hifb/adp/inc    	\
                -I$(MSP_DIR)/drv/hifb/adp/src           \
                -I$(MSP_DIR)/drv/hifb/adp/alg           \
                -I$(MSP_DIR)/drv/tde/include	        \
                -I$(MSP_DIR)/api/tde/include	        \
                -I$(MSP_DIR)/api/higo/include           \
                -I$(COMPONENT_DIR)/ha_codec/include	\
                -I$(MSP_DIR)/drv/jpeg/grc_cmm_inc

ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3798mv310 hi3716mv430),)
HAL_VER := v2_0
EXTRA_CFLAGS += -DCONFIG_HIFB_VERSION_2_0
else
HAL_VER := v1_0
endif

EXTRA_CFLAGS += -I$(MSP_DIR)/drv/hifb/adp/hal_$(HAL_VER)

ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3798cv200 hi3798mv200 hi3798mv300 hi3798mv310 hi3796mv200 hi3716mv430 hi3716mv450),)
EXTRA_CFLAGS += -DCONFIG_GFX_PQ
else
EXTRA_CFLAGS += -DCONFIG_HIFB_VERSION_1_0
endif

ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3798mv200 hi3796mv200 hi3716mv450),)
EXTRA_CFLAGS += -DCONFIG_HIFB_SUPPORT_HDR_DEPRE_MIXG
endif

ifneq ($(findstring $(CFG_HI_KERNEL_VERSION), linux-4.9.y),)
EXTRA_CFLAGS += -I$(srctree)/drivers/hisilicon/hi_fence
else
EXTRA_CFLAGS += -I$(srctree)/drivers/staging/android
endif

ifneq ($(findstring $(CONFIG_SYNC), y),)
ifneq ($(CFG_HI_RECOVERY_SUPPORT),y)
EXTRA_CFLAGS += -DCFG_HIFB_FENCE_SUPPORT
endif
endif

ifeq ($(CFG_ANDROID_PRODUCT),y)
ifneq ($(CFG_HI_RECOVERY_SUPPORT),y)
EXTRA_CFLAGS += -DCFG_HIFB_FENCE_SUPPORT
endif
EXTRA_CFLAGS += -DCFG_HIFB_ANDROID_SUPPORT
endif

ifeq ($(CFG_ANDROID_PRODUCT),y)
EXTRA_CFLAGS += -DCFG_HIFB_FENCE_TIMELINE_NUM=1
else
EXTRA_CFLAGS += -DCFG_HIFB_FENCE_TIMELINE_NUM=1
endif

ifeq ($(CFG_HIFB_CURSOR_SUPPORT), y)
EXTRA_CFLAGS += -DCFG_HIFB_CURSOR_SUPPORT
endif

ifeq ($(CFG_HI_FB_DECOMPRESS_SUPPORT), y)
EXTRA_CFLAGS += -DCFG_HI_FB_DECOMPRESS_SUPPORT
endif

ifeq ($(CFG_HIFB_SCROLLTEXT_SUPPORT), y)
EXTRA_CFLAGS += -DCFG_HIFB_SCROLLTEXT_SUPPORT
endif

EXTRA_CFLAGS += -DCFG_HIFB_STEREO3D_HW_SUPPORT

EXTRA_CFLAGS += -DCFG_HI_HD0_FB_VRAM_SIZE=$(CFG_HI_HD0_FB_VRAM_SIZE)
EXTRA_CFLAGS += -DCFG_HI_HD1_FB_VRAM_SIZE=$(CFG_HI_HD1_FB_VRAM_SIZE)
EXTRA_CFLAGS += -DCFG_HI_HD2_FB_VRAM_SIZE=$(CFG_HI_HD2_FB_VRAM_SIZE)
EXTRA_CFLAGS += -DCFG_HI_SD0_FB_VRAM_SIZE=$(CFG_HI_SD0_FB_VRAM_SIZE)

EXTRA_CFLAGS += -DCONFIG_GFX_STB_SDK
EXTRA_CFLAGS += -DCFG_HIFB_LOGO_SUPPORT

ifeq ($(CFG_HI_LOG_SUPPORT),y)
EXTRA_CFLAGS += -DCONFIG_GFX_LOG_SUPPORT
#EXTRA_CFLAGS += -DCONFIG_GFX_DFX_ENABLE
#EXTRA_CFLAGS += -DCONFIG_GFX_DBG_ENABLE
endif

ifeq ($(CFG_HI_SMMU_SUPPORT),y)
EXTRA_CFLAGS += -DCONFIG_GFX_MMU_SUPPORT
endif

ifeq ($(CFG_HI_FB0_SMMU_SUPPORT),y)
EXTRA_CFLAGS += -DCONFIG_GFX_HI_FB0_SMMU_SUPPORT
endif

ifeq ($(CFG_HI_FB1_SMMU_SUPPORT),y)
EXTRA_CFLAGS += -DCONFIG_GFX_HI_FB1_SMMU_SUPPORT
endif

ifeq ($(CFG_HI_FB2_SMMU_SUPPORT),y)
EXTRA_CFLAGS += -DCONFIG_GFX_HI_FB2_SMMU_SUPPORT
endif

ifeq ($(CFG_HI_PROC_SUPPORT),y)
EXTRA_CFLAGS += -DCONFIG_GFX_PROC_SUPPORT
else
EXTRA_CFLAGS += -DCONFIG_GFX_PROC_UNSUPPORT
endif

EXTRA_CFLAGS += -DCONFIG_GFX_PROC_DEBUG

MOD_NAME := hi_fb

obj-$(HI_DRV_BUILDTYPE) += $(MOD_NAME).o

EXTRA_CFLAGS += $(CFG_HI_KMOD_CFLAGS)

DRIVER_PATH := $(MSP_DIR)/drv/hifb

COMMON_FILES := $(wildcard $(DRIVER_PATH)/src/*.c)
ADAPT_FILES  := $(wildcard $(DRIVER_PATH)/adp/src/*.c)
HAL_FILES    := $(wildcard $(DRIVER_PATH)/adp/hal_$(HAL_VER)/*.c)
ALG_FILES    := $(wildcard $(DRIVER_PATH)/adp/alg/*.c)

ifeq ($(findstring -DCONFIG_GFX_PQ, $(EXTRA_CFLAGS)), -DCONFIG_GFX_PQ)
FULL_PATH_DRV_FILES += $(HAL_FILES)    \
		       $(ADAPT_FILES)  \
		       $(COMMON_FILES)
else
FULL_PATH_DRV_FILES += $(HAL_FILES)    \
                       $(ALG_FILES)    \
                       $(ADAPT_FILES)  \
                       $(COMMON_FILES)
endif

#ifeq ($(CFG_HIFB_SCROLLTEXT_SUPPORT), y)
#FULL_PATH_DRV_FILES := $(filter-out hifb_scrolltext.c, $(FULL_PATH_DRV_FILES))
#endif

DRV_SRCS := $(shell echo $(FULL_PATH_DRV_FILES) \
            | awk '{for(i=1;i<=NF;i++)print $$i}' \
            | sed "s:\(.*\)/\<hifb\>\(.*\):.\2:g")

DRV_SRCS_C := $(filter-out %.S, $(DRV_SRCS))
DRV_SRCS_A := $(filter-out %.c, $(DRV_SRCS))

DRV_OBJS := $(subst .c,.o,$(DRV_SRCS_C))
DRV_OBJS += $(subst .S,.o,$(DRV_SRCS_A))

$(MOD_NAME)-y := $(DRV_OBJS)

BUILD_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/$(subst $(SDK_DIR)/,,$(CURDIR))

BUILD_DIR_MAKEFILE := $(BUILD_DIR)/Makefile

#===============================================================================
#   rules
#===============================================================================
.PHONY: all clean

all: $(BUILD_DIR_MAKEFILE)
	$(AT)make -C $(LINUX_DIR) ARCH=$(CFG_HI_CPU_ARCH) CROSS_COMPILE=$(HI_KERNEL_TOOLCHAINS_NAME)- M=$(BUILD_DIR) src=$(CURDIR) modules
	$(AT)test -d $(HI_MODULE_DIR) || mkdir -p $(HI_MODULE_DIR)
	$(AT)cp -f $(BUILD_DIR)/$(MOD_NAME).ko $(HI_MODULE_DIR)/

clean:
	$(AT)make -C $(LINUX_DIR) ARCH=$(CFG_HI_CPU_ARCH) CROSS_COMPILE=$(HI_KERNEL_TOOLCHAINS_NAME)- M=$(BUILD_DIR) src=$(CURDIR) clean
	$(AT)rm -rf $(HI_MODULE_DIR)/$(MOD_NAME).ko

$(BUILD_DIR_MAKEFILE): $(BUILD_DIR)
	$(AT)touch $@

$(BUILD_DIR):
	$(AT)mkdir -p $@

