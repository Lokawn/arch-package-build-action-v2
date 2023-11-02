#https://askubuntu.com/q/1168750/894787
export DEBUG_OFF='/dev/null'

if [[ -n "${RUNNER_DEBUG}" && "${RUNNER_DEBUG}" = 1 ]]; then
    set -x
    export DEBUG_OFF='/dev/stdout'
fi

