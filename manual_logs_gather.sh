#!/bin/bash
#This script serves as a way to acquire all container pod logs from a target namespace for review/analysis in the event a must-gather or namespace-inspect fails to run
#Try also: $ oc adm must-gather --host-network=true

# Set variables
namespace=<your-target-namespace-here> ##set this variable to your desired namespace

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