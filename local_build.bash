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

# AUR_PKG_DEPS_PATH="/aur_dep_pkgs"
PAC_PKG_DB_FILE="/pac_pkg_db_list"
AUR_PKG_DEPS_FILE="/aur_deps_list"

function initialize_fs() {

    mkdir -p "${MOUNT_PATH}"

    fallocate -l "${SIZE}" "${BUILD_IMG}"
    mkfs.btrfs -f "${BUILD_IMG}"
    mount -t btrfs -o loop,nodatacow "${BUILD_IMG}" "${MOUNT_PATH}"
    btrfs subvolume create "${BUILD_PATH}"

    # copy the makepkg.conf into chroot
    #cp /etc/makepkg.conf rootfs/etc/makepkg.conf

    # bootstrap using our configuration
    pacstrap -K -M -C rootfs/etc/pacman.conf "${BUILD_PATH}"

    # copy the builder mirror list into chroot
    #mkdir -p rootfs/etc/pacman.d
    #cp /etc/pacman.d/mirrorlist rootfs/etc/pacman.d/mirrorlist

    # copy files into chroot
    cp -R manifest rootfs/. "${BUILD_PATH}"/
}

# initialize_fs

# ## Create snapshot as base image, ${BUILD_PATH} will using as aur pkg build host
# btrfs subvolume snapshot -r "${BUILD_PATH}" "${BUILD_PATH_SNAPSHOT}"

# ## Fix arch-chroot error
# mount --bind "${BUILD_PATH}" "${BUILD_PATH}"

# initialize_buildbot ${PAC_PKG_DB_FILE}

# ## Create local-building dir and get related PKGBUILD files
# mkdir -p "${BUILD_PATH}/extra_pkgs"
# mkdir -p "${BUILD_PATH}/own_pkgs"
# mkdir -p "${BUILD_PATH}/aur_dep_pkgs"
# mkdir -p "${MOUNT_PATH}/own_pkgs"
# mkdir -p "${MOUNT_PATH}/aur_pkgs"

# cp -r "${PWD}"/pkgs/* "${BUILD_PATH}"/own_pkgs/

# ## Set permission for chroot builder
# arch-chroot "${BUILD_PATH}" /bin/bash << \
#     EOF
#     chown -hR builder:builder /extra_pkgs
#     chmod -R 755 /extra_pkgs
#     chown -hR builder:builder /own_pkgs
#     chmod -R 755 /own_pkgs
#     chown -hR builder:builder /aur_dep_pkgs
#     chmod -R 755 /aur_dep_pkgs
# EOF

# ## Building and copy project owned pkgs
# build_pkgs "${BUILD_PATH}/own_pkgs" "/own_pkgs" ${PAC_PKG_DB_FILE} ${AUR_PKG_DEPS_FILE}
# # #find ${BUILD_PATH}/extra_pkgs  -type f -iname '*.pkg.tar*' | xargs -i cp {} ${MOUNT_PATH}/aur_pkgs/
# # #find "${BUILD_PATH}"/extra_pkgs  -type f -iname '*.pkg.tar*' -print0 | xargs -0 -i  cp {} ${MOUNT_PATH}/aur_pkgs/
# ### FIXME This is the best style for find && xargs usage?
# find "${BUILD_PATH}/own_pkgs" -type f -iname '*.pkg.tar*' -print0 | xargs -0 -I {} cp {} "${MOUNT_PATH}/own_pkgs/"

# ## Building aur pkgs and aur-dependency pkgs
# download_aur_pkgs /extra_pkgs "${AUR_PACKAGES}"
# build_pkgs "${BUILD_PATH}/extra_pkgs" "/extra_pkgs" ${PAC_PKG_DB_FILE} ${AUR_PKG_DEPS_FILE}
# find "${BUILD_PATH}/extra_pkgs" -type f -iname '*.pkg.tar*' -print0 | xargs -0 -I {} cp {} "${MOUNT_PATH}/aur_pkgs/"

# # For aur-dependency pkgs
# aur_deps_list=""
# while IFS= read -r pkg; do
#     if ! echo "${AUR_PACKAGES}" | grep -e "^${pkg}\$" &&  ! echo "${aur_deps_list}" | grep  "${pkg}"; then
#         aur_deps_list="$pkg ${aur_deps_list}"
#     fi
# done <"${BUILD_PATH}/${AUR_PKG_DEPS_FILE}"

