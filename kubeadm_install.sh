#!/bin/bash

source ./containerd.sh
source ./docker.sh

export END_LINE='\e[0m'
export INFO_LINE='\e[1;32;47m[INFO]\e[0m\e[0;33m -'
export COLOR_LINE='\e[1;33m'
export WARN_LINE='\e[5;31;47m[WARN]\e[0m\e[0;31m -'
export OPT="I"
export K_VERSION="latest"
export CONTAINERD_VERSION="latest"
export CRI=1

if [ "${USER}" != "root" ]; then
    echo -e "${WARN_LINE}This script have to execute as a root to work! ${END_LINE}"
    exit 1
fi

echo -e "${INFO_LINE} It will install the latest version KubeAdm, kubelet and kubectl.${END_LINE}"
echo -e "${COLOR_LINE}"
read -p "--> Do you want refer a version? eg: 1.18.0 [default: latest]: " K_VERSION
echo -e "${END_LINE}"

echo -e "${INFO_LINE} Turn off swap and remove from /etc/fstab ${END_LINE}"
swapoff -a || echo -e "${WARN_LINE} Problem to turn off swap ${END_LINE}"

sed -i '/swap/d' /etc/fstab || echo -e "${WARN_LINE} Problem to remove swap from /etc/fstab ${END_LINE}"

echo -e "${INFO_LINE} Check if module br_netfilter is enabled. ${END_LINE}"
if [ `lsmod | grep br_netfilter | wc -l` -eq 0 ]; then
	echo -e "${INFO_LINE} Module is enable now. ${END_LINE}"
	modprobe br_netfilter
	echo br_netfilter >> /etc/modules-load.d/modules.conf
else
	echo -e "${INFO_LINE} Module br_netfilter already enable. ${END_LINE}"
fi

echo -e "${INFO_LINE} Enable to Linux see the bridge traffic. ${END_LINE}"
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system || echo -e "${WARN_LINE} Problem to enable kernel's modules. ${END_LINE}"

echo
echo -e "${COLOR_LINE}###############################################
#### YOU HAVE TO HAVE INSTALLED A RUNTIME.  ###
#### THE SCRIPT CAN KEEP[k] CRI, INSTALL    ### 
#### DOCKER[d] OR CONTAINERD[c],            ###
#### REMOVE AND INSTALL[r] THE DOKCER       ###
###############################################"
while [ ${CRI} -eq 1 ]; do
read -p "--> What do you want ? [k/d/c/r]: " OPT
echo -e "${END_LINE}"

case $OPT in
d | D)
install_docker
;;

c | C)
install_containerd
;;

r | R)
echo -e "${INFO_LINE} Remove docker installed. ${END_LINE}"
apt-get remove docker docker-engine docker.io containerd runc
install_docker
;;

k | K)
echo -e "${INFO_LINE} The docker install keep intact! ${END_LINE}"
export CRI=0
;;

*)
echo -e "${WARN_LINE} You selected one option that there is no exist!!! ${END_LINE}"
;;
esac
done

echo -e "${INFO_LINE} Installing kubeadm, kubelet and kubectl ${END_LINE}"
apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

if [ "${K_VERSION:-"latest"}" == "latest" ]; then
    echo -e "${INFO_LINE} Installing the \"latest\" version ${END_LINE}"
    apt-get update ; apt-get install -y kubelet kubeadm kubectl
else
    echo -e "${INFO_LINE} Installing the ${K_VERSION} version ${END_LINE}"
    apt-get update
    apt-get install -y \
        "kubelet=${K_VERSION}-00" \
        "kubeadm=${K_VERSION}-00" \
        "kubectl=${K_VERSION}-00"
fi
echo

echo -e "${INFO_LINE} The installation is ${COLOR_LINE}DONE!${END_LINE}"
echo -e "${COLOR_LINE}Now you can initiate a kubernetes using kubeadm and a simple way to do that execute the follow command:"
echo -e "~> ${END_LINE}kubeadm init"
echo
echo -e "${COLOR_LINE}If you want to ensure that the installation doesn't get some update accidentally running the below command: 
~> ${END_LINE}apt-mark hold kubelet kubeadm kubectl"
echo

