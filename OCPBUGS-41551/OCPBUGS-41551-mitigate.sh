#!/bin/bash
#9/24/24
#NOT a supported long/term deployment - provided as-is with no warranties for help in debugging/mitigating OVN-kube failure condition on OpenShift 4.14.30:
#This has been tested on a 4.14 cluster internally and appears to work; but local testing is required before moving this to production.

DATE=$(date +"%Y-%m-%d-%H-%M")
PROBELOG=${DATE}_healthprobe.out
REBUILDLOG=${DATE}_db-rebuild.out

healthprobe() {
#define CLIENT POD:
POD="client-podname-here"


##https://everything.curl.dev/cmdline/exitcode.html
## Operation timeout. The specified time-out period was reached according to the conditions. curl offers several timeouts, and this exit code tells one of those timeout limits were reached. Extend the timeout or try changing something else that allows curl to finish its operation faster. Often, this happens due to network and remote server situations that you cannot affect locally.


##iterate over all pods; get the exit result of a connection; if it's a timeout (28) then log the NAME of the NODE and the result timeout; otherwise skip + add a dot to progress log.
#for i in $(oc get pod -n openshift-dns -o wide | grep dns-default | awk {'print $6'}); do RESULT=$(oc -n openshift-dns rsh $POD curl --connect-timeout 1 -kv -s ${i}:5353/health 2>&1 ) ; if [[ $? -eq 28 ]]; then echo $i; echo $(oc -n openshift-dns get pod -o wide | grep $i | awk {'print $7}') Timed out ; else dummyvalue=true; fi; echo "."; done | tee $PROBELOG
}

###
#iterations on calls to each backend from AAA-AES:
for i in $(oc get pod -n aaa-prod -o wide | grep xplddataaccess | awk {'print $6'}); 
  do RESULT=$(oc -n aaa-prod rsh $POD curl --connect-timeout 1 -kv -s ${i}:8080/HealthCheck 2>&1 ) ; 
  if [[ $? -eq 28 ]]; 
    then echo $i; echo $(oc -n aaa-prod get pod -o wide | grep $i | awk '{print $7}') Timed out ;
  else dummyvalue=true; 
  fi; echo "."; 
done

for i in $(oc get pod -n aaa-prod -o wide | grep addressoverride | awk {'print $6'});
  do RESULT=$(oc -n aaa-prod rsh $POD curl --connect-timeout 1 -kv -s ${i}:8080/HealthCheck 2>&1 ) ; 
  if [[ $? -eq 28 ]]; then echo $i; echo $(oc -n aaa-prod get pod -o wide | grep $i | awk '{print $7}') Timed out ; 
  else dummyvalue=true; 
  fi; echo "."; 
done

for i in $(oc get pod -n aaa-prod -o wide | grep dispatchplanaddrdataaccess | awk {'print $6'});
  do RESULT=$(oc -n aaa-prod rsh $POD curl --connect-timeout 1 -kv -s ${i}:8080/HealthCheck 2>&1 ) ; 
  if [[ $? -eq 28 ]]; then echo $i; echo $(oc -n aaa-prod get pod -o wide | grep $i | awk '{print $7}') Timed out ; 
  else dummyvalue=true; 
  fi; echo "."; 
done

for i in $(oc get pod -n aaa-prod -o wide | grep optadrspntdataaccess | awk {'print $6'});
  do RESULT=$(oc -n aaa-prod rsh $POD curl --connect-timeout 1 -kv -s ${i}:8080/HealthCheck 2>&1 ) ; 
  if [[ $? -eq 28 ]]; then echo $i; echo $(oc -n aaa-prod get pod -o wide | grep $i | awk '{print $7}') Timed out ; 
  else dummyvalue=true; 
  fi; echo ".";
done

for i in $(oc get pod -n aaa-prod -o wide | grep addrlearning | awk {'print $6'});
  do RESULT=$(oc -n aaa-prod rsh $POD curl --connect-timeout 1 -kv -s ${i}:8080/HealthCheck 2>&1 ) ; 
  if [[ $? -eq 28 ]]; then echo $i; echo $(oc -n aaa-prod get pod -o wide | grep $i | awk '{print $7}') Timed out ; 
  else dummyvalue=true; 
  fi; echo "."; 
done

for i in $(oc get pod -n aaa-prod -o wide | grep referencedataaccess | awk {'print $6'});
  do RESULT=$(oc -n aaa-prod rsh $POD curl --connect-timeout 1 -kv -s ${i}:8080/HealthCheck 2>&1 ) ; 
  if [[ $? -eq 28 ]]; then echo $i; echo $(oc -n aaa-prod get pod -o wide | grep $i | awk '{print $7}') Timed out ; 
  else dummyvalue=true; 
  fi; echo "."; 
done

###


#check the healthprobe.out_${DATE} and if a node is detected as a failed host an OVN db rebuild over it:
#call the same $LOG to ensure we always are referencing a NEW log every time this runs to avoid repeatedly rebuilding previous hosts
#also allows to compare that the nodes are the SAME every time or DIFFERENT every time.

# DB-rebuild(){
#     set -x

# #check the list 
# for NODE in $(grep ".linux.us.ups.com" $PROBELOG | awk {'print $1'}); do
#   echo "now rebuilding OVNDB on $NODE"
#   oc debug node/${NODE} -- chroot /host /bin/bash -c 'rm -f /var/lib/ovn-ic/etc/ovn*.db'
#   oc debug node/${NODE} -- chroot /host /bin/bash -c 'systemctl restart ovs-vswitchd ovsdb-server'
#   oc -n openshift-ovn-kubernetes delete pod -l app=ovnkube-node --field-selector=spec.nodeName=${NODE} --wait=true

#   while : ; do
#     POD=$(oc get pod -n openshift-ovn-kubernetes -l=app=ovnkube-node -o custom-columns='POD_NAME:.metadata.name' --no-headers --field-selector=spec.nodeName=${NODE})
#     [ -n "$POD" ] && break
#     sleep 2
#     echo "getting pod..."
#   done

#   oc wait --for=condition=ContainersReady --timeout=600s \
# -n openshift-ovn-kubernetes pod/${POD}

# done
# }

healthprobe
#DB-rebuild | tee $REBUILDLOG