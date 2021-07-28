install_weave(){

    echo -e "${INFO_LINE} Install Weave Net CNI in the cluter. ${END_LINE}"
    kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&env.IPALLOC_RANGE=${CNI_IP_RANGE:-172.16.0.0/16}"

}