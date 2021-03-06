#!/bin/bash

set -e

function initTciScript {
    BG_RED='\033[0;41;93m'
    BG_GREEN='\033[0;31;42m'
    BG_BLUE='\033[0;44;93m'
    BLUE='\033[0;94m'
    BOLDBLUE='\033[1;94m'
    YELLOW='\033[0;93m'
    NC='\033[0m' # No Color

    rm -rf temp 2> /dev/null | true
}

function usage {
    echo -e "\n${BG_BLUE}TCI command usage${NC}\n"
    echo -e "${BLUE}tci.sh${NC} ${BOLDBLUE}<action>${NC} ${BLUE}[option]${NC}"
    echo -e "\n  where ${BOLDBLUE}<action>${NC} is ..."
    echo -e "\t${BOLDBLUE}usage${NC} - show this usage description."
    echo -e "\t${BOLDBLUE}version${NC} - show tci-server version information."
    echo -e "\t${BOLDBLUE}status${NC} - show tci-server server status & version information."
    echo -e "\t${BOLDBLUE}init${NC} - initialize tci-server settings."
    echo -e "\t${BOLDBLUE}start${NC} - start the tci-server."
    echo -e "\t${BOLDBLUE}stop${NC} - stop the tci-server."
    echo -e "\t${BOLDBLUE}restart${NC} - restart the tci-server."
    echo -e "\t${BOLDBLUE}apply${NC} - apply changes in the 'setup' folder on the tci-server."
    echo -e "\t${BOLDBLUE}upgrade${NC} ${BLUE}[git-tag]${NC} - upgrage the tci-server version. If no git-tag specified, upgrade to the latest on 'master' branch."
    echo -e "\t${BOLDBLUE}log${NC} - tail the docker-compose log."
    echo -e "\t${BOLDBLUE}iptest${NC} - test whether the automatic LAN ip detection works OK."
}

