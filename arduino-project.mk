# Copyright 2021 Leandro José Britto de Oliveira
#
# Licensed under the Apache License, Version 2.0 (the "License");
#* you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Base Makfile for projects based on Arduino AVR core library

selfDir      := $(dir $(lastword $(MAKEFILE_LIST)))
coreSrcDir   := $(selfDir)/core
coreDistBase := $(selfDir)/dist

ifeq ($(BOARD), )
    $(error Missing BOARD)
endif

ifeq ($(wildcard $(selfDir)/boards/$(BOARD).mk), )
    $(error Unsupported BOARD: $(BOARD))
endif

include $(selfDir)/boards/$(BOARD).mk

ifeq ($(wildcard $(coreSrcDir)/.git), )
    $(info Cloning core source code...)
    success := $(shell $(MAKE) -C $(selfDir) update && echo $$?)
    ifneq ($(success), 0)
        $(error)
    endif
endif

ifeq ($(CORE_VERSION), )
    $(error Missing CORE_VERSION)
else
    coreVersionMajor := $(shell echo $(CORE_VERSION) | cut -d'.' -f1)
    coreDistDir := $(coreDistBase)/$(CORE_VERSION)/$(BOARD)
    coreLibDir := $(coreDistDir)/lib
    coreLibName := arduino-core$(coreVersionMajor)
    coreLibFilename := lib$(coreLibName)$(coreVersionMajor).a
    ifeq ($(wildcard $(coreLibDir)/$(coreLibFilename)), )
        $(info Creating core distribution (BOARD: $(BOARD), version: $(CORE_VERSION))...)
        success := $(shell $(MAKE) -C $(selfDir) BOARD=$(BOARD) CORE_VERSION=$(CORE_VERSION) install && echo $$?)
        ifneq ($(success), 0)
            $(error)
        endif
    endif
endif

compilerFlags := -mmcu=$(BUILD_MCU) -DF_CPU=$(BUILD_F_CPU) -DARDUINO=$(CORE_VERSION) -DARDUINO_$(BUILD_BOARD) -DARDUINO_ARCH_$(BUILD_ARCH)

LIB_TYPE     := static
BUILD_BASE   := build
BUILD_DIR    := $(BUILD_BASE)/$(CORE_VERSION)/$(BOARD)
GCC_PREFIX   := avr
CC           := gcc
AS           := gcc

override SRC_DIRS     += $(coreSrcDir)/cores/arduino
override INCLUDE_DIRS += $(coreSrcDir)/variants/$(VARIANT) $(coreSrcDir)/cores

ifeq ($(PROJ_TYPE), lib)
    override CFLAGS   += -std=gnu11 -ffunction-sections -fdata-sections -MMD $(compilerFlags)
    override CXXFLAGS += -std=gnu++11 -fpermissive -fno-exceptions -ffunction-sections -fdata-sections -fno-threadsafe-statics -Wno-error=narrowing -MMD $(compilerFlags)
    override ASFLAGS  += -x assembler-with-cpp -MMD $(compilerFlags)
    override LDFLAGS  += -Os -flto -fuse-linker-plugin -Wl,--gc-sections
else
    # app
    override CFLAGS   += -std=gnu11 -ffunction-sections -fdata-sections -MMD $(compilerFlags) -flto -fno-fat-lto-objects
    override CXXFLAGS += -std=gnu++11 -fpermissive -fno-exceptions -ffunction-sections -fdata-sections -fno-threadsafe-statics -Wno-error=narrowing -MMD -flto $(compilerFlags)
    override ASFLAGS  += -x assembler-with-cpp -flto -MMD $(compilerFlags)
    override LDFLAGS  += -Os -flto -fuse-linker-plugin -Wl,--gc-sections -L$(coreLibDir) -l$(coreLibName) -lm
endif

include c-cpp-project-posix.mk

.PHONY: hex
hex: all
    ifeq ($(PROJ_TYPE), lib)
	    $(error Hex file generation does not apply to a library)
    endif
	@printf "$(nl)[HEX] $(buildArtifact)\n"
	$(v)avr-objcopy -O ihex -R .eeprom $(buildArtifact) $(basename $(buildArtifact)).hex

.PHONY: flash
flash: hex
    ifeq ($(PORT), )
	    $(error Missing PORT)
    endif
	$(v) avrdude -C/etc/avrdude.conf -v -p$(BUILD_MCU) -carduino -P$(PORT) -Uflash:w:$(BUILD_DIR)/$(basename $(buildArtifact)).hex):i

