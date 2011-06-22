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
# Helpers.

APP_TEMPLATE_VARS := APP_NAME APP_PACKAGE

# Copies template file; performs replacements.
#   $1: template file
#   $2: target file
define copy-template
$2: $1 $(NDK_APP_MK)
	@echo "Processing $$(notdir $$<)..."
	$(hide) sed \
	  "$(foreach var,$(APP_TEMPLATE_VARS),;s/$(var)/$($(var))/g)"\
	  $$< > $$@
endef

# =========================================================
# Build the application.

ITOA_TMP_APP_PATH := $(APP_TMP_PATH)/app
ITOA_TMP_APP_APK := $(ITOA_TMP_APP_PATH)/bin/app.apk
ITOA_APP_APK := $(APP_BIN_PATH)/app.apk

ITOA_APP_SKELETON_FILES := $(call file-hierarchy,$(ITOA_APP_SKELETON_PATH))
ITOA_APP_SKELETON_TEMPLATES := $(filter %.template,$(ITOA_APP_SKELETON_FILES))
ITOA_APP_SKELETON_FILES := $(filter-out %.template,$(ITOA_APP_SKELETON_FILES))

# Copy app skeleton files.
ITOA_TMP_APP_FILES := $(foreach file,$(ITOA_APP_SKELETON_FILES),\
  $(eval ITOA_TMP_APP_FILE :=  $(ITOA_TMP_APP_PATH)/$(file))\
  $(eval $(call copy-file,$(ITOA_APP_SKELETON_PATH)/$(file),$(ITOA_TMP_APP_FILE)))\
  $(ITOA_TMP_APP_FILE)\
)

# Process and copy templates.
ITOA_TMP_APP_FILES += $(foreach templ,$(ITOA_APP_SKELETON_TEMPLATES),\
  $(eval ITOA_TMP_APP_FILE := $(ITOA_TMP_APP_PATH)/$(patsubst %.template,%,$(templ)))\
  $(eval $(call copy-template,$(ITOA_APP_SKELETON_PATH)/$(templ),$(ITOA_TMP_APP_FILE)))\
  $(ITOA_TMP_APP_FILE)\
)

# Copy module binaries to the app/libs.
ITOA_TMP_APP_FILES += $(foreach abi,$(APP_ABIS),\
  $(call copy-binaries,\
    $(call get-abi-var,$(abi),APP_BINARIES_TO_INSTALL),\
    $(ITOA_TMP_APP_PATH)/libs/$(abi))\
)

# Build the app, copy to the bin folder.
$(ITOA_TMP_APP_APK): $(ITOA_TMP_APP_FILES)
	@echo "Building app..."
	$(hide) ant -f $(ITOA_TMP_APP_PATH)/build.xml debug \
	  -Dsdk.dir=$(ANDROID_SDK_HOME) \
	  -l $(ITOA_TMP_APP_PATH)/build.log \
	  > /dev/null; \
	  if [ $$? -ne 0 ]; then \
	    cat $(ITOA_TMP_APP_PATH)/build.log; \
	    echo "^^^ Failed to build app! Review the log above for error. ^^^"; \
	    exit 1; \
	  fi;
$(eval $(call copy-file,$(ITOA_TMP_APP_APK),$(ITOA_APP_APK)))

# Chain to the target.
build-app: $(ITOA_APP_APK)

# =========================================================
# Install and run.

ANDROID_ADB := $(ANDROID_SDK_HOME)/platform-tools/adb

install-app: build-app
	@echo "Installing app..."
	$(hide) $(ANDROID_ADB) install -r $(ITOA_APP_APK)

run-app: install-app
	@echo "Running app..."
	$(hide) $(ANDROID_ADB) shell am start\
	  -a android.intent.action.MAIN \
	  -n $(APP_PACKAGE)/.MainActivity

