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
BUILD_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/wifi/tools/libnl
LOCAL_PREFIX :=  $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/wifi/tools/libnl/_install
else
BUILD_DIR := $(CURDIR)/tmp
LOCAL_PREFIX := $(COMPONENT_DIR)/wifi/tools/libnl/_install
endif

INSTALL_DIR := $(HI_ROOTFS_DIR)/$(LIB_NAME)

HOST := $(HI_KERNEL_TOOLCHAINS_NAME)
CROSS_COMPILE := $(HOST)-

MODULE_SRC := libnl-3.5.0
MODULE := libnl-3.so.200.26.0 \
	libnl-3.so.200 \
	libnl-genl-3.so.200.26.0 \
	libnl-genl-3.so.200 \
	libnl-route-3.so.200.26.0 \
	libnl-route-3.so.200
MODULE_PATH := $(BUILD_DIR)/$(MODULE_SRC)/lib/.libs/libnl-3.so.200.26.0 \
	$(BUILD_DIR)/$(MODULE_SRC)/lib/.libs/libnl-3.so.200 \
	$(BUILD_DIR)/$(MODULE_SRC)/lib/.libs/libnl-genl-3.so.200.26.0 \
	$(BUILD_DIR)/$(MODULE_SRC)/lib/.libs/libnl-genl-3.so.200 \
	$(BUILD_DIR)/$(MODULE_SRC)/lib/.libs/libnl-route-3.so.200.26.0 \
	$(BUILD_DIR)/$(MODULE_SRC)/lib/.libs/libnl-route-3.so.200

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
#                          modules
#==================================================================
%_build: $(BUILD_DIR)
	@echo -e "\033[31m""Build $(patsubst %_build,%,$@) ...""\033[00m"
	@test -d $(BUILD_DIR)/$(patsubst %_build,%,$@) \
		|| tar -zxf $(patsubst %_build,%,$@).tar.gz -C $(BUILD_DIR)
	cd $(BUILD_DIR)/$(patsubst %_build,%,$@) && \
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
