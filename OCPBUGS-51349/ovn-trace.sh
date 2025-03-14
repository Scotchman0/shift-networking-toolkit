#!/bin/bash
#scripted ovn-trace for faster analysis/easier data-gathering
#Will Russell
#For use in Red Hat troubleshooting diagnostics sessions; provided with AS-IS with no warranty, guarantees or support expectations
#For use with OpenShift 4.14+ (OVN-IC architecture)
#trace pod to pod, pod to pod (via service), pod to node, pod to external client.
#Will create a logfile report of the directional trace, and includes the local `ovn-trace` syntax that was executed within the pod.
#See https://github.com/tssurya/ovnk-interconnect-demo-yamls/tree/main for sample demo traces
#usage: ovn-trace.sh <client-pod> <client-namespace> <target-pod-or-externalIP> <target-port> optional: [target-namespace] [ClusterServiceIP:port]

set -e
DATE=$(date +"%Y-%m-%d-%H-%M-%S")
LOGFILE=./ovn-trace-${DATE}.log


##REQUIRED INPUTS FOR ALL:
#ovn-trace --ct new 'inport=<client-ns>_<client-pod> && eth.src=<mac-of-pod> && eth.dst==<gateway-of-pod> && ip4.src==<IP-of-pod> && ip4.dst==<targetIP> && ip.ttl=64 && tcp && tcp.src==<source-port> && tcp.dst=<destination-port>'
#optional addtional flag: `--lb-dst 172.18.0.3:6443` (serviceIP:port) - needed in event of calling an endpoint via a service tracing. (follows the infile params)

#inputs required from user (always): 
# client podname and namespace
# target podname and namespace (or IP and port)
# optional: are we going through a service (svc IP + PORT)

tracehandler (){
  echo "obtaining variables:"
              echo "client: ${CLIENTPOD}"
              echo "client namespace: ${CLIENTNS}"
              echo "target: ${TARGETPOD}"
              echo "target port: ${TARGETPORT}"
              #define the source port for the trace as neutral and traceable port - hardcoded for now but can be overriden here.
              #failing to set source port results in `tp.src=0` being selected which might impact trace results
              CLIENTPORT=5555
              echo "client port: ${CLIENTPORT}"
              #define client IP as pod IP
              CLIENTIP=$(oc get pod -n $CLIENTNS -o wide | grep -w $CLIENTPOD | awk {'print $6'})
              echo "client IP: ${CLIENTIP}"
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
              TARGETMAC=$(oc -n openshift-ovn-kubernetes exec -it $CLIENTOVN -c northd -- ovn-nbctl --no-leader show | grep -A3 'port rtos' | grep -o ..:..:..:..:..:..)
              echo "target mac address: ${TARGETMAC}"
              #if loadbalancer is defined, spit it out:
              echo "LOADBALANCER: $LOADBALANCER"
              #define a combined literal string of "namespace_client-podname" including quotations
              CONST=$(echo '"'${CLIENTNS}_${CLIENTPOD}'"')
              #define a combined literal string with variable expansion pre-handled on the host to populate the requisite ovn-trace command"
              COMPILESTRING="ovn-trace --ct=new 'inport=="${CONST}" && eth.src==${CLIENTMAC} && eth.dst==${TARGETMAC}  && ip4.dst==${TARGETIP} && ip4.src==${CLIENTIP} && ip.ttl==64 && tcp && tcp.src==${CLIENTPORT} && tcp.dst==${TARGETPORT}' ${LOADBALANCER}"
              echo $COMPILESTRING
              echo "running trace" 
              #execute the compiled command for ovn-trace on the client's ovnkube-node pod and pipe the results to log
              oc -n openshift-ovn-kubernetes exec -it ${CLIENTOVN} -c northd -- /bin/bash -c "${COMPILESTRING}" | tee $LOGFILE
              echo "" >> $LOGFILE
              echo "TRACE COMMAND:" >> $LOGFILE
              echo $COMPILESTRING >> $LOGFILE
              echo "trace compiled - review log at ${LOGFILE}"
}

