#https://askubuntu.com/q/1168750/894787
export DEBUG_OFF='/dev/null'

if [[ -n "$ENABLE_DEBUG" && "$ENABLE_DEBUG" = true ]]; then
    set -x
    export DEBUG_OFF='/dev/stdout'
fi

