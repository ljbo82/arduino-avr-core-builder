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

# Base Makfile for projects based on Arduino AVR core library

# --------------------------------------------------------------------------------------------------
__pwd__ := $(shell pwd)
ifneq (1, $(words $(__pwd__)))
    $(error Current working directory cannot have spaces: $(__pwd__))
endif
# --------------------------------------------------------------------------------------------------

__self_dir__ := $(dir $(lastword $(MAKEFILE_LIST)))

# --------------------------------------------------------------------------------------------------
ifneq ($(TARGET), )
    ifeq ($(wildcard $(__self_dir__)targets/$(TARGET).mk), )
        $(error Unsupported TARGET: $(TARGET))
    endif

    include $(__self_dir__)targets/$(TARGET).mk

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
endif
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
__core_lib_local_git_repo__ := $(__self_dir__)core-src
ifeq ($(wildcard $(__core_lib_local_git_repo__)/.git), )
    $(error Core library source not found)
endif

__core_lib_version__        := $(shell cd $(__core_lib_local_git_repo__) && git describe --tags)
__core_lib_version_major__  := $(shell echo $(__core_lib_version__) | cut -d'.' -f1)
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
ifeq ($(PROJECT_NAME), )
    $(error Missing PROJECT_NAME)
endif
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
ifneq (1, $(words $(PROJECT_NAME)))
    $(error PROJECT_NAME cannot have spaces)
endif
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
ifneq ($(PROJECT_TYPE), app)
    ifneq ($(PROJECT_TYPE), lib)
        $(error Invalid PROJECT_TYPE: $(PROJECT_TYPE))
    endif
endif
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
PROJECT_VERSION ?= 0.1.0
ifeq ($(shell sh -c "echo $(PROJECT_VERSION) | grep -oP '[0-9]+\.[0-9]+\.[0-9]+.*'"), )
    $(error Invalid PROJECT_VERSION: $(PROJECT_VERSION))
endif
__project_version_major__ := $(shell echo $(PROJECT_VERSION) | cut -d'.' -f1)
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
ifeq ($(PROJECT_TYPE), lib)
    __build_artifact__ := lib$(PROJECT_NAME)$(__project_version_major__).a
else
    # app
    __build_artifact__ := $(PROJECT_NAME).hex
endif
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
V ?= 0
ifneq ($(V), 0)
    ifneq ($(V), 1)
        $(error ERROR: Invalid value for V: $(V))
    endif
endif

ifeq ($(V), 0)
    __v__ := @
    __nl__ :=
else
    __v__ :=
    __nl__ := \n
endif
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
ifneq ($(wildcard src), )
    SRC_DIRS  += src
endif

ifneq ($(wildcard include), )
    INCLUDES  += include
endif

__build_dir__ ?= build-$(TARGET)

__src_files__ := $(foreach srcDir, $(SRC_DIRS), $(shell find $(srcDir) -name *.cpp -or -name *.c -or -name *.S))

__includes__ += $(foreach srcDir, $(SRC_DIRS), -I$(srcDir))
__includes__ += $(foreach includeDir, $(INCLUDES), -I$(includeDir))
__includes__ += -I$(__core_lib_local_git_repo__)/variants/$(VARIANT) -I$(__core_lib_local_git_repo__)/cores

__mkdir__     := mkdir -p
__obj_files__ := $(__src_files__:%=$(__build_dir__)/%.o)
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
__cxx__ := avr-g++
__cc__  := avr-gcc
__as__  := avr-gcc

__ar__  := avr-ar
__ld__  := avr-gcc
__hex__ := avr-objcopy

ifeq ($(PROJECT_TYPE), lib)
    __cflags__   += -c -Os -Wall -std=gnu11 -ffunction-sections -fdata-sections -MMD
    __cxxflags__ += -c -Os -Wall -std=gnu++11 -fpermissive -fno-exceptions -ffunction-sections -fdata-sections -fno-threadsafe-statics -Wno-error=narrowing -MMD
    __asflags__  += -c -x assembler-with-cpp -MMD
