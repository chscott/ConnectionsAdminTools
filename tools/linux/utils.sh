#!/bin/bash
# utils.sh

# Source prereqs
. "/etc/ictools.conf"

# Returns ID value from /etc/os-release or "unknown" if not found 
function getDistro() {

    local distro="unknown"

    if [[ -f "/etc/os-release" ]]; then
        distro="$(grep "^ID=" "/etc/os-release" | awk -F "=" '{print $2}' | tr -d '"')"
    fi

    echo "${distro}"

}

# Determines if the kernel on this system is at the provided level or later
# $1: Release string to check (in format w.x.y-z)
function isKernelAtLeast() {

    local releaseToCheck="${1}"
    local kernelAtLeastAsRecent="false"

    let releaseToCheckW=10#$(echo "${releaseToCheck}" | awk -F "." '{print $1}')
    let releaseToCheckX=10#$(echo "${releaseToCheck}" | awk -F "." '{print $2}')
    let releaseToCheckY=10#$(echo "${releaseToCheck}" | awk -F "." '{print $3}' | awk -F "-" '{print $1}')
    let releaseToCheckZ=10#$(echo "${releaseToCheck}" | awk -F "." '{print $3}' | awk -F "-" '{print $2}')
    let kernelW=10#$(uname -r | awk -F "." '{print $1}')
    let kernelX=10#$(uname -r | awk -F "." '{print $2}')
    let kernelY=10#$(uname -r | awk -F "." '{print $3}' | awk -F "-" '{print $1}')
    let kernelZ=10#$(uname -r | awk -F "." '{print $3}' | awk -F "-" '{print $2}')

    if (( kernelW > releaseToCheckW )); then
        # Kernel W is greater than Release W, so the kernel must be at least as recent
        kernelAtLeastAsRecent="true"
    elif (( kernelW < releaseToCheckW )); then
        # Kernel W is less than Release W, so the kernel cannot be at least as recent
        kernelAtLeastAsRecent="false"
    else
        # Kernel W is the same as Release W, so we need to check X
        if (( kernelX > releaseToCheckX )); then
            # Kernel X is greater than Release X, so the kernel must be at least as recent
            kernelAtLeastAsRecent="true"
        elif (( kernelX < releaseToCheckX )); then
            # Kernel X is less than Release X, so the kernel cannot be at least as recent
            kernelAtLeastAsRecent="false"
        else
            # Kernel X is the same as Release X, so we need to check Y 
            if (( kernelY > releaseToCheckY )); then
                # Kernel Y is greater than Release Y, so the kernel must be at least as recent
                kernelAtLeastAsRecent="true"
            elif (( kernelY < releaseToCheckY )); then
                # Kernel Y is less than Release Y, so the kernel cannot be at least as recent
                kernelAtLeastAsRecent="false"
            else
                # Kernel Y is the same as Release Y, so we need to check Z 
                if (( kernelZ > releaseToCheckZ )); then
                    # Kernel Z is greater than Release Z, so the kernel must be at least as recent
                    kernelAtLeastAsRecent="true"
                elif (( kernelZ < releaseToCheckZ )); then
                    # Kernel Z is less than Release Z, so the kernel cannot be at least as recent
                    kernelAtLeastAsRecent="false"
                else
                    # Kernel Z is the same as Release Z, so this kernel is the same release as the one being tested
                    kernelAtLeastAsRecent="true"
                fi
            fi
        fi
    fi

    echo "${kernelAtLeastAsRecent}"

}

# Returns VERSION_ID major number from /etc/os-release or -1 if not found
function getOSMajorVersion() {

    local majorVersion=-1

    if [[ -f "/etc/os-release" ]]; then
        let majorVersion=$(grep "^VERSION_ID=" "/etc/os-release" | awk -F "=" '{print $2}' | tr -d '"' | awk -F "." '{print $1}')
    fi

    echo ${majorVersion}

}

