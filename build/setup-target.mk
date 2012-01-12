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

$(call assert-defined,TARGET_ABI)

$(call ndk_log,Building for ABI '$(TARGET_ABI)')

# =========================================================
# Setup target variables

# Map ABIs to a target architecture
TARGET_ARCH_for_armeabi     := arm
TARGET_ARCH_for_armeabi-v7a := arm
TARGET_ARCH_for_x86         := x86
TARGET_ARCH                 := $(TARGET_ARCH_for_$(TARGET_ABI))


# Setup sysroot-related variables. The SYSROOT point to a directory
# that contains all public header files for a given platform, plus
# some libraries and object files used for linking the generated
# target files properly.

SYSROOT := $(NDK_ROOT)/platform/arch-$(TARGET_ARCH)

TARGET_CRTBEGIN_STATIC_O  := $(SYSROOT)/usr/lib/crtbegin_static.o
TARGET_CRTBEGIN_DYNAMIC_O := $(SYSROOT)/usr/lib/crtbegin_dynamic.o
TARGET_CRTEND_O           := $(SYSROOT)/usr/lib/crtend_android.o

TARGET_PREBUILT_STATIC_LIBRARIES := 
TARGET_PREBUILT_STATIC_LIBRARIES := $(TARGET_PREBUILT_STATIC_LIBRARIES:%=$(SYSROOT)/usr/lib/%.a)

TARGET_PREBUILT_SHARED_LIBRARIES := libc libm
TARGET_PREBUILT_SHARED_LIBRARIES := $(TARGET_PREBUILT_SHARED_LIBRARIES:%=$(SYSROOT)/usr/lib/%.so)

# Setup out variables.
TARGET_OUT_PATH  := $(APP_TMP_PATH)/$(TARGET_ABI)
TARGET_OBJS_PATH := $(TARGET_OUT_PATH)/objs

# =========================================================
# Allow users to specify the toolchain.

NDK_TOOLCHAIN := $(strip $(NDK_TOOLCHAIN))
ifdef NDK_TOOLCHAIN
    # check that the toolchain name is supported
    $(if $(filter-out $(NDK_ALL_TOOLCHAINS),$(NDK_TOOLCHAIN)),\
      $(call ndk_info,NDK_TOOLCHAIN is defined to the unsupported value $(NDK_TOOLCHAIN)) \
      $(call ndk_info,Please use one of the following values: $(NDK_ALL_TOOLCHAINS))\
      $(call ndk_error,Aborting)\
    ,)
    $(call ndk_log, Using specific toolchain $(NDK_TOOLCHAIN))
endif

# Check that we have a toolchain that supports the current ABI.
# NOTE: If NDK_TOOLCHAIN is defined, we're going to use it.
#
ifndef NDK_TOOLCHAIN
    TARGET_TOOLCHAIN_LIST := $(strip $(sort $(call get-current-abi-var,TOOLCHAINS)))
    ifndef TARGET_TOOLCHAIN_LIST
        $(call ndk_info,There is no toolchain that supports the $(TARGET_ABI) ABI.)
        $(call ndk_info,Please correct APP_ABIS definition)
        $(call ndk_info,a set of the following values: $(NDK_ALL_ABIS))
        $(call ndk_error,Aborting)
    endif
    # Select the last toolchain from the sorted list.
    TARGET_TOOLCHAIN := $(lastword $(TARGET_TOOLCHAIN_LIST))
    $(call ndk_log,Using target toolchain '$(TARGET_TOOLCHAIN)' for '$(TARGET_ABI)' ABI)
else # NDK_TOOLCHAIN is not empty
    TARGET_TOOLCHAIN_LIST := $(strip $(filter $(NDK_TOOLCHAIN),$(call get-current-abi-var,TOOLCHAINS)))
    ifndef TARGET_TOOLCHAIN_LIST
        $(call ndk_info,The selected toolchain ($(NDK_TOOLCHAIN)) does not support the $(TARGET_ABI) ABI.)
        $(call ndk_info,Please correct APP_ABIS definition)
        $(call ndk_info,a set of the following values: $(NDK_TOOLCHAIN.$(NDK_TOOLCHAIN).abis))
        $(call ndk_info,Or change your NDK_TOOLCHAIN definition.)
        $(call ndk_error,Aborting)
    endif
    TARGET_TOOLCHAIN := $(NDK_TOOLCHAIN)
endif # NDK_TOOLCHAIN is not empty

# Call the toolchain-specific setup script
include $(NDK_TOOLCHAIN.$(TARGET_TOOLCHAIN).setup)

# =========================================================
# Setup itoa

include $(BUILD_SYSTEM)/setup-itoa.mk

# =========================================================
# Parse the Module.mk for the application

APP_BINARIES_TO_INSTALL :=
APP_STATIC_LIBRARIES :=
APP_SHARED_LIBRARIES :=
APP_BINARIES_TO_INSTALL += $(TARGET_ITOA_LIBRARIES)

# Reset module makefile list.
LAST_MODULE_MAKEFILE := $(words $(MAKEFILE_LIST))

# Parse module(s).
include $(APP_MODULE_MK)

# Record variables for the installation process.
$(call set-current-abi-var,APP_BINARIES_TO_INSTALL)
$(call set-current-abi-var,APP_STATIC_LIBRARIES)
$(call set-current-abi-var,APP_SHARED_LIBRARIES)
$(call set-current-abi-var,APP_MODULES_BIN_PATH)

