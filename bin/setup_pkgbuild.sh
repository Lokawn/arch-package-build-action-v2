## Function list
#1. env_failed
#2. initial_setup - used in final_setup
#3. create_srcinfo - used in final_setup
#4. import_public_keys - used in final_setup
#5. create_dependency_list - used in final_setup
#6. final_setup
#7. seg_aur
#8. install_dependencies
#9. namcap_pkg
#10. pkg_info
#11. pkg_files
#12. build_pkg

# In case environment preparation fails run this function.
# Delete entry "${1}" from pkglist "${2}"
env_failed() {
    mv -vf "${2}" "${2}.bak" &> $DEBUG_OFF
    grep -Fxv "${1}" "${2}.bak" | tee "${2}" &> $DEBUG_OFF
    rm -vf "${2}.bak" &> $DEBUG_OFF
    echo -e "${ORANGE_COLOR}${BOLD_TEXT}Failed to build ${1} - skipping.${UNSET_COLOR}"

    # The continue statement skips the remaining commands inside the body of
    # the enclosing loop for the current iteration and passes program control
    # to the next iteration of the loop.
}

###### Inital setup
initial_setup() {
    if [[ ! -d "${pkgbuild_dir}" ]]; then
        echo -e "${ORANGE_COLOR}${BOLD_TEXT}${pkgbuild_dir} should be a directory.${UNSET_COLOR}"
        env_failed "${PKGNAME}" /github/workspace/pkglist && return 1
    fi

    if [[ ! -e "${pkgbuild_dir}/PKGBUILD" ]]; then
        echo -e "${ORANGE_COLOR}${BOLD_TEXT}${pkgbuild_dir} does not contain a PKGBUILD file.${UNSET_COLOR}"
        env_failed "${PKGNAME}" /github/workspace/pkglist && return 1
    fi
}

create_srcinfo() {
    echo -e "${GREEN_COLOR}Creating SRCINFO file.${UNSET_COLOR}"
    if ! sudo -u buildd makepkg --printsrcinfo \
        | sudo -u buildd tee .SRCINFO
    then
        echo -e "${ORANGE_COLOR}makepkg --printsrcinfo: ${PKGNAME}/.SRCINFO failed - skipping.${UNSET_COLOR}"
        env_failed "${PKGNAME}" /github/workspace/pkglist && return 1
    fi
}

import_public_keys() {
# Exit status for the function will be 0 if there are no errors.
    if grep -E 'validpgpkeys' .SRCINFO  &> $DEBUG_OFF
        # exit status 0 means there are validpgpkeys to import.
    then
        echo -e "${GREEN_COLOR}Importing PGP Keys.${UNSET_COLOR}"
        if [[ -d "${pkgbuild_dir}/keys/pgp" ]]
        then
            for asc in $(grep -E 'validpgpkeys' .SRCINFO | sed -e \
                's/.*validpgpkeys = //' -e 's/:.*//' | xargs)
            do
                if [[ -f "${pkgbuild_dir}/keys/pgp/${asc}.asc" ]]; then
                    sudo -u buildd gpg --import "${pkgbuild_dir}/keys/pgp/${asc}.asc" &> $DEBUG_OFF
                else
                    echo -e "${ORANGE_COLOR}${asc}.asc missing from keys/pgp folder.${UNSET_COLOR}"
                    if ! grep -E 'validpgpkeys' .SRCINFO | sed -e \
                        's/.*validpgpkeys = //' -e 's/:.*//' | xargs sudo -u \
                            buildd gpg --recv-keys &> $DEBUG_OFF
                    then
                        echo -e "${ORANGE_COLOR}gpg public keys lookup & import failed for ${PKGNAME} - skipping.${UNSET_COLOR}"
                        env_failed "${PKGNAME}" /github/workspace/pkglist && return 1
                    fi
                fi
            done
        elif ! grep -E 'validpgpkeys' .SRCINFO | sed -e \
                's/.*validpgpkeys = //' -e 's/:.*//' | xargs sudo -u \
                    buildd gpg --recv-keys &> $DEBUG_OFF
        then # exit status can be variable depending upon gpg.
            echo -e "${ORANGE_COLOR}gpg public keys lookup & import failed for ${PKGNAME} - skipping.${UNSET_COLOR}"
            env_failed "${PKGNAME}" /github/workspace/pkglist && return 1
        fi
    fi
    # exit status 1 means there are no validpgpkeys to import, so function will not execute.
    # status can't be 2 as .SRCINFO will always be present.
}

