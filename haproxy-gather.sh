#!/bin/bash
#script to gather haproxy stats from each routerpod for analysis
#provided as-is with no warranties for use in supporting Red Hat troubleshooting efforts
#

#set variables:
cmd="echo 'show stat' | socat - UNIX-CONNECT:/var/lib/haproxy/run/haproxy.sock"
info="echo 'show info' | socat - UNIX-CONNECT:/var/lib/haproxy/run/haproxy.sock"
error="echo 'show error' | socat - UNIX-CONNECT:/var/lib/haproxy/run/haproxy.sock"
default=$(oc get pods -n openshift-ingress | grep default | awk {'print $1'} | head -n 1)
TARGETDIR=./haproxy-gather

#create folder
mkdir $TARGETDIR
mkdir $TARGETDIR/raw_stats
mkdir $TARGETDIR/pod_errors
mkdir $TARGETDIR/pod_info

#grab pod overview:
oc get pods -n openshift-ingress -o wide > $TARGETDIR/pod_overview.out

#gather raw stats output for each routerpod:
for i in $(oc get pods -n openshift-ingress | grep router | awk {'print $1'}); do oc exec $i -n openshift-ingress -- bash -c "$cmd" > ${TARGETDIR}/${i}_haproxystats_dirty.out; done

#clean the stats entries for readability:
for i in $(ls ./haproxy-gather/ | grep dirty.out); do column -s, -t < ./haproxy-gather/${i} | less -#2 -N -S > ./haproxy-gather/${i}_cleaned.out; done

#move the dirtystats to $TARGETDIR/raw_stats
for i in $(ls ./haproxy-gather/ | grep "_dirty.out$"); do mv ./haproxy-gather/${i} ./haproxy-gather/raw_stats/; done

#gather info tables
for i in $(oc get pods -n openshift-ingress | grep router | awk {'print $1'}); do oc exec $i -n openshift-ingress -- bash -c "$info" > ${TARGETDIR}/pod_info/${i}_info.out; done

#gather error logs
for i in $(oc get pods -n openshift-ingress | grep router | awk {'print $1'}); do oc exec $i -n openshift-ingress -- bash -c "$error" > ${TARGETDIR}/pod_errors/${i}_errors.out; done

#gather haproxy.config to pair with output:
oc cp ${default}:haproxy.config -n openshift-ingress ${TARGETDIR}/default_haproxy.config

#gather haproxy.config from any other non-default router pods (probably going to get more than we want but better than not enough)
for i in $(oc get pods -n openshift-ingress | grep router | grep -v default | awk {'print $1'}); do oc cp ${i}:haproxy.config -n openshift-ingress ${TARGETDIR}/${i}_haproxy.config; done


#tarball the contents
tar czf haproxy-gather-$(date +"%Y-%m-%d-%H-%M-%S").tar.gz $TARGETDIR/
