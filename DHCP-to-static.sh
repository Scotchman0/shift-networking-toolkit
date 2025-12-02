#!/bin/bash
#This script will suggest an nmcli string to set up static interfacing based on existing DHCP rules
#It is designed to aide in testing and caution should be used whenever possible. Not for use in production environments.
#does not actually execute any changes - just prints suggested config options.

#safeties:
set -o nounset
set -o errexit
set -o pipefail

## get existing values of current config:

## abort if there's already a config file ##
if [ ! $(ls /etc/NetworkManager/system-connections) ];
  then
  if ip a | grep br-ex 
    then
    #pull base iface from br-ex:
    MACADDRESS=$(ip a | grep -A1 br-ex | grep ether | awk {'print $2'})
    PRIMARYIFACE=$(ip a | grep -B1 $MACADDRESS | grep -v br-ex | grep -v SLAVE | head -n 1 | awk {'print $2'} | awk -F ":" {'print $1'})
    else
    #pull base iface from Wired connection 1
    PRIMARYIFACE=$(grep interface-name /run/NetworkManager/system-connections/Wired\ connection\ 1.nmconnection| awk -F '=' {'print $2'})
  fi
  NODEIP=$(ip a | grep -E 'br-ex' | grep -v 169.254 | grep inet | awk {'print $2'})
  GATEWAY=$(ip route get 168.63.129.16 | awk {'print $3'} | head -n 1)
  CLUSTERSEARCH=$(awk '/^search/ { print $2; }' /etc/resolv.conf)
  SEARCHDOMAIN=$(awk '/^search/ { $1=""; print $0 }' /etc/resolv.conf)
  NAMESERVERS=$(awk '/^nameserver/ { print $2; }' /etc/resolv.conf | grep -v $(echo ${NODEIP} | awk -F '/' {'print $1'}))

    else
    echo "static configuration file found at /etc/NetworkManager/system-connections/ aborting"
    ls -lah /etc/NetworkManager/system-connections/
fi

#prep string:
echo ""
echo "suggested command to set up static interfacing (not executed, echoed only for review):"
echo "-----"
echo "#nmcli con add con-name ${PRIMARYIFACE} type ethernet ifname ${PRIMARYIFACE} ipv4.method manual ipv4.address ${NODEIP} ipv4.gateway ${GATEWAY} ipv4.dns $(for i in ${NAMESERVERS}; do echo -n ${i},; done) ipv4.dns-search $(for i in ${SEARCHDOMAIN}; do echo -n ${i},; done)"
echo "-----"
echo "NOTE: Cluster domain search string: ${CLUSTERSEARCH} should be automatically appended by the platform and may not need to be included in the above dns-search string."
echo "Do not apply this command unless you validate the result yourself first, applying invalid network configurations can result in a degraded cluster node state"
echo ""
exit 0