################################################################################
ifeq ($(CFG_HI_EXPORT_FLAG),)
SDK_DIR ?= $(shell cd $(shell pwd)/../../../.. && /bin/pwd)

include $(SDK_DIR)/base.mak
endif

#===============================================================================
# local variables
#===============================================================================
ifeq ($(CFG_HI_MINIBOOT_SUPPORT),y)
BOOT_DIR := $(SDK_DIR)/source/boot/miniboot
else
BOOT_DIR := $(SDK_DIR)/source/boot/fastboot
endif

ifneq ($(O),)
PRODUCT_DIR := $(O)/product
else
PRODUCT_DIR := $(BOOT_DIR)/../product
endif

SSA_DIR := $(PRODUCT_DIR)/ssa

# The case for advca type
ifeq ($(CFG_HI_ADVCA_TYPE), CONAX)
CA_DIR := conax
else ifeq ($(CFG_HI_ADVCA_TYPE), VERIMATRIX)
CA_DIR := vmx_advance
else ifeq ($(CFG_HI_ADVCA_TYPE), VERIMATRIX_ULTRA)
CA_DIR := vmx_ultra
else ifeq ($(CFG_HI_ADVCA_TYPE), NAGRA)
CA_DIR := nagra
else ifeq ($(CFG_HI_ADVCA_TYPE), DCAS)
CA_DIR := dcas
else ifeq ($(CFG_HI_ADVCA_TYPE), IRDETO)
CA_DIR := irdeto
else ifeq ($(CFG_HI_ADVCA_TYPE), L2)
CA_DIR := general/L2
else
# The case for common CA or other special usage
CA_DIR := misc
endif

#===============================================================================
# rules
#===============================================================================
all:
	$(AT)make -C $(SSA_DIR)/$(CA_DIR) install

clean:
	$(AT)make -C $(SSA_DIR)/$(CA_DIR) clean

install: all

uninstall:
