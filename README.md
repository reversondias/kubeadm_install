# kubeadm_install
Shell script to install kubeadm  

For now the script is working with Ubuntu 18.04.

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

