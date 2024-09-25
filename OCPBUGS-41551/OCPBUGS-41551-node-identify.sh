#!/bin/bash
#script to detect whether a node has an overlapping network range and is POTENTIALLY likely to encounter the failure outlined in
#03939297 + OCPBUGS-41551
#provided as-is with no warranties for help in debugging/mitigating OVN-kube failure condition

DATE=$(date +"%Y-%m-%d-%H-%M")
LOG=${DATE}_nodereport.out


node-get() {

for i in $(oc get node | awk {'print $1'}); do echo $i; oc get node -o yaml | grep -E "node-subnets|node-transit-switch-port-ifaddr" | tee $LOG

}




