#!/bin/bash
# utils.sh

# Source prereqs
. "/etc/ictools.conf"

# Tests to make sure the effective user ID is root
function checkForRoot() {

    local script="$(basename "${0}")"

	if [[ ${EUID} != 0 ]]; then
		log "${script} needs to run as root. Exiting."
		exit 1
	fi

}

# Tests to make sure the WAS Deployment Manager is available on this system
function checkForDmgr() {

    local script="$(basename "${0}")"

    if [[ ! -d "${wasDmgrProfile}" ]]; then
        log "${script} can only run on the Deployment Manager node. Exiting."
        exit 1
    fi

}

# Tests to make sure Connections is installed on this system
function checkForIC() {

    local script="$(basename "${0}")"

    if [[ ! -d "${icInstallDir}" ]]; then
        log "${script} can only run on Connections nodes. Exiting."
        exit 1
    fi

}

# Tests to make sure TDI is installed on this system
function checkForTDI() {

    local script="$(basename "${0}")"

    if [[ ! -d "${tdiSolutionDir}" ]]; then
        log "${script} can only run on TDI nodes. Exiting."
        exit 1
    fi

}

# Tests to make sure Kubernetes is available on this system
function checkForK8s() {

    local script="$(basename "${0}")"

    if [[ ! -x "${kubectl}" ]]; then
        log "${script} can only run on Component Pack nodes. Exiting."
        exit 1
    fi

}

# Print message
# $1: message to print
function log() {

    local message="${1}"

	printf "%s\n" "${message}"

}

# Verify that a given directory exists
function directoryExists() {

    local directory="${1}"

    if [[ -d "${directory}" ]]; then
        echo "true"
    else
        echo "false"
    fi

}

# Verify that a given directory has subdirectories
function directoryHasSubDirs() {

    local directory="${1}"
    local status="false"

    cd "${directory}" 2>&1

    # No error, so directory exists
    if [[ ${?} == 0 ]]; then
        ls -d * >/dev/null 2>&1 
        # No error, so at least one subdir was found
        if [[ ${?} == 0 ]]; then
            status="true"
        fi
    fi           

    echo "${status}"

}

# Given a profileKey.metadata file, return the profile type
function getWASProfileType() {

    local profileKeyFile="${1}"
    local profileType=""

    profileType="$(grep "com.ibm.ws.profile.type" "${profileKeyFile}" | awk -F "=" '{print $2}')"
    
    if [[ ${?} == 0 ]]; then
        echo "${profileType}"
    else
        echo "INVALID"
    fi

}

# Determine if a given profile is of type DEPLOYMENT_MANAGER
function isWASDmgrProfile() {

    local profile="${1}"

    # Determine the profile type
    local profileKey="${wasProfileRoot}/${profile}/properties/profileKey.metadata"
    if [[ -f "${profileKey}" ]]; then
        profileType=$(getWASProfileType "${profileKey}")
    fi

    if [[ "${profileType}" == "DEPLOYMENT_MANAGER" ]]; then
        echo "true"
    else
        echo "false"
    fi

}

# Determine if a given profile is of type BASE
function isWASBaseProfile() {

    local profile="${1}"

    # Determine the profile type
    local profileKey="${wasProfileRoot}/${profile}/properties/profileKey.metadata"
    if [[ -f "${profileKey}" ]]; then
        profileType=$(getWASProfileType "${profileKey}")
    fi

    if [[ "${profileType}" == "BASE" ]]; then
        echo "true"
    else
        echo "false"
    fi

}

# Determine if this server is a managed webserver
function isWASWebserver() {

    # Get all server.xml files in the cell, find the one for this server, and see if it's a webserver
    if [[ $(find "${wasProfileRoot}/${profile}/config/cells/${wasCellName}/nodes" -name "server.xml" -print 2>/dev/null | \
        xargs grep "name=\""${server}"\"" | \
        grep -c "xmi:type=\"webserver:WebServer\"") > 0 ]]; then
        echo "true"
    else
        echo "false"
    fi      

}

# Determine if a given server is part of the WAS cell
function isServerInWASCell() {

        local server="${1}"
        local profile="${2}"
        local isInCell="false"

        # Build an array of servers known to this cell
        local cellServers=($( \
            find "${wasProfileRoot}/${profile}/config/cells/${wasCellName}/nodes" -name "serverindex.xml" -print 2>/dev/null | \
            xargs grep "serverName" | \
            awk -F 'serverName=' '{print $2}' | \
            awk '{print $1}' | \
            tr -d '"' | \
            sort | \
            uniq \
        )) 

        # Verify that the server exists in the cell
        for cellServer in "${cellServers[@]}"; do
            if [[ "${cellServer}" == "${server}" ]]; then
                isInCell="true"
            fi
        done

        echo "${isInCell}"

}

