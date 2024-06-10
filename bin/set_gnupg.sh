if ! mkdir -vp "/github/home/.gnupg/"; then
    echo -e "${RED_COLOR}Failed to make /github/home/.gnupg/.${UNSET_COLOR}"
    exit 1
fi

# use more reliable keyserver
echo "keyserver hkps://keys.openpgp.org" | \
    tee "/github/home/.gnupg/gpg.conf" &> $DEBUG_OFF

import_sign() {

    sign_file() {
        echo "${PASSPHRASE}" | sudo -u buildd \
            gpg --detach-sign --pinentry-mode loopback \
            --passphrase --passphrase-fd 0 --sign "${1}" &> $DEBUG_OFF

        if sudo -u buildd gpg --verify "${1}.sig" "${1}" &> $DEBUG_OFF
        then
            echo -e "${BLUE_COLOR}Signed ${1}.${UNSET_COLOR}"
        else
            echo -e "${ORANGE_COLOR}Failed to Sign ${1}.${UNSET_COLOR}"
        fi
    }

    disable_package_verify() {
            unset PRIVATE_KEY
            if ! grep -Fxq "LocalFileSigLevel = Never" /etc/pacman.conf
            then
                sed -i '/"LocalFileSigLevel ="/c "LocalFileSigLevel = Never"' /etc/pacman.conf &> $DEBUG_OFF
            fi
    }

    if [[ -n "$PRIVATE_KEY" ]]
    then
        if sudo -u buildd gpg --list-secret-key | grep "$KEY_FINGERPRINT" &> $DEBUG_OFF
        then
            sign_file "${1}"
        elif echo -e "$PRIVATE_KEY" | sudo -u buildd \
            gpg --batch --import &> $DEBUG_OFF
        then
            sign_file "${1}"
        else
            echo -e "${RED_COLOR}Failed to import private key, not signing ${1}.${UNSET_COLOR}"
            disable_package_verify
        fi
    else
        echo -e "${ORANGE_COLOR}No Secret Key present, not signing ${1}.${UNSET_COLOR}"
        disable_package_verify
    fi
}
