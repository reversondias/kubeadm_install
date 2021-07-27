# kubeadm_install
Shell script to install kubeadm  

For now the script is working with Ubuntu 18.04.

## Rutime Support
This scrtpt install on of the follows runtimes:  
- Docker
- ContaicerD

## Running the script
This script was written to running as a root. Because the intention is to use that in a non-production environment.  
You can run using root user or using `sudo` command.

First you need apply the execute permission.  
```
$ chmod u+x kubeadm_install.sh
```
If you are using the root user:  
```
./kubeadm_install.sh
```
If you are using a non-root user:  
```
sudo ./kubeadm_install.sh
```

## Modification after choose the Kubernetes version
Some requirements configuration most be made before the Kubernetes installation.  
This script will be the follow modification after the Kubernets version was choosen:  
 - Turn off swap and remove from _/etc/fstab _  
 - Enable module br_netfilter and keep it on _/etc/modules-load.d/modules.conf_ file  
 - Enables the kernel modules `net.bridge.bridge-nf-call-ip6tables` and `net.bridge.bridge-nf-call-iptables` using file _/etc/sysctl.d/k8s.conf_  