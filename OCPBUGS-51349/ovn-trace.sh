#!/bin/bash
#scripted ovn-trace for faster analysis
#Will Russell
#2/27/25
#For use in Red Hat troubleshooting diagnostics sessions; provided with AS-IS with no warranty, guarantees or support expectations
#usage: usage: ovn-trace.sh <client-pod> <client-namespace> <target-pod> <target-namespace> <target-port>
#will trace ovn-flows between pods directly

set -e
DATE=$(date +"%Y-%m-%d-%H-%M-%S")
LOGFILE=./ovn-trace-${DATE}.log

#set conditional exits to ensure options are populated before executing:
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
              #define client pod as arg $1
              CLIENTPOD="$1"
              echo "client: ${CLIENTPOD}"
              #define client namespace as arg $2
              CLIENTNS="$2"
              echo "client namespace: ${CLIENTNS}"
              #define target pod as arg $3
              TARGETPOD="$3"
              echo "target pod: ${TARGETPOD}"
              #define target namespace as arg $4
              TARGETNS="$4"
              echo "target namespace: ${TARGETNS}"
              #define target port as arg $5
              TARGETPORT="$5"
              echo "target port: ${TARGETPORT}"
              #define the source port for the trace as neutral and traceable port - hardcoded for now but can be overriden here.
              #failing to set source port results in `tp.src=0` being selected which might impact trace results
              CLIENTPORT=5555
              #define client IP as pod IP
              CLIENTIP=$(oc get pod -n $CLIENTNS -o wide | grep $CLIENTPOD | awk {'print $6'})
              echo "client IP: ${CLIENTIP}"
              #define target IP as pod IP
              TARGETIP=$(oc get pod -n $TARGETNS -o wide | grep $TARGETPOD | awk {'print $6'})
              echo "target IP: ${TARGETIP}"
              #define client host as node name where client pod is scheduled
              CLIENTHOST=$(oc get pod $CLIENTPOD -n $CLIENTNS -o wide | grep -v "NAME" | awk {'print $7'})
              echo "client host node: ${CLIENTHOST}"
              #define target host as node name where target pod is scheduled
              TARGETHOST=$(oc get pod $TARGETPOD -n $TARGETNS -o wide | grep -v "NAME" | awk {'print $7'})
              echo "client target host node: ${TARGETHOST}"
              #define the ovnkube-node pod running on the client's host node
              CLIENTOVN=$(oc get pod -n openshift-ovn-kubernetes -o wide | grep ovnkube-node | grep $CLIENTHOST | awk {'print $1'})
              echo "client OVN pod: ${CLIENTOVN}"
              #define the ovnkube-node pod running on the target's host node
              TARGETOVN=$(oc get pod -n openshift-ovn-kubernetes -o wide | grep ovnkube-node | grep $TARGETHOST | awk {'print $1'})
              echo "target OVN pod: ${TARGETOVN}"
              #enter the client's ovnkube-node pod and pull the MAC address of the primary eth0 iface of client pod
              CLIENTMAC=$(oc -n openshift-ovn-kubernetes exec -it $CLIENTOVN -c northd -- ovn-nbctl show | grep -A1 $CLIENTPOD | grep -o ..:..:..:..:..:..)
              echo "client mac address: ${CLIENTMAC}"
              #Pull the MAC of the router port on the source node (routing table entry)
              #TARGETMAC=$(oc -n openshift-ovn-kubernetes exec -it $TARGETOVN -c northd -- ovn-nbctl show | grep -A1 $TARGETPOD | grep -o ..:..:..:..:..:..)
              TARGETMAC=$(oc -n openshift-ovn-kubernetes exec -it $CLIENTOVN -c northd -- ovn-nbctl --no-leader show | grep -A3 'port rtos' | grep -o ..:..:..:..:..:..)
              echo "target mac address: ${TARGETMAC}"
              #define a combined literal string of "namespace_client-podname" including quotations
              CONST=$(echo '"'${CLIENTNS}_${CLIENTPOD}'"')
              #define a combined literal string with variable expansion pre-handled on the host to populate the requisite ovn-trace command"
              COMPILESTRING="ovn-trace ${CLIENTHOST} --ct=new 'inport=="${CONST}" && eth.src==${CLIENTMAC} && eth.dst==${TARGETMAC}  && ip4.dst==${TARGETIP} && ip4.src==${CLIENTIP} && ip.ttl==64 && tcp && tcp.src==${CLIENTPORT} && tcp.dst==${TARGETPORT}' --lb-dst ${TARGETIP}:${TARGETPORT}"
              echo $COMPILESTRING
              echo "running trace" 
              #execute the compiled command for ovn-trace on the client's ovnkube-node pod and pipe the results to log
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