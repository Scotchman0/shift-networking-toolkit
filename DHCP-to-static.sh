#!/bin/bash
#This script will suggest an nmcli string to set up static interfacing based on existing DHCP rules
#It is designed to aide in testing and caution should be used whenever possible. Not for use in production environments.
#does not actually execute any changes - just prints suggested config options.

#WARNINGS: This script makes a few assumptions:
#1. assumes br-ex is up/available and this is OVNkuberentes hosted node
#2. assumes we are using the standard/supported network definition files at /etc/NetworkManager/system-connections - does not check for legacy files

#safeties:
set -o errexit

## get existing values of current config:

if ip addr show br-ex
  then
    #pull base iface from br-ex:
    MACADDRESS=$(ip a | grep -A1 br-ex | grep ether | awk {'print $2'})
    PRIMARYIFACE=$(ip a | grep -B1 $MACADDRESS | grep -v br-ex | grep -v SLAVE | head -n 1 | awk {'print $2'} | awk -F ":" {'print $1'})
  else
    #advise br-ex is not UP, and therefore we cannot determine the correct link - share possible primaryIFACE names:
    echo "br-ex interface is not available/ready - exiting"
    exit 1
fi

#set definitions
NODEIP=$(ip -o -4 addr show br-ex | awk '!/169\.254/ {print $4}')
NODEIPV6=$(ip -o -6 addr show br-ex | awk '!/169\.254/ {print $4}')
GATEWAY=$(ip -o -4 route | grep default | awk {'print $3'} | head -n 1)
GATEWAYV6=$(ip -o -6 route | grep default | awk {'print $3'} | head -n 1)
CLUSTERSEARCH=$(awk '/^search/ { print $2; }' /etc/resolv.conf)
SEARCHDOMAIN=$(awk '/^search/ { $1=""; print $0 }' /etc/resolv.conf)
NAMESERVERS=$(awk '/^nameserver/ { print $2; }' /etc/resolv.conf | grep -v $(echo ${NODEIP} | awk -F '/' {'print $1'}))

#prep string:
#Is there already an nmconnection file?
if [ $(ls /etc/NetworkManager/system-connections | grep ${PRIMARYIFACE}) ]
  then 
    #iface exists as a connection file - is it auto?
    if nmcli con show ${PRIMARYIFACE} | grep ipv4.method | grep auto
      then
        if nmcli con show ${PRIMARYIFACE} | grep ipv6.method | grep auto
          then
          #IPV6 and IPV4 method.auto
          ASSEMBLEDSTRING=$(echo "#nmcli con mod ${PRIMARYIFACE} type ethernet ifname ${PRIMARYIFACE} ipv4.method manual ipv4.address ${NODEIP} ipv4.gateway ${GATEWAY} ipv6.method manual ipv6.address ${NODEIPV6} ipv6.gateway ${GATEWAYV6} ipv4.dns $(for i in ${NAMESERVERS}; do echo -n ${i},; done) ipv4.dns-search $(for i in ${SEARCHDOMAIN}; do echo -n ${i},; done)")
          else
          #ipv4 is auto, IPV6 is manual already - offer conversion only for ipv4:
          ASSEMBLEDSTRING=$(echo "#nmcli con mod ${PRIMARYIFACE} type ethernet ifname ${PRIMARYIFACE} ipv4.method manual ipv4.address ${NODEIP} ipv4.gateway ${GATEWAY} ipv4.dns $(for i in ${NAMESERVERS}; do echo -n ${i},; done) ipv4.dns-search $(for i in ${SEARCHDOMAIN}; do echo -n ${i},; done)")
        fi
      else
        #ipv4 method is already static, abort.
        echo "iface definition for ${PRIMARYIFACE} exists at /etc/NetworkManager/system-connections/ and is not ipv4.method=auto, aborting"
        exit 1
    fi
  else
    #iface doesn't exist as a static definition yet, so suggest creating it with both configs if available:
    if [[ ! $(ip -o -6 addr show br-ex) ]]
      then 
        #create ipv4 static only
        ASSEMBLEDSTRING=$(echo "#nmcli con add con-name ${PRIMARYIFACE} type ethernet ifname ${PRIMARYIFACE} ipv4.method manual ipv4.address ${NODEIP} ipv4.gateway ${GATEWAY} ipv4.dns $(for i in ${NAMESERVERS}; do echo -n ${i},; done) ipv4.dns-search $(for i in ${SEARCHDOMAIN}; do echo -n ${i},; done)")
      else
        # create ipv4/ipv6 static:
        ASSEMBLEDSTRING=$(echo "#nmcli con add con-name ${PRIMARYIFACE} type ethernet ifname ${PRIMARYIFACE} ipv4.method manual ipv4.address ${NODEIP} ipv4.gateway ${GATEWAY} ipv6.method manual ipv6.address ${NODEIPV6} ipv6.gateway ${GATEWAYV6} ipv4.dns $(for i in ${NAMESERVERS}; do echo -n ${i},; done) ipv4.dns-search $(for i in ${SEARCHDOMAIN}; do echo -n ${i},; done)")
    fi
fi

echo ""
echo "suggested command to set up static interfacing (not executed, echoed only for review):"
echo "-----"
echo "$ASSEMBLEDSTRING"
echo "-----"
echo "NOTE: If default gateway for IPV6 isn't defined, remove 'ipv6.gateway' from the string above (if present) to avoid syntax error, or set manually before applying."
echo "NOTE: Cluster domain search string: ${CLUSTERSEARCH} may be automatically appended by the platform and may not need to be included in the above dns-search string explicitly."
echo "an explicit nameserver entry is required in a manual interface definition to succeed boot on RHCOS"
echo "Do not apply this command unless you validate the result yourself first, applying invalid network configurations can result in a degraded cluster node state. Open a support ticket for assistance."
echo ""
exit 0