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
                        jq --arg RELEASE_INDEX $RELEASE_INDEX --arg CONTAINERD_VERSION $CONTAINERD_VERSION '.[$RELEASE_INDEX|tonumber].assets[] | if .name == "containerd-"+$CONTAINERD_VERSION+"-linux-amd64.tar.gz" then(.) else empty end | .browser_download_url'`

else
    export CONTAINERD_URL=`curl -s \
                            -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/containerd/containerd/releases | \
                            jq --arg CONTAINERD_VERSION $CONTAINERD_VERSION '.[].assets[] | if .name == "containerd-"+$CONTAINERD_VERSION+"-linux-amd64.tar.gz" then(.) else empty end | .browser_download_url'`
fi
echo -e "${INFO_LINE} The URL from binary ${CONTAINERD_URL}. ${END_LINE}"
echo -e "${INFO_LINE} Install ContainerD version ${CONTAINERD_VERSION}. ${END_LINE}"
export FILE_NAME="containerd-v${CONTAINERD_VERSION}-linux-amd64.tar.gz"
wget -q `echo ${CONTAINERD_URL} | sed -e 's/\"//g'` -O /tmp/${FILE_NAME}
tar --strip-components 1 -C /usr/local/bin/ -xvf /tmp/${FILE_NAME} bin/containerd 

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