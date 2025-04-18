################################################################################
#    Create By Czyong
################################################################################

PWD           = $(shell pwd)
CROSS_COMPILE = arm-hisiv200-linux-
TOPDIR        =
BINIMAGE      = $(TOPDIR)/fastboot-burn.bin

include $(TOPDIR)/config.mk

################################################################################
CC       := $(CROSS_COMPILE)gcc
AR       := $(CROSS_COMPILE)ar
LD       := $(CROSS_COMPILE)ld
OBJCOPY  := $(CROSS_COMPILE)objcopy

################################################################################
BOOT     := mini-boot

CFLAGS   := -g -Os -fno-strict-aliasing -fno-common \
	-D__KERNEL__ -DTEXT_BASE=$(TEXT_BASE) \
	-I$(TOPDIR)/include -Wall \
	-fno-builtin -ffreestanding \
	-mfloat-abi=soft \
	-pipe  -DCONFIG_ARM -D__ARM__ -marm  -mabi=aapcs-linux  \
	-mno-thumb-interwork -march=armv7-a $(MKFLAGS)

################################################################################
START    := start.o
COBJS    := arm_exception.o early_timer.o chip.o \
	startup.o cache-cp15.o uart.o mmu.o image_data.o tail.o sys_soft_reset.o

DDR_TRAINING_COBJS := ddr_training_impl.o ddr_training_ctl.o ddr_training_boot.o ddr_training_custom.o
COBJS    += $(DDR_TRAINING_COBJS)

REG      := $(wildcard $(TOPDIR)/*.reg $(TOPDIR)/.reg)

sinclude $(TOPDIR)/platform.mk
################################################################################
.PHONY: $(BOOT).bin

$(BOOT).bin: $(BOOT).elf regfile
	$(OBJCOPY) -O srec $< $(BOOT).srec
	$(OBJCOPY) --gap-fill=0xff -O binary $< $@
	@chmod 754 $(BOOT).bin
	@cp -fv $@ $(TOPDIR)
	@echo $(BOOT).bin is Ready.

$(BOOT).elf: image_data.lzma $(START) $(COBJS)
	$(LD) -Bstatic -T mini-boot.lds -Ttext $(TEXT_BASE) $(START) \
		$(COBJS) -Map $(BOOT).map -o $@

.PHONY: regfile
regfile:
	@if [ "$(words $(REG))" = "0" ]; then ( \
		echo '***' Need '.reg' or '*.reg' file in directory $(TOPDIR); \
		exit 1; \
	) fi

################################################################################
start.o: start.S
	$(CC) -D__ASSEMBLY__ $(CFLAGS) -o $@ $< -c

image_data.lzma: $(BINIMAGE)
	lzma -fkzc -7 $< > $@

%.o: %.c
	$(CC) $(CFLAGS) -Wall -Wstrict-prototypes \
		-fno-stack-protector -o $@ $< -c

%.o: %.S
	$(CC) -D__ASSEMBLY__ $(CFLAGS) -o $@ $< -c

image_data.o: image_data.S image_data.lzma
	$(CC) -D__ASSEMBLY__ $(CFLAGS) -o $@ $< -c

#############################################################################

$(DDR_TRAINING_COBJS):
	ln -fs $(TOPDIR)/drivers/ddr/hi3716mv420n/$@ ./

SRC := start.S tail.S arm_exception.S chip.c \
	early_timer.c uart.S sys_soft_reset.S

$(SRC):
	ln -fs ../$@ ./

SRC += mmu.S cache-cp15.c

cache-cp15.c \
mmu.S:
	ln -sf ./../../../lib/$@ ./

startup.c: unlzma.c

SRC += unlzma.c
unlzma.c:
	ln -fs ./../../../../../lib/$@ ./

################################################################################
TMPS := $(COBJS) start.o $(SRC) \
	$(BOOT).map $(BOOT).elf $(BOOT).srec $(BOOT).bin $(BOOT).tmp \
	image_data.lzma

distclean: clean

clean:
	@rm -f $(TMPS)

################################################################################
.PHONY: clean
################################################################################
