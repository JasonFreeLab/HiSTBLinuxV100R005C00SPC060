#
# (C) Copyright 2006
# Wolfgang Denk, DENX Software Engineering, wd@denx.de.
#
# See file CREDITS for list of people who contributed to this
# project.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA 02111-1307 USA
#

include $(TOPDIR)/config.mk

LIB	:= $(obj)libmmc.a

COBJS-$(CONFIG_GENERIC_MMC) += mmc.o
COBJS-$(CONFIG_HIMCI_V100) += himciv200.o himciv200_dbg_boot_read.o himci_mmc_test.o
COBJS-$(CONFIG_HIMCI_V200) += himciv200.o himciv200_dbg_boot_read.o himci_mmc_test.o
COBJS-$(CONFIG_HIMCI_V300) += himciv300.o himciv300_dbg_boot_read.o himci_mmc_test.o

COBJS-$(CONFIG_ATMEL_MCI) += atmel_mci.o
COBJS-$(CONFIG_BFIN_SDH) += bfin_sdh.o
COBJS-$(CONFIG_OMAP3_MMC) += omap3_mmc.o
COBJS-$(CONFIG_FSL_ESDHC) += fsl_esdhc.o
COBJS-$(CONFIG_MXC_MMC) += mxcmmc.o
COBJS-$(CONFIG_PXA_MMC) += pxa_mmc.o
COBJS-$(CONFIG_ARCH_HI3798CV2X) += mmc_ids_hi3798cvx.o
COBJS-$(CONFIG_ARCH_HI3798MV2X) += mmc_ids_hi3798mvx.o
COBJS-$(CONFIG_ARCH_HI3798MV310) += mmc_ids_hi3798mv310.o
COBJS-$(CONFIG_ARCH_HI3796MV2X) += mmc_ids_hi3796mv2x.o

COBJS	:= $(COBJS-y)
SRCS	:= $(COBJS:.o=.c)
OBJS	:= $(addprefix $(obj),$(COBJS))

all:	$(LIB)

$(LIB): $(obj).depend $(OBJS)
	$(AR) $(ARFLAGS) $@ $(OBJS)

#########################################################################

# defines $(obj).depend target
include $(SRCTREE)/rules.mk

sinclude $(obj).depend

#########################################################################
