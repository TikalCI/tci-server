#!/bin/bash

set -e

clear

function initTciScript {
    BG_RED='\033[0;41;93m'
    BG_GREEN='\033[0;31;42m'
    BG_BLUE='\033[0;44;93m'
    BLUE='\033[0;94m'
    YELLOW='\033[0;93m'
    NC='\033[0m' # No Color

    rm -rf temp 2> /dev/null | true
    mkdir -p temp
}

function initTciConfig {
    echo "#!/bin/bash" > temp/tci.config
    echo -e "" >> temp/tci.config
}

function inputVariable {

    TITLE=$1
    VARIABLE_NAME=$2
    VALUE=${!VARIABLE_NAME}
    echo -e -n "${TITLE}\n\t[${BLUE}${VALUE}${NC}]? "
    read -r
    if [[ "$REPLY" != "" ]]; then
        VALUE="$REPLY"
    fi
    echo "export $VARIABLE_NAME=${VALUE}" >> temp/tci.config
    export $VARIABLE_NAME=${VALUE}
}

function inputTextVariable {

    TITLE=$1
    VARIABLE_NAME=$2
    VALUE=${!VARIABLE_NAME}
    echo -e -n "${TITLE}\n\t[${BLUE}${VALUE}${NC}]? "
    read -r
    if [[ "$REPLY" != "" ]]; then
        VALUE="$REPLY"
    fi
    echo "export $VARIABLE_NAME='${VALUE}'" >> temp/tci.config
    export $VARIABLE_NAME='${VALUE}'
}

initTciScript
initTciConfig

inputVariable "tci-master Docker image" TCI_MASTER_VERSION
inputVariable "TCI host IP address (set to * for automatic IP calculation)" TCI_HOST_IP
inputVariable "Jenkins server HTTP port" JENKINS_HTTP_PORT_FOR_SLAVES
inputVariable "Jenkins JNLP port for slaves" JENKINS_SLAVE_AGENT_PORT
inputTextVariable "TCI customization folder root path" TCI_CUSTOMIZATION_FOLDER
inputVariable "Number of executers on master" JENKINS_ENV_EXECUTERS
inputTextVariable "TCI banner title" TCI_MASTER_TITLE_TEXT
inputVariable "TCI banner title color" TCI_MASTER_TITLE_COLOR
inputVariable "TCI banner background color" TCI_MASTER_BANNER_COLOR

cp temp/tci.config tci.config


