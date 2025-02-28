#!/bin/bash 
#Will Russell
#NOT a supported long/term deployment - provided as-is with no warranties for help in debugging/mitigating OVN-kube failure condition on OpenShift 4.14.30: 
 
DATE=$(date +"%Y-%m-%d-%H-%M") 
PROBELOG=${DATE}_healthprobe.out 
 
healthprobe() { 
##https://everything.curl.dev/cmdline/exitcode.html 
## Operation timeout. The specified time-out period was reached according to the conditions. 
##curl offers several timeouts, and this exit code tells one of those timeout limits were reached. 
##Extend the timeout or try changing something else that allows curl to finish its operation faster. 
##Often, this happens due to network and remote server situations that you cannot affect locally. 

echo "now querying all dns-peers for cross-talk capacity..." 
##iterate over all peer pods; get the exit result of a connection; if it's a timeout (28) then log the NAME of the NODE and the result timeout; otherwise skip + add a dot to progress log. 
for SOURCE in $(oc get pod -n openshift-dns | grep dns-default | awk {'print $1'}); do 
  #define client host node:
  CLIENTHOST=$(oc get pod -n openshift-dns -o wide | grep ${SOURCE} | awk {'print $7'})
	echo "Current client: ${SOURCE}, ${CLIENTHOST}"
    for TARGET in $(oc get pod -n openshift-dns -o wide | grep dns-default | awk {'print $6'}); do 
      #define TARGET host node:
      TARGETHOST=$(oc get pod -n openshift-dns -o wide | grep ${TARGET} | awk {'print $7'})
      #check conditional call to peer 
      RESULT=$(oc -n openshift-dns rsh $SOURCE curl --connect-timeout 1 -kv -s ${TARGET}:5353/health 2>&1 )
      if [[ $? -eq 28 ]]
      then 
        echo "connection failure calling to peer ${TARGET}, ${TARGETHOST} - call timed out!"
      else dummyvalue=true; fi; echo "."; 
    done
done | tee $PROBELOG 
}

healthprobe
echo "done"
exit 0