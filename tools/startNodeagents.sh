#!/bin/bash
# startNodeagents.sh: Start all WAS application server nodeagents

# Source the prereqs
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "/etc/ictools.conf"
. "${scriptDir}/utils.sh"

function init() {

    # Make sure we're running as root
    checkForRoot

    # Build an array of WAS profiles
    cd "${wasProfileRoot}"
    profiles=($(ls -d *))

}

init

# Start WAS server nodeagents
for profile in "${profiles[@]}"; do

    # Determine the profile type
    profileKey="${wasProfileRoot}/${profile}/properties/profileKey.metadata"
    if [[ -f "${profileKey}" ]]; then
        profileType=$(getWasProfileType "${profileKey}")
    fi

    if [[ "${profileType}" == "BASE" ]]; then

        # Change to the servers directory so we can get an array of servers from the subdirectories
        cd "${wasProfileRoot}/${profile}/servers" >/dev/null 2>&1

        # If there is no servers directory, skip it 
        if [[ ${?} == 0 ]]; then
            # Get an array of servers (only the nodeagent!)
            servers=($(ls -d * | grep "nodeagent")) 
            # Start the servers
            for server in "${servers[@]}"; do
                startWASServer "${server}" "${wasProfileRoot}/${profile}"
            done
        fi

    fi

done