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
LIB_NAME := lib64
else
OBJ_NAME := obj
LIB_NAME := lib
endif

ifneq ($(HI_OUT_DIR),)
BUILD_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/wifi/tools/aircrack-ng
LOCAL_PREFIX :=  $(BUILD_DIR)/_install
LIBNL_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/wifi/tools/libnl/_install
OPENSSL_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/openssl/release
ZLIB_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/zlib/release
HWLOC_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/wifi/tools/hwloc/_install
PCRE_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/pcre/_install
else
BUILD_DIR := $(CURDIR)/tmp
LOCAL_PREFIX := $(COMPONENT_DIR)/wifi/tools/aircrack-ng/_install
LIBNL_DIR := $(COMPONENT_DIR)/wifi/tools/libnl/_install
OPENSSL_DIR := $(COMPONENT_DIR)/openssl/release
ZLIB_DIR := $(COMPONENT_DIR)/zlib/release
HWLOC_DIR := $(COMPONENT_DIR)/wifi/tools/hwloc/_install
PCRE_DIR := $(COMPONENT_DIR)/pcre/_install
endif

HOST := $(HI_KERNEL_TOOLCHAINS_NAME)
CROSS_COMPILE := $(HOST)-

INSTALL_DIR_BIN := $(HI_ROOTFS_DIR)/bin
INSTALL_DIR_SBIN := $(HI_ROOTFS_DIR)/sbin

INSTALL_DIR_LIB := $(HI_ROOTFS_DIR)/$(LIB_NAME)

MODULE_SRC := aircrack-ng-1.7
MODULE_BIN := aircrack-ng airdecap-ng airdecloak-ng buddy-ng ivstools kstats makeivs-ng packetforge-ng wpaclean
MODULE_SBIN := airbase-ng aireplay-ng airmon-ng airodump-ng airodump-ng-oui-update airserv-ng airtun-ng airventriloquist-ng
MODULE_LIB := libaircrack-ce-wpa-1.7.0.so libaircrack-osdep-1.7.0.so

MODULE_BIN_PATH := $(LOCAL_PREFIX)/bin/aircrack-ng \
	$(LOCAL_PREFIX)/bin/airdecap-ng \
	$(LOCAL_PREFIX)/bin/airdecloak-ng \
	$(LOCAL_PREFIX)/bin/buddy-ng \
	$(LOCAL_PREFIX)/bin/ivstools \
	$(LOCAL_PREFIX)/bin/kstats \
	$(LOCAL_PREFIX)/bin/makeivs-ng \
	$(LOCAL_PREFIX)/bin/packetforge-ng \
	$(LOCAL_PREFIX)/bin/wpaclean

MODULE_SBIN_PATH := $(LOCAL_PREFIX)/sbin/airbase-ng \
	$(LOCAL_PREFIX)/sbin/aireplay-ng \
	$(LOCAL_PREFIX)/sbin/airmon-ng \
	$(LOCAL_PREFIX)/sbin/airodump-ng \
	$(LOCAL_PREFIX)/sbin/airodump-ng-oui-update \
	$(LOCAL_PREFIX)/sbin/airserv-ng \
	$(LOCAL_PREFIX)/sbin/airtun-ng \
	$(LOCAL_PREFIX)/sbin/airventriloquist-ng

MODULE_LIB_PATH := $(LOCAL_PREFIX)/lib/libaircrack-ce-wpa-1.7.0.so \
	$(LOCAL_PREFIX)/lib/libaircrack-osdep-1.7.0.so

BUILD_MODULES = $(patsubst %,%_build,${MODULE_SRC})
UNINSTALL_MODULES_BIN = $(patsubst %,%_uninstall_bin,${MODULE_BIN})
UNINSTALL_MODULES_SBIN = $(patsubst %,%_uninstall_sbin,${MODULE_SBIN})
UNINSTALL_MODULES_LIB = $(patsubst %,%_uninstall_lib,${MODULE_LIB})

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#   rules
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#==================================================================
#                          all
#==================================================================
.PHONY: all clean install uninstall
all: $(BUILD_MODULES)
	@test -d $(INSTALL_DIR_BIN) || mkdir -p $(INSTALL_DIR_BIN)
	@cp -v $(MODULE_BIN_PATH) $(INSTALL_DIR_BIN)/
	@test -d $(INSTALL_DIR_SBIN) || mkdir -p $(INSTALL_DIR_SBIN)
	@cp -v $(MODULE_SBIN_PATH) $(INSTALL_DIR_SBIN)/
	@test -d $(INSTALL_DIR_LIB) || mkdir -p $(INSTALL_DIR_LIB)
	@cp -v $(MODULE_LIB_PATH) $(INSTALL_DIR_LIB)/

clean:
	@rm -rf $(BUILD_DIR)
	@rm -rf $(LOCAL_PREFIX)

install: all

uninstall: $(UNINSTALL_MODULES_BIN) $(UNINSTALL_MODULES_SBIN) $(UNINSTALL_MODULES_LIB)

#==================================================================
#                          modules
#==================================================================
%_build: $(BUILD_DIR)
	@echo -e "\033[31m""Build $(patsubst %_build,%,$@) ...""\033[00m"
	@test -d $(BUILD_DIR)/$(patsubst %_build,%,$@) \
		|| tar -zxf $(patsubst %_build,%,$@).tar.gz -C $(BUILD_DIR)
	cd $(BUILD_DIR)/$(patsubst %_build,%,$@) && \
	autoreconf -i && \
	./configure --with-experimental \
	--host=$(HOST) \
	--prefix=$(LOCAL_PREFIX) \
	--with-openssl=$(OPENSSL_DIR) \
	CFLAGS="-I$(OPENSSL_DIR)/include \
	-I$(LIBNL_DIR)/include/libnl3 \
	-I$(ZLIB_DIR)/include \
	-I$(HWLOC_DIR)/include \
	-I$(PCRE_DIR)/include" \
	LDFLAGS="-L$(OPENSSL_DIR)/lib \
	-L$(LIBNL_DIR)/lib \
	-L$(ZLIB_DIR)/lib \
	-L$(HWLOC_DIR)/lib \
	-L$(PCRE_DIR)/lib" \
	&& \
	make -j16 && \
	make install


$(BUILD_DIR):
	@test -d $(BUILD_DIR) || mkdir -p $(BUILD_DIR)

%_uninstall_bin:
	@rm -f $(INSTALL_DIR_BIN)/$(patsubst %_uninstall_bin,%,$@)

%_uninstall_sbin:
	@rm -f $(INSTALL_DIR_SBIN)/$(patsubst %_uninstall_sbin,%,$@)

%_uninstall_lib:
	@rm -f $(INSTALL_DIR_LIB)/$(patsubst %_uninstall_lib,%,$@)