# download_aur_pkgs /aur_dep_pkgs "${aur_deps_list}"
# build_pkgs "${BUILD_PATH}/aur_dep_pkgs" "/aur_dep_pkgs" ${PAC_PKG_DB_FILE} ${AUR_PKG_DEPS_FILE}
# find "${BUILD_PATH}/aur_dep_pkgs" -type f -iname '*.pkg.tar*' -print0 | xargs -0 -I {} cp {} "${MOUNT_PATH}/aur_pkgs/"

# ## remove pkg build host
# umount -l "${BUILD_PATH}"
# # rm -rf "${BUILD_PATH}"
# mv "${BUILD_PATH}" "${BUILD_PATH}"-buildbot

## re-create base imgae as final release image
# btrfs subvolume snapshot "${BUILD_PATH_SNAPSHOT}" "${BUILD_PATH}"

# mkdir "${BUILD_PATH}"/own_pkgs
# mkdir "${BUILD_PATH}"/extra_pkgs

# cp -rv "${MOUNT_PATH}"/aur_pkgs/*.pkg.tar* "${BUILD_PATH}"/extra_pkgs
# cp -rv "${MOUNT_PATH}"/own_pkgs/*.pkg.tar* "${BUILD_PATH}"/own_pkgs

# if [ -n "${PACKAGE_OVERRIDES}" ]; then
#     wget --directory-prefix=/tmp/extra_pkgs ${PACKAGE_OVERRIDES}
#     cp -rv /tmp/extra_pkgs/*.pkg.tar* "${BUILD_PATH}"/own_pkgs
# fi

# # chroot into target
# mount --bind "${BUILD_PATH}" "${BUILD_PATH}"
arch-chroot "${BUILD_PATH}" /bin/bash << \
EOF
    set -e
    set -x

    source /manifest

    # pacman-key --populate

    # echo "LANG=en_US.UTF-8" > /etc/locale.conf
    # locale-gen

    # # Disable parallel downloads
    # sed -i '/ParallelDownloads/s/^/#/g' /etc/pacman.conf

    # # Cannot check space in chroot
    # sed -i '/CheckSpace/s/^/#/g' /etc/pacman.conf

    # update package databases
    # pacman --noconfirm -Syy

    # # install kernel package first to avoid dkms problem
    # pacman --noconfirm -U --overwrite '*' /own_pkgs/${KERNEL_PACKAGE}-*.pkg.tar.zst 

    # # install packages
    # pacman --noconfirm -S --overwrite '*' --disable-download-timeout ${PACKAGES}
    # rm -rf /var/cache/pacman/pkg

    # # install AUR packages
    # pacman --noconfirm -U --overwrite '*' /extra_pkgs/*

    # # install own override packages
    # pacman --noconfirm -U --overwrite '*' /own_pkgs/*


# enable services
systemctl enable ${SERVICES}

# enable user services
systemctl --global enable ${USER_SERVICES}

# disable root login
passwd --lock root

# create user
# groupadd -r autologin
# useradd -m ${USERNAME} -G autologin,wheel
# echo "${USERNAME}:${USERNAME}" | chpasswd

# set the default editor, so visudo works
echo "export EDITOR=/usr/bin/vim" >> /etc/bash.bashrc

echo "[Seat:*]
autologin-user=${USERNAME}
" > /etc/lightdm/lightdm.conf.d/00-autologin-user.conf

echo "${SYSTEM_NAME}" > /etc/hostname

# enable multicast dns in avahi
sed -i "/^hosts:/ s/resolve/mdns resolve/" /etc/nsswitch.conf

# configure ssh
echo "
AuthorizedKeysFile	.ssh/authorized_keys
PasswordAuthentication no
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

echo 'NAME="${SYSTEM_DESC}"
VERSION="${DISPLAY_VERSION}"
VERSION_ID="${VERSION_NUMBER}"
BUILD_ID="${BUILD_ID}"
PRETTY_NAME="${SYSTEM_DESC} ${DISPLAY_VERSION}"
ID=${SYSTEM_NAME}
ID_LIKE=arch
ANSI_COLOR="1;31"
HOME_URL="${WEBSITE}"
DOCUMENTATION_URL="${DOCUMENTATION_URL}"
BUG_REPORT_URL="${BUG_REPORT_URL}"' > /etc/os-release

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