create_dependency_list() {
        # https://www.shellcheck.net/wiki/SC2024 - sudo doesn't affect redirects
    grep -E 'depends' .SRCINFO | sed -e 's/.*depends = //' -e 's/:.*//' -e 's/[<..>]=[0-9].*//g' -e 's/=[0-9].*//g' \
        | tee -a "/tmp/${PKGNAME}_deps.txt" &> $DEBUG_OFF
        # "/tmp/${PKGNAME}_deps.txt" here contains all package dependencies.

    if [[ -s "/tmp/${PKGNAME}_deps.txt" ]]; then
            # Only print lines unique to column 2.
        comm -13 <(pacman -Slq | sort | uniq) <(sort "/tmp/${PKGNAME}_deps.txt" | uniq) \
            | tee "/tmp/${PKGNAME}_deps_aur.txt" &> $DEBUG_OFF
            # "/tmp/${PKGNAME}_deps_aur.txt" contains dependencies not in repositories.
    fi

    if [[ -s "/tmp/${PKGNAME}_deps_aur.txt" ]]
    then
        cp -v "/tmp/${PKGNAME}_deps.txt" "/tmp/${PKGNAME}_deps.bak" &> $DEBUG_OFF
        cp -v "/tmp/${PKGNAME}_deps_aur.txt" "/tmp/${PKGNAME}_deps_aur.bak" &> $DEBUG_OFF

        comm -23 <(sort "/tmp/${PKGNAME}_deps.bak" | uniq) <(sort "/tmp/${PKGNAME}_deps_aur.txt" | uniq) \
            | tee "/tmp/${PKGNAME}_deps.txt" &> $DEBUG_OFF
            # "/tmp/${PKGNAME}_deps.txt" contains only packages present in repositories.

        rm -vf "/tmp/${PKGNAME}_deps.bak" &> $DEBUG_OFF

        current_run_aurdep=0
        while read aurdep && [[ -n "${aurdep}" ]] || [[ -n "${aurdep}" ]] #from "/tmp/${PKGNAME}_deps_aur.txt"
        do
        #TODO: use case statement instead of using if twice.
            if ! grep -Fx "${aurdep}" "/tmp/${PKGNAME}_deps_aur.txt" &> $DEBUG_OFF; then
                    aurdep=$(head -n $(($current_run_aurdep + 1)) "/tmp/${PKGNAME}_deps_aur.txt" | tail -n +$(($current_run_aurdep + 1)))
            fi

            if grep -Fx "${aurdep}" "/tmp/${PKGNAME}_deps_aur.txt" &> $DEBUG_OFF; then
                add_dep_to_pkglist() {
                    local aur_lineno pkg_lineno
                    aur_lineno=$(grep -nFx "${aurdep}" "/github/workspace/pkglist" | cut -d ":" -f1)
                    pkg_lineno=$(grep -nFx "${PKGNAME}" "/github/workspace/pkglist" | cut -d ":" -f1)
                    if [[ "$aur_lineno" > "$pkg_lineno" ]]
                    then
                        cp -vf /github/workspace/pkglist /github/workspace/pkglist.bak &> $DEBUG_OFF
                        grep -Fxv "${PKGNAME}" "/github/workspace/pkglist.bak" | tee "/github/workspace/pkglist" &> $DEBUG_OFF
                        echo "${PKGNAME}" | tee -a "/github/workspace/pkglist" &> $DEBUG_OFF
                    fi
                }

                if [[ -d "/github/workspace/pkgs/${aurdep}" ]]; then
                    if grep -Fx "${aurdep}" "/github/workspace/pkglist" &> $DEBUG_OFF; then
                        add_dep_to_pkglist
                        echo "${aurdep}" | tee -a "/tmp/${PKGNAME}_deps_aur_installable.txt"
                        # "/tmp/${PKGNAME}_deps_aur_installable.txt" conatins locally available dependencies.
                    elif compgen -G "/github/workspace/pkgdir/${aurdep}-*${PKGEXT}" &> $DEBUG_OFF; then
                        echo "${aurdep}" | tee -a "/tmp/${PKGNAME}_deps_aur_installable.txt"
                    else
                        echo "${PKGNAME}" | tee -a "/github/workspace/pkglist"
                        add_dep_to_pkglist
                        echo "${aurdep}" | tee -a "/tmp/${PKGNAME}_deps_aur_installable.txt"
                    fi
                fi

                unset aurdep
                current_run_aurdep=$(($current_run_aurdep + 1))
            else continue
            fi

        done < "/tmp/${PKGNAME}_deps_aur.txt"

        unset current_run_aurdep

        if [[ -s "/tmp/${PKGNAME}_deps_aur_installable.txt" ]]
        then
            echo -e "${ORANGE_COLOR}\"$(xargs<\
                "/tmp/${PKGNAME}_deps_aur_installable.txt")\" PKGBUILD in source directory.${UNSET_COLOR}"

            # Since column 2 should not contain any unique lines "-3" is used (so -2 not needed).
            # Only print lines unique to column 1.
            comm -3 <(sort "/tmp/${PKGNAME}_deps_aur.bak" | uniq) <(sort "/tmp/${PKGNAME}_deps_aur_installable.txt" | uniq) \
                | tee "/tmp/${PKGNAME}_deps_aur.txt" &> $DEBUG_OFF
                # "/tmp/${PKGNAME}_deps_aur.txt" conatins packages neither locally available nor in repositories.
        fi

        if [[ -s "/tmp/${PKGNAME}_deps_aur.txt" ]]; then
            cp -vf "/tmp/${PKGNAME}_deps_aur.txt" "/tmp/${PKGNAME}_deps_aur.bak" &> $DEBUG_OFF

            current_deps_aur=0
            while read CHECKPKG_PKG && [[ -n $CHECKPKG_PKG ]] || [[ -n $CHECKPKG_PKG ]]
            do
            #TODO
                if ! grep -Fx "${CHECKPKG_PKG}" "/tmp/${PKGNAME}_deps_aur.bak" &> $DEBUG_OFF; then
                    CHECKPKG_PKG=$(head -n $((current_deps_aur + 1)) "/github/workspace/pkglist" | tail -n +$((current_deps_aur + 1)))
                fi
                CHECKPKG="${CHECKPKG_PKG}"
                if pacman -S --noconfirm --needed --color=never "${CHECKPKG}" |& sudo -u buildd tee "/github/workspace/logdir/pacman.log" &> $DEBUG_OFF
                then
                    mv -vf "/tmp/${PKGNAME}_deps_aur.txt" "/tmp/${PKGNAME}_deps_aur.txt.bak" &> $DEBUG_OFF
                    grep -Fxv "${CHECKPKG}" "/tmp/${PKGNAME}_deps_aur.txt.bak" | tee "/tmp/${PKGNAME}_deps_aur.txt" &> $DEBUG_OFF
                    rm -vf "/tmp/${PKGNAME}_deps_aur.txt.bak" &> $DEBUG_OFF
                else continue
                fi
                unset CHECKPKG CHECKPKG_PKG
                current_deps_aur=$((current_deps_aur + 1))
            done < "/tmp/${PKGNAME}_deps_aur.bak"
            unset current_deps_aur
            rm -vf "/tmp/${PKGNAME}_deps_aur.bak" &> $DEBUG_OFF
        fi
    fi
}

