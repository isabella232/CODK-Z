TOP_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
CODK_FLASHPACK_URL := https://github.com/01org/CODK-Z-Flashpack.git
CODK_FLASHPACK_DIR := $(TOP_DIR)/flashpack
CODK_FLASHPACK_TAG := master
GEN_USER_ENV := $(CODK_FLASHPACK_DIR)/gen_user_env.sh
BLE_IMAGE := $(CODK_FLASHPACK_DIR)/images/firmware/ble_core/imagev3.bin
OUT_DIR := $(TOP_DIR)/out
OUT_X86_DIR := $(OUT_DIR)/x86
OUT_ARC_DIR := $(OUT_DIR)/arc
ZEPHYR_DIR := $(TOP_DIR)/../zephyr
ZEPHYR_DIR_REL = $(shell $(CODK_FLASHPACK_DIR)/relpath "$(TOP_DIR)" "$(ZEPHYR_DIR)")
ZEPHYR_VER := 1.6.0
ZEPHYR_SDK_VER := 0.8.2
PROJ_DIR := my_project
X86_DIR := $(TOP_DIR)/x86
ARC_DIR := $(TOP_DIR)/arc
X86_PROJ ?= $(X86_DIR)/examples/blank
ARC_PROJ ?= $(ARC_DIR)/examples/blank
X86_PROJ_DIR ?= $(X86_DIR)/examples/hello
ARC_PROJ_DIR ?= $(ARC_DIR)/examples/hello
CODK_DIR ?= $(TOP_DIR)

help:
	@echo
	@echo "CODK-Z available targets"
	@echo
	@echo "project            : create new blank project (PROJ_DIR variable must be set)"
	@echo "convert-sketch     : convert *.ino to *.cpp (SKETCH variable must be set)"
	@echo "compile-x86        : compile the x86 application in X86_PROJ_DIR"
	@echo "compile-arc        : compile the ARC application in ARC_PROJ_DIR"
	@echo "compile            : compile x86 and ARC applications"
	@echo "upload-x86-dfu     : upload the x86 application (USB cable & dfu-util)"
	@echo "upload-arc-dfu     : upload the ARC application (USB cable & dfu-util)"
	@echo "upload             : upload the ARC and x86 applications (USB cable & dfu-util)"
	@echo "upload-x86-jtag    : upload the x86 application using OpenOCD configured  "
	@echo "                     for a Flyswatter2 JTAG debugger"
	@echo "upload-arc-jtag    : upload the ARC application using OpenOCD configured  "
	@echo "                     for a Flyswatter2 JTAG debugger"
	@echo "upload-jtag        : upload the ARC and x86 applications using OpenOCD configured "
	@echo "                     for a Flyswatter2 JTAG debugger"
	@echo "upload-x86-jlink   : upload the x86 application using OpenOCD configured "
	@echo "                     for a Jlink JTAG debugger"
	@echo "upload-arc-jlink   : upload the ARC application using OpenOCD configured "
	@echo "                     for a Jlink JTAG debugger"
	@echo "upload-jlink       : upload the ARC and x86 applications using OpenOCD "
	@echo "                     configured for a Jlink JTAG debugger"
	@echo "upload-ble-dfu     : upload the Nordic BLE firmware (USB cable & dfu-util)"
	@echo "debug-server       : start OpenOCD server, configured for a Flyswatter2 "
	@echo "                     JTAG debugger (deprecated)"
	@echo "debug-server-jtag  : start OpenOCD server, configured for a Flyswatter2 "
	@echo "                     JTAG debugger"
	@echo "debug-server-jlink : start OpenOCD server, configured for a Jlink "
	@echo "                     JTAG debugger"
	@echo "debug-x6           : Debug x86 application with GDB"
	@echo "debug-arc          : Debug ARC application with GDB"

check-root:
	@if [ `whoami` != root ]; then echo "Please run as sudoer/root" ; exit 1 ; fi

