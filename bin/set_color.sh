# Set colors.
RED_COLOR="\e[1;31m" # Failure
ORANGE_COLOR="\e[1;33m" # Warning -> Skip
GREEN_COLOR="\e[0;36m" # Initiating command
BLUE_COLOR="\e[0;34m" # Success
UNSET_COLOR="\e[0m" # Unset colors
BOLD_TEXT="\e[1m" # Bold text

for color in RED_COLOR UNSET_COLOR ORANGE_COLOR GREEN_COLOR BLUE_COLOR BOLD_TEXT; do
    # shellcheck disable=SC2163
    if [[ -n "${color}" ]]
    then
        export "${color}"
    fi
done