else
    #app
    __cflags__   += -c -Os -Wall -std=gnu11 -ffunction-sections -fdata-sections -MMD -flto -fno-fat-lto-objects
    __cxxflags__ += -c -Os -Wall -std=gnu++11 -fpermissive -fno-exceptions -ffunction-sections -fdata-sections -fno-threadsafe-statics -Wno-error=narrowing -MMD -flto
    __asflags__  += -c -x assembler-with-cpp -flto -MMD
endif

__arflags__  := rcs
__ldflags__  := -Os -flto -fuse-linker-plugin -Wl,--gc-sections
__hexflags__ := -O ihex -R .eeprom
# --------------------------------------------------------------------------------------------------

.PHONY: bin pre-build clean clean-all flash

bin: pre-build $(__build_dir__)/$(__build_artifact__)

pre-build:
    ifneq ($(PRE_BUILD),)
	    $(__v__)sh -c "$(PRE_BUILD)"
    endif

clean:
    ifeq ($(TARGET), )
	    $(error TARGET not set)
    endif
	$(__v__)rm -rf $(__build_dir__)

clean-all:
	$(__v__)rm -rf build-*

flash: bin
    ifeq ($(PROJECT_TYPE), lib)
	    $(error Cannot flash a library)
    else
        ifeq ($(PORT), )
	        $(error PORT not set)
        endif
	    $(__v__) avrdude -C/etc/avrdude.conf -v -p$(BUILD_MCU) -carduino -P$(PORT) -Uflash:w:$(__build_dir__)/$(__build_artifact__):i
    endif

$(__build_dir__)/$(__build_artifact__): $(__obj_files__)
    ifeq ($(PROJECT_TYPE), lib)
	    @printf "$(__nl__)[AR] $(__obj_files__)\n"
	    $(__v__)$(__ar__) $(__arflags__) $(EXTRA_ARFLAGS) $@ $(__obj_files__)
    else
	    @printf "$(__nl__)[LD] $(__obj_files__)\n"
	    $(__v__)$(__ld__) $(__ldlags__) -mmcu=$(BUILD_MCU) -o $(basename $@).elf $(__obj_files__) $(EXTRA_LDFLAGS) -L$(__self_dir__)build-$(TARGET) -larduino-core$(__core_lib_version_major__) -lm
	    @printf "$(__nl__)[HEX] $(basename $@).elf\n"
	    $(__v__)$(__hex__) $(__hexflags__) $(EXTRA_HEXFLAGS) $(basename $@).elf $@
    endif

# C files
$(__build_dir__)/%.c.o: %.c
    ifeq ($(TARGET), )
	    $(error TARGET not set)
    endif
	@$(__mkdir__) $(dir $@)
	@printf "$(__nl__)[CC] $<\n"
	$(__v__)$(__cc__) $(__cflags__) -mmcu=$(BUILD_MCU) -DF_CPU=$(BUILD_F_CPU) -DARDUINO=$(__core_lib_version__) -DARDUINO_$(BUILD_BOARD) -DARDUINO_ARCH_$(BUILD_ARCH) $(EXTRA_CFLAGS) $(__includes__) $< -o $@

# C++ files
$(__build_dir__)/%.cpp.o: %.cpp
    ifeq ($(TARGET), )
	    $(error TARGET not set)
    endif
	@$(__mkdir__) $(dir $@)
	@printf "$(__nl__)[CXX] $<\n"
	$(__v__)$(__cxx__) $(__cxxflags__) -mmcu=$(BUILD_MCU) -DF_CPU=$(BUILD_F_CPU) -DARDUINO=$(__core_lib_version__) -DARDUINO_$(BUILD_BOARD) -DARDUINO_ARCH_$(BUILD_ARCH) $(EXTRA_CXXFLAGS) $(__includes__) $< -o $@

# Assembly files
$(__build_dir__)/%.S.o: %.S
    ifeq ($(TARGET), )
	    $(error TARGET not set)
    endif
	@$(__mkdir__) $(dir $@)
	@printf "$(__nl__)[AS] $<\n"
	$(__v__)$(__as__) $(__asflags__) -mmcu=$(BUILD_MCU) -DF_CPU=$(BUILD_F_CPU) -DARDUINO=$(__core_lib_version__) -DARDUINO_$(BUILD_BOARD) -DARDUINO_ARCH_$(BUILD_ARCH) $(EXTRA_ASFLAGS) $(__includes__) $< -o $@
