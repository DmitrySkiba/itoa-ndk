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

# We use the GNU Make Standard Library
include $(NDK_ROOT)/build/gmsl/gmsl

# -----------------------------------------------------------------------------
# Macro    : empty
# Returns  : an empty macro
# Usage    : $(empty)
# -----------------------------------------------------------------------------
empty :=

# -----------------------------------------------------------------------------
# Macro    : space
# Returns  : a single space
# Usage    : $(space)
# -----------------------------------------------------------------------------
space  := $(empty) $(empty)

# -----------------------------------------------------------------------------
# Function : assert-defined
# Arguments: 1: list of variable names
# Returns  : None
# Usage    : $(call assert-defined, VAR1 VAR2 VAR3...)
# Rationale: Checks that all variables listed in $1 are defined, or abort the
#            build
# -----------------------------------------------------------------------------
assert-defined = $(foreach __varname,$(strip $1),\
  $(if $(strip $($(__varname))),,\
    $(call ndk_error, Assertion failure: $(__varname) is not defined)\
  )\
)

# -----------------------------------------------------------------------------
# Function : clear-vars
# Arguments: 1: list of variable names
#            2: file where the variable should be defined
# Returns  : None
# Usage    : $(call clear-vars, VAR1 VAR2 VAR3...)
# Rationale: Clears/undefines all variables in argument list
# -----------------------------------------------------------------------------
clear-vars = $(foreach __varname,$1,$(eval $(__varname) := $(empty)))

# -----------------------------------------------------------------------------
# Function : check-required-vars
# Arguments: 1: list of variable names
#            2: file where the variable(s) should be defined
# Returns  : None
# Usage    : $(call check-required-vars, VAR1 VAR2 VAR3..., <file>)
# Rationale: Checks that all required vars listed in $1 were defined by $2
#            or abort the build with an error
# -----------------------------------------------------------------------------
check-required-vars = $(foreach __varname,$1,\
  $(if $(strip $($(__varname))),,\
    $(call ndk_info, Required variable $(__varname) is not defined by $2)\
    $(call ndk_error,Aborting)\
  )\
)

# -----------------------------------------------------------------------------
# Function : check-MODULE_NAME
# Returns  : None
# Usage    : $(eval $(check-MODULE_NAME))
# Rationale: Checks MODULE_NAME for spaces; generates MODULE_NAME if it is empty
# -----------------------------------------------------------------------------
define check-MODULE_NAME
  ifeq ($(MODULE_NAME),)
    UNNAMED_MODULES_COUNT += x
    MODULE_NAME := unnamed_module_$$(words $$(UNNAMED_MODULES_COUNT))
  else ifneq ($(words $(MODULE_NAME)),1)
    $$(call ndk_info,MODULE_NAME definition contains spaces: '$(MODULE_NAME)')
    $$(call ndk_error,Please correct error. Aborting)
  else
    MODULE_NAME := $(call strip-lib-prefix,$(MODULE_NAME))
  endif
endef

# -----------------------------------------------------------------------------
# Strip any 'lib' prefix in front of a given string.
#
# Function : strip-lib-prefix
# Arguments: 1: module name
# Returns  : module name, without any 'lib' prefix if any
# Usage    : $(call strip-lib-prefix,$(MODULE_NAME))
# -----------------------------------------------------------------------------
strip-lib-prefix = $(1:lib%=%)

# -----------------------------------------------------------------------------
# Macro    : my-dir
# Returns  : the directory of the current Makefile
# Usage    : $(my-dir)
# -----------------------------------------------------------------------------
my-dir = $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))

# =============================================================================
#
# Misc utilities
#
# =============================================================================

# -----------------------------------------------------------------------------
# Creates rule to copy a single file.
#   $1: source file
#   $2: target file
# -----------------------------------------------------------------------------
define copy-file
$2: $1
	@echo "Copying to $$@"
	$(hide) mkdir -p $$(dir $$@)
	$(hide) cp -f $$< $$@
endef

# -----------------------------------------------------------------------------
# Returns all files under a path, relative to that path.
#   $1: path
# -----------------------------------------------------------------------------
define file-hierarchy
  $(patsubst ./%,%,$(shell cd $1; find . -name "*" -type f))