# Check to see if Deployment Manager is available
function isDmgrAvailable() {

    local status="$(nmap "${wasDmgrHost}" -p ${wasDmgrSoapPort})"

    if [[ "${status}" =~ "open" ]]; then
        echo 0
    else
        echo 1
    fi

}

# Prints the status of the specified WAS server
# $1: server to check
# $2: profile root
# $3: (Optional) boolean (true returns the result via subshell, any other value prints to display)
function getWASServerStatus() {

    local server="${1}"
    local profile="${2}"
    local noDisplay="${3}"

    # Get the basename of the profile directory
    local profileBasename=$(basename "${profile}")

    # If no WAS installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${wasInstallDir}" || ! -d "${wasInstallDir}" ]]; then
        return
    fi

    # Only print info if noDisplay is not true
    if [[ "${noDisplay}" != "true" ]]; then
        printf "${left2Column}" "Server: ${profileBasename}.${server}"
    fi

    # This approach is much faster than using serverStatus.sh and unlikely to yield false positives
    if [[ $(ps -ef | grep -v "grep" | grep "${profile}" | awk '{print $NF}' | grep -c "${server}") > 0 ]]; then 
        # If we found a match, the server is started
        if [[ "${noDisplay}" == "true" ]]; then
            echo "STARTED"
        else
            printf "${right2Column}" "${greenText}STARTED${normalText}"
        fi
    else 
        # If we did not find a match, the server is stopped
        if [[ "${noDisplay}" == "true" ]]; then
            echo "STOPPED"
        else
            printf "${right2Column}" "${redText}STOPPED${normalText}"
        fi
    fi

}

# Start the specified WAS server
# $1: server
# $2: profile path
function startWASServer() {

    local server="${1}"
    local profile="${2}"

    # Get the basename of the profile directory
    local profileBasename=$(basename "${profile}")

    printf "${left2Column}" "Starting server ${server} in profile ${profileBasename}..."

    if [[ "$(getWASServerStatus "${server}" "${profile}" "true")" == "STOPPED" ]]; then
        # If the server is stopped, start it
        local status="$("${profile}/bin/startServer.sh" "${server}")"
        if [[ "${status}" =~ "ADMU3027E" || "${status}" =~ "ADMU3000I" ]]; then
            printf "${right2Column}" "${greenText}SUCCESS${normalText}"
        else
            printf "${right2Column}" "${redText}FAILURE${normalText}"
        fi
    else
        # The server is already started, so report success
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
    fi

}

# Stop the specified WAS server
# $1: server
# $2: profile path
function stopWASServer() {

    local server="${1}"
    local profile="${2}"

    # Get the basename of the profile directory
    local profileBasename=$(basename "${profile}")

    printf "${left2Column}" "Stopping server ${server} in profile ${profileBasename}..."

    if [[ "$(getWASServerStatus "${server}" "${profile}" "true")" == "STARTED" ]]; then
        # If the server is started, stop it
        local status="$("${profile}/bin/stopServer.sh" "${server}" -username "${wasAdmin}" -password "${wasAdminPwd}")"
        if [[ "${status}" =~ "ADMU0509I" || "${status}" =~ "ADMU4000I" ]]; then
            printf "${right2Column}" "${greenText}SUCCESS${normalText}"
        else
            printf "${right2Column}" "${redText}FAILURE${normalText}"
        fi
    else
        # The server is already stopped, so report success
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
    fi

}

# Prints the status of the IHS server
function getIHSServerStatus() {

    # If no IHS installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${ihsInstallDir}" || ! -d "${ihsInstallDir}" ]]; then
        return
    fi

    printf "${left2Column}" "Server: IHS"

    # See if the server is running
    ps -ef | grep "${ihsInstallDir}/bin/httpd" | grep -v "admin.conf" | grep -v "grep" >/dev/null 2>&1

    if [[ ${?} == 0 ]]; then
        # If we found a match, the server is started
        printf "${right2Column}" "${greenText}STARTED${normalText}"
    else 
        # If we did not find a match, the server is stopped
        printf "${right2Column}" "${redText}STOPPED${normalText}"
    fi

}

