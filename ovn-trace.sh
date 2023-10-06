#!/bin/bash
#scripted ovn-trace for faster analysis
#Will Russell (SunBro)
#10.06.23
#For use in Red Hat troubleshooting diagnostics sessions; provided with AS-IS with no warranty, guarantees or support expectations

#SET GLOBAL VARIABLES:

DATE=$(date +"%Y-%m-%d-%H-%M")

#get master node IP:
MASTER1_IP=$(oc get nodes -o wide | grep master | awk {'print $6'} | sed -n '1 p')
MASTER2_IP=$(oc get nodes -o wide | grep master | awk {'print $6'} | sed -n '2 p')
MASTER3_IP=$(oc get nodes -o wide | grep master | awk {'print $6'} | sed -n '3 p')

#set namespace to ovn-kubernetes to ensure we can rsh/execute on target pods
oc project openshift-ovn-kubernetes

#Get OVN-kube-master pod target
OVNMASTER=$(oc get pods -n openshift-ovn-kubernetes | grep master | awk {'print $1'} | head -n 1)

#Get Default service IP address for basic testing
DEFAULTSERVICEIP=$(oc get svc -n default | grep ClusterIP | grep kubernetes | awk {'print $3'})


#Get source pod variables:
echo "insert source podname for OVN-trace and press return: <example>: iputils-container-001"
read SOURCEPOD

echo "insert source namespace and press return: <example>: rh-testing"
read SOURCENS

#Get source pod address details (IP/MAC/HOST):
#source pod mac
ETHSRC=$(oc rsh ${OVNMASTER} ovn-nbctl --no-leader show | grep -i ${SOURCEPOD} -A 1 | grep addresses | awk '{print $2}' | cut -c 3-)
#source pod IP (easier to pull directly from pod yaml:)
IPV4SRC=$(oc get pod/${SOURCEPOD} -n ${SOURCENS} -o yaml | grep ip: | awk {'print $3'})
#Source pod HOST node:
SPHOST=$(oc get pod/${SOURCEPOD} -n ${SOURCENS} -o wide | awk {'print $7'} | grep -v NODE)
#Source pod HOST node IP:
SPHOSTIP=$(oc get nodes -o wide | grep ${SPHOST} | awk {'print $6'})

#source pod host node MAC
ETHDST=$(oc rsh ${OVNMASTER} ovn-nbctl --no-leader show | grep -i "port rtos-${SPHOST}" -A3 | grep mac: | awk {'print $2'} | tr -d '"' | sed 's/^M//g')

echo "do you want to specify a target pod (y/N)? Selecting N will test against default kubernetes service IP address for basic trace"
read option

case $option in
	 y|Y|yes) 
     echo "specify target podname and press return: <example>: targetpod-002"
     read TARGETPOD
     echo "specify target namespace and press return: <example>: rh-testing"
     read TARGETNS
     #target pod mac
     TPMAC=$(oc rsh ${OVNMASTER} ovn-nbctl --no-leader show | grep -i ${TARGETPOD} -A 1 | grep addresses | awk '{print $2}' | cut -c 3-)
     #target pod IP (easier to pull directly from pod yaml:)
     TPIP=$(oc get pod/$TARGETNS -n $SOURCENS -o yaml | grep ip: | awk {'print $3'})
     #target pod host node:
     TPHOST=$(oc get pod/$TARGETPOD -o wide -n $TARGETNS | awk {'print $7'} | grep -v NODE)

     ;;
     n|N|no)
     echo "continuing with basic test against the default service IP for kubernetes"
     ;;
     *)
     echo "unexpected answer inserted, defaulting to no target, continuing with basic test against default kubernetes service IP"
     ;;
 esac

echo "all variables"
echo $MASTER1_IP
echo $MASTER2_IP
echo $MASTER3_IP
echo $OVNMASTER
echo $DEFAULTSERVICEIP
echo $SOURCEPOD
echo $SOURCENS
echo $SPHOST
echo $ETHDST
echo $ETHSRC
echo $IPV4SRC
echo $DATE

#redefine podname with quotes for usage in string:
SOURCEPOD=\"${SOURCEPOD}\"

##TRACE COMMAND COMPILED:
#echo the command out first for logging:
echo "oc -n openshift-ovn-kubernetes rsh -c ovnkube-master ${OVNMASTER} ovn-trace -p /ovn-cert/tls.key -c /ovn-cert/tls.crt -C /ovn-ca/ca-bundle.crt --db ssl:${MASTER1_IP}:9642,ssl:${MASTER2_IP}:9642,ssl:${MASTER3_IP}:9642 ${SPHOST} 'inport == ${SOURCEPOD} && eth.src == ${ETHSRC} && eth.dst == ${ETHDST} && ip4.src == ${IPV4SRC} && ip4.dst == ${SPHOSTIP} && ip.ttl == 64 && icmp4.type == 8'" | tee test.out

#execute it:
oc -n openshift-ovn-kubernetes rsh -c ovnkube-master ${OVNMASTER} ovn-trace -p /ovn-cert/tls.key -c /ovn-cert/tls.crt -C /ovn-ca/ca-bundle.crt --db ssl:${MASTER1_IP}:9642,ssl:${MASTER2_IP}:9642,ssl:${MASTER3_IP}:9642 ${SPHOST} 'inport == ${SOURCEPOD} && eth.src == ${ETHSRC} && eth.dst == ${ETHDST} && ip4.src == ${IPV4SRC} && ip4.dst == ${SPHOSTIP} && ip.ttl == 64 && icmp4.type == 8' | tee trace-${SOURCEPOD}-${DATE}.out