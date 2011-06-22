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

# Script to detect and normalize various host properties.
#
# Currently detected:
#   HOST_ARCH
#   HOST_EXE
#   HOST_OS
#   HOST_TAG
#   HOST_NUM_CPUS
#   BUILD_NUM_CPUS

# =========================================================
# Detect HOST_ARCH
#
# Supported values:
#   x86
#   x86_64
#   ppc

HOST_ARCH=`uname -m`
case "$HOST_ARCH" in
    i?86) HOST_ARCH=x86
    ;;
    amd64) HOST_ARCH=x86_64
    ;;
    powerpc) HOST_ARCH=ppc
    ;;
esac

# =========================================================
# Detect HOST_OS and HOST_EXE
#
# Supported values:
#   linux
#   darwin
#   windows (MSys)
#   cygwin

HOST_EXE=""
HOST_OS=`uname -s`
case "$HOST_OS" in
    Darwin)
        HOST_OS=darwin
        ;;
    Linux)
        # note that building  32-bit binaries on x86_64 is handled later
        HOST_OS=linux
        ;;
    FreeBsd)  # note: this is not tested
        HOST_OS=freebsd
        ;;
    CYGWIN*|*_NT-*)
        HOST_OS=windows
        HOST_EXE=.exe
        if [ "x$OSTYPE" = xcygwin ] ; then
            HOST_OS=cygwin
        fi
        ;;
esac

# =========================================================
# Compute HOST_TAG.
#
# Possible combinations:
#   linux-x86
#   linux-x86_64
#   darwin-x86
#   darwin-ppc
#   windows

case "$HOST_OS" in
    windows|cygwin)
        HOST_TAG="windows"
        ;;
    *)  HOST_TAG="${HOST_OS}-${HOST_ARCH}"
esac

# =========================================================
# Detect HOST_NUM_CPUS, compute HOST_BUILD_NUM_CPUS.
#
# HOST_BUILD_NUM_CPUS equals to BUILD_NUM_CPUS if it is defined.

case "$HOST_OS" in
    linux)
        HOST_NUM_CPUS=`cat /proc/cpuinfo | grep processor | wc -l`
        ;;
    darwin|freebsd)
        HOST_NUM_CPUS=`sysctl -n hw.ncpu`
        ;;
    windows|cygwin)
        HOST_NUM_CPUS=$NUMBER_OF_PROCESSORS
        ;;
    *)  # let's play safe here
        HOST_NUM_CPUS=1
esac

if [ -z "$BUILD_NUM_CPUS" ] ; then
    HOST_BUILD_NUM_CPUS=`expr $HOST_NUM_CPUS \* 2`
else
    HOST_BUILD_NUM_CPUS=$BUILD_NUM_CPUS
fi

