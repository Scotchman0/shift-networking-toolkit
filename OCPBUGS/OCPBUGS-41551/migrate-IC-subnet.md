# MIGRATE IC subnet steps (unsupported) 4.14.35(-)

NOTE: the steps above have been tested but are considered TEMPORARY and are unsupported without a support exception. 
Permanent update is necessary to latest 4.14.z version that will include the fix; to enable CNO activation + proper migration stays put.


 - Disable CNO:

 $ oc patch clusterversion version --type json -p '[{"op":"add","path":"/spec/overrides","value":[{"kind":"Deployment","group":"apps","name":"network-operator","namespace":"openshift-network-operator","unmanaged":true}]}]'
 
 $ oc -n openshift-network-operator scale deployment network-operator --replicas=0

 - Set the new subnet on deployment for the ovnkube-control-plane:

~~~
 $ oc set env deployment/ovnkube-control-plane -c ovnkube-cluster-manager OVN_V4_TRANSIT_SWITCH_SUBNET="<new_subnet>"
~~~

 - Once the pods restart edit:
~~~
 $ oc set env pod <ovnkube-control-plane-pod_name> -c ovnkube-cluster-manager --list (just to double on bot pods the env is set and subnet is correct)
~~~

- edit the deployment:

~~~
 $ oc edit deployment/ovnkube-control-plane

      - command:
        - /bin/bash
        - -c
        - |
          set -xe
          if [[ -f "/env/_master" ]]; then
            set -o allexport
            source "/env/_master"
            set +o allexport
          fi

          echo "I$(date "+%m%d %H:%M:%S.%N") - ovnkube-control-plane - start ovnkube --init-cluster-manager ${K8S_NODE}"
          exec /usr/bin/ovnkube \
            --enable-interconnect \
            --init-cluster-manager "${K8S_NODE}" \
            --config-file=/run/ovnkube-config/ovnkube.conf \
            --loglevel "${OVN_KUBE_LOG_LEVEL}" \
            --metrics-bind-address "127.0.0.1:29108" \
            --metrics-enable-pprof \
            --metrics-enable-config-duration \  --> don't forget this escape
            --cluster-manager-v4-transit-switch-subnet "${OVN_V4_TRANSIT_SWITCH_SUBNET}"  --> add this new option
        env:
        - name: OVN_KUBE_LOG_LEVEL
          value: "4"
        - name: K8S_NODE
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: spec.nodeName
        - name: POD_NAME
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.name
        - name: OVN_V4_TRANSIT_SWITCH_SUBNET
          value: <new_subnet>
~~~

 - Once the pods restart, confirm the nodes annotation:

~~~
 $ oc get nodes -o yaml |  grep "k8s.ovn.org/node-transit-switch-port-ifaddr"
~~~

 - The new values should be there and if so rollout the ovnkube-node ds:

 ~~~
 $ oc rollout restart ds/ovnkube-node
 $ oc rollout status ds/ovnkube-node
~~~

 - To make sure everything was actually change something like this can be done:

~~~
 $ for OVNNODE in $(oc get pods -l app=ovnkube-node -o custom-columns=NAME:.metadata.name --no-headers); do \
   echo "Transit Switch config on $OVNNODE" ; \ 
   echo "---------------------------------" ; \
   oc rsh -Tc northd $OVNNODE ovn-nbctl show transit_switch ; \
   echo "---------------------------------" ; sleep 2;
   done
~~~

- When everything is correct, the cluster will have subnets without any colliding IPs and hopefully things will start to look better, has no routing problems in OVN will happen.

- The only thing is that they can't enable CNO, otherwise everything goes crazy again, since all changes are reverted. We need to ensure that once the fixes are released they can safely enable it.