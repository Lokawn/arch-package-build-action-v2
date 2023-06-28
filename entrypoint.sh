#!/bin/bash

# fail whole script if any command fails
set -e

PATH=$PATH:/github/workspace/action/bin/

source "/github/workspace/action/bin/set_debug.sh"
source "/github/workspace/action/bin/set_color.sh"

check_exist /github/workspace/action/config/{makepkg.conf,pacman.conf}

mv -vf /github/workspace/action/config/{makepkg.conf,pacman.conf} /etc/  &> $DEBUG_OFF

source "/github/workspace/action/bin/set_gnupg.sh"
source "/github/workspace/action/bin/set_attr.sh"

source "/github/workspace/action/bin/setup_pacman.sh"
source "/github/workspace/action/bin/setup_user.sh"

source "/github/workspace/action/bin/setup_pkgbuild.sh"
source "/github/workspace/action/bin/setup_repo.sh"

# shellcheck disable=SC1091
source /etc/makepkg.conf # get PKGEXT

if ! MAKEFLAGS=-j$(nproc); then
    echo -e "${ORANGE_COLOR}${BOLD_TEXT}Failed to set thread cound in makepkg.${UNSET_COLOR}"
else
    export MAKEFLAGS
fi

cat "/github/workspace/pkglist" &> $DEBUG_OFF

# setup_pkgbuild.sh
final_setup
seg_aur

for i in {1..5}
do install_dependencies && break || sleep 5
done

build_pkg

# setup_repo.sh
create_checksum
create_repo

# set_attr.sh
reset_attr
