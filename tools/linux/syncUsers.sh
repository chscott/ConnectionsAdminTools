#!/bin/bash

function init() {

    # Source prereqs
    scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    . "/etc/ictools.conf"
    . "${scriptDir}/utils.sh"

    # Make sure we're running as root
    checkForRoot

    # Make sure TDI is available on this system
    checkForTDI
    
}

init "${@}" 

printf "${left2Column}" "Synchronizing Profiles with LDAP..."

"${tdiSolutionDir}/sync_all_dns.sh" >/dev/null 2>&1

# Report status
if [[ ${?} == 0 ]]; then
    printf "${right2Column}" "${greenText}SUCCESS${normalText}"
else
    printf "${right2Column}" "${redText}FAILURE${normalText}"
fi
