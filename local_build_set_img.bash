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

# chroot into target
# mount --bind "${BUILD_PATH}" "${BUILD_PATH}"
arch-chroot "${BUILD_PATH}" /bin/bash << \
EOF
    set -e
    set -x

    source /manifest

    pacman-key --populate

    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    locale-gen

    # Disable parallel downloads
    sed -i '/ParallelDownloads/s/^/#/g' /etc/pacman.conf

    # Cannot check space in chroot
    sed -i '/CheckSpace/s/^/#/g' /etc/pacman.conf

    # update package databases
    pacman --noconfirm -Syy

    # install kernel package first to avoid dkms problem
    pacman --noconfirm -U --overwrite '*' /own_pkgs/${KERNEL_PACKAGE}-*.pkg.tar.zst 

    # install packages
    pacman --noconfirm -S --overwrite '*' --disable-download-timeout ${PACKAGES}
    rm -rf /var/cache/pacman/pkg

    # install AUR packages
    pacman --noconfirm -U --overwrite '*' /extra_pkgs/*

    # install own override packages
    pacman --noconfirm -U --overwrite '*' /own_pkgs/*

    # enable services
    systemctl enable ${SERVICES}

    # enable user services
    systemctl --global enable ${USER_SERVICES}

    # disable root login
    #passwd --lock root

    # create user
    groupadd -r autologin
    useradd -m ${USERNAME} -G autologin,wheel
    echo "${USERNAME}:${USERNAME}" | chpasswd

    # set the default editor, so visudo works
    echo "export EDITOR=nano" >> /etc/bash.bashrc

    # echo "[Seat:*]
    # autologin-user=${USERNAME}
    # " > /etc/lightdm/lightdm.conf.d/00-autologin-user.conf
    mkdir -p /etc/sddm.conf.d
    echo "
[Autologin]
User=${USERNAME}
Session=plasma
" > /etc/sddm.conf.d/00-autologin-user.conf

    echo "${SYSTEM_NAME}" > /etc/hostname

    # enable multicast dns in avahi
    sed -i "/^hosts:/ s/resolve/mdns resolve/" /etc/nsswitch.conf

    # configure ssh
    # Enable PasswordAuthentication for testing
    echo "
AuthorizedKeysFile	.ssh/authorized_keys
PasswordAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
PrintMotd no # pam does that
Subsystem	sftp	/usr/lib/ssh/sftp-server
" > /etc/ssh/sshd_config

    echo "
LABEL=frzr_root /          btrfs subvol=deployments/${SYSTEM_NAME}-${VERSION},ro,noatime,nodatacow 0 0
LABEL=frzr_root /var       btrfs subvol=var,rw,noatime,nodatacow 0 0
LABEL=frzr_root /home      btrfs subvol=home,rw,noatime,nodatacow 0 0
LABEL=frzr_root /frzr_root btrfs subvol=/,rw,noatime,nodatacow 0 0
LABEL=frzr_efi  /boot      vfat  rw,noatime,nofail  0 0
" > /etc/fstab

    echo "
LSB_VERSION=1.4
DISTRIB_ID=${SYSTEM_NAME}
DISTRIB_RELEASE=\"${LSB_VERSION}\"
DISTRIB_DESCRIPTION=${SYSTEM_DESC}
" > /etc/lsb-release

    echo '
NAME="${SYSTEM_DESC}"
VERSION="${DISPLAY_VERSION}"
VERSION_ID="${VERSION_NUMBER}"
BUILD_ID="${BUILD_ID}"
PRETTY_NAME="${SYSTEM_DESC} ${DISPLAY_VERSION}"
ID=${SYSTEM_NAME}
ID_LIKE=arch
ANSI_COLOR="1;31"
HOME_URL="${WEBSITE}"
DOCUMENTATION_URL="${DOCUMENTATION_URL}"
BUG_REPORT_URL="${BUG_REPORT_URL}"
' > /etc/os-release

    # install extra certificates
    trust anchor --store /extra_certs/*.crt

    # run post install hook
    postinstallhook

    # record installed packages & versions
    pacman -Q > /manifest

    # preserve installed package database
    mkdir -p /usr/var/lib/pacman
    cp -r /var/lib/pacman/local /usr/var/lib/pacman/

    # move kernel image and initrd to a defualt location if "linux" is not used
    if [ ${KERNEL_PACKAGE} != 'linux' ] ; then
        mv /boot/vmlinuz-${KERNEL_PACKAGE} /boot/vmlinuz-linux
        mv /boot/initramfs-${KERNEL_PACKAGE}.img /boot/initramfs-linux.img
        mv /boot/initramfs-${KERNEL_PACKAGE}-fallback.img /boot/initramfs-linux-fallback.img
    fi

    # clean up/remove unnecessary files
    rm -rf \
    /own_pkgs \
    /extra_pkgs \
    /extra_certs \
    /home \
    /var \

    rm -rf ${FILES_TO_DELETE}

    # create necessary directories
    mkdir /home
    mkdir /var
    mkdir /frzr_root
EOF