###### Setup ENV.
final_setup() {

    # https://stackoverflow.com/a/12916758/10702557: Shell script read missing last line
    # SC2013: To read lines rather than words, pipe/redirect to a 'while read' loop.
    # https://www.shellcheck.net/wiki/SC2013
    #for PKGNAME in $(cat /github/workspace/pkglist)

    current_pkgsetup=0
    while read PKGLIST_PKG_SETUP && [[ -n ${PKGLIST_PKG_SETUP} ]] || [[ -n ${PKGLIST_PKG_SETUP} ]]
    do
        if ! grep -Fx "${PKGLIST_PKG_SETUP}" "/github/workspace/pkglist" &> $DEBUG_OFF; then
            PKGLIST_PKG_SETUP=$(head -n $(($current_pkgsetup + 1)) "/github/workspace/pkglist" | tail -n +$(($current_pkgsetup + 1)))
        fi

        PKGNAME="${PKGLIST_PKG_SETUP}"
        if grep -Fx "${PKGNAME}" "/github/workspace/pkglist" &> $DEBUG_OFF; then

            echo -e "::group::${GREEN_COLOR}${BOLD_TEXT}Preparing env to build ${PKGNAME}.${UNSET_COLOR}"

            # nicely cleans up path, ie.
            # ///dsq/dqsdsq/my-package//// -> /dsq/dqsdsq/my-package
            pkgbuild_dir=$(readlink "/github/workspace/pkgs/${PKGNAME}" -f)

            initial_setup || continue

            cd "${pkgbuild_dir}"
            echo -e "${ORANGE_COLOR}${BOLD_TEXT}PWD='${PWD}'${UNSET_COLOR}"

            create_srcinfo || continue

            import_public_keys || continue

            create_dependency_list

            if [[ -s "/tmp/${PKGNAME}_deps_aur.txt" ]]
            then
                    # https://unix.stackexchange.com/a/63663/444404
                echo -e "${ORANGE_COLOR}\"$(xargs<\
                    "/tmp/${PKGNAME}_deps_aur.txt")\" not in repos, neither PKGBUILD provided.${UNSET_COLOR}"
                echo -e "${ORANGE_COLOR}Skipping ${PKGNAME}.${UNSET_COLOR}"
                env_failed "${PKGNAME}" /github/workspace/pkglist
                continue
            fi

            echo "::endgroup::"
            cat "/tmp/${PKGNAME}_deps.txt" | tee -a "/tmp/pkg_deps_assorted.txt"
            unset PKGNAME PKGLIST_PKG_SETUP
        else
            echo -e "${ORANGE_COLOR}${PKGNAME} package not found - skipping.${UNSET_COLOR}"
            continue
        fi
        current_pkgsetup=$(($current_pkgsetup + 1))

    done < "/github/workspace/pkglist"
    unset current_pkgsetup
}

