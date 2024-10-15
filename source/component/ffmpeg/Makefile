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
BUILD_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/ffmpeg
LOCAL_PREFIX := $(BUILD_DIR)/_install
X264_DIR := $(HI_OUT_DIR)/$(OBJ_NAME)/source/component/x264/_install
else
BUILD_DIR  := $(CURDIR)/tmp
LOCAL_PREFIX := $(COMPONENT_DIR)/ffmpeg/_install
X264_DIR := $(COMPONENT_DIR)/x264/_install
endif

INSTALL_BIN_DIR := $(HI_ROOTFS_DIR)/bin
INSTALL_LIB_DIR := $(HI_ROOTFS_DIR)/$(LIB_NAME)

HOST := $(HI_KERNEL_TOOLCHAINS_NAME)
CROSS_COMPILE := $(HOST)-

MODULE_SRC := FFmpeg-n4.3.8
MODULE_BIN := ffmpeg
MODULE_BIN_PATH := $(LOCAL_PREFIX)/bin/ffmpeg
MODULE_LIB := libavcodec.so.58.91.100 \
libavdevice.so.58.10.100 \
libavfilter.so.7.85.100 \
libavformat.so.58.45.100 \
libavutil.so.56.51.100 \
libpostproc.so.55.7.100 \
libswresample.so.3.7.100 \
libswscale.so.5.7.100
MODULE_LIB_PATH := $(LOCAL_PREFIX)/lib/libavcodec.so.58.91.100 \
$(LOCAL_PREFIX)/lib/libavdevice.so.58.10.100 \
$(LOCAL_PREFIX)/lib/libavfilter.so.7.85.100 \
$(LOCAL_PREFIX)/lib/libavformat.so.58.45.100 \
$(LOCAL_PREFIX)/lib/libavutil.so.56.51.100 \
$(LOCAL_PREFIX)/lib/libpostproc.so.55.7.100 \
$(LOCAL_PREFIX)/lib/libswresample.so.3.7.100 \
$(LOCAL_PREFIX)/lib/libswscale.so.5.7.100

BUILD_MODULES = $(patsubst %,%_build,${MODULE_SRC})
UNINSTALL_BIN_MODULES = $(patsubst %,%_uninstall_bin,${MODULE_BIN_PATH})
UNINSTALL_LIB_MODULES = $(patsubst %,%_uninstall_lib,${MODULE_LIB_PATH})

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
		|| tar -zxf $(OPEN_SOURCE_DIR)/$(patsubst %_build,%,$@).tar.gz -C $(BUILD_DIR)
	cd $(BUILD_DIR)/$(patsubst %_build,%,$@) && \
	./configure \
	--cross-prefix=$(CROSS_COMPILE) \
	--enable-cross-compile \
	--target-os=linux \
	--cc=$(CROSS_COMPILE)gcc \
	--arch=arm \
	--prefix=$(LOCAL_PREFIX) \
	--enable-shared \
	--disable-static \
	--enable-gpl \
	--enable-version3 \
	--enable-libx264 \
	--disable-x86asm \
	--disable-asm \
	--enable-parsers \
	--disable-decoders \
	--enable-decoder=h264 \
	--enable-decoder=aac \
	--disable-debug \
	--disable-encoders \
	--disable-muxers \
	--enable-muxer=mp4 \
	--disable-demuxers \
	--disable-protocols \
	--enable-protocol=file \
	--disable-filters \
	--disable-bsfs \
	--disable-stripping \
	--disable-doc \
	--enable-swresample \
	--enable-ffmpeg \
	--extra-libs=-ldl \
	--extra-cflags="-I$(X264_DIR)/include" \
	--extra-ldflags="-L$(X264_DIR)/lib" \
	&& \
	make -j16 && \
	make install && \
	cd -

$(BUILD_DIR):
	@test -d $(BUILD_DIR) || mkdir -p $(BUILD_DIR)

%_uninstall_bin:
	@rm -f $(INSTALL_BIN_DIR)/$(patsubst %_uninstall_bin,%,$@)

%_uninstall_lib:
	@rm -f $(INSTALL_LIB_DIR)/$(patsubst %_uninstall_lib,%,$@)