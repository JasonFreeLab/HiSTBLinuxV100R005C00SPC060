#===============================================================================
# export variable
#===============================================================================
ifeq ($(CFG_HI_EXPORT_FLAG),)
SDK_DIR ?= $(shell cd $(CURDIR)/../../.. && /bin/pwd)

include $(SDK_DIR)/base.mak
endif

CUTILS_SRC_DIR := base/cutils
UTILS_SRC_DIR := base/utils
LIBLOG_SRC_DIR := base/liblog
BINDER_IPC_SRC_DIR := base/ipc

ifeq ($(CFG_SINGLE_PROCESS_ENABLE), )
MULTI_PROCESS := y
else
MULTI_PROCESS := n
endif

TARGETS :=drm


#===============================================================================
# rules
#===============================================================================
.PHONY: all drm clean

all: $(TARGETS)

drm: build_cutils build_utils build_liblog build_binder_ipc build_servicemanager build_drmservice build_drmengine

build_cutils: build_liblog
	$(AT)make -j16 -C $(CUTILS_SRC_DIR) all

build_utils: build_liblog build_cutils
	$(AT)make -j16 -C $(UTILS_SRC_DIR) all

build_liblog:
	$(AT)make -j16 -C $(LIBLOG_SRC_DIR) all

build_binder_ipc: build_cutils build_utils build_liblog
	$(AT)make -j16 -C $(BINDER_IPC_SRC_DIR) all

build_servicemanager: build_cutils build_utils build_liblog build_binder_ipc
ifeq ($(MULTI_PROCESS),y)
	$(AT)make -j16 -C servicemanager all $(LOGFLAGS)
else
	$(AT)echo "Not make -j16 servicemanager, SINGLE PROCESS"
endif

build_drmservice: build_cutils build_utils build_liblog build_binder_ipc
	$(AT)make -j16 -C drmservice all $(LOGFLAGS)

build_drmengine: build_cutils build_utils build_liblog build_drmservice
	$(AT)make -j16 -C drmengine all $(LOGFLAGS)

clean:
	$(AT)make -j16 -C $(CUTILS_SRC_DIR) clean
	$(AT)make -j16 -C $(UTILS_SRC_DIR) clean
	$(AT)make -j16 -C $(LIBLOG_SRC_DIR) clean
	$(AT)make -j16 -C $(BINDER_IPC_SRC_DIR) clean
ifeq ($(MULTI_PROCESS),y)
	$(AT)make -j16 -C servicemanager clean
endif
	$(AT)make -j16 -C drmservice clean
	$(AT)make -j16 -C drmengine clean