seg_aur() {
    if [[ -s "/tmp/pkg_deps_assorted.txt" ]]; then
        sort "/tmp/pkg_deps_assorted.txt" | uniq | tee "/tmp/pkg_deps_sorted.txt" &> $DEBUG_OFF
    fi
}

# Install dependencies for all packages in one go.
install_dependencies() {
    if ! xargs pacman -Syu --needed --noconfirm --color=never \
            namcap git audit diffutils < "/tmp/pkg_deps_sorted.txt" \
            |& sudo -u buildd tee -a "/github/workspace/logdir/pacman.log" &> $DEBUG_OFF
    then
        echo -e "${RED_COLOR}${BOLD_TEXT}Failed to install dependencies - aborting.${UNSET_COLOR}"
        exit 1
    else
        for alldeps in namcap git diff auditd; do
            if ! command -v "${alldeps}" &> $DEBUG_OFF
            then
                echo -e "${RED_COLOR}${BOLD_TEXT}${alldeps} not in '$PATH' - aborting.${UNSET_COLOR}"
                exit 1
            fi
        done
        echo -e "${BLUE_COLOR}${BOLD_TEXT}Dependencies installed.${UNSET_COLOR}"
    fi
}

namcap_pkg() {
    if ! namcap "${1}" |& sudo -u buildd \
        tee "/github/workspace/logdir/namcap_${PKGNAME}.log" &> $DEBUG_OFF
    then
        echo -e "${ORANGE_COLOR}${BOLD_TEXT}namcap ${1} failed - skipping.${UNSET_COLOR}"
        return 1
    fi
}

pkg_info() {
    # Remove colours from output while piping using tee.
    # https://unix.stackexchange.com/a/694677/444404

    echo -e "${GREEN_COLOR}${1} information.${UNSET_COLOR}" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${GITHUB_STEP_SUMMARY}")

    # SC2027: The surrounding quotes actually unquote this. Remove or escape them.
    # https://www.shellcheck.net/wiki/SC2027
    # SC2086: Double quote to prevent globbing and word splitting.
    # https://www.shellcheck.net/wiki/SC2086

    pacman -Qip "${1}" \
        |& sudo -u buildd tee -a "/github/workspace/logdir/build_${PKGNAME}.log" \
        | tee -a "${GITHUB_STEP_SUMMARY}"
    echo "" | tee -a "${GITHUB_STEP_SUMMARY}" &> $DEBUG_OFF # Create break in log.
    echo "" | tee -a "${GITHUB_STEP_SUMMARY}" &> $DEBUG_OFF
}

pkg_files() {
    pacman -Qlp "${1}" \
        |& sudo -u buildd tee -a "/github/workspace/logdir/build_${PKGNAME}.log" &> $DEBUG_OFF
}

