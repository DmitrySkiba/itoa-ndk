#
# Copyright (C) 2011 Dmitry Skiba
# Copyright (C) 2008 The Android Open Source Project
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

# =========================================================
# Determine MODULE_MAKEFILES, list of makefiles that were included
#  during the build of this module.

MODULE_MAKEFILES := $(wordlist $(LAST_MODULE_MAKEFILE),$(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))

# Filter out Itoa NDK makefiles
MODULE_MAKEFILES := $(filter-out $(BUILD_SYSTEM)/%,$(MODULE_MAKEFILES))

# Update list pointer
LAST_MODULE_MAKEFILE := $(words $(MAKEFILE_LIST))

# =========================================================
# Build targets: build-<module>, build-<module>-<abi>

build-module := build-$(MODULE_NAME)
build-module-abi := build-$(MODULE_NAME)-$(TARGET_ABI)
.PHONY: $(build-module) $(build-module-abi) 

build-modules: $(build-module)
$(build-module): $(build-module-abi)
$(build-module-abi): $(LOCAL_BUILT_MODULE)

# =========================================================
# Clean targets: clean-<module>, clean-<module>-<abi>

clean-module := clean-$(MODULE_NAME)
clean-module-abi := clean-$(MODULE_NAME)-$(TARGET_ABI)
.PHONY: $(clean-module) $(clean-module-abi)

clean: $(clean-module)
$(clean-module): $(clean-module-abi)
$(clean-module-abi): PRIVATE_NAME := $(MODULE_NAME)
$(clean-module-abi): PRIVATE_ABI := $(TARGET_ABI)
$(clean-module-abi): PRIVATE_PATHS := $(LOCAL_BUILT_MODULE) $(LOCAL_OBJS_PATH)
$(clean-module-abi):
	@echo "Clean: $(PRIVATE_NAME) [$(PRIVATE_ABI)]"
	$(hide) rm -rf $(PRIVATE_PATHS)

# =========================================================

# list of generated object files
LOCAL_OBJECTS :=

# always define ANDROID when building binaries
#
MODULE_CFLAGS := -DANDROID $(MODULE_CFLAGS)

#
# Add the default system shared libraries to the build
#
ifeq ($(LOCAL_SYSTEM_SHARED_LIBRARIES),none)
  MODULE_SHARED_LIBRARIES += $(TARGET_DEFAULT_SYSTEM_SHARED_LIBRARIES)
else
  MODULE_SHARED_LIBRARIES += $(LOCAL_SYSTEM_SHARED_LIBRARIES)
endif


#
# Check MODULE_CPP_EXTENSION, use '.cpp' by default
#
MODULE_CPP_EXTENSION := $(strip $(MODULE_CPP_EXTENSION))
ifeq ($(MODULE_CPP_EXTENSION),)
  MODULE_CPP_EXTENSION := .cpp
else
  ifneq ($(words $(MODULE_CPP_EXTENSION)),1)
    $(call ndk_info, MODULE_CPP_EXTENSION must be one word only, not '$(MODULE_CPP_EXTENSION)')
    $(call ndk_error, Aborting)
  endif
endif

#
# If MODULE_ALLOW_UNDEFINED_SYMBOLS is not true, the linker will allow the generation
# of a binary that uses undefined symbols.
#
ifneq ($(MODULE_ALLOW_UNDEFINED_SYMBOLS),true)
  MODULE_LDFLAGS += $(MODULE_LDFLAGS) $(TARGET_NO_UNDEFINED_LDFLAGS)
endif

# If MODULE_DISABLE_NO_EXECUTE is not true, we disable generated code from running from
# the heap and stack by default.
#
ifndef ($(MODULE_DISABLE_NO_EXECUTE),true)
  MODULE_CFLAGS += $(TARGET_NO_EXECUTE_CFLAGS)
  MODULE_LDFLAGS += $(TARGET_NO_EXECUTE_LDFLAGS)
endif

#
# The original Android build system allows you to use the .arm prefix
# to a source file name to indicate that it should be defined in either
# 'thumb' or 'arm' mode, depending on the value of MODULE_ARM_MODE
#
# First, check MODULE_ARM_MODE, it should be empty, 'thumb' or 'arm'
# We make the default 'thumb'
#
MODULE_ARM_MODE := $(strip $(MODULE_ARM_MODE))
ifdef MODULE_ARM_MODE
  ifneq ($(words $(MODULE_ARM_MODE)),1)
      $(call ndk_info,   MODULE_ARM_MODE must be one word, not '$(MODULE_ARM_MODE)')
      $(call ndk_error, Aborting)
  endif
  # check that MODULE_ARM_MODE is defined to either 'arm' or 'thumb'
  $(if $(filter-out thumb arm, $(MODULE_ARM_MODE)),\
      $(call ndk_info,   MODULE_ARM_MODE must be defined to either 'arm' or 'thumb', not '$(MODULE_ARM_MODE)')\
      $(call ndk_error, Aborting)\
  )
endif

# As a special case, the original Android build system
# allows one to specify that certain source files can be
# forced to build in ARM mode by using a '.arm' suffix
# after the extension, e.g.
#
#  MODULE_SRC_FILES := foo.c.arm
#
# to build source file $(MODULE_PATH)/foo.c as ARM
#

# As a special extension, the Itoa NDK also supports the .neon extension suffix
# to indicate that a single file can be compiled with ARM NEON support
# We must support both foo.c.neon and foo.c.arm.neon here
#
# Also, if MODULE_ARM_NEON is set to 'true', force Neon mode for all source
# files
#

neon_sources  := $(filter %.neon,$(MODULE_SRC_FILES))
neon_sources  := $(neon_sources:%.neon=%)