endef

# -----------------------------------------------------------------------------
# Creates rule to copy a single file.
#   $1: target to chain to
#   $2: source path
#   $3: target path
# -----------------------------------------------------------------------------
define targeted-copy-file
$3: $2
	@echo "Copying to $$@"
	$(hide) mkdir -p $$(dir $$@)
	$(hide) cp -f $$< $$@
$1: $3
endef

# -----------------------------------------------------------------------------
# Creates rules to copy all files under a path.
#   $1: target to chain copy rules to
#   $2: source path
#   $3: target path
# -----------------------------------------------------------------------------
define copy-files
  $(foreach file,$(call file-hierarchy,$2),\
    $(eval $(call targeted-copy-file,$1,$2/$(file),$3/$(file))))
endef

# -----------------------------------------------------------------------------
# Copies files to the Itoa root.
#   $1: source path
#   $2: target subpath
# -----------------------------------------------------------------------------
define itoa-copy-files
  $(call copy-files,before-build-modules,$1,$(ITOA_ROOT)/$2)
endef

# -----------------------------------------------------------------------------
# Copies file to the Itoa root.
#   $1: source file path
#   $2: target file subpath
# -----------------------------------------------------------------------------
define itoa-copy-file
  $(call targeted-copy-file,before-build-modules,$1,$(ITOA_ROOT)/$2)
endef

# -----------------------------------------------------------------------------
# Copies files to the Itoa sysroot.
#   $1: source path
#   $2: target subpath
# -----------------------------------------------------------------------------
define itoa-sysroot-copy-files
  $(call copy-files,before-build-modules,$1,$(ITOA_SYSROOT)/$2)
endef

# -----------------------------------------------------------------------------
# Copies a single binary. Strips it.
#   $1: source binary
#   $2: target binary
# -----------------------------------------------------------------------------
define copy-binary
$2: $1
	@echo "Copying $$(notdir $$<) to $$(dir $$@)..."
	$(hide) mkdir -p $$(dir $$@)
	$(hide) cp -f $$< $$@
	$(hide) $$(call cmd-strip, $$@)
endef

# -----------------------------------------------------------------------------
# Copies binaries to the target path.
#   $1: source binaries
#   $2: target path
#   Returns list of target files.
# -----------------------------------------------------------------------------
define copy-binaries
  $(foreach binary,$1,\
    $(eval $0target-binary := $2/$(notdir $(binary)))\
    $(eval $(call copy-binary,$(binary),$($0target-binary)))\
    $($0target-binary) \
    $(eval $0target-binary := )\
  )
endef

# =============================================================================
#
# Source file tagging support.
#
# Each source file listed in MODULE_SRC_FILES can have any number of
# 'tags' associated to it. A tag name must not contain space, and its
# usage can vary.
#
# For example, the 'debug' tag is used to sources that must be built
# in debug mode, the 'arm' tag is used for sources that must be built
# using the 32-bit instruction set on ARM platforms, and 'neon' is used
# for sources that must be built with ARM Advanced SIMD (a.k.a. NEON)
# support.
#
# More tags might be introduced in the future.
#
#  LOCAL_SRC_TAGS contains the list of all tags used (initially empty)
#  MODULE_SRC_FILES contains the list of all source files.
#  LOCAL_SRC_TAG.<tagname> contains the set of source file names tagged
#      with <tagname>
#  MODULE_SRC_FILES_TAGS.<filename> contains the set of tags for a given
#      source file name
#
# Tags are processed by a toolchain-specific function (e.g. TARGET-compute-cflags)
# which will call various functions to compute source-file specific settings.
# These are currently stored as:
#
#  MODULE_SRC_FILES_TARGET_CFLAGS.<filename> contains the list of
#      target-specific C compiler flags used to compile a given
#      source file. This is set by the function TARGET-set-cflags
#      defined in the toolchain's setup.mk script.
#
#  MODULE_SRC_FILES_TEXT.<filename> contains the 'text' that will be
#      displayed along the label of the build output line. For example
#      'thumb' or 'arm  ' with ARM-based toolchains.
#
# =============================================================================

