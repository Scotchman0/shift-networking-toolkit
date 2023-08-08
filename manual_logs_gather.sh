#!/bin/bash

# Set variables
namespace=openshift-ovn-kubernetes

#mkdir namespace directory
mkdir ./${namespace}

# Get a list of pod names in the namespace
pod_list=$(oc get pods -n $namespace -o jsonpath='{.items[*].metadata.name}')

# Iterate over each pod
for pod in $pod_list; do

  # Get a list of container names in the pod
  container_list=$(oc get pod $pod -n $namespace -o jsonpath='{.spec.containers[*].name}')

  # Iterate over each container in the pod
  for container in $container_list; do

    # Save logs to a file named <container-name>.out
    oc logs $pod -c $container -n $namespace > ./${namespace}/${pod}_${container}.out

  done

done

