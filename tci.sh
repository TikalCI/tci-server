#!/bin/bash

set -e

action='restart'
if [[ $# > 0 ]]; then
    action=$1
fi
if [[ "$action" == "upgrade" ]]; then
    git pull origin HEAD
fi


if [ ! -f tci.config ]; then
    cp templates/tci-server/tci.config.template tci.config
    action='init'
fi

mkdir -p customization/docker-compose
mkdir -p customization/files
mkdir -p customization/tci-server

source templates/tci-server/tci.config.template
source tci.config

if [[ "$action" == "init" || "$action" == "upgrade" ]]; then
    echo "Initializing tci-server. You'll need to restart the server after that action."
    . ./scripts/init-tci.sh
fi

if [ ! -f docker-compose.yml ]; then
    cp templates/tci-server/docker-compose.yml.template docker-compose.yml
fi
if [ ! -f tci-server-config.yml ]; then
    cp templates/tci-server/tci-server-config.yml.template tci-server-config.yml
fi

if [ ! -n "$TCI_HOST_IP" ]; then
    export TCI_HOST_IP="$(/sbin/ifconfig | grep 'inet ' | grep -Fv 127.0.0.1 | awk '{print $2}' | head -n 1 | sed -e 's/addr://')"
fi
export GIT_PRIVATE_KEY=`cat $GITHUB_PRIVATE_KEY_FILE_PATH`


if [[ "$action" == "info" ]]; then
    echo [Server host IP address] $TCI_HOST_IP
    echo [Private SSH key file path] $GITHUB_PRIVATE_KEY_FILE_PATH
    echo [TCI HTTP port] $JENKINS_HTTP_PORT_FOR_SLAVES
    echo [TCI JNLP port for slaves] $JENKINS_SLAVE_AGENT_PORT
    echo [TCI number of master executors] $JENKINS_ENV_EXECUTERS
    exit 0
fi

if [[ "$action" == "stop" || "$action" == "restart" ]]; then
   docker-compose down --remove-orphans
   sleep 2
fi

if [[ "$action" == "start"  || "$action" == "restart" ]]; then

    mkdir -p .data/jenkins_home/userContent
    cp -f images/tci-small-logo.png .data/jenkins_home/userContent | true
    sed "s/TCI_SERVER_TITLE_TEXT/${TCI_SERVER_TITLE_TEXT}/ ; s/TCI_SERVER_TITLE_COLOR/${TCI_SERVER_TITLE_COLOR}/ ; s/TCI_BANNER_COLOR/${TCI_BANNER_COLOR}/" templates/tci-server/tci.css.template > .data/jenkins_home/userContent/tci.css
    cp -f templates/tci-server/org.codefirst.SimpleThemeDecorator.xml.template .data/jenkins_home/org.codefirst.SimpleThemeDecorator.xml
    docker-compose up -d
    sleep 2
    docker-compose logs -f | while read LOGLINE
    do
        echo ${LOGLINE}
        [[ "${LOGLINE}" == *"Entering quiet mode. Done..."* ]] && pkill -P $$ docker-compose
    done
    echo "tci-server loaded successfully"
fi
