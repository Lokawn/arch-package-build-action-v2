# ERROR: Running makepkg as root is not allowed as it can cause permanent,
# catastrophic damage to your system.
# https://bbs.archlinux.org/viewtopic.php?id=271671.

useradd -d "/github/home" buildd

echo "buildd ALL=(ALL) NOPASSWD: ALL" | \
    tee -a "/etc/sudoers" &> $DEBUG_OFF

    # Still the owner of files in /github/home is 1001:123
echo -e "${BLUE_COLOR}user 'buildd' created.${UNSET_COLOR}"

# Still the owner of files is 1001:123
# '/github/workspace' is mounted as a volume
# and has owner set to root set the owner to
# the 'buildd' user, so it can access package files.
chown -vR buildd:buildd "/github/home" | \
    tee -a "/tmp/ownership.log" &> $DEBUG_OFF

chown -vR buildd:buildd "/github/workspace" | \
    tee -a "/tmp/ownership.log" &> $DEBUG_OFF

chmod -v 700 -R "/github/home/.gnupg" | \
    tee -a "/tmp/ownership.log" &> $DEBUG_OFF

export GNUPGHOME="/github/home/.gnupg/"

if [[ -f /tmp/ownership.log ]]; then
    sudo -u buildd cp -v "/tmp/ownership.log"\
        "/github/workspace/logdir/ownership.log" &> $DEBUG_OFF
else
    echo -e "${RED_COLOR}/tmp/ownership.log doesn't exist.${UNSET_COLOR}"
    exit 1
fi

echo -e "${BLUE_COLOR}Ownership of '/github/home' & \
'/github/workspace' changed to user 'buildd'.${UNSET_COLOR}"
