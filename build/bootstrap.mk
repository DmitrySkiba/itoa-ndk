#
# Copyright (C) 2011 Dmitry Skiba
# Copyright (C) 2009-2010 The Android Open Source Project
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

NDK_NAME := Itoa NDK

# =========================================================
# Logging.

ndk_info    = $(info $(NDK_NAME): $1 $2 $3 $4 $5)
ndk_warning = $(warning $(NDK_NAME): $1 $2 $3 $4 $5)
ndk_error   = $(error $(NDK_NAME): $1 $2 $3 $4 $5)

# Define ndk_log function which logs only when NDK_LOG is defined.
NDK_LOG := $(strip $(NDK_LOG))
ifdef NDK_LOG
    ndk_log = $(ndk_info)
else
    ndk_log :=
endif

# =========================================================
# Detect NDK_ROOT by processing this Makefile's location.
# This assumes we are located under $NDK_ROOT/build/.

NDK_ROOT := $(dir $(lastword $(MAKEFILE_LIST)))
NDK_ROOT := $(strip $(NDK_ROOT:%build/=%))
NDK_ROOT := $(NDK_ROOT:%/=%)
ifeq ($(NDK_ROOT),)
    # for the case when we're invoked from the Itoa NDK install path
    NDK_ROOT := .
endif
ifdef NDK_LOG
    $(call ndk_info,NDK installation path auto-detected: '$(NDK_ROOT)')
endif
ifneq ($(words $(NDK_ROOT)),1)
    $(call ndk_info,You Itoa NDK installation path contains spaces.)
    $(call ndk_info,Please re-install to a different location to fix the issue !)
    $(call ndk_error Aborting.)
endif

# =========================================================
# Startup checks.

# Check that we have at least GNU Make 3.81
# We do this by detecting whether 'lastword' is supported
ifneq ($(lastword a b c d e f),f)
    $(call ndk_error,GNU Make version $(MAKE_VERSION) is too low (should be >= 3.81)
endif

ANDROID_SDK_HOME := $(strip $(ANDROID_SDK_HOME))
ifndef ANDROID_SDK_HOME
    $(call ndk_error,ANDROID_SDK_HOME is not defined. It should point to Android SDK folder.)
endif

# =========================================================
# Definitions.

# The location of the build system files
BUILD_SYSTEM := $(NDK_ROOT)/build

# Include common definitions
include $(BUILD_SYSTEM)/definitions.mk

# =========================================================
#
# Read all toolchain-specific configuration files.
#
# Each toolchain must have a corresponding config.mk file located
# in toolchains/<name>/ that will be included here.
#
# Each one of these files should define the following variables:
#   TOOLCHAIN_NAME   toolchain name (e.g. arm-eabi-4.2.1)
#   TOOLCHAIN_ABIS   list of target ABIs supported by the toolchain.

# Location where toolchains are residing
HOST_TOOLCHAINS := $(NDK_ROOT)/toolchains

# These variables are updated by add-toolchain.mk
NDK_ALL_TOOLCHAINS :=
NDK_ALL_ABIS       :=

HOST_TOOLCHAIN_CONFIGS := $(wildcard $(HOST_TOOLCHAINS)/*/config.mk)
$(foreach _config_mk,$(HOST_TOOLCHAIN_CONFIGS),\
    $(eval include $(BUILD_SYSTEM)/add-toolchain.mk)\
)

NDK_ALL_TOOLCHAINS   := $(call uniq,$(NDK_ALL_TOOLCHAINS))
NDK_ALL_ABIS         := $(call uniq,$(NDK_ALL_ABIS))

$(call ndk_log, This Itoa NDK supports the following toolchains and target ABIs:)
$(foreach tc,$(NDK_ALL_TOOLCHAINS),\
    $(call ndk_log, $(space)$(space)$(tc):  $(NDK_TOOLCHAIN.$(tc).abis))\
)

# =========================================================
# Do the work.

include $(BUILD_SYSTEM)/main.mk

