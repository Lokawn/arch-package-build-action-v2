create_checksum() {
    echo -e "::group::${GREEN_COLOR}${BOLD_TEXT}Generating and Signing SHA512SUMS.${UNSET_COLOR}"
        cd "/github/workspace/pkgdir"

        sha512sum -- *.zst | tee "sha512sums" \
            | xargs -d "\n" \
                printf "${BLUE_COLOR}${BOLD_TEXT}%s${UNSET_COLOR}\n"

        # SC2035: Use ./*glob* or -- *glob* so names with dashes won't become options.
        # https://www.shellcheck.net/wiki/SC2035

        echo "Signing sha512sums."
        import_sign "sha512sums" || return 0
        cp -v /github/workspace/pkgdir/sha512sums* /github/workspace/repo/x86_64/ &> $DEBUG_OFF
    echo "::endgroup::"
}

create_repo() {
    echo -e "::group::${GREEN_COLOR}${BOLD_TEXT}Generating Arch Repo files.${UNSET_COLOR}"
        echo -e "${GREEN_COLOR}Moving package files to 'repo/x86_64/'.${UNSET_COLOR}"
        mv -v /github/workspace/pkgdir/*.zst* "/github/workspace/repo/x86_64/" &> $DEBUG_OFF
        cd "/github/workspace/repo/x86_64"
        echo -e "${ORANGE_COLOR}${BOLD_TEXT}PWD='${PWD}'${UNSET_COLOR}"

        repo-add "/github/workspace/repo/x86_64/repo.db.tar.gz" ./*.pkg.tar.zst &> $DEBUG_OFF

        echo -e "${GREEN_COLOR}Signing repo.db.tar.gz${UNSET_COLOR}"
        import_sign "repo.db.tar.gz" || return 0
        rm -f "/github/workspace/repo/x86_64/repo.db" "/github/workspace/repo/x86_64/repo.files"
        cp -f "/github/workspace/repo/x86_64/repo.db.tar.gz" "/github/workspace/repo/x86_64/repo.db"
        cp -f "/github/workspace/repo/x86_64/repo.files.tar.gz" "/github/workspace/repo/x86_64/repo.files"
    echo "::endgroup::"
}