# -----------------------------------------------------------------------------
# Macro    : clear-all-src-tags
# Returns  : remove all source file tags and associated data.
# Usage    : $(clear-all-src-tags)
# -----------------------------------------------------------------------------
clear-all-src-tags = \
$(foreach __tag,$(LOCAL_SRC_TAGS), \
    $(eval LOCAL_SRC_TAG.$(__tag) := $(empty)) \
) \
$(foreach __src,$(MODULE_SRC_FILES), \
    $(eval MODULE_SRC_FILES_TAGS.$(__src) := $(empty)) \
    $(eval MODULE_SRC_FILES_TARGET_CFLAGS.$(__src) := $(empty)) \
    $(eval MODULE_SRC_FILES_TEXT.$(__src) := $(empty)) \
) \
$(eval LOCAL_SRC_TAGS := $(empty_set))

# -----------------------------------------------------------------------------
# Macro    : tag-src-files
# Arguments: 1: list of source files to tag
#            2: tag name (must not contain space)
# Usage    : $(call tag-src-files,<list-of-source-files>,<tagname>)
# Rationale: Add a tag to a list of source files
# -----------------------------------------------------------------------------
tag-src-files = \
$(eval LOCAL_SRC_TAGS := $(call set_insert,$2,$(LOCAL_SRC_TAGS))) \
$(eval LOCAL_SRC_TAG.$2 := $(call set_union,$1,$(LOCAL_SRC_TAG.$2))) \
$(foreach __src,$1, \
    $(eval MODULE_SRC_FILES_TAGS.$(__src) += $2) \
)

# -----------------------------------------------------------------------------
# Macro    : get-src-files-with-tag
# Arguments: 1: tag name
# Usage    : $(call get-src-files-with-tag,<tagname>)
# Return   : The list of source file names that have been tagged with <tagname>
# -----------------------------------------------------------------------------
get-src-files-with-tag = $(LOCAL_SRC_TAG.$1)

# -----------------------------------------------------------------------------
# Macro    : get-src-files-without-tag
# Arguments: 1: tag name
# Usage    : $(call get-src-files-without-tag,<tagname>)
# Return   : The list of source file names that have NOT been tagged with <tagname>
# -----------------------------------------------------------------------------
get-src-files-without-tag = $(filter-out $(LOCAL_SRC_TAG.$1),$(MODULE_SRC_FILES))

# -----------------------------------------------------------------------------
# Macro    : set-src-files-target-cflags
# Arguments: 1: list of source files
#            2: list of compiler flags
# Usage    : $(call set-src-files-target-cflags,<sources>,<flags>)
# Rationale: Set or replace the set of compiler flags that will be applied
#            when building a given set of source files. This function should
#            normally be called from the toolchain-specific function that
#            computes all compiler flags for all source files.
# -----------------------------------------------------------------------------
set-src-files-target-cflags = $(foreach __src,$1,$(eval MODULE_SRC_FILES_TARGET_CFLAGS.$(__src) := $2))

# -----------------------------------------------------------------------------
# Macro    : add-src-files-target-cflags
# Arguments: 1: list of source files
#            2: list of compiler flags
# Usage    : $(call add-src-files-target-cflags,<sources>,<flags>)
# Rationale: A variant of set-src-files-target-cflags that can be used
#            to append, instead of replace, compiler flags for specific
#            source files.
# -----------------------------------------------------------------------------
add-src-files-target-cflags = $(foreach __src,$1,$(eval MODULE_SRC_FILES_TARGET_CFLAGS.$(__src) += $2))

# -----------------------------------------------------------------------------
# Macro    : get-src-file-target-cflags
# Arguments: 1: single source file name
# Usage    : $(call get-src-file-target-cflags,<source>)
# Rationale: Return the set of target-specific compiler flags that must be
#            applied to a given source file. These must be set prior to this
#            call using set-src-files-target-cflags or add-src-files-target-cflags
# -----------------------------------------------------------------------------
get-src-file-target-cflags = $(MODULE_SRC_FILES_TARGET_CFLAGS.$1)

