#!/usr/bin/env bash

source manifest

LOCAL_PKG_BUILDBOT="cos-kde-buildbot <buildbot@localhost>"

####
# Argumenuts:
#   pkg:                        Target buiding pkg
#   pac_pkg_db_file:            File stored in chroot(EG:/pac_pkg_db_list) which contains name of all pkgs in pacman
#   target_aur_pkg_deps_file:   Temporary file which stored deps in aur for $pkg
####
function generate_pkg_deps() {
    local pkg=$1
    local pac_pkg_db_file=$2
    local target_aur_pkg_deps_file=$3

    if [ -z "${pkg}" ] || [ -z "${pac_pkg_db_file}" ] || [ -z "${target_aur_pkg_deps_file}" ]; then
        echo "[fn > generate_pkg_deps] Invalid parameter!!"
        return 255
    fi

    local tmp_deps="dummy"
    echo "pkg >>>>>>> ${pkg}"
    expac -Q '%E' "${pkg}"
    tmp_deps=$(expac -Q '%E' "${pkg}")
    echo "tmp_deps >>> ${tmp_deps}"
    for i in $tmp_deps; do
        echo "check dep > $i"
        # deps=$(echo $deps | awk '{for (i=2;i<=NF;i++) {print $i}}')
        # echo "now deps $deps"
        if grep -e "^${i}\$" "${pac_pkg_db_file}"; then
            echo "Package find in ${pac_pkg_db_file}"
        else
            if LC_ALL=c pacman -Qi "${i}" | grep "Provides" | grep "${i}"; then
                echo "Package ${i} is a virtual package"
            else
                if grep -e "^${i}\$" "${target_aur_pkg_deps_file}"; then
                    echo "Package ${i} allready added"
                else
                    echo -e "${i}" >>"${target_aur_pkg_deps_file}"
                    # echo -e "${i} $(cat ${AUR_PKG_DEPS_LIST})" > ${AUR_PKG_DEPS_LIST}
                    echo "now dep list $(cat "${target_aur_pkg_deps_file}")"
                    generate_pkg_deps "$i" "${pac_pkg_db_file}" "${target_aur_pkg_deps_file}"
                fi
            fi
        fi
    done
}

####
# Argumenuts:
#   pkg_path:                   Full path in buildbot for pkgs
#   chroot_path:                Abstract path of ${pkg_path} in chroot
#   pac_pkg_db_file:            File stored in chroot(EG:/pac_pkg_db_list) which contains name of all pkgs in pacman, see generate_pkg_deps
#   target_aur_pkg_deps_file:   Temporary file which stored deps in aur for $pkg, see generate_pkg_deps
####
function build_pkgs() {
    local pkg_path=$1
    local chroot_path=$2
    local pac_pkg_db_file=$3
    local target_aur_pkg_deps_file=$4

    if [ -z "${pkg_path}" ] || [ -z "${chroot_path}" ] || [ -z "${pac_pkg_db_file}" ] || [ -z "${target_aur_pkg_deps_file}" ]; then
        echo "[fn > build_pkgs] Invalid parameter!!"
        return 255
    fi

    while IFS= read -r pkg; do
        echo "-------------------- build in dir [$pkg]"

        ### Start build in chroot
        arch-chroot "${BUILD_PATH}" /bin/bash << \
            EOF
        set -e
        set -x

#echo "linux-api-headers<4.10" | awk -F '>|<|=' '{print $1}'
#expac -Q "%o" gamescope-session-steam-git
#pacman -Rnc
        source /local_package_builder_env.bash

        cd ${chroot_path}/${pkg};
        # If dependency package in aur, and building failure, using paru to install dependency, then building again
        # makepkg , add -f -c option?
        su builder -c "while true; do \
                            if makepkg --noconfirm -s -i -c  -f; then \
                                break; \
                            else \
                                while true; do \
                                    paru -S --noconfirm ${pkg}; \
                                    if makepkg --noconfirm -s -i -c  -f; then \
                                        break; \
                                    fi; \

                                done;    
                            fi; \
                        done"
        # generate_pkg_deps ${pkg} ${pac_pkg_db_file} ${target_aur_pkg_deps_file}
        # pacman -Rsc --noconfirm "${pkg}"
        # #Reinstall base base-devel to avoid pacman -Rsc mistake
        # pacman -S --noconfirm base base-devel

        # ## Query packages from aur/PKGBUILD
        # pacman -Qqm > /PKG_DEP_${pkg} || continue
        expac "%n\t%p" | grep "${LOCAL_PKG_BUILDBOT}"| cut -f1 > /PKG_DEP_TMP
EOF
        ## End build in chroot

        # cd "${pkg_path}/${pkg}" || continue
        # ##FIXME ugly code for sed using
        # local p_names=$(crudini --get PKGBUILD "" "pkgname" | sed 's/(//g' | sed 's/)//g' | sed "s/'//g")
        # for pkg_name in ${p_names}; do
        #     echo "check dependency for pkg [${pkg_name}] in dir [${pkg_path}/${pkg}]"

        #     arch-chroot "${BUILD_PATH}" /bin/bash -c " \
        #         set -e; \
        #         set -x; \
        #         source /local_package_builder_env.bash; \
        #         generate_pkg_deps ${pkg_name} ${pac_pkg_db_file} ${target_aur_pkg_deps_file}; \
        #     "
        # done

        local p_names="";
        while IFS= read -r pkg_name; do
            echo "check dependency for pkg [${pkg_name}] in dir [${pkg_path}/${pkg}]"
            p_names="${pkg_name} ${p_names}"

            arch-chroot "${BUILD_PATH}" /bin/bash -c " \
                set -e; \
                set -x; \
                source /local_package_builder_env.bash; \
                generate_pkg_deps ${pkg_name} ${pac_pkg_db_file} ${target_aur_pkg_deps_file}; \
            "
        #done <<< "$(grep -xvFf <(pacman -Qqm) <(expac "%n\t%p" | grep "${LOCAL_PKG_BUILDBOT}"| cut -f1))"
        done < /"${BUILD_PATH}"/PKG_DEP_TMP

        arch-chroot "${BUILD_PATH}" /bin/bash -c " \
            set -e; \
            set -x; \
            echo 'Remove packages [${p_names}]'; \
            pacman -Rsncu --noconfirm ${p_names} || continue; \
            pacman -S --noconfirm base base-devel; \
        "
    done < <(find "${pkg_path}" -maxdepth 1 -mindepth 1 -type d -printf '%f\n')
}

