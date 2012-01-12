#
# Copyright (C) 2011 Dmitry Skiba
# Copyright (C) 2009 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Note that the following APP_ variables are evaluated for
# each abi so you can use TARGET_ variables in them:
#  APP_MODULES_BIN_PATH
#
# All other APP_ variables are evaluated once.

# =========================================================
# If NDK_PROJECT_PATH is not defined, let it be the current path.
# Check for ItoaApp.mk.

NDK_PROJECT_PATH := $(strip $(NDK_PROJECT_PATH))
ifndef NDK_PROJECT_PATH
    NDK_PROJECT_PATH_GUESS := $(strip $(shell pwd))
    NDK_PROJECT_PATH := $(patsubst %/,%,$(dir $(wildcard $(NDK_PROJECT_PATH_GUESS)/ItoaApp.mk)))
    ifndef NDK_PROJECT_PATH
        $(call ndk_info,There is no ItoaApp.mk in '$(NDK_PROJECT_PATH_GUESS)'!)
        $(call ndk_info,Either create ItoaApp.mk there or define NDK_PROJECT_PATH property.)
        $(call ndk_error,Aborting)
    endif
endif

# Check that there are no spaces in the project path, or bad things will happen
ifneq ($(words $(NDK_PROJECT_PATH)),1)
    $(call ndk_info,Your application project path contains spaces: '$(NDK_PROJECT_PATH)')
    $(call ndk_info,The Itoa NDK build cannot work here. Please move your project to a different location.)
    $(call ndk_error,Aborting.)
endif

$(call ndk_log,Found project path: $(NDK_PROJECT_PATH))

# =========================================================
# Parse application.

NDK_APP_MK := $(NDK_PROJECT_PATH)/ItoaApp.mk

include $(NDK_APP_MK)

# Evaluate and strip each variable.
$(foreach var,$(APP_VARS),\
    $(eval $(var) := $$(strip $$($(var)))))

# =========================================================
# Check and set defaults.

ifndef APP_PROJECT_PATH
    APP_PROJECT_PATH := $(NDK_PROJECT_PATH)
endif

ifndef APP_BIN_PATH
  APP_BIN_PATH = $(APP_PROJECT_PATH)/bin
endif

ifndef APP_TMP_PATH
  APP_TMP_PATH = $(APP_PROJECT_PATH)/tmp
endif

ifndef APP_CLEAN_MODULES_BIN_PATH
  APP_CLEAN_MODULES_BIN_PATH := true
endif

# =========================================================
# If APP_MODULE_MK is defined, check that the file exists.
# If undefined, look in $(APP_PROJECT_PATH)/ItoaModule.mk

ifdef APP_MODULE_MK
    _build_script := $(strip $(wildcard $(APP_MODULE_MK)))
    ifndef _build_script
        $(call ndk_info,Your APP_MODULE_MK points to an unknown file: $(APP_MODULE_MK))
        $(call ndk_error,Aborting...)
    endif
    APP_MODULE_MK := $(_build_script)
    $(call ndk_log,  Using build script $(APP_MODULE_MK))
else
    _build_script := $(strip $(wildcard $(APP_PROJECT_PATH)/ItoaModule.mk))
    ifndef _build_script
        $(call ndk_info,There is no ItoaModule.mk under $(APP_PROJECT_PATH))
        $(call ndk_info,If this is intentional, please define APP_MODULE_MK to point)
        $(call ndk_info,to a valid Itoa NDK build script.)
        $(call ndk_error,Aborting...)
    endif
    APP_MODULE_MK := $(_build_script)
    $(call ndk_log,  Defaulted to APP_MODULE_MK=$(APP_MODULE_MK))
endif

# =========================================================
# Check APP_OPTIM.

ifneq ($(APP_OPTIM),)
    # check that APP_OPTIM, if defined, is either 'release' or 'debug'
    $(if $(filter-out release debug,$(APP_OPTIM)),\
        $(call ndk_info, The APP_OPTIM defined in $(NDK_APP_MK) must only be 'release' or 'debug')\
        $(call ndk_error,Aborting)\
    )
    $(call ndk_log,Selecting optimization mode through ItoaApp.mk: $(APP_OPTIM))
else
    $(call ndk_log,Selecting release optimization mode (application is not debuggable))
    APP_OPTIM := release
endif

# Set release/debug build flags. We always use the -g flag because
# we generate symbol versions of the binaries that are later stripped
# when they are copied to the final project's bin directory.
ifeq ($(APP_OPTIM),debug)
  APP_OPTIM_CFLAGS := -O0 -g
else
  APP_OPTIM_CFLAGS := -O2 -DNDEBUG -g
endif

# =========================================================
# Check configured abis.

ifndef APP_ABIS
    # the default ABI for now is armeabi
    APP_ABIS := armeabi
endif

# check the target ABIs for this application
_bad_abis = $(strip $(filter-out $(NDK_ALL_ABIS),$(APP_ABIS)))
ifneq ($(_bad_abis),)
    $(call ndk_info,Application targets unknown ABI(s): $(_bad_abis))
    $(call ndk_info,Please fix APP_ABIS definition.)
    $(call ndk_error,Aborting)
endif