# -----------------------------------------------------------------------------
# Macro    : set-src-files-text
# Arguments: 1: list of source files
#            2: text
# Usage    : $(call set-src-files-text,<sources>,<text>)
# Rationale: Set or replace the 'text' associated to a set of source files.
#            The text is a very short string that complements the build
#            label. For example, it will be either 'thumb' or 'arm  ' for
#            ARM-based toolchains. This function must be called by the
#            toolchain-specific functions that processes all source files.
# -----------------------------------------------------------------------------
set-src-files-text = $(foreach __src,$1,$(eval MODULE_SRC_FILES_TEXT.$(__src) := $2))

# -----------------------------------------------------------------------------
# Macro    : get-src-file-text
# Arguments: 1: single source file
# Usage    : $(call get-src-file-text,<source>)
# Rationale: Return the 'text' associated to a given source file when
#            set-src-files-text was called.
# -----------------------------------------------------------------------------
get-src-file-text = $(MODULE_SRC_FILES_TEXT.$1)

# This should only be called for debugging the source files tagging system
dump-src-file-tags = \
$(info LOCAL_SRC_TAGS := $(LOCAL_SRC_TAGS)) \
$(info MODULE_SRC_FILES = $(MODULE_SRC_FILES)) \
$(foreach __tag,$(LOCAL_SRC_TAGS),$(info LOCAL_SRC_TAG.$(__tag) = $(LOCAL_SRC_TAG.$(__tag)))) \
$(foreach __src,$(MODULE_SRC_FILES),$(info MODULE_SRC_FILES_TAGS.$(__src) = $(MODULE_SRC_FILES_TAGS.$(__src)))) \
$(info WITH arm = $(call get-src-files-with-tag,arm)) \
$(info WITHOUT arm = $(call get-src-files-without-tag,arm)) \
$(foreach __src,$(MODULE_SRC_FILES),$(info MODULE_SRC_FILES_TARGET_CFLAGS.$(__src) = $(MODULE_SRC_FILES_TARGET_CFLAGS.$(__src)))) \
$(foreach __src,$(MODULE_SRC_FILES),$(info MODULE_SRC_FILES_TEXT.$(__src) = $(MODULE_SRC_FILES_TEXT.$(__src)))) \

# =============================================================================
#
# Generated files support
#
# =============================================================================

# -----------------------------------------------------------------------------
# Function  : static-library-path
# Arguments : 1: library module name (e.g. 'foo')
# Returns   : location of generated static library name (e.g. '..../libfoo.a)
# Usage     : $(call static-library-path,<modulename>)
# -----------------------------------------------------------------------------
static-library-path = $(TARGET_OUT_PATH)/lib$1.a

# -----------------------------------------------------------------------------
# Function  : shared-library-path
# Arguments : 1: library module name (e.g. 'foo')
# Returns   : location of generated shared library name (e.g. '..../libfoo.so)
# Usage     : $(call shared-library-path,<modulename>)
# -----------------------------------------------------------------------------
shared-library-path = $(TARGET_OUT_PATH)/lib$1.so

# =============================================================================
#
# Build commands support
#
# =============================================================================

# -----------------------------------------------------------------------------
# Macro    : hide
# Returns  : nothing
# Usage    : $(hide)<make commands>
# Rationale: To be used as a prefix for Make build commands to hide them
#            by default during the build. To show them, set V=1 in your
#            environment or command-line.
#
#            For example:
#
#                foo.o: foo.c
#                -->|$(hide) <build-commands>
#
#            Where '-->|' stands for a single tab character.
#
# -----------------------------------------------------------------------------
ifeq ($(V),1)
hide = $(empty)
else
hide = @
endif

# -----------------------------------------------------------------------------
# Template  : ev-compile-c-source
# Arguments : 1: single C source file name (relative to MODULE_PATH)
#             2: target object file (without path)
# Returns   : None
# Usage     : $(eval $(call ev-compile-c-source,<srcfile>,<objfile>)
# Rationale : Internal template evaluated by compile-c-source and
#             compile-s-source
# -----------------------------------------------------------------------------
define  ev-compile-c-source
_SRC:=$$(MODULE_PATH)/$(1)
_OBJ:=$$(LOCAL_OBJS_PATH)/$(2)

