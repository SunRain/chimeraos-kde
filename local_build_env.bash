#!/usr/bin/env bash

export VERSION="46"
export SYSTEM_DESC="ChimeraOS"
export SYSTEM_NAME="chimeraos"
export USERNAME="gamer"
export SIZE="10000MB"
export ARCHIVE_DATE=$(date -d 'yesterday' +%Y/%m/%d)
export WEBSITE="https://chimeraos.org"
export DOCUMENTATION_URL="https://chimeraos.org/about"
export BUG_REPORT_URL="https://github.com/ChimeraOS/chimeraos/issues"

export KERNEL_PACKAGE="linux-chimeraos"
export KERNEL_PACKAGE_ORIGIN="local"

export DISPLAY_VERSION=${VERSION}
export LSB_VERSION=${VERSION}
export VERSION_NUMBER=${VERSION}

export MOUNT_PATH="/tmp/${SYSTEM_NAME}-build"
export BUILD_PATH="${MOUNT_PATH}/subvolume"
export SNAP_PATH="${MOUNT_PATH}/${SYSTEM_NAME}-${VERSION}"
export BUILD_IMG="${PWD}/output/${SYSTEM_NAME}-build.img"
export BUILD_PATH_SNAPSHOT="${BUILD_PATH}-snapshot"