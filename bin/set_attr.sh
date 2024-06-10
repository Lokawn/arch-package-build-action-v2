if ! ownerWork="$(getfacl -an "/github/workspace" | grep owner | awk '{print $3}')"; then
    echo -e "${RED_COLOR}Unable to set ownerWork.${UNSET_COLOR}"
    exit 1
fi

if ! groupWork="$(getfacl -an "/github/workspace" | grep group | awk '{print $3}')"; then
    echo -e "${RED_COLOR}Unable to set groupWork.${UNSET_COLOR}"
    exit 1
fi
if ! ownerHome="$(getfacl -an "/github/home" | grep owner | awk '{print $3}')"; then
    echo -e "${RED_COLOR}Unable to set ownerHome.${UNSET_COLOR}"
    exit 1
fi
if ! groupHome="$(getfacl -an "/github/home" | grep group | awk '{print $3}')"; then
    echo -e "${RED_COLOR}Unable to set groupHome.${UNSET_COLOR}"
    exit 1
fi

# SC2155: Declare and assign separately to avoid masking return values.
# https://www.shellcheck.net/wiki/SC2155
for owner in ownerWork groupWork ownerHome groupHome; do
    # shellcheck disable=SC2163
    if [[ -n "${owner}" ]]
    then
        export "${owner}"
    fi
done

reset_attr() {

    #echo "::group::Changing ownership of '/github' to runner:docker."
    #echo "Changing ownership of /github/workspace from root to runner:docker."

    chown -R "${ownerWork}":"${groupWork}" "/github/workspace" &> $DEBUG_OFF
    #echo "Changing ownership of /github/home from root to runner:docker."

    chown -R "${ownerHome}":"${groupHome}" "/github/home" &> $DEBUG_OFF
    #echo "::endgroup::"

    echo -e "${BLUE_COLOR}Ownership of '/github' changed to runner:docker.${UNSET_COLOR}"
}
