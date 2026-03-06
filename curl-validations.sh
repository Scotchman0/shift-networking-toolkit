#!/bin/bash
#basic troubleshooting script to perform some targeted curls to confirm/validate traffic from router pods --> console pods
#performs a curl from console pod to self
#performs a curl from router pod to console pod
#performs a curl from host node of router to console pod
#performs a curl from host node of console pod to local console pod
ROUTER=$(oc get pod -n openshift-ingress -o wide | grep -v NAME | grep Running | grep router-default | awk {'print $1'} | head -n 1)
ROUTERHOSTNODE=$(oc get pod -n openshift-ingress -o wide | grep -v NAME | grep Running | grep router-default | awk {'print $7'} | head -n 1)
TARGET=$(oc get pod -n openshift-console -o wide | grep -v NAME | grep Running | grep console | awk {'print $1'} | head -n 1)
TARGETIP=$(oc get pod -n openshift-console -o wide | grep -v NAME | grep Running | grep console | awk {'print $6'} | head -n 1)
TARGETHOSTNODE=$(oc get pod -n openshift-console -o wide | grep -v NAME | grep Running | grep console | awk {'print $7'} | head -n 1)

echo "router=$ROUTER router-host=$ROUTERHOSTNODE \n targetpod=$TARGET targetip=$TARGETIP targethost-node=$TARGETHOSTNODE"  | tee -a curl-validations.out
echo "------" | tee -a curl-validations.out
echo "curl from console pod to self:" | tee -a curl-validations.out
oc -n openshift-console rsh ${TARGET} curl -kv https://127.0.0.1:8443/healthz | tee -a curl-validations.out
echo "------" | tee -a curl-validations.out
echo "curl from router to console pod IP" | tee -a curl-validations.out
oc -n openshift-ingress rsh ${ROUTER} curl --noproxy '*' -kv https://${TARGETIP}:8443/healthz | tee -a curl-validations.out
echo "------" | tee -a curl-validations.out
echo "curl from Router Host Node to console pod"  | tee -a curl-validations.out
oc debug node/${ROUTERHOSTNODE} -- chroot /host sh -c "curl --noproxy '*' -kv https://${TARGETIP}:8443/healthz" | tee -a curl-validations.out 
echo "------" | tee -a curl-validations.out
echo "curl from TARGET host node to console pod (local)" | tee -a curl-validations.out
oc debug node/${TARGETHOSTNODE} -- chroot /host sh -c "curl --noproxy '*' -kv https://${TARGETIP}:8443/healthz" | tee -a curl-validations.out 
