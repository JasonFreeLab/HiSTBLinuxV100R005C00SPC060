################################################################################
#     COPYRIGHT (C) 2012 Czyong. Hisilicon
#     All rights reserved.
# 
#     Create by Czyong 2012-12-20
# 
################################################################################

CFLAGS += -Wall -Wstrict-prototypes -fno-stack-protector

SRCS-y := start.S early_irq.S

SRCS-y += lowlevel_init.c irq.c

SRCS-y += early_uart.S chip.c cpu.c tail.S

SRCS-y += sys_soft_reset.S

TEMPS   += $(TOPDIR)/.init.reg

$(SRCDIR)start.o: $(TOPDIR)/.init.reg

$(TOPDIR)/.init.reg: $(INIT_REG)
	@cp -f $< $@

