#!/usr/bin/env bash

source manifest

DISPLAY_VERSION=${VERSION}
LSB_VERSION=${VERSION}
VERSION_NUMBER=${VERSION}

BUILD_ID="local-test"

# if [ -n "$1" ]; then
#     DISPLAY_VERSION="${VERSION} (${1})"
#     VERSION="${VERSION}_${1}"
#     LSB_VERSION="${LSB_VERSION}　(${1})"
#     BUILD_ID="${1}"
# fi

MOUNT_PATH="/tmp/${SYSTEM_NAME}-build"
BUILD_PATH="${MOUNT_PATH}/subvolume"
BUILD_PATH_SNAPSHOT="${BUILD_PATH}-snapshot"
SNAP_PATH="${MOUNT_PATH}/${SYSTEM_NAME}-${VERSION}"
BUILD_IMG="${PWD}/output/${SYSTEM_NAME}-build.img"

export AUR_PKG_DEPS_LIST="/aur_deps_list"
# AUR_PKG_DEPS_PATH="/aur_dep_pkgs"
export AUR_PKG_DEPS_PATH="/tpg"
export PAC_PKG_DB="/pac_pkg_db_list"

# export pkg="gamescope-session-steam-plus-git"
# export deps=""

function generate_deps() {
    local tmp_pkg=$1
    local tmp_deps="dummy"
    echo "tmp_pkg >>>>>>> ${tmp_pkg}"
    expac -Q '%E' "${tmp_pkg}"
    tmp_deps=$(expac -Q '%E' "${tmp_pkg}")
    echo "tmp_deps >>> ${tmp_deps}"
    for i in $tmp_deps; do
        echo "check dep > $i"
        # deps=$(echo $deps | awk '{for (i=2;i<=NF;i++) {print $i}}')
        # echo "now deps $deps"
        if grep -e "^${i}\$" ${PAC_PKG_DB}; then
            echo "Package find in ${PAC_PKG_DB}"
        else
            if LC_ALL=c pacman -Qi "${i}" | grep "Provides" | grep "${i}"; then
                echo "Package ${i} is a virtual package"
            else
                if grep -e "^${i}\$" "${AUR_PKG_DEPS_LIST}"; then
                    echo "Package ${i} allready added"
                else
                    # AUR_PKG_DEPS_LIST="$i ${AUR_PKG_DEPS_LIST}"
                    echo -e "${i}" >> ${AUR_PKG_DEPS_LIST}
                    # echo -e "${i} $(cat ${AUR_PKG_DEPS_LIST})" > ${AUR_PKG_DEPS_LIST}
                    echo "now dep list $(cat ${AUR_PKG_DEPS_LIST})"
                    generate_deps "$i"
                fi
            fi
        fi
    done
}
