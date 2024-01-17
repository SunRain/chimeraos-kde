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

source ${PWD}/manifest

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

# if [ -n "$1" ]; then
#     DISPLAY_VERSION="${VERSION} (${1})"
#     VERSION="${VERSION}_${1}"
#     LSB_VERSION="${LSB_VERSION}　(${1})"
#     BUILD_ID="${1}"
# fi

MOUNT_PATH="/tmp/${SYSTEM_NAME}-build"
BUILD_PATH="${MOUNT_PATH}/subvolume"
BUILD_PATH_BASE="${BUILD_PATH}-base"
SNAP_PATH="${MOUNT_PATH}/${SYSTEM_NAME}-${VERSION}"
BUILD_IMG="${PWD}/output/${SYSTEM_NAME}-build.img"

function initialize_fs() {

    mkdir -p ${MOUNT_PATH}

    fallocate -l ${SIZE} ${BUILD_IMG}
    mkfs.btrfs -f ${BUILD_IMG}
    mount -t btrfs -o loop,nodatacow ${BUILD_IMG} ${MOUNT_PATH}
    btrfs subvolume create ${BUILD_PATH}

    # copy the makepkg.conf into chroot
    #cp /etc/makepkg.conf rootfs/etc/makepkg.conf

    # bootstrap using our configuration
    pacstrap -K -M -C rootfs/etc/pacman.conf ${BUILD_PATH}

    # copy the builder mirror list into chroot
    #mkdir -p rootfs/etc/pacman.d
    #cp /etc/pacman.d/mirrorlist rootfs/etc/pacman.d/mirrorlist

    # copy files into chroot
    cp -R manifest rootfs/. ${BUILD_PATH}/
}

function initialize_paru() {

    arch-chroot ${BUILD_PATH} /bin/bash << \
        EOF
        set -e
        set -x

        source /manifest

        pacman-key --populate

        echo "LANG=en_US.UTF-8" > /etc/locale.conf
        locale-gen

        # Add archlinuxCN repo to download paru
        if ! grep 'repo.archlinuxcn.org/\$arch' /etc/pacman.conf ; then
            echo '
        [archlinuxcn]
        SigLevel = Never
        Server = https://repo.archlinuxcn.org/\$arch

        ' >> /etc/pacman.conf
        fi

        # update package databases
        pacman --noconfirm -Syy

        pacman -S --noconfirm archlinuxcn-keyring paru base-devel

        # # install devtools to build aur pkgs in chroot
        # pacman -S --noconfirm devtools

EOF
}

#initialize_fs

# Create snapshot as base image, ${BUILD_PATH} will using as aur pkg build host
#btrfs subvolume snapshot ${BUILD_PATH} ${BUILD_PATH}-base

# Fix arch-chroot error
# mount --bind ${BUILD_PATH} ${BUILD_PATH}

# initialize_paru

arch-chroot ${BUILD_PATH} /bin/bash << \
    EOF
    set -e
    set -x

    source /manifest

    # sudo permissions without password
	# sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^# //g' /etc/sudoers
    # sed -i '/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/s/^# //g' /etc/sudoers

    # groupadd builder
    # useradd -g builder -s /bin/bash builder
    # echo "builder:builder" | chpasswd
    # usermod -aG wheel builder
    mkdir -p /home/builder
    chown builder:builder /home/builder
    chmod 775 /home/builder

    # mkdir /own_pkgs
    # mkdir /extra_pkgs

    # chown -hR builder:builder /extra_pkgs
    # chmod -R 755 /extra_pkgs
    
    # chown -hR builder:builder /own_pkgs
    # chmod -R 755 /own_pkgs

    # cd /extra_pkgs 
    # paru --clonedir /extra_pkgs -G  ${AUR_PACKAGES}

#     su -l builder -c "paru --clonedir /extra_pkgs -G  ${AUR_PACKAGES}"

#         su test -s "echo $(whoami)"

EOF

# for pkg in "${BUILD_PATH}"/extra_pkgs/*/; do
#     pkg=${pkg%*/} # remove the trailing "/"
#     echo $pkg
# done

# for pkg in $(find "${BUILD_PATH}"/extra_pkgs -maxdepth 1 -mindepth 1 -type d -printf '%f\n'); do

#     arch-chroot ${BUILD_PATH} /bin/bash << \
# EOF
#         set -e
#         set -x

#         source /manifest

#         echo "---- data pkg is $pkg"

# EOF

# done

#find "${BUILD_PATH}"/extra_pkgs -maxdepth 1 -mindepth 1 -type d -print0
while IFS= read -r pkg; do
    echo "$pkg"
    arch-chroot ${BUILD_PATH} /bin/bash << \
        EOF
        set -e
        set -x

        source /manifest

        echo "---- data pkg is $pkg"
        cd /extra_pkgs/${pkg};
        # Building and installing aur package to fix building dependency problem
        # If dependency package in aur, and building failure, using paru to install dependency, then building again
        su builder -c "while true; do \
                            if makepkg --noconfirm -s -i -f; then \
                                break; \
                            else \
                                while true; do \
                                    paru -S --noconfirm ${pkg}; \
                                    if makepkg --noconfirm -s -i -f; then \
                                        break; \
                                    fi; \
                                done;    
                            fi; \
                        done"
EOF
done < <(find "${BUILD_PATH}"/extra_pkgs -maxdepth 1 -mindepth 1 -type d -printf '%f\n')
