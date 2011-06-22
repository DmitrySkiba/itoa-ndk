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

# this file is included repeatedly from ItoaModule.mk files in order to clean
# the module-specific variables from the environment,

NDK_LOCAL_VARS := \
  MODULE_NAME \
  MODULE_SRC_FILES \
  MODULE_C_INCLUDES \
  MODULE_CFLAGS \
  MODULE_OBJCFLAGS \
  MODULE_CPPFLAGS \
  MODULE_OBJCPPFLAGS \
  MODULE_LDFLAGS \
  MODULE_LDLIBS \
  MODULE_ARFLAGS \
  MODULE_CPP_EXTENSION \
  MODULE_STATIC_LIBRARIES \
  MODULE_STATIC_WHOLE_LIBRARIES \
  MODULE_SHARED_LIBRARIES \
  MODULE_ALLOW_UNDEFINED_SYMBOLS \
  MODULE_ARM_MODE \
  MODULE_ARM_NEON \
  MODULE_DISABLE_NO_EXECUTE \

$(call clear-vars, $(NDK_LOCAL_VARS))

