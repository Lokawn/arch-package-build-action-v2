[[ -d "$GITHUB_WORKSPACE/repo" ]] || mkdir -vp "$GITHUB_WORKSPACE"/repo &> $DEBUG_OFF
[[ -d "/home/runner/.ssh/" ]] || mkdir -vp "/home/runner/.ssh/" &> $DEBUG_OFF

check_sfhost() {
    if ! grep -Fxq "$HOST" "/home/runner/.ssh/known_hosts"
    then
        if ! echo "$HOST" | tee -a "/home/runner/.ssh/known_hosts" &> /dev/null
        then
            echo -e "${RED_COLOR}${BOLD_TEXT}Failed to append REMOTE to '~/.ssh/known_hosts' - aborting.${UNSET_COLOR}"
            exit 1
        fi
        echo -e "${BLUE_COLOR}${BOLD_TEXT}REMOTE appended to '~/.ssh/known_hosts' - proceeding.${UNSET_COLOR}"
    fi
}

add_sfhost() {
    if [[ -f "/home/runner/.ssh/known_hosts" ]]
    then
        check_sfhost
    else
        touch "/home/runner/.ssh/known_hosts"
        check_sfhost
    fi
    if chmod -v 0600 "/home/runner/.ssh/known_hosts" &> $DEBUG_OFF
    then
        echo -e "${BLUE_COLOR}${BOLD_TEXT}Corrected permissions of '~/.ssh/known_hosts' - proceeding.${UNSET_COLOR}"
    else
        echo -e "${RED_COLOR}${BOLD_TEXT}Failed to set correct permissions of '~/.ssh/known_hosts' - aborting.${UNSET_COLOR}"
        exit 1
    fi
}

addkey() {
    if [[ -f "/home/runner/.ssh/id_ed25519" ]]
    then
        echo -e "$SSHKEY" | tee "/home/runner/.ssh/id_ed25519.bak" &> /dev/null
        if ! diff "/home/runner/.ssh/id_ed25519" "/home/runner/.ssh/id_ed25519.bak" &> $DEBUG_OFF
        then
            mv -v "/home/runner/.ssh/id_ed25519.bak" "/home/runner/.ssh/id_ed25519" &> $DEBUG_OFF
            echo -e "${BLUE_COLOR}${BOLD_TEXT}Private SSH Key created - proceeding.${UNSET_COLOR}"
        fi
    else
        echo -e "$SSHKEY" | tee "/home/runner/.ssh/id_ed25519" &> /dev/null
        echo -e "${BLUE_COLOR}${BOLD_TEXT}Private SSH Key created - proceeding.${UNSET_COLOR}"
    fi
    chmod -v 0600 "/home/runner/.ssh/id_ed25519" &> $DEBUG_OFF
}

rsyncfiles() {
    if rsync -a --delete -e "ssh -v -i /home/runner/.ssh/id_ed25519" "$1" "$2" &> $DEBUG_OFF
    then
        echo -e "${BLUE_COLOR}${BOLD_TEXT}Successfully synced files - proceeding.${UNSET_COLOR}"
    else
        echo -e "${RED_COLOR}${BOLD_TEXT}Failed to sync files - aborting.${UNSET_COLOR}"
        return 1
    fi || (exit 1)
}

add_sfhost
addkey
