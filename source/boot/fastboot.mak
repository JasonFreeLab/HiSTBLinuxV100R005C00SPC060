################################################################################
#    source/boot/Makefile
#    Create By czyong, yjtao
#    2012.09.17
################################################################################

#
#  import variable.
#

#  CFG_HI_BOOT_ENV_STARTADDR
#  CFG_HI_BOOT_ENV_SIZE
#  CFG_HI_BOOT_ENV_RANGE
#  CFG_HI_EXPORT_FLAG
#  CFG_HI_BOOT_REG_NAME
#  CROSS_COMPILE
#  CFG_HI_ETH_UP_PHYADDR
#  CFG_HI_ETH_DOWN_PHYADDR
#  HI_ADVCA_FUNCTION_RELEASE //FIX ME:CA
#  HI_ADVCA_FUNCTION_DEBUG   //FIX ME:CA
#  CFG_HI_ADVCA_TYPE         //FIX ME:CA
#  CFG_HI_CHIP_TYPE          //FIX ME:product,take out
#  CFG_HI_SDK_VERSION        //FIX ME:product,take out
#  CFG_HI_BUILD_WITH_PRODUCT
#  CFG_HI_BOOT_COMPRESSED

CONFIG_SYSREG  := $(CFG_HI_BOOT_REG_NAME)
ifeq ($(CFG_HI_UNIFIED_BOOT_SUPPORT), y)
CONFIG_SYSREG0  := $(CFG_HI_BOOT_REG_NAME)
CONFIG_SYSREG1  := $(CFG_HI_BOOT_REG1_NAME)
CONFIG_SYSREG2  := $(CFG_HI_BOOT_REG2_NAME)
CONFIG_SYSREG3  := $(CFG_HI_BOOT_REG3_NAME)
CONFIG_SYSREG4  := $(CFG_HI_BOOT_REG4_NAME)
CONFIG_SYSREG5  := $(CFG_HI_BOOT_REG5_NAME)
CONFIG_SYSREG6  := $(CFG_HI_BOOT_REG6_NAME)
CONFIG_SYSREG7  := $(CFG_HI_BOOT_REG7_NAME)
CONFIG_UNIFIED_BOOT := $(CFG_HI_UNIFIED_BOOT_SUPPORT)
endif

CONFIG_BOOTREG_DEFAULT := $(firstword $(CONFIG_SYSREG0) $(CONFIG_SYSREG1) \
	$(CONFIG_SYSREG2) $(CONFIG_SYSREG3) $(CONFIG_SYSREG4) \
	$(CONFIG_SYSREG5) $(CONFIG_SYSREG6) $(CONFIG_SYSREG7))
ifneq ($(BOOT_ADVCA_PROGRAMMER),y)
CONFIG_PRODUCT_WITH_BOOT := $(CFG_HI_BUILD_WITH_PRODUCT)
endif

CONFIG_COMPRESS_BOOT := $(CFG_HI_BOOT_COMPRESSED)

ifeq ($(findstring fpga,$(CFG_HI_BOOT_REG_NAME)), fpga)
CFG_FPGA := 1
else
CFG_FPGA := 0
endif

ifeq ($(CFG_HI_CPU_ARCH),arm64)
CONFIG_ARM64_SUPPORT = y
endif

################################################################################
#CONFIG_AUXCODE_COMPILE_SUPPORT=y
################################################################################

TARGET := $(if $(CONFIG_COMPRESS_BOOT),mini-boot.bin,fastboot-burn.bin)

#
# local variable.
#
CURRDIR        = $(shell pwd)

ifneq ($(O),)
OBJ_DIR := $(O)
BUILD_DIR := $(OBJ_DIR)
OBJ_TARGET := $(OBJ_DIR)/fastboot-burn.bin
BOOT_DIR := $(OBJ_DIR)
export BOOT_DIR
else
BUILD_DIR := $(CURRDIR)
endif

FASTBOOT       = $(BUILD_DIR)/fastboot
PRODUCT        = $(BUILD_DIR)/product
AUXCODE        = $(BUILD_DIR)/auxcode

SYSREGDIR      = $(CURRDIR)/sysreg
LIBSPRODUCT    = $(PRODUCT)/libproduct.a
AUXIMG         = $(FASTBOOT)/auxcode_sign.img
SYSREG         = $(SYSREGDIR)/$(CFG_HI_CHIP_TYPE)/$(CFG_HI_BOOT_REG_NAME)

