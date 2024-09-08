#===============================================================================
# export variables
#===============================================================================
ifeq ($(CFG_HI_EXPORT_FLAG),)
SDK_DIR := $(shell cd $(CURDIR)/../../../.. && /bin/pwd)
include $(SDK_DIR)/base.mak
endif

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#   variable
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
objects := libnl

ifeq ($(CFG_HI_WIFI_MODE_STA),y)
objects += wpa_supplicant
endif

ifeq ($(CFG_HI_WIFI_MODE_AP),y)
objects += hostapd
endif

ifeq ($(CFG_HI_WIFI_TOOL_WIRELESS_TOOLS),y)
objects += wireless-tools
endif

ifeq ($(CFG_HI_WIFI_TOOL_IW),y)
objects += iw
endif

ifeq ($(CFG_HI_WIFI_TOOL_AIRCRACK_NG),y)
objects += hwloc
objects += aircrack-ng
objects += libmnl
objects += ethtool
endif

ifeq ($(CFG_HI_WIFI_TOOL_TCPDUMP),y)
objects += libpcap
objects += tcpdump
endif

objects_clean:=$(addsuffix _clean,$(objects))
objects_install:=$(addsuffix _install,$(objects))
objects_uninstall:=$(addsuffix _uninstall,$(objects))

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#   rules
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#==================================================================
#                          all
#==================================================================
.PHONY: all clean install uninstall
all: $(objects)
ifeq ($(CFG_HI_WIFI_MODE_STA),y)
wpa_supplicant: libnl
endif
ifeq ($(CFG_HI_WIFI_MODE_AP),y)
hostapd: libnl
endif
ifeq ($(CFG_HI_WIFI_TOOL_IW),y)
iw: libnl
endif
ifeq ($(CFG_HI_WIFI_TOOL_AIRCRACK_NG),y)
aircrack-ng: libnl hwloc
ethtool: libmnl
endif
ifeq ($(CFG_HI_WIFI_TOOL_TCPDUMP),y)
libpcap: libnl
tcpdump: libnl libpcap
endif

clean: $(objects_clean)

install: $(objects_install)
ifeq ($(CFG_HI_WIFI_MODE_STA),y)
wpa_supplicant_install: libnl_install
endif
ifeq ($(CFG_HI_WIFI_MODE_AP),y)
hostapd_install: libnl_install
endif
ifeq ($(CFG_HI_WIFI_TOOL_IW),y)
iw_install: libnl_install
endif
ifeq ($(CFG_HI_WIFI_TOOL_AIRCRACK_NG),y)
aircrack-ng_install: libnl_install hwloc_install
ethtool_install: libmnl_install
endif
ifeq ($(CFG_HI_WIFI_TOOL_TCPDUMP),y)
libpcap_install: libnl_install
tcpdump_install: libnl_install libpcap_install
endif

uninstall: $(objects_uninstall)

prepare:

unprepare:

#==================================================================
#                          modules
#==================================================================
.PHONY: $(objects) $(objects_clean) $(objects_install) $(objects_uninstall)

$(objects):
	make -C $@ all

$(objects_clean):
	make -C $(patsubst %_clean,%,$@) clean

$(objects_install):
	make -C $(patsubst %_install,%,$@) install

$(objects_uninstall):
	make -C $(patsubst %_uninstall,%,$@) uninstall