install-dep: check-root
	apt-get update
	apt-get install -y curl git make gcc gcc-multilib g++ libc6-dev-i386 g++-multilib python3-ply
	dpkg --purge modemmanager
	cp -f $(CODK_FLASHPACK_DIR)/drivers/rules.d/*.rules /etc/udev/rules.d/
	service udev restart
	usermod -a -G dialout $(SUDO_USER)

setup: clone
	@$(CODK_FLASHPACK_DIR)/install-zephyr.sh $(ZEPHYR_VER) $(ZEPHYR_SDK_VER)

clone: $(CODK_FLASHPACK_DIR)

$(CODK_FLASHPACK_DIR):
	git clone -b $(CODK_FLASHPACK_TAG) $(CODK_FLASHPACK_URL) $(CODK_FLASHPACK_DIR)

check-source:
	@if [ -z "$(value ZEPHYR_BASE)" ]; then echo "Please run: source $(ZEPHYR_DIR_REL)/zephyr-env.sh" ; exit 1 ; fi

project:
	@if [ -d $(PROJ_DIR) ]; then echo "$(PROJ_DIR) already exists."; exit 1; fi
	@mkdir $(CODK_DIR)/$(PROJ_DIR)
	@cp -r $(ARC_PROJ) $(CODK_DIR)/$(PROJ_DIR)/arc
	@cp -r $(X86_PROJ) $(CODK_DIR)/$(PROJ_DIR)/x86
	@$(GEN_USER_ENV) $(CODK_DIR) $(PROJ_DIR)

compile: compile-x86 compile-arc

compile-x86: check-source
	@test -d out || mkdir out
	@echo Compiling x86 core
	$(MAKE) O=$(OUT_X86_DIR) BOARD=arduino_101 ARCH=x86 -C $(X86_PROJ_DIR)

compile-arc: check-source
	@test -d out || mkdir out
	@echo Compiling ARC core
	$(MAKE) O=$(OUT_ARC_DIR) BOARD=arduino_101_sss ARCH=arc -C $(ARC_PROJ_DIR)

upload: upload-x86-dfu upload-arc-dfu

upload-x86-dfu:
	$(CODK_FLASHPACK_DIR)/flash_dfu.sh -x $(OUT_X86_DIR)/zephyr.bin

upload-arc-dfu:
	$(CODK_FLASHPACK_DIR)/flash_dfu.sh -a $(OUT_ARC_DIR)/zephyr.bin

upload-jtag: upload-x86-jtag upload-arc-jtag

upload-x86-jtag:
	$(CODK_FLASHPACK_DIR)/flash_jtag.sh -x $(OUT_X86_DIR)/zephyr.bin

upload-arc-jtag:
	$(CODK_FLASHPACK_DIR)/flash_jtag.sh -a $(OUT_ARC_DIR)/zephyr.bin

upload-jlink: upload-x86-jlink upload-arc-jlink

upload-x86-jlink:
	$(CODK_FLASHPACK_DIR)/flash_jlink.sh -x $(OUT_X86_DIR)/zephyr.bin

upload-arc-jlink:
	$(CODK_FLASHPACK_DIR)/flash_jlink.sh -a $(OUT_ARC_DIR)/zephyr.bin

upload-ble-dfu:
	cd $(CODK_FLASHPACK_DIR) && $(CODK_FLASHPACK_DIR)/flash_ble_dfu.sh $(BLE_IMAGE)

clean: check-source
	rm -rf $(OUT_DIR)
	
debug-server-jlink:
	$(CODK_FLASHPACK_DIR)/bin/openocd -f $(CODK_FLASHPACK_DIR)/scripts/interface/ftdi/jlink.cfg -f $(CODK_FLASHPACK_DIR)/scripts/board/quark_se.cfg

debug-server-jtag:
	$(CODK_FLASHPACK_DIR)/bin/openocd -f $(CODK_FLASHPACK_DIR)/scripts/interface/ftdi/flyswatter2.cfg -f $(CODK_FLASHPACK_DIR)/scripts/board/quark_se.cfg

debug-server: debug-server-jtag

debug-x86:
	gdb $(OUT_X86_DIR)/zephyr.elf

debug-arc:
	$(TOP_DIR)/../zephyr-sdk/sysroots/i686-pokysdk-linux/usr/bin/arc-poky-elf/arc-poky-elf-gdb $(OUT_ARC_DIR)/zephyr.elf