ifeq ($(CFG_HI_UNIFIED_BOOT_SUPPORT), y)
SYSREG1        = $(SYSREGDIR)/$(CFG_HI_CHIP_TYPE)/$(CONFIG_SYSREG1)
SYSREG2        = $(SYSREGDIR)/$(CFG_HI_CHIP_TYPE)/$(CONFIG_SYSREG2)
SYSREG3        = $(SYSREGDIR)/$(CFG_HI_CHIP_TYPE)/$(CONFIG_SYSREG3)
SYSREG4        = $(SYSREGDIR)/$(CFG_HI_CHIP_TYPE)/$(CONFIG_SYSREG4)
SYSREG5        = $(SYSREGDIR)/$(CFG_HI_CHIP_TYPE)/$(CONFIG_SYSREG5)
SYSREG6        = $(SYSREGDIR)/$(CFG_HI_CHIP_TYPE)/$(CONFIG_SYSREG6)
SYSREG7        = $(SYSREGDIR)/$(CFG_HI_CHIP_TYPE)/$(CONFIG_SYSREG7)
endif

export FASTBOOT PRODUCT

################################################################################
ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3798mv100 hi3796mv100 hi3716dv100),)
BOOTCONFIG := hi3798mx
endif

ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3798cv200),)
BOOTCONFIG := hi3798cv2x
endif

ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3798mv200 hi3798mv300),)
BOOTCONFIG := hi3798mv2x
endif

ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3798mv310),)
BOOTCONFIG := hi3798mv310
endif

ifeq ($(CFG_HI3798MV300H),y)
BOOTCONFIG := hi3798mv310
SYSREG         = $(SYSREGDIR)/hi3798mv300h/$(CFG_HI_BOOT_REG_NAME)
ifeq ($(CFG_HI_UNIFIED_BOOT_SUPPORT), y)
SYSREG1        = $(SYSREGDIR)/hi3798mv300h/$(CONFIG_SYSREG1)
SYSREG2        = $(SYSREGDIR)/hi3798mv300h/$(CONFIG_SYSREG2)
SYSREG3        = $(SYSREGDIR)/hi3798mv300h/$(CONFIG_SYSREG3)
SYSREG4        = $(SYSREGDIR)/hi3798mv300h/$(CONFIG_SYSREG4)
SYSREG5        = $(SYSREGDIR)/hi3798mv300h/$(CONFIG_SYSREG5)
SYSREG6        = $(SYSREGDIR)/hi3798mv300h/$(CONFIG_SYSREG6)
SYSREG7        = $(SYSREGDIR)/hi3798mv300h/$(CONFIG_SYSREG7)
endif
endif

ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3796mv200 hi3716mv450),)
BOOTCONFIG := hi3796mv200
endif

ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3716mv410 hi3716mv420),)
ifeq ($(CFG_ADVCA_NAGRA),y)
BOOTCONFIG := hi3716mv420n
else
BOOTCONFIG := hi3716mv410
endif
endif

ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3796mv200 hi3716mv450),)
ifneq ($(findstring $(CFG_HI_ADVCA_TYPE), NAGRA CONAX IRDETO VERIMATRIX_ULTRA),)
CFG_HI_ADVANCED_CHIP=y
endif
endif

CONFIG_FILE    = $(FASTBOOT)/include/configs/$(BOOTCONFIG)_config.h
CONFIG_EXPORT  = $(FASTBOOT)/include/configs/export.sh

BOOTCONFIG_UPPER:=$(shell echo $(BOOTCONFIG) | tr '[a-z]' '[A-Z]')

ifeq ($(CFG_HI_CHIP_TYPE)_$(CFG_HI_TEE_SUPPORT)_$(CFG_HI_ADVCA_TYPE), hi3798mv200_y_VERIMATRIX_ULTRA)
SBL_VXX_UXX = y
endif

############################################################################

MKFLAGS := ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) \
              LIBSPRODUCT=$(LIBSPRODUCT) \
              CONFIG_COMPRESS_BOOT=$(CFG_HI_BOOT_COMPRESSED) \
              O=

ifeq ($(CFG_HI_BENCH_SUPPORT),y)
    MKFLAGS += CONFIG_MERGE_IMAGE=$(FASTBOOT)/merge.img
else
    MKFLAGS += CONFIG_MERGE_IMAGE=
endif

