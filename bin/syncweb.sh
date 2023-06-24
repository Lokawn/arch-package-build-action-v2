[[ -d "$GITHUB_WORKSPACE/repo" ]] || mkdir -vp "$GITHUB_WORKSPACE"/repo &> $DEBUG_OFF
[[ -d "/home/runner/.ssh/" ]] || mkdir -vp "/home/runner/.ssh/" &> $DEBUG_OFF

check_sfhost() {
    if ! grep -Fxq "$HOST" "/home/runner/.ssh/known_hosts"
    then
        echo "$HOST" | tee -a "/home/runner/.ssh/known_hosts" &> /dev/null
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
    chmod -v 0600 "/home/runner/.ssh/known_hosts" &> $DEBUG_OFF
}

addkey() {
    if [[ -f "/home/runner/.ssh/id_ed25519" ]]
    then
        echo -e "$SSHKEY" | tee "/home/runner/.ssh/id_ed25519.bak" &> /dev/null
        if ! diff "/home/runner/.ssh/id_ed25519" "/home/runner/.ssh/id_ed25519.bak" &> $DEBUG_OFF
        then
            mv -v "/home/runner/.ssh/id_ed25519.bak" "/home/runner/.ssh/id_ed25519" &> $DEBUG_OFF
        fi
    else
        echo -e "$SSHKEY" | tee "/home/runner/.ssh/id_ed25519" &> /dev/null
    fi
    chmod -v 0600 "/home/runner/.ssh/id_ed25519" &> $DEBUG_OFF
}

rsyncfiles() {
    rsync -a --remove-source-files -e "ssh -o 'PasswordAuthentication no' -o 'UserKnownHostsFile /home/runner/.ssh/known_hosts' -v" "$1" "$2" &> $DEBUG_OFF
}

add_sfhost
addkey
