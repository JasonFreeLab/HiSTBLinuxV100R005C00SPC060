#===============================================================================
# export variables
#===============================================================================
ifeq ($(CFG_HI_EXPORT_FLAG),)
SDK_DIR := $(shell cd $(CURDIR)/../../.. && /bin/pwd)
include $(SDK_DIR)/base.mak
endif

#===============================================================================
# local variable
#===============================================================================
CFLAGS += -I$(SDK_DIR)/source/msp/include
CFLAGS += -I$(CURDIR)/include

SRCS := src/hi_unf_so.c \
        src/so_queue.c

LIB_NAME := libhi_so

HEADER_FILES := $(CURDIR)/include/hi_unf_so.h

include $(SDK_DIR)/hi_rules.mak

