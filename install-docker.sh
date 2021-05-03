#!/bin/bash

if [ "$EUID" -ne 0 ]
then echo "Please run this tool as an administrator."
     exit
fi

# Install docker
curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh
ip link add name docker0 type bridge
ip addr add dev docker0 172.17.0.1/16
groupadd docker
gpasswd -a pi docker
curl -sfL https://get.k3s.io | sudo sh -

echo "K3S_KUBECONFIG_MODE=\"644\"" >> /etc/systemd/system/k3s.service.env

if [ -z "$(grep cgroup_memory /boot/cmdline.txt)" ]; then
    echo "no cgroups";
    sed -i '1 s/$/ cgroup_memory=1 cgroup_enable=memory/' cmdline.txt
fi

reboot