ifeq ($(BOOT_ADVCA_PROGRAMMER),y)
    MKFLAGS += CONFIG_BOOTROM_CA_SUPPORT=y
endif

ifdef CONFIG_UNIFIED_BOOT
    MKFLAGS += CONFIG_AUXCODE_COMPILE_SUPPORT=$(CONFIG_AUXCODE_COMPILE_SUPPORT)
    MKFLAGS += CONFIG_BOOT_REG0=$(CFG_HI_BOOT_REG_NAME) \
	       CONFIG_BOOT_REG1=$(CFG_HI_BOOT_REG1_NAME) \
	       CONFIG_BOOT_REG2=$(CFG_HI_BOOT_REG2_NAME) \
	       CONFIG_BOOT_REG3=$(CFG_HI_BOOT_REG3_NAME) \
	       CONFIG_BOOT_REG4=$(CFG_HI_BOOT_REG4_NAME) \
	       CONFIG_BOOT_REG5=$(CFG_HI_BOOT_REG5_NAME) \
	       CONFIG_BOOT_REG6=$(CFG_HI_BOOT_REG6_NAME) \
	       CONFIG_BOOT_REG7=$(CFG_HI_BOOT_REG7_NAME)
endif

ifeq ($(CFG_FPGA),1)
    MKFLAGS += CONFIG_FPGA=$(CFG_FPGA)
endif

ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3798cv200),)
    MKFLAGS += MACH=hi3798cv2x
endif
ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3798mv200 hi3798mv300),)
    MKFLAGS += MACH=hi3798mv2x
endif
ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3798mv310),)
    MKFLAGS += MACH=hi3798mv310
endif

    MKFLAGS += CHIP_TYPE=$(CFG_HI_CHIP_TYPE)

ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3796mv200 hi3716mv450),)
ifeq ($(CFG_HI_ADVCA_TYPE),NAGRA)
	MKFLAGS += CONFIG_CA_TYPE=nagra
else ifeq ($(CFG_HI_ADVCA_TYPE),IRDETO)
	MKFLAGS += CONFIG_CA_TYPE=irdeto
else ifeq ($(CFG_HI_ADVCA_TYPE),CONAX)
	MKFLAGS += CONFIG_CA_TYPE=conax
else ifeq ($(CFG_HI_ADVCA_TYPE),VERIMATRIX_ULTRA)
	MKFLAGS += CONFIG_CA_TYPE=vmx_ultra
else
	MKFLAGS += CONFIG_CA_TYPE=null
endif
endif
################################################################################
PHONYS += all product fastboot mini-boot prepare copy_code $(AUXIMG)

all: $(if $(CONFIG_COMPRESS_BOOT),mini-boot,fastboot)
ifneq ($(OBJ_DIR),)
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(OBJ_TARGET)
endif
ifeq ($(CFG_PRODUCT_TYPE),linux)
ifeq ($(CFG_HI_NAND_FLASH_SUPPORT),y)
	$(AT)test -d $(HI_NAND_IMAGE_DIR) || mkdir -p $(HI_NAND_IMAGE_DIR)
ifneq ($(CFG_HI_TWOSTAGEBOOT_SUPPORT),y)
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(HI_NAND_IMAGE_DIR)/fastboot.bin
else
ifeq ($(CFG_HI_BOOT_FBL),y)
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(HI_NAND_IMAGE_DIR)/fastboot.bin
else
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(HI_NAND_IMAGE_DIR)/secondboot.bin
endif
endif
endif
ifeq ($(CFG_HI_SPI_SUPPORT),y)
	$(AT)test -d $(HI_SPI_IMAGE_DIR) || mkdir -p $(HI_SPI_IMAGE_DIR)
ifneq ($(CFG_HI_TWOSTAGEBOOT_SUPPORT),y)
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(HI_SPI_IMAGE_DIR)/fastboot.bin
else
ifeq ($(CFG_HI_BOOT_FBL),y)
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(HI_SPI_IMAGE_DIR)/fastboot.bin
else
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(HI_SPI_IMAGE_DIR)/secondboot.bin
endif
endif
endif
ifeq ($(CFG_HI_EMMC_SUPPORT),y)
	$(AT)test -d $(HI_EMMC_IMAGE_DIR) || mkdir -p $(HI_EMMC_IMAGE_DIR)
