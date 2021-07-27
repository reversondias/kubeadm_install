install_docker(){
check_k8s_version_for_docker
if [ ${CRI} -eq 0 ]; then
    echo -e "${INFO_LINE} Installing Docker. ${END_LINE}"
    apt-get update
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        software-properties-common

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io

    export CRI=0
fi
}

check_k8s_version_for_docker(){

export MSG_VERSION="${WARN_LINE}The Kubernetes with version gather than 1.19.0 doesn't support Docker as runtime. Choose to install ContainerD as a runtime.${END_LINE}"

if [ "${K_VERSION:-"latest"}" == "latest"  ] ; then
        echo -e ${MSG_VERSION}
        export CRI=1
elif [ "`echo ${K_VERSION} | awk -F\. '{print $1$2}'`" -ge "1900" ]; then
        echo -e ${MSG_VERSION}
        export CRI=1
else
    export CRI=0
fi
}
