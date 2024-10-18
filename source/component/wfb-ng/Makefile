#===============================================================================
# export variables
#===============================================================================
ifeq ($(CFG_HI_EXPORT_FLAG),)
SDK_DIR := $(shell cd $(CURDIR)/../../.. && /bin/pwd)
include $(SDK_DIR)/base.mak
endif

#===============================================================================
#   variable
#===============================================================================
ifeq ($(CFG_HI_64BIT_SYSTEM),y)
OBJ_NAME := obj64
else
OBJ_NAME := obj
endif

ifneq ($(HI_OUT_DIR),)
BUILD_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/wfb-ng
LIBSODIUM_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/libsodium/_install
LIBNL_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/wifi/tools/libnl/_install
LIBPCAP_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/wifi/tools/libpcap/_install
else
BUILD_DIR  := $(CURDIR)/tmp
LIBSODIUM_DIR := $(COMPONENT_DIR)/libsodium/_install
LIBNL_DIR := $(COMPONENT_DIR)/wifi/tools/libnl/_install
LIBPCAP_DIR := $(COMPONENT_DIR)/wifi/tools/libpcap/_install
endif

INSTALL_DIR := $(HI_ROOTFS_DIR)/usr/bin

HOST := $(HI_KERNEL_TOOLCHAINS_NAME)
CROSS_COMPILE := $(HOST)-

MODULE_SRC := wfb-ng-wfb-ng-24.08.2
MODULE := wfb_rx wfb_tx wfb_keygen wfb_tx_cmd
MODULE_PATH := $(BUILD_DIR)/$(MODULE_SRC)/wfb_rx \
	$(BUILD_DIR)/$(MODULE_SRC)/wfb_rx \
	$(BUILD_DIR)/$(MODULE_SRC)/wfb_tx \
	$(BUILD_DIR)/$(MODULE_SRC)/wfb_keygen \
	$(BUILD_DIR)/$(MODULE_SRC)/wfb_tx_cmd

BUILD_MODULES = $(patsubst %,%_build,${MODULE_SRC})
UNINSTALL_MODULES = $(patsubst %,%_uninstall,${MODULE})

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#   rules
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#==================================================================
#                          all
#==================================================================
.PHONY: all clean install uninstall
all: $(BUILD_MODULES)
	@test -d $(INSTALL_DIR) || mkdir -p $(INSTALL_DIR)
	@cp -v $(MODULE_PATH) $(INSTALL_DIR)/

clean:
	@rm -rf $(BUILD_DIR)

install: all

uninstall: $(UNINSTALL_MODULES)

#==================================================================
#                          modules LDFLAGS=-static 
#==================================================================
%_build: $(BUILD_DIR)
	@echo -e "\033[31m""Build $(patsubst %_build,%,$@) ...""\033[00m"
	@test -d $(BUILD_DIR)/$(patsubst %_build,%,$@) \
		|| tar -zxf $(OPEN_SOURCE_DIR)/$(patsubst %_build,%,$@).tar.gz -C $(BUILD_DIR) \
		&& cp wfb-ng-wfb-ng-24.08.2.patch $(BUILD_DIR)
	cd $(BUILD_DIR)/$(patsubst %_build,%,$@) && \
	patch -Np1 -i ../wfb-ng-wfb-ng-24.08.2.patch && \
	make all_bin -j16 \
		ARCH=$(CFG_HI_CPU_ARCH) \
		CC=$(CROSS_COMPILE)gcc \
		CXX=$(CROSS_COMPILE)g++ \
		CFLAGS+="-I$(LIBNL_DIR)/include/libnl3 \
			-I$(LIBPCAP_DIR)/include \
			-I$(LIBSODIUM_DIR)/include" \
		LDFLAGS+="-L$(LIBNL_DIR)/lib -lnl-genl-3 -lnl-3 \
			-L$(LIBPCAP_DIR)/lib \
			-L$(LIBSODIUM_DIR)/lib" && \
	cd -

$(BUILD_DIR):
	@test -d $(BUILD_DIR) || mkdir -p $(BUILD_DIR)

%_uninstall:
	@rm -f $(INSTALL_DIR)/$(patsubst %_uninstall,%,$@)