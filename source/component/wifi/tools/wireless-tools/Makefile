#===============================================================================
# export variables
#===============================================================================
ifeq ($(CFG_HI_EXPORT_FLAG),)
SDK_DIR := $(shell cd $(CURDIR)/../../../../.. && /bin/pwd)
include $(SDK_DIR)/base.mak
endif

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#   variable
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ifeq ($(CFG_HI_64BIT_SYSTEM),y)
OBJ_NAME := obj64
else
OBJ_NAME := obj
endif

ifneq ($(HI_OUT_DIR),)
BUILD_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/wifi/tools/wireless-tools
LOCAL_PREFIX :=  $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/wifi/tools/wireless-tools/_install
else
BUILD_DIR := $(CURDIR)/tmp
LOCAL_PREFIX := $(CURDIR)/_install
endif

HOST := $(HI_KERNEL_TOOLCHAINS_NAME)
CROSS_COMPILE := $(HOST)-

INSTALL_DIR := $(HI_ROOTFS_DIR)/sbin

ifeq ($(CFG_HI_64BIT_SYSTEM),y)
INSTALL_LIB_DIR := $(HI_ROOTFS_DIR)/lib64
else
INSTALL_LIB_DIR := $(HI_ROOTFS_DIR)/lib
endif

MODULE_SRC := wireless_tools.29
MODULE := ifrename iwconfig iwevent iwgetid iwlist iwpriv iwspy
MODULE_LIB := libiw.so.29

MODULE_PATH := $(LOCAL_PREFIX)/sbin/ifrename \
	$(LOCAL_PREFIX)/sbin/iwconfig \
	$(LOCAL_PREFIX)/sbin/iwevent \
	$(LOCAL_PREFIX)/sbin/iwgetid \
	$(LOCAL_PREFIX)/sbin/iwlist \
	$(LOCAL_PREFIX)/sbin/iwpriv \
	$(LOCAL_PREFIX)/sbin/iwspy \

MODULE_LIB_PATH := $(LOCAL_PREFIX)/lib/libiw.so.29

BUILD_MODULES = $(patsubst %,%_build,${MODULE_SRC})
UNINSTALL_MODULES = $(patsubst %,%_uninstall,${MODULE})
UNINSTALL_MODULES_LIB = $(patsubst %,%_uninstall_lib,${MODULE_LIB})

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
	@test -d $(INSTALL_LIB_DIR) || mkdir -p $(INSTALL_LIB_DIR)
	@cp -v $(MODULE_LIB_PATH) $(INSTALL_LIB_DIR)/

clean:
	@rm -rf $(BUILD_DIR)
	@rm -rf $(LOCAL_PREFIX)

install: all

uninstall: $(UNINSTALL_MODULES) \
	$(UNINSTALL_MODULES_LIB)

#==================================================================
#                          modules
#==================================================================
%_build: $(BUILD_DIR)
	@echo -e "\033[31m""Build $(patsubst %_build,%,$@) ...""\033[00m"
	@test -d $(BUILD_DIR)/$(patsubst %_build,%,$@) \
		|| tar -zxf $(patsubst %_build,%,$@).tar.gz -C $(BUILD_DIR) \
		&& cp wireless_tools-29-fix_iwlist_scanning-1.patch $(BUILD_DIR)
	cd $(BUILD_DIR)/$(patsubst %_build,%,$@) && \
		patch -Np1 -i ../wireless_tools-29-fix_iwlist_scanning-1.patch && \
		sed -i "s/CC = gcc/CC = $(CROSS_COMPILE)gcc/g" Makefile && \
		sed -i "s/AR = ar/AR = $(CROSS_COMPILE)ar/g" Makefile && \
		sed -i "s/RANLIB = ranlib/RANLIB = $(CROSS_COMPILE)ranlib/g" Makefile && \
		make -j 16 && \
		make PREFIX=$(LOCAL_PREFIX) install && \
		cd -

$(BUILD_DIR):
	@test -d $(BUILD_DIR) || mkdir -p $(BUILD_DIR)

%_uninstall:
	@rm -f $(INSTALL_DIR)/$(patsubst %_uninstall,%,$@)

%_uninstall_lib:
	@rm -f $(INSTALL_LIB_DIR)/$(patsubst %_uninstall_lib,%,$@)