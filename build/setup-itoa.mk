#
# Copyright (C) 2011 Dmitry Skiba
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
# Setup variables.

ifndef APP_IS_ITOA
  TARGET_ITOA_LIBRARIES := $(wildcard $(ITOA_SYSROOT)/usr/lib/*.so)
endif

TARGET_ITOA_CFLAGS := -I$(ITOA_SYSROOT)/usr/include
TARGET_ITOA_CFLAGS += -D__OBJC2__

TARGET_ITOA_OBJCFLAGS := $(TARGET_ITOA_CFLAGS) \
	-fobjc-abi-version=2 \
	-fnext-runtime \
	-fexceptions \
	-fno-objc-sjlj-exceptions \
	-fobjc-zerocost-exceptions

TARGET_ITOA_CPPFLAGS := $(TARGET_ITOA_CFLAGS)
TARGET_ITOA_OBJCPPFLAGS := $(TARGET_ITOA_OBJCFLAGS)

