mkdir -vp "$GITHUB_WORKSPACE"/{pkgdir,logdir} &> $DEBUG_OFF

# Copy package files from previous remote to PKGDIR.
copy_pkg_files() {
    echo "::group::Copying package files from previous remote to PKGDIR."

    for i in $GITHUB_WORKSPACE/repo/x86_64/*.zst
    do
        [[ -e ${i}.sig ]] || rm -rvf "$i"; continue
        cp -v "$i" "${GITHUB_WORKSPACE}/pkgdir/" &> $DEBUG_OFF
        if [[ -n "$ENABLE_DEBUG" && "$ENABLE_DEBUG" = false \
          || -z "$ENABLE_DEBUG" ]]; then
            echo -e "\e[0;34mCopied ${i##*repo*/} to ${GITHUB_WORKSPACE}/pkgdir.\e[0m"
        fi
    done

    echo "::endgroup::"
}

# Segregate package files.
seg_pkg_files() {
    echo "::group::Delete unneeded files from PKGDIR."

    while read -r pkg && [[ -n $pkg ]] || [[ -n $pkg ]]; do
    if compgen -G "${pkg}"*.zst &> $DEBUG_OFF; then
        find "$GITHUB_WORKSPACE/pkgdir/" -name "${pkg}*" -delete
        echo -e "\e[1;33m${pkg} to be updated.\e[0m"
    else
        echo -e "\e[0;34m${pkg} is new.\e[0m"
    fi
    done < "$GITHUB_WORKSPACE"/pkglist

    echo "::endgroup::"
}