# Returns VERSION_ID minor number from /etc/os-release or -1 if not found
# This function is used for numeric comparison and must regard 16.04 as minor version 4 and not "04"
function getOSMinorVersion() {

    local minorVersion=-1

    if [[ "$(getDistro)" == "centos" ]]; then
        # CentOS uses /etc/system-release to store the RHEL equivalent version, including minor version. This is handy for equivalence operations.
        if [[ -f "/etc/system-release" ]]; then
            # Coerce to decimal
            let minorVersion=10#$(awk -F "." '{print $2}' "/etc/system-release")
        fi 
    else
        if [[ -f "/etc/os-release" ]]; then
            # Coerce to decimal
            let minorVersion=10#$(grep "^VERSION_ID=" "/etc/os-release" | awk -F "=" '{print $2}' | tr -d '"' | awk -F "." '{print $2}')
        fi
    fi

    echo ${minorVersion}

}

# Returns VERSION_ID minor number from /etc/os-release or -1 if not found
# This function is used for display and must regard 16.04 as minor version "04" and not 4
function getOSMinorVersionDisplay() {

    local minorVersion="-1"

    if [[ "$(getDistro)" == "centos" ]]; then
        # CentOS uses /etc/system-release to store the RHEL equivalent version, including minor version. This is handy for equivalence operations.
        if [[ -f "/etc/system-release" ]]; then
            minorVersion=$(awk -F "." '{print $2}' "/etc/system-release")
        fi 
    else
        if [[ -f "/etc/os-release" ]]; then
            minorVersion=$(grep "^VERSION_ID=" "/etc/os-release" | awk -F "=" '{print $2}' | tr -d '"' | awk -F "." '{print $2}')
        fi
    fi

    echo ${minorVersion}

}

# Returns the machine architecture
function getMachineArchitecture() {

    local machineArchitecture="$(uname -m)"

    echo "${machineArchitecture}"

}

# Returns the number of logical cores
function getLogicalCores() {

    local logicalCores=$(grep -c "^processor" "/proc/cpuinfo")

    echo ${logicalCores}

}

# Returns the amount of available memory
function getAvailableMemory() {

    local availableMemory=$(grep "MemAvailable:" "/proc/meminfo" | awk '{print $2}')
    
    echo ${availableMemory} 

}

# Returns the amount of total swap memory
function getSwapMemory() {

    local swapMemory=$(grep "SwapTotal:" "/proc/meminfo" | awk '{print $2}')
    
    echo ${swapMemory} 

}

# Returns the file system type for the given directory. If directory doesn't exist, returns the file system type for closest parent
function getFSTypeForDirectory() {

    local directory="${1}"
    local fsType="unknown"

    # Try running df on all directories in path, starting at the leaf and working backward. Use the first directory with FS info
    until df "${directory}" >/dev/null 2>&1; do
        directory="$(dirname "${directory}")"
    done
    # Get the FS type of the directory
    fsType=$(df --output=fstype "${directory}" | grep -v "^Type")

    echo "${fsType}"

}

# Returns whether or not d-type is enabled for xfs directory. If directory doesn't exist, returns the file system type for closest parent
function isDTypeEnabledForDirectory() {

    local directory="${1}"
    local dType="false"
    
    # Return false if xfs_info isn't available
    if command -v xfs_info >/dev/null 2>&1; then
        # Try running xfs_info on all directories in path, starting at the leaf and working backward. Use the first directory with XFS info
        until xfs_info "${directory}" >/dev/null 2>&1; do
            directory="$(dirname "${directory}")"
        done
        # Get the d-type of the directory
        dType=$(xfs_info "${directory}" | grep "ftype" | awk -F "ftype=" '{print $2}')
        if (( ${dType} == 1 )); then
            dType="true"
        else
            dType="false"
        fi
    fi

    echo "${dType}"

}

# Return number of K8s master node ports in use (6443, 2379, 2380, 10250-10252, 10255)
function checkForK8sMasterNodePortsInUse() {

    local activePorts=$(
        netstat --tcp --listen --numeric | \
        awk '{print $4}' | \
        awk -F ':' '{print $NF}' | \
        grep -c -E "^6443$|^2379$|^2380$|^1025[0-2]$|^10255$" \
    )

    echo ${activePorts}

}

