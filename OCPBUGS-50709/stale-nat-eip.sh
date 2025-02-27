#!/bin/bash
#stale-nat-eip.sh
#William Russell and Courtney Ruhm
#Designed to assist with https://issues.redhat.com/browse/OCPBUGS-50709
#provided as-is with no warranties express or inferred for debug purposes only
#To be run on OpenShift 4.14 and later - OVNkube-IC architecture only
#The below for-loop can be run by a Cluster Administrator to review all NAT entries tied to egressIPs
#if a nat entry with external_id exists on a host it will cross-check against the IPs in the egressIP list
#if the nat matches an IP from the egressIP list, it is ignored, (valid)
#if the nat does NOT include an IP from the current egressIP list it is considered stale (invalid) and is purged with optional removal line
#exports all output to log for analysis


for nodeName in $(oc get nodes | grep -v NAME | awk {'print $1'}); do
     echo "=========="
     echo $nodeName
     ips=$(oc get egressip | awk {'print $2'} | grep -v "EGRESSIPS")
     localpod=$(oc get pod -n openshift-ovn-kubernetes -o wide | grep -v NAME | grep -w "$nodeName" | grep ovnkube-node | awk {'print $1'})
     echo "localpod:"
     echo $localpod
     listOfNats=$(oc -n openshift-ovn-kubernetes exec -it $localpod -c northd -- ovn-nbctl --format=csv --column "_uuid, external_ids, external_ip" find nat external-ids:\"name\"!=\"\")
     for nat in ${listOfNats[@]}; do
        echo "nat being evaluated:" 
        echo "$nat"
        if grep -q "$ips" <<< *"$nat"*
        then
            echo "egressIP match found, no action needed"
        else
            echo "match not found, stale nat"
            suuid=$(echo $nat | awk -F ',' {'print $1'})
            slr=$(oc -n openshift-ovn-kubernetes exec -it $localpod -c northd -- ovn-nbctl --bare --column=_uuid,nat find logical_router | grep -B1 $suuid | awk {'print $1'} | head -n 1)
            echo "suuid: $suuid"
            echo "slr: $slr"
            #the below command string will remove any stale NAT entries that do not match existing/expected egressIP entries. comment it out in order to log only
            oc -n openshift-ovn-kubernetes exec -it $localpod -c northd -- ovn-nbctl remove logical_router ${slr} nat ${suuid} ; echo removed nat ${suuid} from logical router ${slr}
        fi
    done
 done | tee nat-query.out