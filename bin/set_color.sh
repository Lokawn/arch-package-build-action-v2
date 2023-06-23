# Set colors.
RED_COLOR="\e[1;31m"
ORANGE_COLOR="\e[1;33m"
GREEN_COLOR="\e[0;36m"
BLUE_COLOR="\e[0;34m"
UNSET_COLOR="\e[0m"
BOLD_TEXT="\e[1m"

for color in RED_COLOR UNSET_COLOR ORANGE_COLOR GREEN_COLOR BLUE_COLOR BOLD_TEXT; do
    # shellcheck disable=SC2163
    if [[ -n "${color}" ]]
    then
        export "${color}"
    fi
done
