kubeadm_init(){

    echo -e "${INFO_LINE} The IP range will be configure to pods network is ${COLOR_LINE} ${CNI_IP_RANGE:-172.16.0.0/16} ${END_LINE}"

    kubeadm init --pod-network-cidr ${CNI_IP_RANGE:-172.16.0.0/16}

    echo
    echo -e "${INFO_LINE} Configuring kubeconfig file to directory home: ${HOME} ${END_LINE}"
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $SUDO_UID:$SUDO_GID $HOME/.kube/config
    echo
    echo -e "${INFO_LINE} Configure kubectl completion to bash ${END_LINE}"
    kubectl completion bash > /etc/bash_completion.d/kubectl
    source /etc/bash_completion.d/kubectl
}