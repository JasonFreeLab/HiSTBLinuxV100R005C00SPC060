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
LIB_NAME := lib64
else
OBJ_NAME := obj
LIB_NAME := lib
endif

ifneq ($(HI_OUT_DIR),)
BUILD_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/x264
LOCAL_PREFIX := $(BUILD_DIR)/_install
else
BUILD_DIR  := $(CURDIR)/tmp
LOCAL_PREFIX := $(COMPONENT_DIR)/x264/_install
endif

INSTALL_BIN_DIR := $(HI_ROOTFS_DIR)/bin
INSTALL_LIB_DIR := $(HI_ROOTFS_DIR)/$(LIB_NAME)

HOST := $(HI_KERNEL_TOOLCHAINS_NAME)
CROSS_COMPILE := $(HOST)-

MODULE_SRC := x264-master

MODULE_BIN := x264
MODULE_BIN_PATH := $(LOCAL_PREFIX)/bin/x264
MODULE_LIB := libx264.so.164
MODULE_LIB_PATH := $(LOCAL_PREFIX)/lib/libx264.so.164

BUILD_MODULES = $(patsubst %,%_build,${MODULE_SRC})
UNINSTALL_BIN_MODULES = $(patsubst %,%_uninstall_bin,${MODULE_BIN})
UNINSTALL_LIB_MODULES = $(patsubst %,%_uninstall_lib,${MODULE_LIB})

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#   rules
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#==================================================================
#                          all
#==================================================================
.PHONY: all clean install uninstall
all: $(BUILD_MODULES)
	@test -d $(INSTALL_BIN_DIR) || mkdir -p $(INSTALL_BIN_DIR)
	@cp -v $(MODULE_BIN_PATH) $(INSTALL_BIN_DIR)/
	@test -d $(INSTALL_LIB_DIR) || mkdir -p $(INSTALL_LIB_DIR)
	@cp -v $(MODULE_LIB_PATH) $(INSTALL_LIB_DIR)/

clean:
	@rm -rf $(BUILD_DIR)
	@rm -rf $(LOCAL_PREFIX)

install: all

uninstall: $(UNINSTALL_BIN_MODULES) $(UNINSTALL_LIB_MODULES)

#==================================================================
#                          modules
#==================================================================
%_build: $(BUILD_DIR)
	@echo -e "\033[31m""Build $(patsubst %_build,%,$@) ...""\033[00m"
	@test -d $(BUILD_DIR)/$(patsubst %_build,%,$@) \
		|| tar -xjf $(OPEN_SOURCE_DIR)/$(patsubst %_build,%,$@).tar.bz2 -C $(BUILD_DIR)
	cd $(BUILD_DIR)/$(patsubst %_build,%,$@) && \
	./configure \
		--cross-prefix=$(CROSS_COMPILE) \
		--host=$(HOST) \
		--prefix=$(LOCAL_PREFIX) \
		--enable-shared \
		--disable-asm && \
	make -j16 && \
	make install && \
	cd -

$(BUILD_DIR):
	@test -d $(BUILD_DIR) || mkdir -p $(BUILD_DIR)

%_uninstall_bin:
	@rm -f $(INSTALL_BIN_DIR)/$(patsubst %_uninstall_bin,%,$@)

%_uninstall_lib:
	@rm -f $(INSTALL_LIB_DIR)/$(patsubst %_uninstall_lib,%,$@)