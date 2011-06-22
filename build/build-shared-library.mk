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

# this file is included from ItoaModule.mk files to build a target-specific
# shared library
#

LOCAL_BUILD_SCRIPT := BUILD_SHARED_LIBRARY
MODULE_NAME_CLASS := SHARED_LIBRARY

$(eval $(check-MODULE_NAME))

LOCAL_BUILT_MODULE := $(call shared-library-path,$(MODULE_NAME))
LOCAL_OBJS_PATH     := $(TARGET_OBJS_PATH)/$(MODULE_NAME)

include $(BUILD_SYSTEM)/build-binary.mk

$(LOCAL_BUILT_MODULE): $(LOCAL_OBJECTS)
	@ mkdir -p $(dir $@)
	@ echo "SharedLibrary  : $(PRIVATE_NAME)"
	$(hide) $(cmd-build-shared-library)

APP_BINARIES_TO_INSTALL += $(LOCAL_BUILT_MODULE)

APP_SHARED_LIBRARIES += $(LOCAL_BUILT_MODULE)

build-app: $(LOCAL_BUILT_MODULE)
