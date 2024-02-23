#!/usr/bin/env bash

#debug
set -e #如果命令执行失败，则立即退出 Shell。
set -u #如果使用未定义的变量，则显示错误信息并退出 Shell。
set -x #显示每个命令执行的详细信息。
#set -v #显示 Shell 中每个命令执行之前的参数和输入。

if [ $EUID -ne 0 ]; then
    echo "$(basename $0) must be run as root"
    exit 1
fi

# source ${PWD}/manifest
source local_package_builder_env.bash

if [ -z "${SYSTEM_NAME}" ]; then
    echo "SYSTEM_NAME must be specified"
    exit
fi

if [ -z "${VERSION}" ]; then
    echo "VERSION must be specified"
    exit
fi

DISPLAY_VERSION=${VERSION}
LSB_VERSION=${VERSION}
VERSION_NUMBER=${VERSION}

BUILD_ID="local-test"

MOUNT_PATH="/tmp/${SYSTEM_NAME}-build"
BUILD_PATH="${MOUNT_PATH}/subvolume"
BUILD_PATH_SNAPSHOT="${BUILD_PATH}-snapshot"
SNAP_PATH="${MOUNT_PATH}/${SYSTEM_NAME}-${VERSION}"
BUILD_IMG="${PWD}/output/${SYSTEM_NAME}-build.img"

# AUR_PKG_DEPS_PATH="/aur_dep_pkgs"
PAC_PKG_DB_FILE="/pac_pkg_db_list"
AUR_PKG_DEPS_FILE="/aur_deps_list"

function create_snap() {
    # copy files into chroot again
    cp -R rootfs/. ${BUILD_PATH}/
    rm -rf ${BUILD_PATH}/extra_certs

    echo "${SYSTEM_NAME}-${VERSION}" >${BUILD_PATH}/build_info
    echo "" >>${BUILD_PATH}/build_info
    cat ${BUILD_PATH}/manifest >>${BUILD_PATH}/build_info
    rm ${BUILD_PATH}/manifest

    # freeze archive date of build to avoid package drift on unlock
    # if no archive date is set
    if [ -z "${ARCHIVE_DATE}" ]; then
        export TODAY_DATE=$(date +%Y/%m/%d)
        echo "Server=https://archive.archlinux.org/repos/${TODAY_DATE}/\$repo/os/\$arch" > \
            ${BUILD_PATH}/etc/pacman.d/mirrorlist
    fi

    btrfs subvolume snapshot -r ${BUILD_PATH} ${SNAP_PATH}
    btrfs send -f ${SYSTEM_NAME}-${VERSION}.img ${SNAP_PATH}

    cp ${BUILD_PATH}/build_info build_info.txt

    # clean up
    # umount -l ${BUILD_PATH}
    # umount -l ${MOUNT_PATH}
    # rm -rf ${MOUNT_PATH}
    # rm -rf ${BUILD_IMG}
}


create_snap