##HELP BLOCK interrupt:
    if [[ $1 == "--help" || $1 == "-h" || $1 == "help" ]]
    then
      echo "ovn-trace:"
      echo "This script is designed to facilitate easy ovn-trace commands for faster support and diagnostics, for use on OpenShift 4.14+"
      echo ""
      echo "USAGE"
      echo "usage: ovn-trace.sh <client-pod> <client-namespace> <target-pod-or-externalIP> <target-port> [target-namespace] [ClusterServiceIP:port]"
      echo ""
      echo "OPTIONS"
      echo "The script will check for the following 6 args after the script execution, the first 4 are mandatory, the last 2 are optional"
      echo ""
      echo "Option <1> requests the name of the client pod that is making our outbound call"
      echo "Option <2> as the name of the client namespace where said client pod is running"
      echo "Option <3> as the name of the target pod (OR the target IP address if external)"
      echo "Option <4> as the target port where said externalIP or target pod is listening/accepting traffic"
      echo "Option [5] (optional) as the target namespace where the target pod is running - leave empty if calling out of the cluster"
      echo "Option [6] (optional) as the loadbalancer IP and port combination (if you wanted to trace through a serviceIP) - example: 172.30.0.10:53"
      echo "NOTE: this script sets a client port as '5555' for tracing simplicity, and assumes TCP traffic"
      echo ""
      echo "// EXAMPLES //"
      echo ""
      echo "POD TO POD DIRECT CALL:"
      echo "./ovn-trace.sh dns-default-48d5d openshift-dns dns-default-6jzd8 8080 openshift-dns"
      echo "POD TO POD VIA SERVICE"
      echo "./ovn-trace.sh dns-default-48d5d openshift-dns dns-default-6jzd8 8080 openshift-dns 172.30.0.10:53"
      echo "POD TO EXTERNAL IP:"
      echo "./ovn-trace.sh dns-default-48d5d openshift-dns 8.8.8.8 53"
      echo ""
      exit 0
    else
      echo "./ovn-trace.sh [--help|-h|help] for options and usage"
    fi

#set conditional exits to ensure options are populated before executing:
#required input flow:
#ovn-trace.sh required: [<client-pod> <client-namespace> <target-pod-or-externalIP> <target-port>] optional: [ <target-pod-namespace> <serviceIP:port>]
if [ -z "$1" ] #no client podname defined?
  then
    echo "Missing variable: no client pod defined"
    echo "usage: ovn-trace.sh <client-pod> <client-namespace> <target-pod-or-externalIP> <target-port> optional: [target-namespace] [ClusterServiceIP:port]"
  else 
    #define client pod as arg $1
    CLIENTPOD="$1"
    if [ -z "$2" ] #no client namespace defined?
    then
        echo "Missing variable: no client namespace defined"
        echo "usage: ovn-trace.sh <client-pod> <client-namespace> <target-pod-or-externalIP> <target-port> optional: [target-namespace] [ClusterServiceIP:port]"
    else 
        #define client namespace as arg $2
        CLIENTNS="$2"
        if [ -z "$3" ] #no target IP or pod defined?
        then
        echo "Missing variable: no target pod or destination IP defined"
        echo "usage: ovn-trace.sh <client-pod> <client-namespace> <target-pod-or-externalIP> <target-port> optional: [target-namespace] [ClusterServiceIP:port]"
        else
          #define target pod as arg $3
          TARGETPOD="$3"
          if [ -z "$4" ] #no port defined?
          then
          echo "no target port defined"
          echo "usage: ovn-trace.sh <client-pod> <client-namespace> <target-pod-or-externalIP> <target-port> optional: [target-namespace] [ClusterServiceIP:port]"
          else #input 4 IS defined:
            #define target port as arg $4
            TARGETPORT="$4"
            #here is where we fire off the request no mater what, checking to see if input 5 or input 6 are populated to inject additional data:
            if [ -z "$5" ] #namespace field is empty?
            then
                #set the value to the exact input provided (IP address) - assume external target
                TARGETIP="$3"
                echo "input 5 (target namespace) is missing"
                echo "setting targetIP to $TARGETIP and assuming that you supplied an IP address instead of a podname"
                echo "usage: ovn-trace.sh <client-pod> <client-namespace> <target-pod-or-externalIP> <target-port> optional: [target-namespace] [ClusterServiceIP:port]"
                tracehandler
              else
                TARGETNS="$5"
                echo "target namespace: ${TARGETNS}"
                TARGETIP=$(oc get pod -n $TARGETNS -o wide | grep -w $TARGETPOD | awk {'print $6'})
                if [ -z "$6" ] #defined loadbalancer?
                then
                #we don't need to do anything here if $6 is null just run it with existing vars
                  echo "input 6 (loadbalancer <IP>:<port> ) is missing"
                  echo "omitting loadbalancer flag from trace"
                  echo "calling tracehandler from INPUT 6 is NOT POPULATED"
                  tracehandler
                else
                  #if $6 is defined, then we're calling a loadbalancer option so inject it:
                  echo "setting loadbalancer as --lb-dst $6"
                  LOADBALANCER="--lb-dst=${6}"
                  tracehandler
                fi
            fi
          fi
        fi
    fi
fi
exit 0 
