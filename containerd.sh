GITHUB_HEADER="Accept: application/vnd.github.v3+json"
CONTAINERD_REPO_RELEASE_URL="https://api.github.com/repos/containerd/containerd/releases"

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
                      -H ${GITHUB_HEADER} ${CONTAINERD_REPO_RELEASE_URL} | \
                      jq '.[0] | if select ( .tag_name | contains("-rc.") ) then (.) else empty end | .tag_name'`
    if [ ! -z ${TAG_NAME} ]; then
        export RELEASE_INDEX=1
    else
        export RELEASE_INDEX=0
    fi
    export CONTAINERD_VERSION=`curl -s \
                      -H ${GITHUB_HEADER} ${CONTAINERD_REPO_RELEASE_URL} | \
                      jq --arg RELEASE_INDEX $RELEASE_INDEX '.[$RELEASE_INDEX|tonumber].name' | awk {'print $2'} | sed -e 's/\"//g'`
    export CONTAINERD_URL=`curl -s \
                        -H ${GITHUB_HEADER} ${CONTAINERD_REPO_RELEASE_URL} | \
                        jq --arg RELEASE_INDEX $RELEASE_INDEX --arg CONTAINERD_VERSION $CONTAINERD_VERSION '.[$RELEASE_INDEX|tonumber].assets[] | if .name == "containerd-"+$CONTAINERD_VERSION+"-linux-amd64.tar.gz" then(.) else empty end | .browser_download_url'`

else
    export CONTAINERD_URL=`curl -s \
                            -H ${GITHUB_HEADER} ${CONTAINERD_REPO_RELEASE_URL} | \
                            jq --arg CONTAINERD_VERSION $CONTAINERD_VERSION '.[].assets[] | if .name == "containerd-"+$CONTAINERD_VERSION+"-linux-amd64.tar.gz" then(.) else empty end | .browser_download_url'`
fi
echo -e "${INFO_LINE} The URL from binary ${CONTAINERD_URL}. ${END_LINE}"
echo -e "${INFO_LINE} Install ContainerD version ${CONTAINERD_VERSION}. ${END_LINE}"
export FILE_NAME="containerd-v${CONTAINERD_VERSION}-linux-amd64.tar.gz"
wget -q `echo ${CONTAINERD_URL} | sed -e 's/\"//g'` -O /tmp/${FILE_NAME}
tar --strip-components 1 -C /usr/local/bin/ -xvf /tmp/${FILE_NAME} 

echo -e "${INFO_LINE} Download and Install runc binary. ${END_LINE}"
export RUNC_URL=`curl -s \
                -H ${GITHUB_HEADER} https://api.github.com/repos/opencontainers/runc/releases | \
                jq '.[0].assets[] | if .name == "runc.amd64" then(.) else empty end | .browser_download_url'`

echo -e "${INFO_LINE} URL to download ${RUNC_URL}. ${END_LINE}"
wget -q `echo ${RUNC_URL}  | sed -e 's/\"//g'` -O /usr/local/bin/runc
chmod u+x /usr/local/bin/runc

echo -e "${INFO_LINE} Download and Install CNI-plugins  binary. ${END_LINE}"
export CNI_URL=`curl -s \
                -H ${GITHUB_HEADER} https://api.github.com/repos/containernetworking/plugins/releases | \
                jq '.[0].assets[] | select( .name | test("cni-plugins-linux-amd64.*.tgz$") ) | .browser_download_url'`
mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin 
echo -e "${INFO_LINE} URL to download ${CNI_URL}. ${END_LINE}"
wget -q `echo ${CNI_URL} | sed -e 's/\"//g'` -O /tmp/cni_plugin.tgz
tar -C /opt/cni/bin/ -xvf /tmp/cni_plugin.tgz
echo -e "${INFO_LINE} Configure CNI brdge conf file. ${END_LINE}"
echo -e "${COLOR_LINE} The default installation will enable the bridge CNI plugin. ${END_LINE}"
echo -e "${COLOR_LINE}"
read -p "~> Indicate IP range to configure (it's related with pods IP). Use the CIDR denotation.[Default: 172.16.0.0/16]: " CNI_IP_RANGE
echo -e "${END_LINE}"
cat <<EOF | sudo tee /etc/cni/net.d/99-bridge.conf
{
    "cniVersion": "0.4.0",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${CNI_IP_RANGE:-172.16.0.0/16}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

echo -e "${INFO_LINE} The configuration above was created in file /etc/cni/net.d/99-bridge.conf. It's using cniVersion 0.4.0. You can change as needed. ${END_LINE}"
### More information about CNI plugins find in the page -> https://www.cni.dev/plugins/current/

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

systemctl enable containerd
systemctl restart containerd
export CRI=0
}