#!/bin/bash
# getPodShell.sh: Run a shell in the specified pod

# Source the prereqs
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "/etc/ictools.conf"
. "${scriptDir}/utils.sh"

function init() {

    checkForRoot

    # Is this running interactively?
    if [[ -t 0 ]]; then
        # No, so get the pod name from $1 
        if [[ -z "${1}" ]]; then
            log "Usage: sudo getPodShell.sh POD_NAME"
            exit 1
        else
            pod="${1}"
        fi
    else
        # Yes, so get the pod name from stdin
        pod="$(cat -)"
    fi

}

init "${@}"

"${kubectl}" exec --namespace "${icNamespace}" -it "${pod}" -- /bin/sh