# Return number of K8s worker node ports in use (10250, 10255, 30000-32767)
function checkForK8sWorkerNodePortsInUse() {

    local activePorts=$(
        netstat --tcp --listen --numeric | \
        awk '{print $4}' | \
        awk -F ':' '{print $NF}' | \
        grep -c -E "^10250$|^10255$|3[0-2][0-7[0-6][0-7]" \
    )

    echo ${activePorts}

}

# Determines if this system is supported for Component Pack. Support is the intersection of support for Docker, K8s and Helm.
# Docker 17.03 requirements: https://docs.docker.com/v17.03/engine/installation/linux/${distro}/#os-requirements
# Kubernetes 1.11 requirements: https://github.com/kubernetes/website/blob/release-1.11/content/en/docs/tasks/tools/install-kubeadm.md
function isCPSupportedPlatform() {

    # Support is explicit
    local isSupported="false"
    local distro="$(getDistro)"
    local majorVersion=$(getOSMajorVersion)
    local minorVersion=$(getOSMinorVersion)

    # Centos (7)
    if [[ "${distro}" == "centos" ]]; then
        if (( ${majorVersion} == 7 )); then 
            isSupported="true"
        fi
    # RHEL (7)
    elif [[ "${distro}" == "rhel" ]]; then
        if (( ${majorVersion} == 7 )); then 
            isSupported="true"
        fi
    # Fedora (25)
    elif [[ "${distro}" == "fedora" ]]; then
        if (( ${majorVersion} == 25 )); then 
            isSupported="true"
        fi
    # Debian (9)
    elif [[ "${distro}" == "debian" ]]; then
        if (( ${majorVersion} == 9 )); then 
            isSupported="true"
        fi
    # Ubuntu (16.04)
    elif [[ "${distro}" == "ubuntu" ]]; then
        if (( ${majorVersion} == 16 && ${minorVersion} == 4 )); then
            isSupported="true"
        fi
    fi 

    # Machine architecture must be x86_64
    if [[ "$(getMachineArchitecture)" != "x86_64" ]]; then
        isSupported="false"
    fi

    # Must have at least 2 CPUs (kubeadm requirement...treating this as logical cores)
    if (( $(getLogicalCores) < 2 )); then
        isSupported="false"
    fi

    # Must have at least 2 GB available memory (kubeadm requirement)
    if (( $(getAvailableMemory) < (2 * 1024 * 1024) )); then
        isSupported="false"
    fi

    # Swap must be disabled (kubeadm requirement)
    if (( $(getSwapMemory) > 0 )); then
        isSupported="false"
    fi

    echo "${isSupported}"

}

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

# Checks to see if Docker CE is installed
function isDockerCEInstalled() {

    local distro="$(getDistro)"
    local isInstalled="false"

    # CentOS/RHEL
    if [[ "${distro}" == "centos" || "${distro}" == "rhel" ]]; then
        if (( $(yum list installed "docker-ce" | grep -c "docker-ce") > 0 )) ; then isInstalled="true"; fi 
    # Fedora
    elif [[ "${distro}" == "fedora" ]]; then
        if (( $(dnf list installed "docker-ce" | grep -c "docker-ce") > 0 )) ; then isInstalled="true"; fi 
    # Debian/Ubuntu
    elif [[ "${distro}" == "debian" || "${distro}" == "ubuntu" ]]; then
        if (( $(dpkg-query --list | grep -c "docker-ce") > 0 )); then isInstalled="true"; fi 
    fi

    echo "${isInstalled}"

}

# Returns the version of Docker CE installed
function getDockerCEVersion() {

    local distro="$(getDistro)"
    local installedVersion=""

    if [[ "$(isDockerCEInstalled)" == "true" ]]; then
        # CentOS/RHEL
        if [[ "${distro}" == "centos" || "${distro}" == "rhel" ]]; then
            installedVersion="$(yum -q list installed "docker-ce" | grep "docker-ce" | awk '{print $2}' | awk -F '.' '{print $1"."$2}')"
        # Fedora
        elif [[ "${distro}" == "fedora" ]]; then
            installedVersion="$(dnf -q list installed "docker-ce" | grep "docker-ce" | awk '{print $2}' | awk -F '.' '{print $1"."$2}')"
        # Debian/Ubuntu
        elif [[ "${distro}" == "debian" || "${distro}" == "ubuntu" ]]; then
            installedVersion="$(if dpkg-query --list | grep "docker-ce" | awk '{print $3}' | awk -F '.' '{print $1"."$2}')"
        fi
    else
        installedVersion="not installed"
    fi

    echo "${installedVersion}"

}

