#!/bin/bash
#stale-nat-eip.sh
#William Russell and Courtney Ruhm
#Designed to assist with https://issues.redhat.com/browse/OCPBUGS-50709
#provided as-is with no warranties express or inferred for debug purposes only
#To be run on OpenShift 4.14 and later - OVNkube-IC architecture only
#The below for-loop can be run by a Cluster Administrator to review all NAT entries tied to egressIPs
#if a nat entry with external_id exists on a host it will cross-check against the IPs in the egressIP list
#if the nat matches an IP from the egressIP list, it is ignored, (valid)
#if the nat does NOT include an IP from the current egressIP list it is considered stale (invalid)
#if there is an egressIP NAT on a host that is NOT allocated as an egressIP host, it is flagged for review
#exports all output to log for analysis
#usage: `stale-nat-eip.sh` optional arg: [--debug]


##TESTING/IMPORTED DRAFT FROM PREVIOUS BRANCH - USE 050709's script instead for now##

#target KCS: https://access.redhat.com/solutions/7110252


DATE=$(date +"%Y-%m-%d-%H-%M") 
NATLOG=${DATE}-nat-check.out 
DUMPFOLDER=natlists_${DATE}

#dump the NAT and LR tables for cross-check and tarball it with the log output results for review
dump-tables() {
echo "pulling total nat list for cross-comparison"
mkdir ./$DUMPFOLDER
for nodeName in $(oc get nodes | grep -v NAME | awk {'print $1'}); do
  ips=$(oc get egressip -o json | jq -r '.items[] | .status.items[]? | .egressIP')
  localpod=$(oc get pod -n openshift-ovn-kubernetes -o wide | grep -v NAME | grep -w "$nodeName" | grep ovnkube-node | awk {'print $1'})
  router_uuid=$(oc -n openshift-ovn-kubernetes exec -it $localpod -c nbdb -- ovn-nbctl --bare --column=_uuid,nat find logical_router)
  listOfNats=$(oc -n openshift-ovn-kubernetes exec -it $localpod -c nbdb -- ovn-nbctl --format=csv --column "_uuid, external_ids, external_ip, logical_ip" find nat)
  echo $listOfNats >> ${DUMPFOLDER}/${localpod}_${nodeName}_nats.csv
  echo $router_uuid >> ${DUMPFOLDER}/${localpod}_${nodeName}_logical_routers.out
done
  egress_hosts=$(oc get egressip -o json | jq -r '.items[] | .status.items[]? | .node')
  ovnkubepods=$(oc get pod -n openshift-ovn-kubernetes -o wide | grep 'ovnkube-node')
  echo $ips >> ${DUMPFOLDER}/egressIPs.out
  echo $ovnkubepods >> ${DUMPFOLDER}/ovnkube-node-pods.out
  echo $egress_hosts >> ${DUMPFOLDER}/active_egress_nodes.out
  cp $NATLOG $DUMPFOLDER/
  tar -czf ${DUMPFOLDER}.tar.gz ./${DUMPFOLDER}
  echo "tarball created:"
  ls | grep "${DUMPFOLDER}"
}

nat-check(){
  echo "running nat-check - if output is empty, no problems detected"
for nodeName in $(oc get nodes | grep -v NAME | awk {'print $1'}); do
  #get egressIPs from status output - requires 'jq'
  ips=$(oc get egressip -o json | jq -r '.items[] | .status.items[]? | .egressIP')
  #get nodes that are allocated as current egressIP hosts - we should only see eip nats here:
  egress_hosts=$(oc get egressip -o json | jq -r '.items[] | .status.items[]? | .node')
  #get the pod name of the ovnkube-node host pod
  localpod=$(oc get pod -n openshift-ovn-kubernetes -o wide | grep -v NAME | grep -w "$nodeName" | grep ovnkube-node | awk {'print $1'})
  #poll local ovnkube-node pod and get the nat table in csv format, selectively pulling the fields: _uuid, external_ids, external_ip, logical_ip.
  #filter output by looking only for populated external_id field, where name =! null to ensure we only review NAT entries that are relating to egressIPs:
  #grep further the output to remove the headers: "_uuid,external_ids,external_ips,logical_ip"
  listOfNats=$(oc -n openshift-ovn-kubernetes exec -it $localpod -c nbdb -- ovn-nbctl --format=csv --column "_uuid, external_ids, external_ip, logical_ip" find nat external-ids:\"name\"!=\"\" | grep -v "_uuid")
  #iterate over the list of nats and cross-compare each nat entry:
  for nat in ${listOfNats}; do
    #If nat is not empty (indicating an egressIP NAT exists on this host), check to see if the nodeName we're checking is an expected host, and log any discrepancy:
    if [[ ! -n "$nat" ]] && ! grep -q "$egress_hosts" <<< "$nodeName"; then
      echo "Possible stale egress Host detected:"
      echo "NODE: ${nodeName}"
      echo "Node has NAT entries for egress but is not listed as an Egress Host at time of scan"
      echo ""
    fi
    # If Nat is not empty, and; the nat entry does NOT contain a string that matches an expected egressIP, log the discrepancy:
    if [[ ! -n "$nat" ]] && ! grep -q "$ips" <<< *"$nat"*; then
        echo "NODE: ${nodeName}"
        echo "ovnkube-node-pod: ${localpod}"
        echo "possible stale nat detected: entry does not match known egressIPs"
        echo "NAT Entry: ${nat}"
        nat_uuid=$(echo $nat | awk -F ',' {'print $1'})
        echo "nat uuid: $nat_uuid"
        router_uuid=$(oc -n openshift-ovn-kubernetes exec -it $localpod -c nbdb -- ovn-nbctl --bare --column=_uuid,nat find logical_router | grep -B1 ${nat_uuid} | awk {'print $1'} | head -n 1)
        echo "router uuid: ${router_uuid}"
    fi
  done
#dump all results to log:
done | tee ${NATLOG}
echo "check complete"
}

#launch commands:
echo "Stale-nat-eip.sh is designed to help identify nat flows involved with EgressIP handling on Openshift clusters running OVNkubernetes"
echo "This script is designed to be run on openshift 4.14 clusters or later, and is considered a diagnostics supplement only"
echo "Please open a case with Red Hat Support for more information and assistance"
echo "This script can be run with the option --debug which will generate a more verbose data bundle for analysis and support"

#Early fail/exit if jq can't be found to avoid softlocks/bad output + determine flags:
if [[ ! $(which jq) ]]
  then echo "jq not installed/found - please ensure you have jq installed for json parsing required by this script"
  exit 1
else
    if [[ $1 == "--debug" ]]
    then
      nat-check
      dump-tables
    else 
      nat-check
    fi 
fi

exit 0
