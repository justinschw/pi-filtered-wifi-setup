#!/bin/bash
set -e

echo "This tool will help you set up a WiFi access point."

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

read -p "Please enter a country code [US]: " country_code
country_code=${country_code:-"US"}

read -p "Please enter the wireless interface [wlan0]: " wifi
wifi=${wifi:-"wlan0"}

read -p "Please enter the WAN interface [eth0]: " wan
wan=${wan:-"eth0"}

read -p "Please enter the ssid [e2guardian-angel]: " ssid
ssid=${ssid:-"e2guardian-angel"}

read -p "Please enter a passphrase: " -s passphrase

systemctl unmask hostapd
systemctl enable hostapd

# Create /etc/dhcpcd.conf
dhcpcd_conf=/etc/dhcpcd.conf
sed '/# BEGIN HOSTAPD SECTION/q' $dhcpcd_conf | head -n -1 > ${dhcpcd_conf}.bak
cp ${dhcpcd_conf}.bak $dhcpcd_conf
echo "# BEGIN HOSTAPD SECTION
interface ${wifi}
    static ip_address=${router_ip}
    nohook wpa_supplicant
" >> $dhcpcd_conf

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
iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
netfilter-persistent save

# Configure DHCP/DNS
dnsmasq_conf=/etc/dnsmasq.conf
sed '/# BEGIN HOSTAPD SECTION/q' $dnsmasq_conf | head -n -1 > ${dnsmasq_conf}.orig
cp ${dnsmasq_conf}.orig $dnsmasq_conf

echo "# BEGIN HOSTAPD SECTION
interface=${wifi} # Listening interface
dhcp-range=${begin_ip},${end_ip},${netmask},24h # Pool of IP addresses served via DHCP
domain=wlan     # Local wireless DNS domain
address=/gw.wlan/${router_ip} # Alias for this router" >> $dnsmasq_conf

# Unblock wifi
rfkill unblock wlan

# Configure hostapd
hostapd_default=/etc/default/hostapd
sed '/# BEGIN HOSTAPD SECTION/q' $hostapd_default | head -n -1 > /tmp/hostapd.bak
cp /tmp/hostapd.bak /etc/default/hostapd
echo "# BEGIN HOSTAPD SECTION
DAEMON_CONF="/etc/hostapd/hostapd.conf"
" >> $hostapd_default

hostapd_conf=/etc/hostapd/hostapd.conf
echo "country_code=${country_code}
interface=${wifi}
ssid=${ssid}
hw_mode=g
channel=7
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${passphrase}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP" > $hostapd_conf

reboot