# Tests to make sure Kubernetes is available on this system
function checkForK8s() {

    local script="$(basename "${0}")"

    if [[ ! -x "${kubectl}" ]]; then
        log "${script} can only run on Component Pack nodes. Exiting."
        exit 1
    fi

}

# Log message to stdout
# $1: message to log
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
# $1: (Optional) boolean (true returns the result via subshell, any other value prints to display)
function getIHSServerStatus() {

    local noDisplay="${1}"

    # If no IHS installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${ihsInstallDir}" || ! -d "${ihsInstallDir}" ]]; then
        return
    fi

    # Only print info if noDisplay is not true
    if [[ "${noDisplay}" != "true" ]]; then
        printf "${left2Column}" "Server: IHS"
    fi

    # See if the server is running
    if [[ $(ps -ef | grep "${ihsInstallDir}/bin/httpd" | grep -v "grep" | grep -c -v "admin.conf") > 0 ]]; then
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

# Start IHS server
function startIHSServer() {

    # If no IHS installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${ihsInstallDir}" || ! -d "${ihsInstallDir}" ]]; then
        log "IHS does not appear to be installed on this system. Exiting."
        exit 0
    fi

    printf "${left2Column}" "Starting IHS server..."

    if [[ "$(getIHSServerStatus "true")" == "STOPPED" ]]; then
        # If the server is stopped, start it 
        "${ihsInstallDir}/bin/apachectl" "start" >/dev/null 2>&1
        # Check to see if the server is started
        if [[ "$(getIHSServerStatus "true")" == "STARTED" ]]; then
            printf "${right2Column}" "${greenText}SUCCESS${normalText}"
        else
            printf "${right2Column}" "${redText}FAILURE${normalText}"
        fi 
    else
        # The server is already started, so report success
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
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

    if [[ "$(getIHSServerStatus "true")" == "STARTED" ]]; then
        # If the server is started, stop it
        "${ihsInstallDir}/bin/apachectl" "stop" >/dev/null 2>&1
        # Wait a few seconds for process termination 
        sleep ${serviceDelaySeconds} 
        # Kill any remaining processes
        ps -ef | grep "${ihsInstallDir}/bin" | grep -v "admin.conf" | grep -v "grep" | awk '{print $2}' | xargs -r kill -9 >/dev/null 2>&1
        # Check to see if server is stopped
        if [[ "$(getIHSServerStatus "true")" == "STOPPED" ]]; then
            printf "${right2Column}" "${greenText}SUCCESS${normalText}"
        else
            printf "${right2Column}" "${redText}FAILURE${normalText}"
        fi 
    else
        # The server is already stopped, so report success
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
    fi

}

# Prints the status of the IHS admin server
# $1: (Optional) boolean (true returns the result via subshell, any other value prints to display)
function getIHSAdminServerStatus() {

    local noDisplay="${1}"

    # If no IHS installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${ihsInstallDir}" || ! -d "${ihsInstallDir}" ]]; then
        return
    fi

    # Only print info if noDisplay is not true
    if [[ "${noDisplay}" != "true" ]]; then
        printf "${left2Column}" "Server: IHS Admin"
    fi

    # See if the server is running
    if [[ $(ps -ef | grep "${ihsInstallDir}/bin/httpd" | grep -v "grep" | grep -c "admin.conf") > 0 ]]; then
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

# Start IHS admin server
function startIHSAdminServer() {

    # If no IHS installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${ihsInstallDir}" || ! -d "${ihsInstallDir}" ]]; then
        log "IHS does not appear to be installed on this system. Exiting."
        exit 0
    fi

    printf "${left2Column}" "Starting IHS Admin server..."
    
    if [[ "$(getIHSAdminServerStatus "true")" == "STOPPED" ]]; then
        # If the server is stopped, start it 
        "${ihsInstallDir}/bin/adminctl" "start" >/dev/null 2>&1
        # Check to see if server is started
        if [[ "$(getIHSAdminServerStatus "true")" == "STARTED" ]]; then
            printf "${right2Column}" "${greenText}SUCCESS${normalText}"
        else
            printf "${right2Column}" "${redText}FAILURE${normalText}"
        fi 
    else
        # The server is already started, so report success
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
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

    if [[ "$(getIHSAdminServerStatus "true")" == "STARTED" ]]; then
        # If the server is started, stop it
        "${ihsInstallDir}/bin/adminctl" "stop" >/dev/null 2>&1
        # Wait a few seconds for process termination 
        sleep ${serviceDelaySeconds} 
        # Kill any remaining processes
        ps -ef | grep "${ihsInstallDir}/bin" | grep "admin.conf" | grep -v "grep" | awk '{print $2}' | xargs -r kill -9 >/dev/null 2>&1
        # Check to see if server is stopped
        if [[ "$(getIHSAdminServerStatus "true")" == "STOPPED" ]]; then
            printf "${right2Column}" "${greenText}SUCCESS${normalText}"
        else
            printf "${right2Column}" "${redText}FAILURE${normalText}"
        fi 
    else
        # The server is already stopped, so report success
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
    fi

}

# Prints the status of the NGINX server
# $1: (Optional) boolean (true returns the result via subshell, any other value prints to display)
function getNGINXServerStatus() {

    local noDisplay="${1}"

    # If the NGINX binary doesn't exist, do nothing 
    local nginx="$(which nginx)"
    if [[ ${?} != 0 ]]; then
        return
    fi

    # Only print info if noDisplay is not true
    if [[ "${noDisplay}" != "true" ]]; then
        printf "${left2Column}" "Server: NGINX"
    fi

    # See if the server is running
    if [[ $(ps -ef | grep -v "grep" | grep -c "nginx") > 0 ]]; then
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

# Start NGINX server
function startNGINXServer() {

    # If the NGINX binary doesn't exist, do nothing 
    local nginx="$(which nginx)"
    if [[ ${?} != 0 ]]; then
        return
    fi

    printf "${left2Column}" "Starting NGINX server..."

    if [[ "$(getNGINXServerStatus "true")" == "STOPPED" ]]; then
        # If the server is stopped, start it 
        "${nginx}" >/dev/null 2>&1
        # Check to see if the server is started
        if [[ "$(getNGINXServerStatus "true")" == "STARTED" ]]; then
            printf "${right2Column}" "${greenText}SUCCESS${normalText}"
        else
            printf "${right2Column}" "${redText}FAILURE${normalText}"
        fi 
    else
        # The server is already started, so report success
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
    fi
    
}

# Stop NGINX server
function stopNGINXServer() {

    # If the NGINX binary doesn't exist, do nothing 
    local nginx="$(which nginx)"
    if [[ ${?} != 0 ]]; then
        return
    fi

    printf "${left2Column}" "Stopping NGINX server..."

    if [[ "$(getNGINXServerStatus "true")" == "STARTED" ]]; then
        # If the server is started, stop it
        "${nginx}" -s stop >/dev/null 2>&1
        # Wait a few seconds for process termination 
        sleep ${serviceDelaySeconds} 
        # Kill any remaining processes
        ps -ef | grep "nginx" | grep -v "grep" | awk '{print $2}' | xargs -r kill -9 >/dev/null 2>&1
        # Check to see if server is stopped
        if [[ "$(getNGINXServerStatus "true")" == "STOPPED" ]]; then
            printf "${right2Column}" "${greenText}SUCCESS${normalText}"
        else
            printf "${right2Column}" "${redText}FAILURE${normalText}"
        fi 
    else
        # The server is already stopped, so report success
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
    fi

}

# Prints the status of the Solr server
# $1: (Optional) boolean (true returns the result via subshell, any other value prints to display)
function getSolrServerStatus() {

    local noDisplay="${1}"

    # If no Solr installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${solrInstallDir}" || ! -d "${solrInstallDir}" ]]; then
        return
    fi

    # Only print info if noDisplay is not true
    if [[ "${noDisplay}" != "true" ]]; then
        printf "${left2Column}" "Server: Solr"
    fi

    # See if the server is running
    if [[ $(ps -ef | grep -v "grep" | grep -c "solr/quick-results-collection") > 0 ]]; then
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

    if [[ "$(getSolrServerStatus "true")" == "STOPPED" ]]; then
        # If the server is stopped, start it 
        cd "${solrInstallDir}/node1" 2>/dev/null
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
        # Check to see if the server is started
        if [[ "$(getSolrServerStatus "true")" == "STARTED" ]]; then
            printf "${right2Column}" "${greenText}SUCCESS${normalText}"
        else
            printf "${right2Column}" "${redText}FAILURE${normalText}"
        fi 
    else
        # The server is already started, so report success
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

    if [[ "$(getSolrServerStatus "true")" == "STARTED" ]]; then
        # If the server is started, stop it 
        "${java}" \
            -jar "${solrInstallDir}/node1/start.jar" \
            "-DSTOP.PORT=${solrPort}" \
            "-DSTOP.KEY=${solrKey}" \
            "--stop" \
            >/dev/null 2>&1
        # Wait a few seconds for the server to stop
        sleep ${serviceDelaySeconds} 
        # Check to see if the server is stopped
        if [[ "$(getSolrServerStatus "true")" == "STOPPED" ]]; then
            printf "${right2Column}" "${greenText}SUCCESS${normalText}"
        else
            printf "${right2Column}" "${redText}FAILURE${normalText}"
        fi 
    else
        # The server is already stopped, so report success
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
    fi

}

# Prints the status of the DB2 server
# $1: (Optional) boolean (true returns the result via subshell, any other value prints to display)
function getDB2ServerStatus() {

    local noDisplay="${1}"

    # If no DB2 installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${db2InstallDir}" || ! -d "${db2InstallDir}" ]]; then
        return
    fi

    # Only print info if noDisplay is not true
    if [[ "${noDisplay}" != "true" ]]; then
        printf "${left2Column}" "Server: DB2"
    fi

    # See if the server is running
    if [[ $(ps -ef | grep -v "grep" | grep -c "db2sysc") > 0 ]]; then
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

# Start DB2 
function startDB2Server() {

    # If no DB2 installation directory is specified in ictools.conf or the directory doesn't exist, do nothing
    if [[ -z "${db2InstallDir}" || ! -d "${db2InstallDir}" ]]; then
        log "DB2 does not appear to be installed on this system. Exiting."
        exit 0
    fi

    printf "${left2Column}" "Starting DB2..."

    if [[ "$(getDB2ServerStatus "true")" == "STOPPED" ]]; then
        # If the server is stopped, start it 
        status=$(sudo -i -u "${db2InstanceUser}" "db2start")
        # Check to see if the server is started
        if [[ "$(getDB2ServerStatus "true")" == "STARTED" ]]; then
            printf "${right2Column}" "${greenText}SUCCESS${normalText}"
        else
            printf "${right2Column}" "${redText}FAILURE${normalText}"
        fi 
    else
        # The server is already started, so report success
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
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

    if [[ "$(getDB2ServerStatus "true")" == "STARTED" ]]; then
        # If the server is started, stop it 
        status=$(sudo -i -u "${db2InstanceUser}" "db2stop")
        if [[ "${status}" =~ "SQL1064N" || "${status}" =~ "SQL1032N" ]]; then
            printf "${right2Column}" "${greenText}SUCCESS${normalText}" 
        elif [[ "${status}" =~ "SQL1025N" ]]; then
            printf "${right2Column}" "${redText}FAILURE${normalText} (active connections)"
        else
            printf "${right2Column}" "${redText}FAILURE${normalText}" 
        fi
    else
        # The server is already stopped, so report success
        printf "${right2Column}" "${greenText}SUCCESS${normalText}"
    fi

}
