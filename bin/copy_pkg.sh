mkdir -vp "$GITHUB_WORKSPACE"/{pkgdir,logdir} &> $DEBUG_OFF

# Copy package files from sync directory to PKGDIR.
copy_pkg_files() {
    echo "::group::Copying package files from sync directory to PKGDIR."

    for i in "$GITHUB_WORKSPACE/repo/x86_64"/*.zst
    do
        local app_name package_file
        package_file=${i##*repo*/}
        app_name=${package_file%%-[0-9]*}

        [[ ! -e "${i}.sig" ]] && rm -rvf "$i" &> $DEBUG_OFF && \
        echo -e "\e[1;33mSignature for ${app_name} not found, package file removed.\e[0m" && \
        [[ -d "${GITHUB_WORKSPACE}/pkgs/${app_name}" ]] && \
        echo ${app_name} | tee -a "${GITHUB_WORKSPACE}/pkglist" && \
        continue

        cp -v "$i"{,.sig} "${GITHUB_WORKSPACE}/pkgdir/" &> $DEBUG_OFF
        if [[ -n "$ENABLE_DEBUG" && "$ENABLE_DEBUG" = false \
          || -z "$ENABLE_DEBUG" ]]; then
            echo -e "\e[0;34mCopied ${package_file} to '${GITHUB_WORKSPACE}/pkgdir'.\e[0m"
        fi
    done
    echo "Options +Indexes" | tee "$GITHUB_WORKSPACE/repo/.htaccess" &> $DEBUG_OFF
    echo "::endgroup::"
}

# Segregate package files.
seg_pkg_files() {
    echo "::group::Delete unneeded files from PKGDIR."

    cd "$GITHUB_WORKSPACE/pkgdir/"

    while read -r pkg && [[ -n $pkg ]] || [[ -n $pkg ]]; do
    if compgen -G ${pkg}-[0-9]*.zst &> $DEBUG_OFF; then
        find "$GITHUB_WORKSPACE/pkgdir/" -name "${pkg}-[0-9]*" -delete
        echo -e "\e[1;33m${pkg} to be updated.\e[0m"
    else
        echo -e "\e[0;34m${pkg} is new.\e[0m"
    fi
    unset pkg
    done < "$GITHUB_WORKSPACE"/pkglist

    echo "::endgroup::"
}
