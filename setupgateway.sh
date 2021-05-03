#!/bin/bash
set -e

echo "This tool will help you set up a gateway."

if [ "$EUID" -ne 0 ]
then echo "Please run this tool as an administrator."
    exit
fi

read -p "Please choose a network [192.168.4.0/24]: " network
network=${network:-"192.168.4.0/24"}
ip=$(echo $network | cut -d'/' -f 1)
mask=$(echo $network | cut -d'/' -f 2)
for part in `echo $ip | tr "." " "`; do
  if [ "$part" -lt 0 ] || [ "$part" -gt 254 ]; then
    echo "Invalid IP range: $ip"
    exit -1
  fi
done
if [ "$mask" -lt 0 ] || [ "$mask" -gt 32 ]; then
  echo "Invalid mask: $mask"
  exit -1
fi
router_ip=`ipcalc $network | grep HostMin | xargs | cut -d' ' -f 2`
base=`echo $router_ip | cut -d'.' -f1-3`
last_octet=`echo $router_ip | cut -d'.' -f4`
begin_ip=${base}.$((last_octet+1))
end_ip=`ipcalc $network | grep HostMax | xargs | cut -d' ' -f 2`
netmask=`ipcalc $network | grep Netmask | xargs | cut -d' ' -f2`

read -p "Please enter the LAN interface [eth1]: " lan
lan=${lan:-"eth1"}

read -p "Please enter the WAN interface [eth0]: " wan
wan=${wan:-"eth0"}

read -p "Please choose a domain name for your network [guardian.angel.local]: " domain
domain=${domain:-"guardian.angel.local"}

# Create /etc/dhcpcd.conf
dhcpcd_conf=/etc/dhcpcd.conf
sed '/# BEGIN STATICIP SECTION/q' $dhcpcd_conf | head -n -1 > ${dhcpcd_conf}.bak
cp ${dhcpcd_conf}.bak $dhcpcd_conf
echo "# BEGIN STATICIP SECTION
interface ${lan}
    static ip_address=${router_ip}
" >> $dhcpcd_conf

# Install and configure dnsmasq
dnsmasq_conf=/etc/dnsmasq.conf
sed '/# BEGIN HOSTAPD SECTION/q' $dnsmasq_conf | head -n -1 > ${dnsmasq_conf}.orig
cp ${dnsmasq_conf}.orig $dnsmasq_conf

echo "# BEGIN DNS section
interface=${lan}
listen-address=127.0.0.1
domain=${domain}
dhcp-range=${begin_ip},${end_ip},${netmask},24h
" >> $dnsmasq_conf

# Configure /etc/network/interfaces
interfaces_conf=/etc/network/interfaces
cp ${interfaces_conf} ${interfaces_conf}.orig

echo "# interfaces(5) file used by ifup(8) and ifdown(8)

# Please note that this file is written to be used with dhcpcd
# For static IP, consult /etc/dhcpcd.conf and 'man dhcpcd.conf'

# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d/

auto lo
iface lo inet loopback

auto ${wan}
iface ${wan} inet dhcp

auto ${lan}
iface ${lan} inet static
      address ${router_ip}
      network ${base}.0
      netmask ${netmask}" >> ${interfaces_conf}

# Enable routing
routed_ap=/etc/sysctl.d/routed-ap.conf
echo "# https://www.raspberrypi.org/documentation/configuration/wireless/access-point-routed.md
# Enable IPv4 routing
net.ipv4.ip_forward=1" > $routed_ap

# Enable masquerading
iptables_save=/etc/iptables.rules.old
if [ ! -f $iptables_save ]; then
  iptables-save > $iptables_save
fi
iptables-restore $iptables_save
iptables -t nat -A POSTROUTING -o $wan -j MASQUERADE
iptables -A FORWARD -i $wan -o $lan -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $lan -o $wan -j ACCEPT
netfilter-persistent save

# Reboot for networking changes to take effect
reboot
