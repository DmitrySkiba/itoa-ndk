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

# =========================================================
# Define phony targets.

.PHONY: all \
        clean \
        before-build-modules build-modules \
          clean-module-bin-paths copy-module-binaries \
        build-app install-app run-app

# The goal.
all: build-modules before-build-modules \
       clean-module-bin-paths copy-module-binaries \
     build-app
	@echo "Done."

# Targets dependencies. 
build-modules: before-build-modules
distclean: clean

# =========================================================
# Add an application.

include $(BUILD_SYSTEM)/add-app.mk

ITOA_ROOT := $(strip $(ITOA_ROOT))
ifndef ITOA_ROOT
  ITOA_ROOT := $(NDK_ROOT)/itoa
endif

ITOA_APP_SKELETON_PATH := $(ITOA_ROOT)/app
ITOA_SYSROOT = $(ITOA_ROOT)/platform/arch-$(TARGET_ARCH)

# Check if we are building the Itoa itself.
ifdef APP_IS_ITOA
  APP_IS_LIBRARY := true
  APP_MODULES_BIN_PATH = $(ITOA_SYSROOT)/usr/lib
  APP_MODULES_CLEAR_BIN := true
endif

# =========================================================
# Build module(s) for each configured abi.

# These macros are used in Module.mk to include the corresponding
# build script that will parse the MODULE_XXX variable definitions.
CLEAR_VARS                := $(BUILD_SYSTEM)/clear-vars.mk
BUILD_STATIC_LIBRARY      := $(BUILD_SYSTEM)/build-static-library.mk
BUILD_SHARED_LIBRARY      := $(BUILD_SYSTEM)/build-shared-library.mk

# This is the list of directories containing dependency information
# generated during the build. It will be updated by build scripts
# when module definitions are parsed.
ALL_DEPENDENCY_PATHS :=

# Build modules.
$(foreach abi,$(APP_ABIS),\
  $(eval TARGET_ABI := $(abi))\
  $(eval include $(BUILD_SYSTEM)/setup-target.mk)\
)

# Include dependency information
ALL_DEPENDENCY_PATHS := $(sort $(ALL_DEPENDENCY_PATHS))
-include $(wildcard $(ALL_DEPENDENCY_PATHS:%=%/*.d))

# =========================================================
# Make the app.
# There are two possibilities:
#  1. If APP_IS_LIBRARY is 'true' then instead of building
#     app we copy module binaries (static and shared libraries)
#     to APP_MODULES_BIN_PATH.
#  2. Else (the default) we build app (apk) and also handle
#     install-app and run-app targets.

ifeq ($(APP_IS_LIBRARY),true)
  include $(BUILD_SYSTEM)/app-library.mk
else
  include $(BUILD_SYSTEM)/app.mk
endif

