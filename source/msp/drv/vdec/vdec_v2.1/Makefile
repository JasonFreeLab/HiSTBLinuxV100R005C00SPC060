#===============================================================================
# export variables
#===============================================================================
ifeq ($(CFG_HI_EXPORT_FLAG),)
    ifneq ($(srctree),)
    KERNEL_DIR := $(srctree)

    SDK_DIR := $(shell cd $(KERNEL_DIR)/../../.. && /bin/pwd)
    else
    SDK_DIR := $(shell cd $(CURDIR)/../../../../.. && /bin/pwd)
    endif

    include $(SDK_DIR)/base.mak
endif

#===============================================================================
# local variables
#===============================================================================
EXTRA_CFLAGS += $(CFG_HI_KMOD_CFLAGS)

EXTRA_CFLAGS += -I$(COMMON_UNF_INCLUDE)                 \
                -I$(COMMON_API_INCLUDE)                 \
                -I$(COMMON_DRV_INCLUDE)                 \
                -I$(MSP_UNF_INCLUDE)                    \
                -I$(MSP_API_INCLUDE)                    \
                -I$(MSP_DRV_INCLUDE)                    \
                -I$(MSP_DIR)/api/vdec/vdec_v2.1         \
                -I$(MSP_DIR)/drv/vdec/vdec_v2.1         \
                -I$(MSP_DIR)/drv/vfmw/vfmw_v5.1/adapter \
                -I$(MSP_DIR)/drv/vfmw/vfmw_v5.1 \
                -I$(MSP_DIR)/drv/omxvdec/omxvdec_v2.1
ifeq ($(CFG_HI_TEE_SUPPORT),y)
EXTRA_CFLAGS += -I$(TEE_DRV_INCLUDE)
endif

ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3716mv410 hi3716mv420),)
EXTRA_CFLAGS += -DHi3716MV410
endif

ifeq ($(CFG_ANDROID_PRODUCT),y)
EXTRA_CFLAGS += -DANDROID
endif

#===============================================================================
# memory config end
#===============================================================================

EXTRA_CFLAGS += -DHI_VDEC_MAX_INSTANCE=16

ifeq (HD_SIMPLE,$(CFG_HI_VFMW_DECODE_CAPABILITY))
EXTRA_CFLAGS += -DHI_VDEC_HD_SIMPLE=1
else
EXTRA_CFLAGS += -DHI_VDEC_HD_SIMPLE=0
endif

ifeq (y,$(CFG_HI_VDEC_USERDATA_CC_SUPPORT))
EXTRA_CFLAGS += -DHI_VDEC_USERDATA_CC_SUPPORT=1
else
EXTRA_CFLAGS += -DHI_VDEC_USERDATA_CC_SUPPORT=0
endif

ifeq ($(CFG_HI_TEE_SUPPORT),y)
EXTRA_CFLAGS += -DHI_TEE_SUPPORT
endif

ifeq (y,$(CFG_HI_VDEC_PRE_ALLOC_VDHMMZ_SUPPORT))
EXTRA_CFLAGS += -DPRE_ALLOC_VDEC_VDH_MMZ=1
else
EXTRA_CFLAGS += -DPRE_ALLOC_VDEC_VDH_MMZ=0
endif

MOD_NAME := hi_vdec

obj-$(HI_DRV_BUILDTYPE) += $(MOD_NAME).o

$(MOD_NAME)-y   :=  drv_vdec_buf_mng.o      \
                    drv_vdec_intf.o         \
                    drv_vdec_intf_k.o

ifeq (y,$(CFG_HI_VDEC_USERDATA_CC_SUPPORT))
$(MOD_NAME)-y   += drv_vdec_userdata.o
endif

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
