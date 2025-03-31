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
#exports all output to log for analysis
#usage: `stale-nat-eip.sh <options> <args>`

DATE=$(date +"%Y-%m-%d-%H-%M") 
NATLOG=${DATE}-nat-check.out 
DUMPFOLDER=natlists_${DATE}

#dump the NAT and LR tables for cross-check and tarball it with the log output results for review
dump-tables() {
echo "pulling total nat list for cross-comparison"
mkdir ./$DUMPFOLDER
for nodeName in $(oc get nodes | grep -v NAME | awk {'print $1'}); do
  echo $nodeName
  ips=$(oc get egressip -o json | jq -r '.items[] | .status.items[]? | .egressIP')
  localpod=$(oc get pod -n openshift-ovn-kubernetes -o wide | grep -v NAME | grep -w "$nodeName" | grep ovnkube-node | awk {'print $1'})
  router_uuid=$(oc -n openshift-ovn-kubernetes exec -it $localpod -c nbdb -- ovn-nbctl --bare --column=_uuid,nat find logical_router)
  listOfNats=$(oc -n openshift-ovn-kubernetes exec -it $localpod -c nbdb -- ovn-nbctl --format=csv --column "_uuid, external_ids, external_ip, logical_ip" find nat)
  echo $listOfNats >> ${DUMPFOLDER}/${localpod}_${nodeName}_nats.csv
  echo $router_uuid >> ${DUMPFOLDER}/${localpod}_${nodeName}_logical_routers.out
done
  cp $NATLOG $DUMPFOLDER/
  tar -czf ${DUMPFOLDER}.tar.gz ./${DUMPFOLDER}
  echo "tarball created:"
  ls | grep "${DUMPFOLDER}"
}


nat-check(){
for nodeName in $(oc get nodes | grep -v NAME | awk {'print $1'}); do
  echo "=========="
  echo ${nodeName}
  #get egressIPs from status output - requires 'jq'
  ips=$(oc get egressip -o json | jq -r '.items[] | .status.items[]? | .egressIP')
  echo "egressIPs:"
  echo "$ips"
  #get the pod name of the ovnkube-node host pod
  localpod=$(oc get pod -n openshift-ovn-kubernetes -o wide | grep -v NAME | grep -w "$nodeName" | grep ovnkube-node | awk {'print $1'})
  echo "localpod:"
  echo ${localpod}
  #poll local ovnkube-node pod and get the nat table in csv format, selectively pulling the fields: _uuid, external_ids, external_ip, logical_ip.
  #filter output by looking only for populated external_id field, where name =! null to ensure we only review NAT entries that are relating to egressIPs:
  #grep further the output to remove the headers: "_uuid,external_ids,external_ips,logical_ip"
  listOfNats=$(oc -n openshift-ovn-kubernetes exec -it $localpod -c nbdb -- ovn-nbctl --format=csv --column "_uuid, external_ids, external_ip, logical_ip" find nat external-ids:\"name\"!=\"\" | grep -v "_uuid")
  #iterate over the list of nats and cross-compare each nat entry:
  for nat in ${listOfNats}; do
    # determine if $nat is empty (no matching entries found) 
    # todo - validate functional check - currently doesn't echo as expected, but does go to the else handler correctly
    if [[ -z "$nat" ]]
    then
      echo "no matching nats found on this host"
    else
      # here-string comparison - using grep to determine if the content of '*"$nat"*'' contains string content found in '$ips'
      if grep -q "$ips" <<< *"$nat"*
      then
        echo "nat being evaluated:" 
        echo $nat
        echo "egressIP match found, no action needed"
      else
        echo "nat being evaluated:"
        echo $nat
        echo "possible stale nat detected: inspect for mismatch:"
        #declare nat_uuid:
        nat_uuid=$(echo $nat | awk -F ',' {'print $1'})
        echo "nat uuid: $nat_uuid"
        #declare router_uuid:
        router_uuid=$(oc -n openshift-ovn-kubernetes exec -it $localpod -c nbdb -- ovn-nbctl --bare --column=_uuid,nat find logical_router | grep -B1 ${nat_uuid} | awk {'print $1'} | head -n 1)
        echo "router uuid: ${router_uuid}"
      fi
    fi
  done
#dump all results to log:
done | tee ${NATLOG}
}

#launch commands:
echo "Stale-nat-eip.sh is designed to help identify nat flows involved with EgressIP handling on Openshift clusters running OVNkubernetes"
echo "This script is designed to be run on openshift 4.14 clusters or later, and is considered a diagnostics supplement only"
echo "Please open a case with Red Hat Support for more information and assistance"

#Early fail/exit if jq can't be found to avoid softlocks/bad output:
if [[ ! $(which jq) ]]
  then echo "jq not installed/found - please ensure you have jq installed for json parsing required by this script"
  exit 1
else
  nat-check
  dump-tables
fi

echo "gather completed"
exit 0