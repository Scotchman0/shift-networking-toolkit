#!/bin/bash
#ipsec log pull for analysis on two affected pods with communication rate failures

pod1=""
pod2=""
LOGPATH=./"ipsec-sample-bundle"
DATE=$(date +"%Y-%m-%d-%H-%M")


mkdir ./ipsec-sample-bundle

for POD in $(oc -n openshift-ovn-kubernetes get pod -o wide | grep -E "$pod1|$pod2" | awk {'print $1'}); do
        echo "grabbing ip xrfm state from $POD"
	oc -n openshift-ovn-kubernetes rsh pod/${POD} ip xfrm state > ${LOGPATH}/${POD}_xrfm_state.out
        echo "grabbing ip xrfm policy from $POD"
	oc -n openshift-ovn-kubernetes rsh pod/${POD} ip xfrm policy > ${LOGPATH}/${POD}_xrfm_policy.out
        echo "grabbing ip xrfm monitor from $POD"
	# oc -n openshift-ovn-kubernetes rsh pod/${POD} ip xfrm monitor > ${LOGPATH}/${POD}_xrfm_monitor.out
        echo "grabbing ipsec status from $POD"
	oc -n openshift-ovn-kubernetes rsh pod/${POD} ipsec status > ${LOGPATH}/${POD}_ipsec_status.out
        echo "grabbing ipsec.conf from $POD"
	oc -n openshift-ovn-kubernetes rsh pod/${POD} cat /etc/ipsec.conf > ${LOGPATH}/${POD}_ipsec.conf
	#ipsec.d/cno.conf and ipsec.d/openshift.conf will only be present on 4.15+ - null capture on 4.14 is okay
        echo "grabbing cno.conf from $POD"
	oc -n openshift-ovn-kubernetes rsh pod/${POD} cat /etc/ipsec.d/cno.conf > ${LOGPATH}/${POD}_cno.conf
        echo "grabbing openshift.conf from $POD"
	oc -n openshift-ovn-kubernetes rsh pod/${POD} cat /etc/ipsec.d/openshift.conf > ${LOGPATH}/${POD}_openshift.conf
        echo "creating log tarball from $POD"
	oc -n openshift-ovn-kubernetes rsh pod/${POD} sh -c "tar -czf /tmp/libreswan.tar.gz /var/log/openvswitch/*"
        echo "grabbing log tarball from $POD"
	oc -n openshift-ovn-kubernetes cp ${POD}:/tmp/libreswan.tar.gz ${LOGPATH}/${POD}_libreswan.tar.gz
done
echo "creating tarball from log sample"
tar -czf ipsec-sample-bundle_${DATE}.tar.gz ./ipsec-sample-bundle/

ls | grep ipsec-sample-bundle

exit 0

