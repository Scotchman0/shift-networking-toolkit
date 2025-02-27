#!/bin/bash
#scripted ovn-trace for faster analysis
#Will Russell
#2/27/25
#For use in Red Hat troubleshooting diagnostics sessions; provided with AS-IS with no warranty, guarantees or support expectations
##CURRENTLY IN PROGRESS - NOT FULLY WORKING

set -e
DATE=$(date +"%Y-%m-%d-%H-%M-%S")
LOGFILE=./ovn-trace-${DATE}.log

if [ -z "$1" ]
  then
    echo "no client pod defined"
    echo "usage: ovn-trace.sh <client-pod> <client-namespace> <target-pod> <target-namespace> <target-port>"
  else 
    if [ -z "$2" ]
    then
        echo "no client namespace defined"
        echo "usage: ovn-trace.sh <client-pod> <client-namespace> <target-pod> <target-namespace> <target-port>"
    else 
        if [ -z "$3" ]
        then
        echo "no target pod defined"
        echo "usage: ovn-trace.sh <client-pod> <client-namespace> <target-pod> <target-namespace> <target-port>"
        else
          if [ -z "$4" ]
          then
          echo "no target namespace defined"
          echo "usage: ovn-trace.sh <client-pod> <client-namespace> <target-pod> <target-namespace> <target-port>"
          else
            if [ -z "$5" ]
            then
                echo "no target port defined"
                echo "usage: ovn-trace.sh <client-pod> <client-namespace> <target-pod> <target-namespace> <target-port>"
            else
              echo "obtaining variables:"
              CLIENTPOD="$1"
              echo "client: ${CLIENTPOD}"
              CLIENTNS="$2"
              echo "client namespace: ${CLIENTNS}"
              TARGETPOD="$3"
              echo "target pod: ${TARGETPOD}"
              TARGETNS="$4"
              echo "target namespace: ${TARGETNS}"
              TARGETPORT="$5"
              echo "target port: ${TARGETPORT}"
              CLIENTIP=$(oc get pod -n $CLIENTNS -o wide | grep $CLIENTPOD | awk {'print $6'})
              echo "client IP: ${CLIENTIP}"
              TARGETIP=$(oc get pod -n $TARGETNS -o wide | grep $TARGETPOD | awk {'print $6'})
              echo "target IP: ${TARGETIP}"
              CLIENTHOST=$(oc get pod $CLIENTPOD -n $CLIENTNS -o wide | grep -v "NAME" | awk {'print $7'})
              echo "client host node: ${CLIENTHOST}"
              TARGETHOST=$(oc get pod $TARGETPOD -n $TARGETNS -o wide | grep -v "NAME" | awk {'print $7'})
              echo "client target host node: ${TARGETHOST}"
              CLIENTOVN=$(oc get pod -n openshift-ovn-kubernetes -o wide | grep ovnkube-node | grep $CLIENTHOST | awk {'print $1'})
              echo "client OVN pod: ${CLIENTOVN}"
              TARGETOVN=$(oc get pod -n openshift-ovn-kubernetes -o wide | grep ovnkube-node | grep $TARGETHOST | awk {'print $1'})
              echo "target OVN pod: ${TARGETOVN}"
              CLIENTMAC=$(oc -n openshift-ovn-kubernetes exec -it $CLIENTOVN -c northd -- ovn-nbctl show | grep -A1 $CLIENTPOD | grep -o ..:..:..:..:..:..)
              echo "client mac address: ${CLIENTMAC}"
              TARGETMAC=$(oc -n openshift-ovn-kubernetes exec -it $TARGETOVN -c northd -- ovn-nbctl show | grep -A1 $TARGETPOD | grep -o ..:..:..:..:..:..)
              echo "target mac address: ${TARGETMAC}"
              CONST=$(echo '"'${CLIENTNS}_${CLIENTPOD}'"')
              COMPILESTRING="ovn-trace ${CLIENTHOST} --ct=new 'inport=="${CONST}" && eth.dst==${TARGETMAC} && eth.src==${CLIENTMAC} && ip4.dst==${TARGETIP} && ip4.src==${CLIENTIP} && ip.ttl==64 && tcp.dst==${TARGETPORT}' --lb-dst ${TARGETIP}:${TARGETPORT}"
              echo $COMPILESTRING
              echo "running trace" 
              oc -n openshift-ovn-kubernetes exec -it ${CLIENTOVN} -c northd -- /bin/bash -c "${COMPILESTRING}" | tee $LOGFILE
              echo "" >> $LOGFILE
              echo "TRACE COMMAND:" >> $LOGFILE
              echo $COMPILESTRING >> $LOGFILE
              echo "trace compiled - review log at ${LOGFILE}"
            fi
          fi
        fi
    fi
fi
exit 0