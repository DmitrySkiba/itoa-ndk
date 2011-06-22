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
# Internal definitions.

# Wires binary and targets.
#   $1: binary
define wire-binary
  copy-module-binaries: $1
  ifeq ($(APP_CLEAN_MODULES_BIN_PATH),true)
    $1: clean-module-bin-paths
  endif
endef # wire-binary

# =========================================================
# Rules.

# Clear all modules bin paths.
ifeq ($(APP_CLEAN_MODULES_BIN_PATH),true)
clean-module-bin-paths: PRIVATE_PATHS := \
  $(foreach abi,$(APP_ABIS),$(call get-abi-var,$(abi),APP_MODULES_BIN_PATH))
clean-module-bin-paths:
	@echo "Cleaning module bin paths..."
	$(hide) rm -rf $(PRIVATE_PATHS)
	$(hide) mkdir -p $(PRIVATE_PATHS)
endif # APP_CLEAN_MODULES_BIN_PATH

# Copy binaries.
ALL_COPIED_BINARIES := $(foreach abi,$(APP_ABIS),\
  $(call copy-binaries,\
    $(call get-abi-var,$(abi),APP_STATIC_LIBRARIES) \
      $(call get-abi-var,$(abi),APP_SHARED_LIBRARIES),\
    $(call get-abi-var,$(abi),APP_MODULES_BIN_PATH))\
)

# Wire binaries and targets.
$(foreach binary,$(ALL_COPIED_BINARIES),\
  $(eval $(call wire-binary,$(binary)))\
)  

