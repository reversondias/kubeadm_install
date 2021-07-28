install_calico(){

    echo -e "${INFO_LINE} Install Calico CNI in the cluter. ${END_LINE}"
    kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
}