# Start IHS server
function startIHSServer() {

    # If no IHS installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${ihsInstallDir}" || ! -d "${ihsInstallDir}" ]]; then
        log "IHS does not appear to be installed on this system. Exiting."
        exit 0
    fi

    printf "${left2Column}" "Starting IHS server..."

    # Start the server
    "${ihsInstallDir}/bin/apachectl" "start" >/dev/null 2>&1
    
    # Check to see if server is started
    if [[ ${?} == 0 ]]; then
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
    else
        printf "${right2Column}" "${redText}FAILURE${normalText}"
    fi 

}

# Stop IHS server
function stopIHSServer() {

    # If no IHS installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${ihsInstallDir}" || ! -d "${ihsInstallDir}" ]]; then
        log "IHS does not appear to be installed on this system. Exiting."
        exit 0
    fi

    printf "${left2Column}" "Stopping IHS server..."

    # Stop the server
    "${ihsInstallDir}/bin/apachectl" "stop" >/dev/null 2>&1
    
    # Wait a few seconds for process termination 
    sleep ${serviceDelaySeconds} 

    # Kill any remaining processes
    ps -ef | grep "${ihsInstallDir}/bin" | grep -v "admin.conf" | grep -v "grep" | awk '{print $2}' | xargs -r kill -9 >/dev/null 2>&1

    # Check to see if server is stopped
    if [[ ${?} == 0 ]]; then
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
    else
        printf "${right2Column}" "${redText}FAILURE${normalText}"
    fi 

}

# Prints the status of the IHS admin server
function getIHSAdminServerStatus() {

    # If no IHS installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${ihsInstallDir}" || ! -d "${ihsInstallDir}" ]]; then
        return
    fi

    printf "${left2Column}" "Server: IHS Admin"

    # See if the server is running
    ps -ef | grep "${ihsInstallDir}/bin/httpd" | grep "admin.conf" | grep -v "grep" >/dev/null 2>&1

    if [[ ${?} == 0 ]]; then
        # If we found a match, the server is started
        printf "${right2Column}" "${greenText}STARTED${normalText}"
    else 
        # If we did not find a match, the server is stopped
        printf "${right2Column}" "${redText}STOPPED${normalText}"
    fi

}

# Start IHS admin server
function startIHSAdminServer() {

    # If no IHS installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${ihsInstallDir}" || ! -d "${ihsInstallDir}" ]]; then
        log "IHS does not appear to be installed on this system. Exiting."
        exit 0
    fi

    printf "${left2Column}" "Starting IHS Admin server..."

    # Start the server
    "${ihsInstallDir}/bin/adminctl" "start" >/dev/null 2>&1
    
    # Check to see if server is started
    if [[ ${?} == 0 ]]; then
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
    else
        printf "${right2Column}" "${redText}FAILURE${normalText}"
    fi 

}

# Stop IHS admin server
function stopIHSAdminServer() {

    # If no IHS installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${ihsInstallDir}" || ! -d "${ihsInstallDir}" ]]; then
        log "IHS does not appear to be installed on this system. Exiting."
        exit 0
    fi

    printf "${left2Column}" "Stopping IHS Admin server..."

    # Stop the server
    "${ihsInstallDir}/bin/adminctl" "stop" >/dev/null 2>&1
    
    # Wait a few seconds for process termination 
    sleep ${serviceDelaySeconds} 

    # Kill any remaining processes
    ps -ef | grep "${ihsInstallDir}/bin" | grep "admin.conf" | grep -v "grep" | awk '{print $2}' | xargs -r kill -9 >/dev/null 2>&1

    # Check to see if server is stopped
    if [[ ${?} == 0 ]]; then
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
    else
        printf "${right2Column}" "${redText}FAILURE${normalText}"
    fi 

}

# Prints the status of the Solr server
function getSolrServerStatus() {

    # If no Solr installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${solrInstallDir}" || ! -d "${solrInstallDir}" ]]; then
        return
    fi

    printf "${left2Column}" "Server: Solr"

    # See if the server is running
    ps -ef | grep "solr/quick-results-collection" | grep -v "grep" >/dev/null 2>&1

    if [[ ${?} == 0 ]]; then
        # If we found a match, the server is started
        printf "${right2Column}" "${greenText}STARTED${normalText}"
    else 
        # If we did not find a match, the server is stopped
        printf "${right2Column}" "${redText}STOPPED${normalText}"
    fi

}

