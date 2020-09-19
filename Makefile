# Copyright 2020 Leandro José Britto de Oliveira
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

# Arduino AVR Core library  (project Makefile)

PROJECT_NAME := arduino-core
PROJECT_TYPE := lib

__clone_dir__ := core-src

SRC_DIRS += $(__clone_dir__)/cores/arduino

CORE_LIB_GIT_REPO ?= https://github.com/arduino/ArduinoCore-avr.git

ifeq ($(wildcard $(__clone_dir__)/.git), )
    $(info Clonning core library repository...)
    $(shell sh -c "git clone -q $(CORE_LIB_GIT_REPO) $(__clone_dir__)")
endif

ifneq ($(CORE_LIB_VERSION), )
    __success__ := $(shell sh -c "cd $(__clone_dir__) && git checkout -q tags/$(CORE_LIB_VERSION) && echo $$?")
    ifneq ($(__success__), 0)
        $(error Invalid CORE_LIB_VERSION: $(CORE_LIB_VERSION))
    endif
endif

PROJECT_VERSION := $(shell cd $(__clone_dir__) && git describe --tags)

include project.mk