ifneq ($(CFG_HI_TWOSTAGEBOOT_SUPPORT),y)
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(HI_EMMC_IMAGE_DIR)/fastboot.bin
else
ifeq ($(CFG_HI_BOOT_FBL),y)
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(HI_EMMC_IMAGE_DIR)/fastboot.bin
else
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(HI_EMMC_IMAGE_DIR)/secondboot.bin
endif
endif
endif
ifeq ($(CFG_HI_SPI_SUPPORT)_$(CFG_HI_EMMC_SUPPORT),y_y)
	$(AT)test -d $(HI_SPI_EMMC_IMAGE_DIR) || mkdir -p $(HI_SPI_EMMC_IMAGE_DIR)
ifneq ($(CFG_HI_TWOSTAGEBOOT_SUPPORT),y)
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(HI_SPI_EMMC_IMAGE_DIR)/fastboot.bin
else
ifeq ($(CFG_HI_BOOT_FBL),y)
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(HI_SPI_EMMC_IMAGE_DIR)/fastboot.bin
else
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(HI_SPI_EMMC_IMAGE_DIR)/secondboot.bin
endif
endif
endif
ifeq ($(CFG_HI_BOOTLOADER_SUPPORT),y)
ifeq ($(SDK_DIR)/platform/HiPro-serial/HiPro-serial_cn/HiPro-serial.exe, $(wildcard $(SDK_DIR)/platform/HiPro-serial/HiPro-serial_cn/HiPro-serial.exe))
	cp -fv $(FASTBOOT)/$(TARGET) $(SDK_DIR)/platform/HiPro-serial/HiPro-serial_cn/program.bin
	cp -fv $(FASTBOOT)/$(TARGET) $(SDK_DIR)/platform/HiPro-serial/HiPro-serial_en/program.bin
else
	cp -fv $(FASTBOOT)/$(TARGET) $(SDK_DIR)/tools/windows/HiPro-serial/HiPro-serial_cn/program.bin
	cp -fv $(FASTBOOT)/$(TARGET) $(SDK_DIR)/tools/windows/HiPro-serial/HiPro-serial_en/program.bin
endif
endif
endif

copy_code:
	$(AT)test -d $(OBJ_DIR) || mkdir -p $(OBJ_DIR)
	$(AT)rm -rf $(OBJ_DIR)/fastboot $(OBJ_DIR)/product
	$(AT)cp -rf $(CURRDIR)/fastboot $(OBJ_DIR)
	$(AT)cp -rf $(CURRDIR)/product  $(OBJ_DIR)
	$(AT)test ! -d $(CURRDIR)/auxcode || cp -rf $(CURRDIR)/auxcode $(OBJ_DIR)

product: prepare
	make -j16 -C $(FASTBOOT) $(MKFLAGS) $(BOOTCONFIG)_config
	make -j16 -C $(PRODUCT) $(MKFLAGS) O=$(O)

auxcode: $(AUXIMG)
ifeq ($(CONFIG_AUXCODE_COMPILE_SUPPORT),y)
ifdef CONFIG_UNIFIED_BOOT
	make -j16 -C $(AUXCODE) $(MKFLAGS) O=$(O) \
	&& cp -rf $(AUXCODE)/auxcode_sign.img $(AUXIMG)
endif
endif

fastboot: $(if $(CONFIG_PRODUCT_WITH_BOOT),product,prepare)
	make -j16 -C $(FASTBOOT) $(MKFLAGS) $(BOOTCONFIG)

mini-boot: fastboot
	make -j16 -C $(FASTBOOT) $(MKFLAGS) mini-boot.bin

advca_programmer_install: \
		prepare \
		$(if $(OBJ_DIR), copy_code,) \
		$(if $(CONFIG_COMPRESS_BOOT),mini-boot,fastboot)
ifeq ($(CFG_PRODUCT_TYPE),linux)
ifeq ($(CFG_HI_NAND_FLASH_SUPPORT),y)
	$(AT)test -d $(HI_NAND_IMAGE_DIR) || mkdir -p $(HI_NAND_IMAGE_DIR)
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(HI_NAND_IMAGE_DIR)/advca_programmer.bin
endif
ifeq ($(CFG_HI_SPI_SUPPORT),y)
	$(AT)test -d $(HI_SPI_IMAGE_DIR) || mkdir -p $(HI_SPI_IMAGE_DIR)
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(HI_SPI_IMAGE_DIR)/advca_programmer.bin
endif
ifeq ($(CFG_HI_EMMC_SUPPORT),y)
	$(AT)test -d $(HI_EMMC_IMAGE_DIR) || mkdir -p $(HI_EMMC_IMAGE_DIR)
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(HI_EMMC_IMAGE_DIR)/advca_programmer.bin
endif
ifeq ($(CFG_HI_SPI_SUPPORT)_$(CFG_HI_EMMC_SUPPORT),y_y)
	$(AT)test -d $(HI_SPI_EMMC_IMAGE_DIR) || mkdir -p $(HI_SPI_EMMC_IMAGE_DIR)
	$(AT)cp -f $(FASTBOOT)/$(TARGET) $(HI_SPI_EMMC_IMAGE_DIR)/advca_programmer.bin
