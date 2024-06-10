# Set colors.
RED_COLOR="\e[0;31m" # Failure
YELLOW_COLOR="\e[1;33m" # Skip
ORANGE_COLOR="\e[0;33m" # Warning
GREEN_COLOR="\e[0;32m" # Initiating command
BLUE_COLOR="\e[0;34m" # Success
UNSET_COLOR="\e[0m" # Unset colors
BOLD_TEXT="\e[1m" # Bold text

for color in RED_COLOR UNSET_COLOR YELLOW_COLOR ORANGE_COLOR GREEN_COLOR BLUE_COLOR BOLD_TEXT; do
    # shellcheck disable=SC2163
    if [[ -n "${color}" ]]
    then
        export "${color}"
    fi
done