###### Package Files.
build_pkg() {
    # https://stackoverflow.com/a/12916758/10702557: Shell script read missing last line
    # SC2013: To read lines rather than words, pipe/redirect to a 'while read' loop.
    # https://www.shellcheck.net/wiki/SC2013
    #for PKGNAME in $(cat /github/workspace/pkglist)

    current_pkgbuild=0
    while read PKGLIST_PKG_BUILD && [[ -n $PKGLIST_PKG_BUILD ]] || [[ -n $PKGLIST_PKG_BUILD ]]
    do
        if ! grep -Fx "${PKGLIST_PKG_BUILD}" "/github/workspace/pkglist" &> $DEBUG_OFF; then
            PKGLIST_PKG_BUILD=$(head -n $(($current_pkgbuild + 1)) "/github/workspace/pkglist" | tail -n +$(($current_pkgbuild + 1)))
        fi

        PKGNAME="${PKGLIST_PKG_BUILD}"
        if grep -Fx "${PKGNAME}" "/github/workspace/pkglist" &> $DEBUG_OFF; then

            echo -e "::group::${GREEN_COLOR}${BOLD_TEXT}Packaging ${PKGNAME}.${UNSET_COLOR}"

            pkgbuild_dir=$(readlink "/github/workspace/pkgs/${PKGNAME}" -f)

            cd "${pkgbuild_dir}"
            echo -e "${ORANGE_COLOR}${BOLD_TEXT}PWD='${PWD}'${UNSET_COLOR}"

            if [[ -s "/tmp/${PKGNAME}_deps_aur_installable.txt" ]]; then
                current_build_aurdep=0
                while read aurdep && [[ -n "${aurdep}" ]] || [[ -n "${aurdep}" ]]
                do
                    if ! grep -Fx "${aurdep}" "/tmp/${PKGNAME}_deps_aur_installable.txt" &> $DEBUG_OFF; then
                        aurdep=$(head -n $(($current_build_aurdep + 1)) "/tmp/${PKGNAME}_deps_aur_installable.txt" | tail -n +$(($current_build_aurdep + 1)))
                    fi

                    for aurdeppkg in '/github/workspace/pkgdir/'"${aurdep}"-*"${PKGEXT}"
                    do
                        echo -e "${ORANGE_COLOR}Installing ${aurdep}.${UNSET_COLOR}"
                        pacman -Uv --noconfirm "${aurdeppkg}" \
                            |& sudo -u buildd tee "/github/workspace/logdir/pacman.log" &> $DEBUG_OFF
                    done
                    unset aurdep aurdeppkg
                    current_build_aurdep=$(($current_build_aurdep + 1))
                done < "/tmp/${PKGNAME}_deps_aur_installable.txt"
                unset current_build_aurdep
            fi

            if echo -e "${GREEN_COLOR}${BOLD_TEXT}Building ${PKGNAME}.${UNSET_COLOR}" && \
                sudo -u buildd makepkg --syncdeps --noconfirm \
                    |& sudo -u buildd tee "/github/workspace/logdir/build_${PKGNAME}.log" &> $DEBUG_OFF
                # SC2024: sudo doesn't affect redirects.
                # https://www.shellcheck.net/wiki/SC2024
            then
                # SC2144: -f doesn't work with globs. Use a for loop.
                # https://www.shellcheck.net/wiki/SC2144
                for pkg in "${pkgbuild_dir}"/*"${PKGEXT}"
                do
                    if [[ -f "${pkg}" ]]
                    then
                        echo -e "${BLUE_COLOR}${pkg//${PKGEXT}} packaged.${UNSET_COLOR}"
                            # https://www.shellcheck.net/wiki/SC2104
                        namcap_pkg "${pkg}" || continue
                        pkg_info "${pkg}" || continue
                        pkg_files "${pkg}" || continue
                        import_sign  "${pkg}" || continue
                        mv -v "${pkg}"* "/github/workspace/pkgdir" &> $DEBUG_OFF
                        echo "Package file moved to PKGDIR."
                    else
                        echo -e "${ORANGE_COLOR}${BOLD_TEXT}Failed to build ${PKGNAME} - skipping.${UNSET_COLOR}"
                        continue
                    fi
                done
            else
                echo -e "${ORANGE_COLOR}${BOLD_TEXT}Failed to build ${PKGNAME} - skipping.${UNSET_COLOR}"
                continue
            fi
            echo "::endgroup::"
            unset PKGNAME PKGLIST_PKG_BUILD
        else
            echo -e "${ORANGE_COLOR}$PKGNAME package not found - skipping.${UNSET_COLOR}"
            continue
        fi
    done < "/github/workspace/pkglist"
    unset current_pkgbuild
}