####
# Argumenuts:
#   pkg_path: path used for chroot, EG: /tmp, /pgk_dir, etc
#   pkg_list: aur pkgs for downloading
####
function download_aur_pkgs() {
    local pkg_path=$1
    local pkg_list=$2

    if [ -z "${pkg_path}" ] || [ -z "${pkg_list}" ]; then
        echo "[fn > download_aur_pkgs] Invalid parameter!!"
        return 255
    fi

    arch-chroot "${BUILD_PATH}" /bin/bash << \
        EOF
    set -e
    set -x

    cd "${pkg_path}"
    while true; do
        if paru --clonedir "${pkg_path}" -G  ${pkg_list}; then
            break;
        fi;
    done

    # Set permission for chroot builder 
    chown -hR builder:builder "${pkg_path}"
    chmod -R 755 "${pkg_path}"

EOF
}

####
# Argumenuts:
#   pac_pkg_db_file:            File stored in chroot(EG:/pac_pkg_db_list) which contains name of all pkgs in pacman
####
function initialize_buildbot() {
    local pac_pkg_db_file=$1

    if [ -z "${pac_pkg_db_file}" ]; then
        echo "[fn > initialize_buildbot] Invalid parameter!!"
        return 255
    fi

    cp -f local_package_builder_env.bash "${BUILD_PATH}/local_package_builder_env.bash"
    chmod 755 "${BUILD_PATH}/local_package_builder_env.bash"

    arch-chroot "${BUILD_PATH}" /bin/bash << \
        EOF
        set -e
        set -x

        source /local_package_builder_env.bash

        pacman-key --populate

        echo "LANG=en_US.UTF-8" > /etc/locale.conf
        locale-gen

        # update package databases and save base package lists
        pacman --noconfirm -Syy
        pacman --noconfirm -Ssq >> ${pac_pkg_db_file}

        chmod 666 ${pac_pkg_db_file}

        # Add archlinuxCN repo to download paru
        if ! grep 'repo.archlinuxcn.org/\$arch' /etc/pacman.conf ; then
            echo '
                [archlinuxcn]
                SigLevel = Never
                Server = https://mirrors.ustc.edu.cn/archlinuxcn/\$arch

                ' >> /etc/pacman.conf
        fi

        # update package databases
        pacman --noconfirm -Syy

        pacman -S --noconfirm archlinuxcn-keyring paru base-devel

        ## Install expac for queying installed package  dependencies
        pacman -S --noconfirm expac

        # # install devtools to build aur pkgs in chroot
        # pacman -S --noconfirm devtools
        
        # sudo permissions without password
        sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^# //g' /etc/sudoers
        sed -i '/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/s/^# //g' /etc/sudoers

        groupadd builder
        useradd -g builder -s /bin/bash builder
        echo "builder:builder" | chpasswd
        usermod -aG wheel builder
        mkdir -p /home/builder
        chown builder:builder /home/builder
        chmod 775 /home/builder

        # paru -S --noconfirm crudini
        # while true; do
        #     if su builder -c "paru -S --noconfirm crudini"; then
        #         break;
        #     fi
        # done

        echo "PACKAGER=\"${LOCAL_PKG_BUILDBOT}\"" >> /etc/makepkg.conf
EOF
}
