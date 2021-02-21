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

# Arduino AVR Core library  (avr-core builder)

CORE_GIT_REPO ?= https://github.com/arduino/ArduinoCore-avr.git
coreSrcDir := core

ifeq ($(BOARD), )
    BOARD := uno
endif

ifeq ($(wildcard boards/$(BOARD).mk), )
    $(error Unsupported BOARD: $(BOARD))
endif

include boards/$(BOARD).mk

ifeq ($(BUILD_MCU), )
    $(error Missing BUILD_MCU)
endif

ifeq ($(BUILD_F_CPU), )
    $(error Missing BUILD_F_CPU)
endif

ifeq ($(BUILD_BOARD), )
    $(error Missing BUILD_BOARD)
endif

ifeq ($(BUILD_ARCH), )
    $(error Missing BUILD_ARCH)
endif

ifeq ($(VARIANT), )
    $(error Missing VARIANT)
endif

ifeq ($(wildcard $(coreSrcDir)/.git), )
    $(info Cloning core source code...)
    success := $(shell git clone -q $(CORE_GIT_REPO) $(coreSrcDir) && echo $$?)
    ifneq ($(success), 0)
        $(error)
    endif
endif

ifneq ($(CORE_VERSION), )
    success := $(shell cd $(coreSrcDir) && git checkout -q tags/$(CORE_VERSION) && echo $$?)
    ifneq ($(success), 0)
        $(error Invalid CORE_VERSION: $(CORE_VERSION))
    endif
else
    CORE_VERSION := $(shell cd $(coreSrcDir) && git describe --tags)
endif

distBase := dist
distDir  := $(distBase)/$(CORE_VERSION)/$(BOARD)

# Project definition
PROJ_NAME    := arduino-core
PROJ_TYPE    := lib
LIB_TYPE     := static
BUILD_BASE   := build
BUILD_DIR    := $(BUILD_BASE)/$(CORE_VERSION)/$(BOARD)
SRC_DIRS     += $(coreSrcDir)/cores/arduino
INCLUDE_DIRS += $(coreSrcDir)/variants/$(VARIANT) $(coreSrcDir)/cores
PROJ_VERSION := $(CORE_VERSION)
GCC_PREFIX   := avr
CC           := gcc
AS           := gcc

CFLAGS   += -Os -std=gnu11 -ffunction-sections -fdata-sections
CXXFLAGS += -Os -std=gnu++11 -fpermissive -fno-exceptions -ffunction-sections -fdata-sections -fno-threadsafe-statics -Wno-error=narrowing
ASFLAGS  += -x assembler-with-cpp
LDFLAGS  += -Os -Wl,--gc-sections

CFLAGS   += -mmcu=$(BUILD_MCU) -DF_CPU=$(BUILD_F_CPU) -DARDUINO=$(CORE_VERSION) -DARDUINO_$(BUILD_BOARD) -DARDUINO_ARCH_$(BUILD_ARCH)
CXXFLAGS += -mmcu=$(BUILD_MCU) -DF_CPU=$(BUILD_F_CPU) -DARDUINO=$(CORE_VERSION) -DARDUINO_$(BUILD_BOARD) -DARDUINO_ARCH_$(BUILD_ARCH)
ASFLAGS  += -mmcu=$(BUILD_MCU) -DF_CPU=$(BUILD_F_CPU) -DARDUINO=$(CORE_VERSION) -DARDUINO_$(BUILD_BOARD) -DARDUINO_ARCH_$(BUILD_ARCH)

PRE_CLEAN += rm -rf $(distBase);

include make/c-cpp-posix.mk

.PHONY: clean-all
clean-all: clean
	$(v)rm -rf $(coreSrcDir)

.PHONY: update
update: $(coreSrcDir)/.git
	$(v)cd $(coreSrcDir); git checkout master && git pull

.PHONY: board-list
board-list:
	@find boards -maxdepth 1 -type f | grep boards/ | xargs -I{} basename {} .mk

.PHONY: dist
dist: all
	$(v)mkdir -p $(distDir)/lib
	$(v)mkdir -p $(distDir)/include
	$(v)cp -a $(BUILD_DIR)/libarduino-core*.a* $(distDir)/lib
	$(v)cp -a $(coreSrcDir)/cores/arduino/*.h $(distDir)/include
	$(v)cp -a $(coreSrcDir)/variants/$(VARIANT)/*.h $(distDir)/include