MODULE_ARM_NEON := $(strip $(MODULE_ARM_NEON))
ifdef MODULE_ARM_NEON
  $(if $(filter-out true false,$(MODULE_ARM_NEON)),\
    $(call ndk_info,MODULE_ARM_NEON must be defined either to 'true' or 'false', not '$(MODULE_ARM_NEON)')\
    $(call ndk_error,Aborting) \
  )
endif
ifeq ($(MODULE_ARM_NEON),true)
  neon_sources += $(MODULE_SRC_FILES:%.neon=%))
endif

neon_sources := $(strip $(neon_sources))
ifdef neon_sources
  ifneq ($(TARGET_ABI),armeabi-v7a)
    $(call ndk_info,NEON support is only possible for armeabi-v7a ABI)
    $(call ndk_error,Aborting)
  endif
  $(call tag-src-files,$(neon_sources:%.arm=%),neon)
endif

MODULE_SRC_FILES := $(MODULE_SRC_FILES:%.neon=%)

# strip the .arm suffix from MODULE_SRC_FILES
# and tag the relevant sources with the 'arm' tag
#
arm_sources     := $(filter %.arm,$(MODULE_SRC_FILES))
arm_sources     := $(arm_sources:%.arm=%)
thumb_sources   := $(filter-out %.arm,$(MODULE_SRC_FILES))
MODULE_SRC_FILES := $(arm_sources) $(thumb_sources)

ifeq ($(MODULE_ARM_MODE),arm)
    arm_sources := $(MODULE_SRC_FILES)
endif
ifeq ($(MODULE_ARM_MODE),thumb)
    arm_sources := $(empty)
endif
$(call tag-src-files,$(arm_sources),arm)

# Process all source file tags to determine toolchain-specific
# target compiler flags, and text.
#
$(call TARGET-process-src-files-tags)

# only call dump-src-file-tags during debugging
#$(dump-src-file-tags)

# Build the sources to object files
#

$(foreach src,$(filter %.c,$(MODULE_SRC_FILES)),\
    $(call compile-c-source,$(src)))

$(foreach src,$(filter %.S %.s,$(MODULE_SRC_FILES)),\
    $(call compile-s-source,$(src)))

$(foreach src,$(filter %.m,$(MODULE_SRC_FILES)),\
    $(call compile-m-source,$(src)))

$(foreach src,$(filter %$(MODULE_CPP_EXTENSION),$(MODULE_SRC_FILES)),\
    $(call compile-cpp-source,$(src)))

$(foreach src,$(filter %.mm,$(MODULE_SRC_FILES)),\
    $(call compile-mm-source,$(src)))

unknown_sources := $(strip $(filter-out %.c %.S %.s %.m %$(MODULE_CPP_EXTENSION) %.mm,$(MODULE_SRC_FILES)))
ifdef unknown_sources
    $(call ndk_info,WARNING: Unsupported source file extensions for module $(MODULE_NAME))
    $(call ndk_info,  $(unknown_sources))
endif

#
# The compile-xxx-source calls updated LOCAL_OBJECTS and LOCAL_DEPENDENCY_PATHS
#
ALL_DEPENDENCY_PATHS += $(sort $(LOCAL_DEPENDENCY_PATHS))

#
# Handle the static and shared libraries this module depends on
#
MODULE_STATIC_LIBRARIES := $(call strip-lib-prefix,$(MODULE_STATIC_LIBRARIES))
MODULE_SHARED_LIBRARIES := $(call strip-lib-prefix,$(MODULE_SHARED_LIBRARIES))

# Add dependencies to build-module-abi target
$(build-module-abi): $(patsubst %,build-%-$(TARGET_ABI),$(MODULE_STATIC_LIBRARIES))
$(build-module-abi): $(patsubst %,build-%-$(TARGET_ABI),$(MODULE_SHARED_LIBRARIES))

static_libraries := $(call map,static-library-path,$(MODULE_STATIC_LIBRARIES))
shared_libraries := $(call map,shared-library-path,$(MODULE_SHARED_LIBRARIES)) \
                    $(TARGET_PREBUILT_SHARED_LIBRARIES) \
                    $(TARGET_ITOA_LIBRARIES)

$(LOCAL_BUILT_MODULE): $(static_libraries) $(shared_libraries)

# If MODULE_LDLIBS contains anything like -l<library> then
# prepend a -L$(SYSROOT)/usr/lib to it to ensure that the linker
# looks in the right location
#
ifneq ($(filter -l%,$(MODULE_LDLIBS)),)
    MODULE_LDLIBS := -L$(SYSROOT)/usr/lib $(MODULE_LDLIBS)
endif

# These variables are used in commands defined in toolchain/config.mk.
$(LOCAL_BUILT_MODULE): PRIVATE_STATIC_LIBRARIES := $(static_libraries) $(TARGET_PREBUILT_STATIC_LIBRARIES)
$(LOCAL_BUILT_MODULE): PRIVATE_SHARED_LIBRARIES := $(shared_libraries)
$(LOCAL_BUILT_MODULE): PRIVATE_OBJECTS          := $(LOCAL_OBJECTS)
$(LOCAL_BUILT_MODULE): PRIVATE_LDFLAGS          := $(TARGET_LDFLAGS) $(MODULE_LDFLAGS)
$(LOCAL_BUILT_MODULE): PRIVATE_LDLIBS           := $(MODULE_LDLIBS) $(TARGET_LDLIBS)

# This variable is used in build-xxx-library.mk.
$(LOCAL_BUILT_MODULE): PRIVATE_NAME := $(notdir $(LOCAL_BUILT_MODULE))
