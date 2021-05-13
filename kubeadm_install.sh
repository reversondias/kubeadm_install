#!/bin/bash
export END_LINE='\e[0m'
export INFO_LINE='\e[1;32;47m[INFO]\e[0m\e[0;33m -'
export COLOR_LINE='\e[1;33m'
export WARN_LINE='\e[5;31;47m[WARN]\e[0m\e[0;31m -'
export OPT="I"
export K_VERSION="latest"
export CONTAINERD_VERSION="latest"
export DOCKER_INSTALL=1
export CRI=1

if [ "${USER}" != "root" ]; then
    echo -e "${WARN_LINE}This script have to execute as a root to work! ${END_LINE}"
    exit 1
fi

install_docker(){
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
}

install_containerd(){
echo -e "${INFO_LINE} Installing ContainerD. ${END_LINE}"
echo -e "${COLOR_LINE}"
read -p "--> Do you want refer a version? eg: 1.5.0 [default: latest]: " CONTAINERD_VERSION
echo -e "${END_LINE}"
echo -e "${INFO_LINE} Preparing environment. ${END_LINE}"
cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
echo

modprobe overlay
modprobe br_netfilter
echo

cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
echo

sysctl --system
apt-get update
apt-get install -y \
    jq wget tar
echo -e "${INFO_LINE} Download ContainerD binary. ${END_LINE}"
if [ "${CONTAINERD_VERSION:-"latest"}" == "latest" ]; then

    export TAG_NAME=`curl -s \
                      -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/containerd/containerd/releases | \
                      jq '.[0] | if select ( .tag_name | contains("-rc.") ) then (.) else empty end | .tag_name'`
    if [ ! -z ${TAG_NAME} ]; then
        export RELEASE_INDEX=1
    else
        export RELEASE_INDEX=0
    fi
    export CONTAINERD_VERSION=`curl -s \
                      -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/containerd/containerd/releases | \
                      jq --arg RELEASE_INDEX $RELEASE_INDEX '.[$RELEASE_INDEX|tonumber].name' | awk {'print $2'} | sed -e 's/\"//g'`
    export CONTAINERD_URL=`curl -s \
                        -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/containerd/containerd/releases | \
                        jq --arg RELEASE_INDEX $RELEASE_INDEX --arg CONTAINERD_VERSION $CONTAINERD_VERSION '.[$RELEASE_INDEX|tonumber].assets[] | if .name == "containerd-$CONTAINERD_VERSION-linux-amd64.tar.gz" then(.) else empty end | .browser_download_url'`

else
    export CONTAINERD_URL=`curl -s \
                            -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/containerd/containerd/releases | \
                            jq --arg CONTAINERD_VERSION $CONTAINERD_VERSION '.[].assets[] | if .name == "containerd-"+$CONTAINERD_VERSION+"-linux-amd64.tar.gz" then(.) else empty end | .browser_download_url'`
fi

echo -e "${INFO_LINE} Install ContainerD version ${CONTAINERD_VERSION}. ${END_LINE}"
wget -q ${CONTAINERD_URL} -o /tmp/containerd-v${CONTAINERD_VERSION}.tar.gz
tar -xvf /tmp/containerd-v${CONTAINERD_VERSION}.tar.gz bin/containerd -C /bin/
tar --strip-components 1 -C /bin/ -xvf /tmp/containerd-v${CONTAINERD_VERSION}.tar.gz bin/containerd 

mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
echo

cat <<EOF | tee /lib/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target

EOF

systemctl enablle containerd
systemctl restart containerd
export CRI=0
}

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
export DOCKER_INSTALL=0
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

