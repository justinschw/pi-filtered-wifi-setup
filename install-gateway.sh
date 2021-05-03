#!/bin/bash

if [ "$EUID" -ne 0 ]
then echo "Please run this tool as an administrator."
     exit
fi

# Install gateway requirements
apt install -y dnsmasq ipcalc resolvconf
DEBIAN_FRONTEND=noninteractive apt install -y netfilter-persistent iptables-persistent

# Use predictable interface names
echo "$(head -n1 /boot/cmdline.txt) net.ifnames=0" >> /boot/cmdline.txt
echo "guardian-angel" > /etc/hostname
echo "127.0.0.1 guardian-angel" >> /etc/hosts

reboot
