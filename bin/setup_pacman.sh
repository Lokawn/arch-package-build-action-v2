# Setup pacman, from
# https://gitlab.archlinux.org/archlinux/archlinux-docker/-/blob/master/README.md
if [[ -n "$ENABLE_DEBUG" && "$ENABLE_DEBUG" = true ]]; then
    echo -e "::group::${GREEN_COLOR}Initializing pacman.${UNSET_COLOR}"
fi
pacman-key --init --verbose &> $DEBUG_OFF
pacman-key --populate --verbose archlinux &> $DEBUG_OFF

cat<<EOF>/etc/pacman.d/mirrorlist
Server = https://mirror.fcix.net/archlinux
Server = https://mirror.osbeck.com/archlinux/
EOF

pacman -Sy &> $DEBUG_OFF # just to remove warning.

if [[ -n "$ENABLE_DEBUG" && "$ENABLE_DEBUG" = true ]]; then
    echo "::endgroup::"
else
    echo -e "${BLUE_COLOR}${BOLD_TEXT}Pacman Key initialized.${UNSET_COLOR}"
fi

if [[ -n "$PUBLIC_KEY" && -n "$KEY_FINGERPRINT" ]]
then
    if echo -e "$PUBLIC_KEY" | pacman-key --add - &> $DEBUG_OFF
    then
        pacman-key --lsign-key "${KEY_FINGERPRINT}" &> $DEBUG_OFF
        echo -e "${BLUE_COLOR}${BOLD_TEXT}Pacman-key imported Public Key.${UNSET_COLOR}"
    else
        echo -e "${RED_COLOR}${BOLD_TEXT}Pacman-key failed to import Public Key.${UNSET_COLOR}"
        exit 1
    fi
fi