# Start Solr server
function startSolrServer() {

    # If no Solr installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${solrInstallDir}" || ! -d "${solrInstallDir}" ]]; then
        log "Solr does not appear to be installed on this system. Exiting."
        exit 0
    fi

    printf "${left2Column}" "Starting Solr server..."

    # See if Java is installed
    local java="$(which java)"
    if [[ ${?} != 0 ]]; then
        printf "${right2Column}" "${redText}FAILURE${normalText}" "(Could not find Java)"
        exit 1
    fi

    cd "${solrInstallDir}/node1" 2>/dev/null

    # Start Solr
    nohup "${java}" \
        -jar "${solrInstallDir}/node1/start.jar" \
        "-DSTOP.PORT=${solrPort}" \
        "-DSTOP.KEY=${solrKey}" \
        "-Djetty.ssl.clientAuth=true" \
        "-Dhost=$(hostname --fqdn)" \
        "-Dcollection.configName=myConf" \
        "-DzkRun" \
        "-DnumShards=1" \
        "-Dbootstrap_confdir=${solrInstallDir}/node1/solr/quick-results-collection/conf" \
        >/dev/null 2>&1 &

    # Wait a few seconds for the server to start
    sleep ${serviceDelaySeconds} 

    # See if the server is started
    ps -ef | grep "solr/quick-results-collection" | grep -v "grep" >/dev/null 2>&1
    if [[ ${?} == 1 ]]; then
        # Failure to grep Solr is failure in a start scenario
        printf "${right2Column}" "${redText}FAILURE${normalText}"
    else
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
    fi 

}

# Stop Solr server
function stopSolrServer() {

    # If no Solr installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${solrInstallDir}" || ! -d "${solrInstallDir}" ]]; then
        log "Solr does not appear to be installed on this system. Exiting."
        exit 0
    fi

    printf "${left2Column}" "Stopping Solr server..."

    # See if Java is installed
    local java="$(which java)"
    if [[ ${?} != 0 ]]; then
        printf "${right2Column}" "${redText}FAILURE${normalText}" "(Could not find Java)"
        exit 1
    fi

    # Stop Solr
    "${java}" \
        -jar "${solrInstallDir}/node1/start.jar" \
        "-DSTOP.PORT=${solrPort}" \
        "-DSTOP.KEY=${solrKey}" \
        "--stop" \
        >/dev/null 2>&1

    # Wait a few seconds for the server to stop
    sleep ${serviceDelaySeconds} 

    # See if the server is stopped
    ps -ef | grep "solr/quick-results-collection" | grep -v "grep" >/dev/null 2>&1
    if [[ ${?} == 1 ]]; then
        # Failure to grep Solr is success in a stop scenario
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
    else
        printf "${right2Column}" "${redText}FAILURE${normalText}"
    fi 

}

# Prints the status of the DB2 server
function getDB2ServerStatus() {

    # If no DB2 installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${db2InstallDir}" || ! -d "${db2InstallDir}" ]]; then
        return
    fi

    printf "${left2Column}" "Server: DB2"

    # See if the server is running
    ps -ef | grep "db2sysc" | grep -v "grep" >/dev/null 2>&1

    if [[ ${?} == 0 ]]; then
        # If we found a match, the server is started
        printf "${right2Column}" "${greenText}STARTED${normalText}"
    else 
        # If we did not find a match, the server is stopped
        printf "${right2Column}" "${redText}STOPPED${normalText}"
    fi

}

# Start DB2 
function startDB2Server() {

    # If no DB2 installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${db2InstallDir}" || ! -d "${db2InstallDir}" ]]; then
        log "DB2 does not appear to be installed on this system. Exiting."
        exit 0
    fi

    printf "${left2Column}" "Starting DB2..."

    status=$(sudo -i -u "${db2InstanceUser}" "db2start")

    if [[ "${status}" =~ "SQL1063N" || "${status}" =~ "SQL1026N" ]]; then
        printf "${right2Column}" "${greenText}SUCCESS${normalText}" 
    else
        printf "${right2Column}" "${redText}FAILURE${normalText}" 
    fi

}

# Stop DB2
function stopDB2Server() {

    # If no DB2 installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${db2InstallDir}" || ! -d "${db2InstallDir}" ]]; then
        log "DB2 does not appear to be installed on this system. Exiting."
        exit 0
    fi

    printf "${left2Column}" "Stopping DB2..."

    status=$(sudo -i -u "${db2InstanceUser}" "db2stop")

    if [[ "${status}" =~ "SQL1064N" || "${status}" =~ "SQL1032N" ]]; then
        printf "${right2Column}" "${greenText}SUCCESS${normalText}" 
    elif [[ "${status}" =~ "SQL1025N" ]]; then
        printf "${right2Column}" "${redText}FAILURE${normalText} (active connections)"
    else
        printf "${right2Column}" "${redText}FAILURE${normalText}" 
    fi

}