$$(_OBJ): PRIVATE_SRC      := $$(_SRC)
$$(_OBJ): PRIVATE_OBJ      := $$(_OBJ)
$$(_OBJ): PRIVATE_MODULE   := $$(MODULE_NAME)
$$(_OBJ): PRIVATE_ARM_MODE := $$(MODULE_ARM_MODE)
$$(_OBJ): PRIVATE_ARM_TEXT := $$(call get-src-file-text,$1)
$$(_OBJ): PRIVATE_CC       := $$(TARGET_CC)
$$(_OBJ): PRIVATE_CFLAGS   := $$(TARGET_CFLAGS) \
                              $$(TARGET_ITOA_CFLAGS) \
                              $$(call get-src-file-target-cflags,$(1)) \
                              $$(MODULE_C_INCLUDES:%=-I%) \
                              -I$$(MODULE_PATH) \
                              $$(MODULE_CFLAGS) \
                              $$(APP_OPTIM_CFLAGS)

$$(_OBJ): $$(_SRC) $$(MODULE_MAKEFILES) $$(NDK_APP_MK)
	@mkdir -p $$(dir $$(PRIVATE_OBJ))
	@echo "Compile $$(PRIVATE_ARM_TEXT)  : $$(PRIVATE_MODULE) <= $$(PRIVATE_SRC)"
	$(hide) $$(PRIVATE_CC) $$(PRIVATE_CFLAGS) -c \
	-MMD -MP -MF $$(PRIVATE_OBJ).d \
	$$(PRIVATE_SRC) \
	-o $$(PRIVATE_OBJ)

LOCAL_OBJECTS         += $$(_OBJ)
LOCAL_DEPENDENCY_PATHS += $$(dir $$(_OBJ))
endef

# -----------------------------------------------------------------------------
# Function  : compile-c-source
# Arguments : 1: single C source file name (relative to MODULE_PATH)
# Returns   : None
# Usage     : $(call compile-c-source,<srcfile>)
# Rationale : Setup everything required to build a single C source file
# -----------------------------------------------------------------------------
compile-c-source = $(eval $(call ev-compile-c-source,$1,$(1:%.c=%.o)))

# -----------------------------------------------------------------------------
# Function  : compile-s-source
# Arguments : 1: single Assembly source file name (relative to MODULE_PATH)
# Returns   : None
# Usage     : $(call compile-s-source,<srcfile>)
# Rationale : Setup everything required to build a single Assembly source file
# -----------------------------------------------------------------------------
compile-s-source = $(eval $(call ev-compile-c-source,$1,$(1:%.S=%.o)))


# -----------------------------------------------------------------------------
# Template  : ev-compile-m-source
# Arguments : 1: single ObjC source file name (relative to MODULE_PATH)
#             2: target object file (without path)
# Returns   : None
# Usage     : $(eval $(call ev-compile-m-source,<srcfile>,<objfile>)
# Rationale : Internal template evaluated by compile-m-source
# -----------------------------------------------------------------------------
define  ev-compile-m-source
_SRC:=$$(MODULE_PATH)/$(1)
_OBJ:=$$(LOCAL_OBJS_PATH)/$(2)

$$(_OBJ): PRIVATE_SRC      := $$(_SRC)
$$(_OBJ): PRIVATE_OBJ      := $$(_OBJ)
$$(_OBJ): PRIVATE_MODULE   := $$(MODULE_NAME)
$$(_OBJ): PRIVATE_ARM_MODE := $$(MODULE_ARM_MODE)
$$(_OBJ): PRIVATE_ARM_TEXT := $$(call get-src-file-text,$1)
$$(_OBJ): PRIVATE_CC       := $$(TARGET_CC)
$$(_OBJ): PRIVATE_CFLAGS   := $$(TARGET_CFLAGS) \
                              $$(TARGET_ITOA_OBJCFLAGS) \
                              $$(call get-src-file-target-cflags,$(1)) \
                              $$(MODULE_C_INCLUDES:%=-I%) \
                              -I$$(MODULE_PATH) \
                              $$(MODULE_CFLAGS) \
                              $$(MODULE_OBJCFLAGS) \
                              $$(APP_OPTIM_CFLAGS)

