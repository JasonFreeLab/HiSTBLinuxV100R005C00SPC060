#===============================================================================
# export variables
#===============================================================================
ifeq ($(CFG_HI_EXPORT_FLAG),)
SDK_DIR := $(shell cd $(CURDIR)/../../../../.. && /bin/pwd)
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
BUILD_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/wifi/tools/tcpdump
LOCAL_PREFIX := $(BUILD_DIR)/_install
LIBNL_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/wifi/tools/libnl/_install
OPENSSL_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/openssl/release
else
BUILD_DIR  := $(CURDIR)/tmp
LOCAL_PREFIX := $(COMPONENT_DIR)/wifi/tools/tcpdump/_install
LIBNL_DIR := $(COMPONENT_DIR)/wifi/tools/libnl/_install
OPENSSL_DIR := $(COMPONENT_DIR)/openssl/release
endif

PKG_CONFIG_PATH := $(LIBNL_DIR)/lib/pkgconfig:$(OPENSSL_DIR)/lib/pkgconfig

INSTALL_DIR := $(HI_ROOTFS_DIR)/bin

HOST := $(HI_KERNEL_TOOLCHAINS_NAME)
CROSS_COMPILE := $(HOST)-

MODULE_SRC := tcpdump-4.99.5
MODULE := tcpdump
MODULE_PATH := $(LOCAL_PREFIX)/bin/tcpdump

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
	@rm -rf $(LOCAL_PREFIX)

install: all

uninstall: $(UNINSTALL_MODULES)

#==================================================================
#                          modules LDFLAGS=-static 
#==================================================================
%_build: $(BUILD_DIR)
	@echo -e "\033[31m""Build $(patsubst %_build,%,$@) ...""\033[00m"
	@test -d $(BUILD_DIR)/$(patsubst %_build,%,$@) \
		|| tar Jxvf $(patsubst %_build,%,$@).tar.xz -C $(BUILD_DIR)
	cd $(BUILD_DIR)/$(patsubst %_build,%,$@) && \
	export PKG_CONFIG_PATH="$(PKG_CONFIG_PATH):$$PKG_CONFIG_PATH" && \
	./configure \
		--host=$(HOST) \
		--prefix=$(LOCAL_PREFIX) && \
	make -j16 && \
	make install && \
	cd -

$(BUILD_DIR):
	@test -d $(BUILD_DIR) || mkdir -p $(BUILD_DIR)

%_uninstall:
	@rm -f $(INSTALL_DIR)/$(patsubst %_uninstall,%,$@)