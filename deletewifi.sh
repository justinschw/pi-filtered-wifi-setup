#!/bin/bash

echo "This tool will help you set up a WiFi access point."

if [ "$EUID" -ne 0 ]
then echo "Please run this tool as an administrator."
     exit
fi

systemctl disable hostapd

# Restore /etc/dhcpcd.conf
dhcpcd_conf=/etc/dhcpcd.conf
cp ${dhcpcd_conf}.bak $dhcpcd_conf

# Disable routing
routed_ap=/etc/sysctl.d/routed-ap.conf
rm $routed_ap

# Disable masquerading
iptables_save=/etc/iptables.rules.old
iptables-restore $iptables_save
netfilter-persistent save

# Restore DHCP/DNS
dnsmasq_conf=/etc/dnsmasq.conf
cp ${dnsmasq_conf}.orig $dnsmasq_conf

reboot
