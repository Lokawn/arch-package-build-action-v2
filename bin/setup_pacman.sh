# Setup pacman, from
# https://gitlab.archlinux.org/archlinux/archlinux-docker/-/blob/master/README.md

if [[ -n "$ENABLE_DEBUG" && "$ENABLE_DEBUG" = true ]]; then
    echo -e "::group::${GREEN_COLOR}Initializing pacman.${UNSET_COLOR}"
fi

pacman-key --init --verbose &> $DEBUG_OFF
[[ $(echo $?) ]] || (echo -e "${RED_COLOR}${BOLD_TEXT}Pacman-key failed to initialize.${UNSET_COLOR}" && exit 1)

pacman-key --populate --verbose archlinux &> $DEBUG_OFF
[[ `echo $?` ]] || (echo -e "${RED_COLOR}${BOLD_TEXT}Pacman-key failed to populate.${UNSET_COLOR}" && exit 1)

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

# Add local repo to pacman.conf
if sed -i '/\[core\]/i \[repo\]\nServer\ =\ file:\/\/\/github\/workspace\/repo\/x86_64-old' /etc/pacman.conf
then
    echo -e "${BLUE_COLOR}${BOLD_TEXT}Enabled local repository in 'pacman.conf'.${UNSET_COLOR}"
else
    echo -e "${RED_COLOR}${BOLD_TEXT}Failed to enable local repository, necessary for building packages - aborting.${UNSET_COLOR}" && exit 1
fi

# just to remove warning.
for i in {1..5}
do
#    if [[ $i -le 5 ]]
#    then
        if pacman -Sy &> $DEBUG_OFF
        then
            echo -e "${BLUE_COLOR}${BOLD_TEXT}Pacman database updated.${UNSET_COLOR}"
        else
            if [[ $i -le 4 ]]; then
                (echo -e "${RED_COLOR}${BOLD_TEXT}Pacman database update failed - retrying.${UNSET_COLOR}" && exit 1)
            elif [[ $i == 5 ]]; then
                (echo -e "${RED_COLOR}${BOLD_TEXT}Pacman database update failed, 5 times - aborting.${UNSET_COLOR}" && exit 1)
            fi || (exit 1)
        fi && break || (exit 1)
#    fi || (sleep 5; exit 1)
done || exit 1