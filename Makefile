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

# Arduino AVR Core library builder

BUILDER_VERSION := 0.1.0

ifeq ($(CORE_GIT_REPO), )
    CORE_GIT_REPO := https://github.com/arduino/ArduinoCore-avr.git
endif
coreSrcDir := core

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

ifeq ($(BOARD), )
    BOARD := uno
endif
ifeq ($(BOARD), )
    $(error Missing BOARD)
endif

ifeq ($(wildcard arduino-gcc-project-builder/boards/$(BOARD).mk), )
    $(error Unsupported BOARD: $(BOARD))
endif

include arduino-gcc-project-builder/boards/$(BOARD).mk

PROJ_NAME    := arduino-core
PROJ_TYPE    := lib
SRC_DIRS     += $(coreSrcDir)/cores/arduino
INCLUDE_DIRS += $(coreSrcDir)/variants/$(VARIANT) $(coreSrcDir)/cores
PROJ_VERSION := $(CORE_VERSION)

ifeq ($(BUILD_BASE), )
    BUILD_BASE := build
endif
BUILD_DIR := $(BOARD)/$(CORE_VERSION)

ifeq ($(DIST_BASE), )
    DIST_BASE := dist
endif
DIST_DIR := $(BOARD)/$(CORE_VERSION)

srcHeaders   := $(shell find $(coreSrcDir)/cores -type f -name *.h -or -name *.hpp 2> /dev/null) $(shell find $(coreSrcDir)/variants/$(VARIANT) -type f -name *.h -or -name *.hpp 2> /dev/null)
distHeaders  := $(foreach srcHeader, $(srcHeaders), $(DIST_BASE)/$(DIST_DIR)/include/arduino/$(notdir $(srcHeader)))
POST_DIST_DEPS := $(distHeaders)

include arduino-gcc-project-builder/posix-arduino-project.mk

.PHONY: update
update: $(coreSrcDir)/.git
	$(_v_)cd $(coreSrcDir); git checkout master && git pull

$(POST_DIST_DEPS): $(srcHeaders)
	$(_v_)mkdir -p $(DIST_BASE)/$(DIST_DIR)/include/arduino
	$(_v_)cp -a $< $@

