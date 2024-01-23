#!/usr/bin/env bash

#debug
#set -e #如果命令执行失败，则立即退出 Shell。
set -u #如果使用未定义的变量，则显示错误信息并退出 Shell。
set -x #显示每个命令执行的详细信息。
#set -v #显示 Shell 中每个命令执行之前的参数和输入。

if [ $EUID -ne 0 ]; then
    echo "$(basename $0) must be run as root"
    exit 1
fi

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

# source ${PWD}/tst_build_env.bash

# cp -f ${PWD}/tst_build_env.bash ${BUILD_PATH}/tst_build_env.bash

# function build_pkgs() {
#     local pkg_path=$1
#     local chroot_path=$2

#     while IFS= read -r pkg; do
#         echo "--------------------build $pkg"
#         arch-chroot "${BUILD_PATH}" /bin/bash << \
#             EOF
#         set -e
#         set -x

# #echo "linux-api-headers<4.10" | awk -F '>|<|=' '{print $1}'
# #expac -Q "%o" gamescope-session-steam-git
# #pacman -Rnc
#         source /tst_build_env.bash

#         cd ${chroot_path}/${pkg};
#         # If dependency package in aur, and building failure, using paru to install dependency, then building again
#         # makepkg , add -f -c option?
#         su builder -c "while true; do \
#                             if makepkg --noconfirm -s -i -c -r -f; then \
#                                 break; \
#                             else \
#                                 while true; do \
#                                     paru -S --noconfirm ${pkg}; \
#                                     if makepkg --noconfirm -s -i -c -r -f; then \
#                                         break; \
#                                     fi; \

#                                 done;    
#                             fi; \
#                         done"
#         generate_deps "${pkg}"
#         pacman -Rsc "${pkg}"
#         #Reinstall base base-devel to avoid pacman -Rsc mistake
#         pacman -S --noconfirm base base-devel
# EOF
#     done < <(find "${pkg_path}" -maxdepth 1 -mindepth 1 -type d -printf '%f\n')
# }

# build_pkgs "${BUILD_PATH}"/extra_pkgs /extra_pkgs


# while IFS= read -r pkg; do
#     if echo "${AUR_PACKAGES}" | grep -e "^${pkg}\$"; then
#         echo "AUR package [${pkg}] already built"
#     else
#         builder_download_aur_pkg "${BUILD_PATH}/${AUR_PKG_DEPS_PATH}" "${pkg}"
#     fi
# done <"${BUILD_PATH}/${AUR_PKG_DEPS_LIST}"

download_aur_pkgs /aur_pkgs "${AUR_PACKAGES}"

# aur_deps_list=""
# while IFS= read -r pkg; do
#     if ! echo "${AUR_PACKAGES}" | grep -e "^${pkg}\$" &&  ! echo "${aur_deps_list}" | grep  "${pkg}"; then
#         aur_deps_list="$pkg ${aur_deps_list}"
#     fi
# done <"${BUILD_PATH}/${AUR_PKG_DEPS_LIST}"

# arch-chroot ${BUILD_PATH} /bin/bash << \
#     EOF
#     set -e
#     set -x

#     source /tst_build_env.bash

#     cd ${AUR_PKG_DEPS_PATH}
#     while true; do
#         if paru --clonedir ${AUR_PKG_DEPS_PATH} -G  ${aur_deps_list}; then
#             break;
#         fi;
#     done

#     # Set permission for chroot builder 
#     chown -hR builder:builder ${AUR_PKG_DEPS_PATH}
#     chmod -R 755 ${AUR_PKG_DEPS_PATH}

# EOF
 
#  build_pkgs ${BUILD_PATH}/"${AUR_PKG_DEPS_PATH}"  "${AUR_PKG_DEPS_PATH}"

# mkdir -p "${MOUNT_PATH}"/aur_pkgs
# #find ${BUILD_PATH}/extra_pkgs  -type f -iname '*.pkg.tar*' | xargs -i sudo cp {} ${MOUNT_PATH}/aur_pkgs/
# #find "${BUILD_PATH}"/extra_pkgs  -type f -iname '*.pkg.tar*' -print0 | xargs -0 -i  cp {} ${MOUNT_PATH}/aur_pkgs/
# ## FIXME This is the best style for find && xargs usage?
# find "${BUILD_PATH}"/extra_pkgs -type f -iname '*.pkg.tar*' -print0 | xargs -0 -I {} cp {} "${MOUNT_PATH}"/aur_pkgs/
# find "${BUILD_PATH}/${AUR_PKG_DEPS_PATH}" -type f -iname '*.pkg.tar*' -print0 | xargs -0 -I {} cp {} "${MOUNT_PATH}"/aur_pkgs/

# build_pkgs "${BUILD_PATH}/own_pkgs" /own_pkgs

# mkdir -p "${MOUNT_PATH}"/own_pkgs
# find "${BUILD_PATH}"/own_pkgs -type f -iname '*.pkg.tar*' -print0 | xargs -0 -I {} cp {} "${MOUNT_PATH}"/own_pkgs/