function upgrade {
    if [[ -d customization && ! -d setup ]]; then
        mv customization setup
    fi

    if [[ $# > 1 ]]; then
        version=$2
        git checkout $version 2> /dev/null | true
    else
        version=latest
        git checkout master  2> /dev/null | true
        git pull origin master 2> /dev/null | true
    fi
    hash=`git rev-parse --short=8 HEAD` 2> /dev/null | true
    mkdir -p info/version
    echo -e "[Version]\t${BLUE}${version}${NC}" > info/version/version.txt
    echo -e "[Hash]\t\t${BLUE}${hash}${NC}" >> info/version/version.txt

    echo -e "\n${BG_RED}NOTE:${NC} You need to run again with '${BG_RED}init${NC}' action\n"
}

function ipTest {
    export TCI_HOST_IP="$(/sbin/ifconfig | grep 'inet ' | grep -Fv 127.0.0.1 | awk '{print $2}' | head -n 1 | sed -e 's/addr://')"
    echo -e "\nIP: ${BG_BLUE}${TCI_HOST_IP}${NC}\n"
}

function setupTciScript {
    if [ ! -f tci.config ]; then
        cp templates/tci-server/tci.config.template tci.config
        action='init'
    fi

    source templates/tci-server/tci.config.template
    source tci.config

    if [[ "$action" == "init" ]]; then
        . ./scripts/init-tci.sh
    fi

    mkdir -p cust/docker-compose
    rm -rf setup | true
    mkdir -p setup/docker-compose
    if [ ! -f setup/docker-compose/docker-compose.yml.template ]; then
        cp templates/docker-compose/docker-compose.yml.template setup/docker-compose/docker-compose.yml.template
    fi
    cp -n templates/customized/docker-compose/*.yml cust/docker-compose/ 2> /dev/null | true
    cp -f ${TCI_CUSTOMIZATION_FOLDER}/docker-compose/*.yml setup/docker-compose/ 2> /dev/null | true
    echo "# PLEASE NOTICE:" > docker-compose.yml
    echo "# This is a generated file, so any change in it will be lost on the next TCI action!" >> docker-compose.yml
    echo "" >> docker-compose.yml
    cat setup/docker-compose/docker-compose.yml.template >> docker-compose.yml
    numberOfFiles=`ls -1q setup/docker-compose/*.yml 2> /dev/null | wc -l | xargs`
    if [[ "$numberOfFiles" != "0" ]]; then
        cat setup/docker-compose/*.yml >> docker-compose.yml | true
    fi

    mkdir -p setup/tci-master
    mkdir -p cust/tci-master
    cp -n templates/customized/tci-master/*.yml cust/tci-master/ 2> /dev/null | true
    cp -f templates/tci-master/*.yml setup/tci-master/ 2> /dev/null | true
    cp -f ${TCI_CUSTOMIZATION_FOLDER}/tci-master/*.yml setup/tci-master/ 2> /dev/null | true
    echo "# PLEASE NOTICE:" > tci-master-config.yml
    echo "# This is a generated file, so any change in it will be lost on the next TCI action!" >> tci-master-config.yml
    echo "" >> tci-master-config.yml
    numberOfFiles=`ls -1q setup/tci-master/*.yml 2> /dev/null | wc -l | xargs`
    cat setup/tci-master/*.yml >> tci-master-config.yml | true

    mkdir -p setup/userContent
    mkdir -p cust/userContent
    cp -n templates/customized/userContent/*.yml cust/userContent/ 2> /dev/null | true
    cp -n templates/userContent/* setup/userContent/ 2> /dev/null | true
    cp -f ${TCI_CUSTOMIZATION_FOLDER}/userContent/* setup/userContent/ 2> /dev/null | true
    mkdir -p .data/jenkins_home/userContent
    sed "s/TCI_MASTER_TITLE_TEXT/${TCI_MASTER_TITLE_TEXT}/ ; s/TCI_MASTER_TITLE_COLOR/${TCI_MASTER_TITLE_COLOR}/ ; s/TCI_MASTER_BANNER_COLOR/${TCI_MASTER_BANNER_COLOR}/" templates/tci-server/tci.css.template > setup/userContent/tci.css
    cp setup/userContent/* .data/jenkins_home/userContent 2> /dev/null | true

    mkdir -p setup/files
    cp -n -R templates/files/* setup/files/ 2> /dev/null | true
    cp -R setup/files/* . 2> /dev/null | true

    mkdir -p setup/plugins
    mkdir -p cust/plugins
    cp -n -R templates/plugins/* setup/plugins/ 2> /dev/null | true
    cp -f ${TCI_CUSTOMIZATION_FOLDER}/plugins/* setup/plugins/ 2> /dev/null | true
    export JENKINS_ENV_PLUGINS=`awk -v ORS=, '{ print $1 }' setup/plugins/* | sed 's/,$//'`

    if [[ ! -n "$TCI_HOST_IP" || "$TCI_HOST_IP" == "*" ]]; then
        export TCI_HOST_IP="$(/sbin/ifconfig | grep 'inet ' | grep -Fv 127.0.0.1 | awk '{print $2}' | head -n 1 | sed -e 's/addr://')"
    fi

    if [[ "$action" == "init" ]]; then
        exit 0
    fi
}

function info {
    echo -e "\n${BG_BLUE}TCI MASTER SERVER INFORMATION${NC}\n"
    echo -e "[Server host IP address]\t${BLUE}$TCI_HOST_IP${NC}"
    echo -e "[TCI HTTP port]\t\t\t${BLUE}$JENKINS_HTTP_PORT_FOR_SLAVES${NC}"
    echo -e "[TCI JNLP port for slaves]\t${BLUE}$JENKINS_SLAVE_AGENT_PORT${NC}"
    echo -e "[Number of master executors]\t${BLUE}$JENKINS_ENV_EXECUTERS${NC}"
}

function version {
    if [[ ! -f info/version/version.txt ]]; then
        version=latest
        mkdir -p info/version
        echo -e "[Version]\t${BLUE}${version}${NC}" > info/version/version.txt
        echo -e "[Hash]\t\t${BLUE}${hash}${NC}" >> info/version/version.txt
    fi
    echo -e "\n${BG_BLUE}TCI MASTER VERSION INFORMATION${NC}\n"
    cat info/version/version.txt
}

function stopTciServer {
   docker-compose down --remove-orphans
   sleep 2
}

function startTciServer {
    docker-compose up -d
    sleep 2
}

function showTciServerStatus {
    status=`curl -s -I -m 5 http://localhost:$JENKINS_HTTP_PORT_FOR_SLAVES | grep "403" | wc -l | xargs`
    if [[ "$status" == "1" ]]; then
        echo -e "\n${BLUE}[TCI status] ${BG_GREEN}tci-server is up and running${NC}\n"
    else
        status=`curl -s -I -m 5 http://localhost:$JENKINS_HTTP_PORT_FOR_SLAVES | grep "401" | wc -l | xargs`
        if [[ "$status" == "1" ]]; then
            echo -e "\n${BLUE}[TCI status] ${BG_GREEN}tci-server is up and running${NC}\n"
        else
            status=`curl -s -I -m 5 http://localhost:$JENKINS_HTTP_PORT_FOR_SLAVES | grep "503" | wc -l | xargs`
            if [[ "$status" == "1" ]]; then
                echo -e "\n${BLUE}[TCI status] ${BG_RED}tci-server is starting${NC}\n"
            else
                echo -e "\n${BLUE}[TCI status] ${BG_RED}tci-server is down${NC}\n"
            fi
        fi
    fi
}

function tailTciServerLog {
    SECONDS=0
    docker-compose logs -f -t --tail="1"  | while read LOGLINE
    do
        echo -e "${BLUE}[ET:${SECONDS}s]${NC} ${LOGLINE}"
        if [[ $# > 0 && "${LOGLINE}" == *"$1"* ]]; then
            pkill -P $$ docker-compose
        fi
    done
}

initTciScript

if [[ $# > 0 ]]; then
    action=$1
else
    usage
    exit 1
fi

if [[ "$action" == "iptest" ]]; then
    ipTest
    exit 0
fi

if [[ "$action" == "upgrade" ]]; then
    upgrade
    exit 0
fi

setupTciScript

if [[ "$action" == "apply" ]]; then
    tailTciServerLog "Running update-config.sh. Done"
    exit 0
fi

if [[ "$action" == "info" ]]; then
    info
    exit 0
fi

if [[ "$action" == "info" || "$action" == "version" ]]; then
    version
    info
    exit 0
fi

if [[ "$action" == "status" ]]; then
    showTciServerStatus
    exit 0
fi

if [[ "$action" == "stop" ]]; then
    stopTciServer
    showTciServerStatus
    exit 0
fi

if [[ "$action" == "restart" ]]; then
    stopTciServer
    startTciServer
    tailTciServerLog "Entering quiet mode. Done..."
    showTciServerStatus
    exit 0
fi

if [[ "$action" == "start" ]]; then
    startTciServer
    tailTciServerLog "Entering quiet mode. Done..."
    showTciServerStatus
    exit 0
fi

if [[ "$action" == "log" ]]; then
    tailTciServerLog
    exit 0
fi

usage
