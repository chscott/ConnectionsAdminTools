#!/bin/bash
# connectToMongo.sh: Connect to the MongoDB microservice

# Source the prereqs
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "/etc/ictools.conf"
. "${scriptDir}/utils.sh"

function init() {

    checkForRoot
    checkForK8s

}

function commonCommands() {

    printf "%s\n" "${greenText}Common Mongo commands:${normalText}"
    printf "\t%s\n" "${greenText}show dbs: List available databases${normalText}" 
    printf "\t%s\n" "${greenText}use <database>: Connect to a database${normalText}"
    printf "\t%s\n" "${greenText}show collections: List available document collections (views)${normalText}"
    printf "\t%s\n" "${greenText}db.<collection>.find(): Print the documents in a collection${normalText}"
    printf "\t%s\n" "${greenText}db.<collection>.find({<key>:<value>}): Print the documents in a collection that have <key> matching <value>${normalText}"

}

init "${@}"

# Get an array of all Mongo pods
pods=($("${scriptDir}/getPodInfo.sh" --all | grep "mongo" | awk '{print $1}'))

# Try to connect to a pod
for pod in "${pods[@]}"; do

    log "Connecting to ${pod}..."
    commonCommands 

    "${kubectl}" exec "${pod}" --namespace "${icNamespace}" --container "mongo" --stdin --tty -- \
        "/usr/bin/mongo" \
        --ssl \
        --sslPEMKeyFile "/etc/ca/user_admin.pem" \
        --sslCAFile "/etc/ca/internal-ca-chain.cert.pem" \
        --host "${pod}.mongo.connections.svc.cluster.local" \
        --authenticationMechanism "MONGODB-X509" \
        --authenticationDatabase '$external' \
        --username "C=IE,ST=Ireland,L=Dublin,O=IBM,OU=Connections-Middleware-Clients,CN=admin,emailAddress=admin@mongodb"

    # If we successfully connected to a pod, exit. Otherwise, try the next one
    if [[ $? == 0 ]]; then
        exit 0
    fi

done
