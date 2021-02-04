#!/bin/bash

# Install docker
curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh
ip link add name docker0 type bridge
ip addr add dev docker0 172.17.0.1/16
groupadd docker
gpasswd -a pi docker

# Install wifi requirements
apt install hostapd
systemctl unmask hostapd
systemctl enable hostapd
apt install dnsmasq
DEBIAN_FRONTEND=noninteractive apt install -y netfilter-persistent iptables-persistent

