#!/bin/bash
#data-gatherer-2000

pod1=""
pod2=""
PATH=./"ipsec-sample-bundle"
DATE=$(date +"%Y-%m-%d-%H-%M")


mkdir ./ipsec-sample-bundle

for POD in $(oc -n openshift-ovn-kubernetes get pod -o wide | grep -E "$pod1|$pod2" | awk {'print $1'}); do
	oc -n openshift-ovn-kubernetes rsh $POD ip xfrm state > $PATH/$POD_xrfm_state.out
	oc -n openshift-ovn-kubernetes rsh $POD ip xfrm policy > $PATH/$POD_xrfm_policy.out
	oc -n openshift-ovn-kubernetes rsh $POD ip xfrm monitor > $PATH/$POD_xrfm_monitor.out
	oc -n openshift-ovn-kubernetes rsh $POD ipsec status > $PATH/$POD_ipsec_status.out
	oc -n openshift-ovn-kubernetes rsh $POD cat /etc/ipsec.conf > $PATH/$POD_ipsec.conf
	oc -n openshift-ovn-kubernetes rsh $POD cat /etc/ipsec.d/cno.conf > $PATH/$POD_cno.conf
	oc -n openshift-ovn-kubernetes rsh $POD cat /etc/ipsec.d/openshift.conf > $PATH/$POD_openshift.conf
	oc -n openshift-ovn-kubernetes rsh $POD sh -c "tar -czf /tmp/libreswan.tar.gz /var/log/openvswitch/*"
	oc -n openshift-ovn-kubernetes cp $POD:/tmp/libreswan.tar.gz $PATH/$POD_libreswan.tar.gz
done

tar -czf ipsec-sample-bundle_DATE=$(date +"%Y-%m-%d-%H-%M").tar.gz ./ipsec-sample-bundle/

exit 0