$$(_OBJ): $$(_SRC) $$(MODULE_MAKEFILES) $$(NDK_APP_MK)
	@mkdir -p $$(dir $$(PRIVATE_OBJ))
	@echo "Compile $$(PRIVATE_ARM_TEXT)  : $$(PRIVATE_MODULE) <= $$(PRIVATE_SRC)"
	$(hide) $$(PRIVATE_CC) $$(PRIVATE_CFLAGS) -c \
	-MMD -MP -MF $$(PRIVATE_OBJ).d \
	$$(PRIVATE_SRC) \
	-o $$(PRIVATE_OBJ)

LOCAL_OBJECTS         += $$(_OBJ)
LOCAL_DEPENDENCY_PATHS += $$(dir $$(_OBJ))
endef

# -----------------------------------------------------------------------------
# Function  : compile-m-source
# Arguments : 1: single ObjC source file name (relative to MODULE_PATH)
# Returns   : None
# Usage     : $(call compile-m-source,<srcfile>)
# Rationale : Setup everything required to build a single ObjC source file
# -----------------------------------------------------------------------------
compile-m-source = $(eval $(call ev-compile-m-source,$1,$(1:%.m=%.o)))


# -----------------------------------------------------------------------------
# Template  : ev-compile-cpp-source
# Arguments : 1: single C++ source file name (relative to MODULE_PATH)
#             2: target object file (without path)
# Returns   : None
# Usage     : $(eval $(call ev-compile-cpp-source,<srcfile>,<objfile>)
# Rationale : Internal template evaluated by compile-cpp-source
# -----------------------------------------------------------------------------

define  ev-compile-cpp-source
_SRC:=$$(MODULE_PATH)/$(1)
_OBJ:=$$(LOCAL_OBJS_PATH)/$(2)

$$(_OBJ): PRIVATE_SRC      := $$(_SRC)
$$(_OBJ): PRIVATE_OBJ      := $$(_OBJ)
$$(_OBJ): PRIVATE_MODULE   := $$(MODULE_NAME)
$$(_OBJ): PRIVATE_ARM_MODE := $$(MODULE_ARM_MODE)
$$(_OBJ): PRIVATE_ARM_TEXT := $$(call get-src-file-text,$1)
$$(_OBJ): PRIVATE_CXX      := $$(TARGET_CXX)
$$(_OBJ): PRIVATE_CXXFLAGS := $$(TARGET_CXXFLAGS) \
                              $$(TARGET_ITOA_CPPFLAGS) \
                              $$(call get-src-file-target-cflags,$(1)) \
                              $$(MODULE_C_INCLUDES:%=-I%) \
                              -I$$(MODULE_PATH) \
                              $$(MODULE_CFLAGS) \
                              $$(MODULE_CPPFLAGS) \
                              $$(APP_OPTIM_CFLAGS)

$$(_OBJ): $$(_SRC) $$(MODULE_MAKEFILES) $$(NDK_APP_MK)
	@mkdir -p $$(dir $$(PRIVATE_OBJ))
	@echo "Compile++ $$(PRIVATE_ARM_TEXT): $$(PRIVATE_MODULE) <= $$(PRIVATE_SRC)"
	$(hide) $$(PRIVATE_CXX) $$(PRIVATE_CXXFLAGS) -c \
	-MMD -MP -MF $$(PRIVATE_OBJ).d \
	$$(PRIVATE_SRC) \
	-o $$(PRIVATE_OBJ)

LOCAL_OBJECTS         += $$(_OBJ)
LOCAL_DEPENDENCY_PATHS += $$(dir $$(_OBJ))
endef

# -----------------------------------------------------------------------------
# Function  : compile-mm-source
# Arguments : 1: single ObjC++ source file name (relative to MODULE_PATH)
# Returns   : None
# Usage     : $(call compile-mm-source,<srcfile>)
# Rationale : Setup everything required to build a single ObjC++ source file
# -----------------------------------------------------------------------------
compile-mm-source = $(eval $(call ev-compile-mm-source,$1,$(1:%.mm=%.o)))


