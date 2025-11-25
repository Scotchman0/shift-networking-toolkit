# README
This file contains scripts and tools relating to RFE: https://issues.redhat.com/browse/ARO-22870 
and case: 04308498
- The code change in aro-dnsmasq-pre-modified.sh has been submitted as a PR here: https://github.com/openshift/installer-aro-wrapper/pull/367 
- The 99-worker-aro-dns-override.yaml is a manual shim that can insert this script for testing
- The DHCP-to-static.sh script can be used to suggest a network interface command to define a static iface for ARO clusters that includes cluster name.
this script must be run as root on the host node - makes no changes on the host, but requires /etc/resolv.conf.dnsmasq to be present.

Testing locally has been successful but full validation is pending reviews/confirmation from engineering teams