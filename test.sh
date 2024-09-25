#!/bin/bash


set -x

LOG=2024-09-24-17-41_healthprobe.out

#check the list 
for NODE in $(grep "sunbro" $LOG | awk {'print $1'}); do
  echo "now rebuilding OVNDB on $NODE"
  oc debug node/${NODE} -- chroot /host /bin/bash -c 'rm -f /var/lib/ovn-ic/etc/ovn*.db'
  oc debug node/${NODE} -- chroot /host /bin/bash -c 'systemctl restart ovs-vswitchd ovsdb-server'
  oc -n openshift-ovn-kubernetes delete pod -l app=ovnkube-node --field-selector=spec.nodeName=${NODE} --wait=true

  while : ; do
    POD=$(oc get pod -n openshift-ovn-kubernetes -l=app=ovnkube-node -o custom-columns='POD_NAME:.metadata.name' --no-headers --field-selector=spec.nodeName=${NODE})
    [ -n "$POD" ] && break
    sleep 2
    echo "getting pod..."
  done

  oc wait --for=condition=ContainersReady --timeout=600s \
-n openshift-ovn-kubernetes pod/${POD}

done