# -----------------------------------------------------------------------------
# Template  : ev-compile-mm-source
# Arguments : 1: single ObjC++ source file name (relative to MODULE_PATH)
#             2: target object file (without path)
# Returns   : None
# Usage     : $(eval $(call ev-compile-mm-source,<srcfile>,<objfile>)
# Rationale : Internal template evaluated by compile-mm-source
# -----------------------------------------------------------------------------

define  ev-compile-mm-source
_SRC:=$$(MODULE_PATH)/$(1)
_OBJ:=$$(LOCAL_OBJS_PATH)/$(2)

$$(_OBJ): PRIVATE_SRC      := $$(_SRC)
$$(_OBJ): PRIVATE_OBJ      := $$(_OBJ)
$$(_OBJ): PRIVATE_MODULE   := $$(MODULE_NAME)
$$(_OBJ): PRIVATE_ARM_MODE := $$(MODULE_ARM_MODE)
$$(_OBJ): PRIVATE_ARM_TEXT := $$(call get-src-file-text,$1)
$$(_OBJ): PRIVATE_CXX      := $$(TARGET_CXX)
$$(_OBJ): PRIVATE_CXXFLAGS := $$(TARGET_CXXFLAGS) \
                              $$(TARGET_ITOA_OBJCPPFLAGS) \
                              $$(call get-src-file-target-cflags,$(1)) \
                              $$(MODULE_C_INCLUDES:%=-I%) \
                              -I$$(MODULE_PATH) \
                              $$(MODULE_CFLAGS) \
                              $$(MODULE_CPPFLAGS) \
                              $$(MODULE_OBJCFLAGS) \
                              $$(MODULE_OBJCPPFLAGS) \
                              $$(APP_OPTIM_CFLAGS)


$$(_OBJ): $$(_SRC) $$(MODULE_MAKEFILES) $$(NDK_APP_MK)
	@mkdir -p $$(dir $$(PRIVATE_OBJ))
	@echo "Compile++ $$(PRIVATE_ARM_TEXT): $$(PRIVATE_MODULE) <= $$(PRIVATE_SRC)"
	$(hide) $$(PRIVATE_CXX) $$(PRIVATE_CXXFLAGS) -c \
	-MMD -MP -MF $$(PRIVATE_OBJ).d \
	$$(PRIVATE_SRC) \
	-o $$(PRIVATE_OBJ)

LOCAL_OBJECTS         += $$(_OBJ)
LOCAL_DEPENDENCY_PATHS += $$(dir $$(_OBJ))
endef

# -----------------------------------------------------------------------------
# Function  : compile-cpp-source
# Arguments : 1: single C++ source file name (relative to MODULE_PATH)
# Returns   : None
# Usage     : $(call compile-c-source,<srcfile>)
# Rationale : Setup everything required to build a single C++ source file
# -----------------------------------------------------------------------------
compile-cpp-source = $(eval $(call ev-compile-cpp-source,$1,$(1:%$(MODULE_CPP_EXTENSION)=%.o)))

# =============================================================================
#
# ABI-dependant variables
#
# =============================================================================

# -----------------------------------------------------------------------------
# Adds abi-dependant variable.
#   $1 = abi
#   $2 = variable name
#   $3 = variable value
# -----------------------------------------------------------------------------
add-abi-var = $(eval ABI_VARS.$1.$2 := $3)

# -----------------------------------------------------------------------------
# Gets abi-dependant variable.
#   $1 = abi
#   $2 = variable name
# -----------------------------------------------------------------------------
get-abi-var = $(ABI_VARS.$1.$2)

# -----------------------------------------------------------------------------
# Adds abi-dependant variable to the current abi.
#   #1 = variable name
# -----------------------------------------------------------------------------
set-current-abi-var = $(call add-abi-var,$(TARGET_ABI),$1,$($1))

# -----------------------------------------------------------------------------
# Gets abi-dependant variable from the current abi.
#   $1 = variable name
# -----------------------------------------------------------------------------
get-current-abi-var = $(call get-abi-var,$(TARGET_ABI),$1)

