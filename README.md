# pi-filtered-wifi-setup
This is just a set of preliminary scripts for setting up a raspberry pi as a filtered access point or gateway. This is part of the e2guardian-angel project. This includes scripts for installing docker, kubernetes, deploying the e2guardian-angel stack, as well as networking scripts for setting up your pi as either a wifi access point or as a gateway. The utlimate goal is to make it as easy as possible for the average user to set it up. More detailed instructions will be written when the project is further along.

**Note:** all of these scripts must be run with sudo.

* install-docker.sh: installs necessary base software for the filter, i.e. docker and k3s.
* install-wifi.sh: Installs necessary software for a wifi hotspot.
* install-gateway.sh: Installs necessary software for a wired gateway.
* setupwifi.sh: Interactive script to set up a wifi hotspot
* deletewifi.sh: tears down the wifi hotspot that you have set up
* setupgateway.sh: sets up the wired gateway. **Note**: this requires an additional ethernet adapter, and you must know which interface is which. eth0 is usually the built-in adapter. Know which goes to the Internet and which goes to the filtered lan.
* TODO: create deletegateway.sh

TODO: scripts to start up squid/e2guardian content filter combo