endif
endif
ifeq ($(OBJ_DIR),)
	make -j16 -C $(PRODUCT)  $(MKFLAGS) clean
	make -j16 -C $(FASTBOOT) $(MKFLAGS) distclean
	make -j16 -C $(FASTBOOT) $(MKFLAGS) mini-boot.clean
	$(AT)rm -f $(FASTBOOT)/*.reg
endif

prepare: $(SYSREG) $(CONFIG_FILE)
	$(AT)rm -f $(FASTBOOT)/*.reg
	$(AT)test -d $(FASTBOOT)/ || mkdir -p $(FASTBOOT)
ifeq ($(CFG_HI_UNIFIED_BOOT_SUPPORT), y)
ifneq ($(strip $(CONFIG_SYSREG)),)
	$(AT)cp -fv $(SYSREG) $(FASTBOOT)
endif
ifneq ($(strip $(CONFIG_SYSREG1)),)
	$(AT)cp -fv $(SYSREG1) $(FASTBOOT)
endif
ifneq ($(strip $(CONFIG_SYSREG2)),)
	$(AT)cp -fv $(SYSREG2) $(FASTBOOT)
endif
ifneq ($(strip $(CONFIG_SYSREG3)),)
	$(AT)cp -fv $(SYSREG3) $(FASTBOOT)
endif
ifneq ($(strip $(CONFIG_SYSREG4)),)
	$(AT)cp -fv $(SYSREG4) $(FASTBOOT)
endif
ifneq ($(strip $(CONFIG_SYSREG5)),)
	$(AT)cp -fv $(SYSREG5) $(FASTBOOT)
endif
ifneq ($(strip $(CONFIG_SYSREG6)),)
	$(AT)cp -fv $(SYSREG6) $(FASTBOOT)
endif
ifneq ($(strip $(CONFIG_SYSREG7)),)
	$(AT)cp -fv $(SYSREG7) $(FASTBOOT)
endif
else
	$(AT)cp -fv $(SYSREG) $(FASTBOOT)
endif

BOOT_REG_DEF=$(if $(strip $(CONFIG_SYSREG$(1))), @$(CONFIG_EXPORT) "BOOT_REG$(1)=\"$(FASTBOOT)/$(CONFIG_SYSREG$(1))\"" "boot reg$(1)" $@, @$(CONFIG_EXPORT) "BOOT_REG$(1)=" "boot reg$(1)" $@)

################################################################################

$(CONFIG_FILE): $(if $(OBJ_DIR), copy_code,) force
	$(AT)test ! -f $(CONFIG_FILE) || rm -rvf $(CONFIG_FILE)
	chmod 0755 $(CONFIG_EXPORT)
	@$(CONFIG_EXPORT) "SDK_VERSION_STRING=\"$(CFG_HI_SDK_VERSION)\"" \
		"SDK Version" $@
	@$(CONFIG_EXPORT) "CONFIG_NAND_SUPPORT=$(CFG_HI_NAND_SUPPORT)" \
		"nand flash support" $@
	@$(CONFIG_EXPORT) "CONFIG_SPI_NAND_SUPPORT=$(CFG_HI_SPI_NAND_SUPPORT)" \
		"spi-nand flash support" $@
	@$(CONFIG_EXPORT) "CONFIG_SPIFLASH_SUPPORT=$(CFG_HI_SPI_SUPPORT)" \
		"spi flash support" $@
ifeq ($(BOOT_ADVCA_PROGRAMMER),y)
	@$(CONFIG_EXPORT) "CONFIG_NET_SUPPORT=y" \
		"eth support" $@
else
	@$(CONFIG_EXPORT) "CONFIG_NET_SUPPORT=$(CFG_HI_ETH_SUPPORT)" \
		"eth support" $@
endif
	@$(CONFIG_EXPORT) "HISFV_PHY_U=$(CFG_HI_ETH_UP_PHYADDR)" \
		"eth upport phy address" $@
	@$(CONFIG_EXPORT) "HISFV_PHY_D=$(CFG_HI_ETH_DOWN_PHYADDR)" \
		"eth downport phy address" $@
	@$(CONFIG_EXPORT) "CONFIG_EMMC_SUPPORT=$(CFG_HI_EMMC_SUPPORT)" \
		"emmc flash support" $@
	@$(CONFIG_EXPORT) "CONFIG_MFTL_SUPPORT=$(CFG_HI_MFTL_SUPPORT)" \
		"MFTL flash support" $@
	@$(CONFIG_EXPORT) "CFG_ENV_ADDR=$(CFG_HI_BOOT_ENV_STARTADDR)" \
		"boot environment variables start address" $@
	@$(CONFIG_EXPORT) "CONFIG_BOOTCOMMAND=\"$(CFG_HI_BOOT_CMD)\"" \
		"boot command for fbl" $@
	@$(CONFIG_EXPORT) "CFG_SECONDBOOT_ADDR=$(CFG_HI_SECONDBOOT_STARTADDR)" \
		"second boot start address" $@
	@$(CONFIG_EXPORT) "CFG_SECONDBOOT_SIZE=$(CFG_HI_SECONDBOOT_SIZE)" \
		"second boot size" $@
	@$(CONFIG_EXPORT) "CFG_SECONDBOOT_PARTITION_SIZE=$(CFG_HI_SECONDBOOT_PARTITION_SIZE)" \
		"second boot partition size" $@
	@$(CONFIG_EXPORT) "CFG_ENV_SIZE=$(CFG_HI_BOOT_ENV_SIZE)" \
		"boot environment variables size" $@
	@$(CONFIG_EXPORT) "CFG_ENV_RANGE=$(CFG_HI_BOOT_ENV_RANGE)" \
		"boot environment variables range" $@
	@$(CONFIG_EXPORT) "CONFIG_ENV_BACKUP=$(CFG_HI_BOOT_ENV_BAK_SUPPORT)" \
		"Bakup boot environment variables support" $@
	@$(CONFIG_EXPORT) "CFG_ENV_BACKUP_ADDR=$(CFG_HI_BOOT_ENV_STARTADDR_BAKUP)" \
		"Bakup boot environment variables start address" $@
	@$(CONFIG_EXPORT) "CONFIG_PRODUCT_WITH_BOOT=$(CONFIG_PRODUCT_WITH_BOOT)" \
		"build product with boot" $@
	@$(CONFIG_EXPORT) "CONFIG_HI3798MV2X_UMAP5=$(CFG_FPGA_VERSION_UMAP5)" \
		"build for umap5 fpga version" $@
	@$(CONFIG_EXPORT) "CONFIG_AUXCODE_COMPILE_SUPPORT=$(CONFIG_AUXCODE_COMPILE_SUPPORT)" \
		"build auximg from auxcode" $@
	@$(CONFIG_EXPORT) "CONFIG_NET_HIGMACV300=$(CONFIG_NET_HIGMACV300)" \
		"build higmacv300" $@
	@$(CONFIG_EXPORT) "CONFIG_NET_HISFV300=$(CONFIG_NET_HISFV300)" \
		"build hisfv300" $@
	@$(CONFIG_EXPORT) "CONFIG_USB_HOST_ETHER=$(CONFIG_USB_HOST_ETHER)" \
		"build usb2eth" $@
	@$(CONFIG_EXPORT) "CONFIG_BOOTROM_CA_SUPPORT=$(BOOT_ADVCA_PROGRAMMER)" \
		"build advca_programmer" $@
#TODO: XXX
	@$(CONFIG_EXPORT) "CFG_$(BOOTCONFIG_UPPER)_FPGA=$(CFG_FPGA)" \
		"FPGA" $@
	@$(CONFIG_EXPORT) "CONFIG_BOOT_SIMULATE=$(CONFIG_BOOT_SIMULATE)" \
		"Simulate boot" $@
	@$(CONFIG_EXPORT) "CHIP_TYPE_$(CFG_HI_CHIP_TYPE)=1" \
		"Chip type" $@
	@$(CONFIG_EXPORT) "CONFIG_ADVANCED_CHIP=$(CFG_HI_ADVANCED_CHIP)" \
		"Advanced Chip" $@
ifeq ($(CFG_HI_FORCE_ENV_TO_MEDIA), y)
ifeq ($(CFG_FORCE_ENV_IN_NAND), y)
	@$(CONFIG_EXPORT) "CONFIG_FORCE_ENV_IN_NAND=$(CFG_FORCE_ENV_IN_NAND)" \
		"Force env to Nand" $@
endif
ifeq ($(CFG_FORCE_ENV_IN_SPI), y)
	@$(CONFIG_EXPORT) "CONFIG_FORCE_ENV_IN_SPI=$(CFG_FORCE_ENV_IN_SPI)" \
		"Force env to SPI Flash " $@
endif
ifeq ($(CFG_FORCE_ENV_IN_EMMC), y)
	@$(CONFIG_EXPORT) "CONFIG_FORCE_ENV_IN_EMMC=$(CFG_FORCE_ENV_IN_EMMC)" \
		"Force env to eMMC" $@
endif
endif

ifeq ($(CFG_HI_GPIO_LIGHT_SUPPORT), y)
	@$(CONFIG_EXPORT) "CONFIG_GPIO_LIGHT_SET=$(CFG_HI_GPIO_LIGHT_SET)" \
		"Gpio Light config" $@
endif
	@$(CONFIG_EXPORT) "CONFIG_AVS_SUPPORT=$(CFG_HI_AVS_SUPPORT)" \
		"AVS config" $@
	@$(CONFIG_EXPORT) "CONFIG_PMU_DEVICE=$(CFG_HI_PMU_DEVICE_SELECT)" \
		"PMU Device config" $@
	@$(CONFIG_EXPORT) "CONFIG_USB_SUPPORT=$(CFG_HI_BOOT_USB_SUPPORT)" \
		"USB Driver config" $@
	@$(CONFIG_EXPORT) "CONFIG_TEE_SUPPORT=$(CFG_HI_TEE_SUPPORT)" \
		"TEE config" $@
	@$(CONFIG_EXPORT) "CONFIG_TEE_ATF_SUPPORT=$(CFG_HI_TEE_ATF_SUPPORT)" \
		"TEE ATF config" $@
	@$(CONFIG_EXPORT) "CONFIG_TEE_MEM_LAYOUT_$(CFG_HI_TVP_MEM_LAYOUT)=y" \
		"TEE Memory Layout config" $@
	@$(CONFIG_EXPORT) "CONFIG_ARM64_TOOLCHAINS=$(HI_KERNEL_TOOLCHAINS_NAME)" \
		"ARM64 toolchains config" $@
	@$(CONFIG_EXPORT) "CONFIG_ARM64_SUPPORT=$(CONFIG_ARM64_SUPPORT)" \
		"ARM64 support config" $@
	@$(CONFIG_EXPORT) "CONFIG_DISABLE_CONSOLE_INPUT=$(CFG_HI_USER_MODE)" \
		"Disable console input" $@
	@$(CONFIG_EXPORT) "CONFIG_ENABLE_CONSOLE_OUTPUT=$(CFG_HI_BOOT_LOG_SUPPORT)" \
		"Enable console output" $@
	@$(CONFIG_EXPORT) "CONFIG_SBL_VXX_UXX=$(SBL_VXX_UXX)" \
		"Second boot config" $@
	@$(CONFIG_EXPORT) "CONFIG_KEYPROVISION_SUPPORT=$(CFG_HI_KEYPROVISION_SUPPORT)" \
		"Keyprovision config" $@
ifneq ($(findstring $(CFG_HI_CHIP_TYPE), hi3798mv200),)
	@$(CONFIG_EXPORT) "CONFIG_SUPPORT_CA_MULTI_REG=$(firstword $(CFG_ADVCA_OTHER) $(CFG_SEC_MULTI_REGS))" \
		"Support CA multi regs for hi3798mv200" $@
endif

#+++++++++++++++++++++ADVCA compile options+++++++++++++++++++++++++++++++++++++++++++++
ifneq ($(BOOT_ADVCA_PROGRAMMER),y)
ifeq ($(CFG_HI_ADVCA_SUPPORT),y)
	@$(CONFIG_EXPORT) "CONFIG_SUPPORT_CA=$(CFG_HI_ADVCA_TYPE)" \
		"CA type" $@
	@$(CONFIG_EXPORT) "CONFIG_SUPPORT_CA_$(CFG_HI_ADVCA_TYPE)=y" \
		"CA type" $@

ifeq ($(findstring -DHI_ADVCA_FUNCTION_RELEASE,$(CFG_HI_CFLAGS)),-DHI_ADVCA_FUNCTION_RELEASE)
	@$(CONFIG_EXPORT) "CONFIG_SUPPORT_CA_RELEASE=y" \
		"CA relase" $@
endif

ifeq ($(findstring -DHI_ADVCA_FUNCTION_DEBUG,$(CFG_HI_CFLAGS)),-DHI_ADVCA_FUNCTION_DEBUG)
	@$(CONFIG_EXPORT) "CONFIG_SUPPORT_CA_DEBUG=y" \
		"CA debug" $@
endif
endif
endif

ifeq ($(CFG_HI_BOOT_COMPRESSED),y)
	@$(CONFIG_EXPORT) "CONFIG_COMPRESS_BOOT=$(CFG_HI_BOOT_COMPRESSED)" \
		"Compress boot" $@
endif

ifeq ($(CFG_HI_TWOSTAGEBOOT_SUPPORT),y)
ifeq ($(CFG_HI_BOOT_FBL),y)
	@$(CONFIG_EXPORT) "CONFIG_FBL=y" \
		"Support two stage boot FBL" $@
endif
ifeq ($(CFG_HI_BOOT_SBL),y)
	@$(CONFIG_EXPORT) "CONFIG_SBL=y" \
		"Support two stage boot SBL" $@
endif
endif
#+++++++++++++++++++++ unified boot +++++++++++++++++++++++++++++++++++++++++++++
ifeq ($(CFG_HI_UNIFIED_BOOT_SUPPORT),y)
	@$(CONFIG_EXPORT) "CONFIG_UNIFIED_BOOT=$(CFG_HI_UNIFIED_BOOT_SUPPORT)" \
		"Unified boot" $@
	@$(CONFIG_EXPORT) "CONFIG_BOOTREG_DEFAULT=\"$(FASTBOOT)/$(CONFIG_BOOTREG_DEFAULT)\"" \
		"default boot reg" $@
	$(call BOOT_REG_DEF,0)
	$(call BOOT_REG_DEF,1)
	$(call BOOT_REG_DEF,2)
	$(call BOOT_REG_DEF,3)
	$(call BOOT_REG_DEF,4)
	$(call BOOT_REG_DEF,5)
	$(call BOOT_REG_DEF,6)
	$(call BOOT_REG_DEF,7)
endif

force: ;

################################################################################
PHONYS += clean distclean

distclean: clean

clean :
ifeq ($(CFG_HI_NAND_FLASH_SUPPORT),y)
	$(AT)rm -rf $(HI_NAND_IMAGE_DIR)/*[Bb]oot.bin
endif
ifeq ($(CFG_HI_SPI_SUPPORT),y)
	$(AT)rm -rf $(HI_SPI_IMAGE_DIR)/*[Bb]oot.bin
endif
ifeq ($(CFG_HI_EMMC_SUPPORT),y)
	$(AT)rm -rf $(HI_NAND_IMAGE_DIR)/*[Bb]oot.bin
endif
ifeq ($(CFG_HI_SPI_SUPPORT)_$(CFG_HI_EMMC_SUPPORT),y_y)
	$(AT)rm -rf $(HI_SPI_EMMC_IMAGE_DIR)/*[Bb]oot.bin
endif
ifeq ($(OBJ_DIR),)
ifeq ($(CONFIG_PRODUCT_WITH_BOOT),y)
	make -j16 -C $(PRODUCT)  $(MKFLAGS) clean
endif
	make -j16 -C $(FASTBOOT) $(MKFLAGS) distclean
	make -j16 -C $(FASTBOOT) $(MKFLAGS) mini-boot.clean
ifeq ($(CFG_HI_UNIFIED_BOOT_SUPPORT),y)
ifeq ($(CONFIG_AUXCODE_COMPILE_SUPPORT),y)
	make -j16 -C $(AUXCODE) $(MKFLAGS) clean
endif
endif
	$(AT)rm -f $(FASTBOOT)/*.reg
else
	$(AT)rm -rf $(OBJ_DIR)
	$(AT)rm -rf $(OBJ_DIR)_fbl
	$(AT)rm -rf $(OBJ_DIR)_sbl
endif

################################################################################
.PHONY: $(PHONYS)
################################################################################
