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
EXTRA_CFLAGS += $(CFG_HI_KMOD_CFLAGS)

EXTRA_CFLAGS += -I$(COMMON_UNF_INCLUDE)                 \
                -I$(COMMON_API_INCLUDE)                 \
                -I$(COMMON_DRV_INCLUDE)                 \
                -I$(MSP_UNF_INCLUDE)                    \
                -I$(MSP_API_INCLUDE)                    \
                -I$(MSP_DRV_INCLUDE)                    \
                -I$(MSP_DIR)/api/higo/include	        \
                -I$(MSP_DIR)/api/tde/include	        \
                -I$(MSP_DIR)/api/jpge/include	        \
                -I$(MSP_DIR)/drv/jpge/include	        \
                -I$(MSP_DIR)/drv/adsp/adsp_v1_1/include

ifeq ($(CFG_HI_RECOVERY_SUPPORT),y)
EXTRA_CFLAGS += -DHI_RECOVERY_SUPPORT
endif

ifeq ($(CFG_HI_FRONTEND_SUPPORT),y)
EXTRA_CFLAGS += -DHI_FRONTEND_SUPPORT
endif

ifeq ($(CFG_HI_PLCIPHER_SUPPORT),y)
EXTRA_CFLAGS += -DHI_PLCIPHER_SUPPORT
endif

ifeq ($(CFG_ANDROID_PRODUCT),y)
EXTRA_CFLAGS += -DHI_OMX_SUPPORT
endif

ifeq ($(CFG_HI_IR_TYPE_LIRC),y)
EXTRA_CFLAGS += -DHI_IR_TYPE_LIRC
endif

ifeq ($(CFG_HI_SPI_BUS_SUPPORT),y)
EXTRA_CFLAGS += -DHI_SPI_BUS_SUPPORT
endif

ifeq ($(CFG_HI_PWM_SUPPORT),y)
EXTRA_CFLAGS += -DHI_PWM_SUPPORT
endif

ifeq ($(CFG_HI_ADVCA_SUPPORT),y)
EXTRA_CFLAGS += -DHI_ADVCA_SUPPORT
ifeq ($(CFG_ADVCA_NAGRA),y)
EXTRA_CFLAGS += -DHI_ADVCA_C1_SUPPORT
endif
endif

ifeq ($(CFG_HI_OTP_KLAD_V100),y)
    EXTRA_CFLAGS += -DCA_FRAMEWORK_V100_SUPPORT
else ifeq ($(CFG_HI_OTP_KLAD_V200),y)
    EXTRA_CFLAGS += -DCA_FRAMEWORK_V200_SUPPORT
else
    $(error otp_klad version is error)
endif

ifeq ($(CFG_HI_JPGE_SUPPORT),y)
EXTRA_CFLAGS += -DHI_JPGE_SUPPORT
endif

ifeq ($(findstring $(CFG_HI_CHIP_TYPE), hi3798mv100 hi3796mv100),)
EXTRA_CFLAGS += -DHI_WDG_SUPPORT
endif

ifeq ($(CFG_HI_CIPLUS_SUPPORT),y)
    EXTRA_CFLAGS += -DHI_CIPLUS_SUPPORT

    ifeq ($(CFG_HI_CI_DEV_CIMAX),y)
    EXTRA_CFLAGS += -DHI_CI_DEV_CIMAX
    endif

    ifeq ($(CFG_HI_CI_DEV_CIMAXPLUS),y)
    EXTRA_CFLAGS += -DHI_CI_DEV_CIMAXPLUS
    endif

    ifeq ($(CFG_HI_CI_DEV_HICI),y)
    EXTRA_CFLAGS += -DHI_CI_DEV_HICI
    endif
endif

ifeq ($(CFG_HI_SM_SUPPORT),y)
EXTRA_CFLAGS += -DHI_SM_SUPPORT
endif

ifeq ($(CFG_HI_MAILBOX_SUPPORT),y)
EXTRA_CFLAGS += -DHI_MAILBOX_SUPPORT
endif

ifeq ($(CFG_HI_LOAD_CAS_IMAGE),y)
EXTRA_CFLAGS += -DHI_LOAD_CAS_IMAGE
endif

MOD_NAME := hi_base

obj-y += $(MOD_NAME).o

$(MOD_NAME)-y   :=  hi_init.o
