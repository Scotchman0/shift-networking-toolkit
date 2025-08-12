#!/bin/bash
#patch script for manual debugging/egress diagnostics and step-through of an upgrade
#objective: Pause worker pools and allow manual/staged step-through of the upgrade to check and clear each host before moving to the next one)
#8/12/25
#This script is provided as-is with no warranties or expectation of support or service for TESTING ONLY. Using this script is at your own risk.
#DO NOT RUN THIS ON A PRODUCTION PLATFORM UNLESS YOU'VE TESTED IT FIRST AND KNOW HOW IT WORKS



#set variables with a set from the customer input:

node_updater(){
$ oc patch node $node_name  --type merge --patch "{\"metadata\": {\"annotations\": {\"machineconfiguration.openshift.io/desiredConfig\": \"${new_value}\"}}}"
$ oc patch node $node_name  --type merge --patch '{"metadata": {"annotations": {"machineconfiguration.openshift.io/reason": ""}}}'
$ oc patch node $node_name  --type merge --patch '{"metadata": {"annotations": {"machineconfiguration.openshift.io/state": "Done"}}}'
$ oc debug node/$node_name -- chroot /host sh -c "touch /run/machine-config-daemon-force"
}


#====================== LOGIC START ======================#


#Early fail/exit if OC can't be found to avoid softlocks/bad output:
if [[ ! $(which oc) ]]
  then echo "oc not installed/found - please ensure this command is run on a bastion server for openshift as cluster Admin"
  exit 1
else
  nat-check
  dump-tables
fi

#Ensure worker pools are stopped before this fires off:
oc patch --type=merge --patch='{"spec":{"paused":true}}' machineconfigpool/worker
oc patch --type=merge --patch='{"spec":{"paused":true}}' machineconfigpool/infra

#confirm with output:
oc get 

# throw an alert that what they're doing is unsupported and is at their own risk:
echo "Use of this script infers no expectations of support or warranties and is at your own risk - press return to contine"
read lockvariable #wait until input is given

#Find all pools that aren't master and pause them:
echo "pausing machine-config pools that aren't master pool"
pools=$(oc get mcp | grep -Eiv "NAME|master" | awk {'print $1'})
for pool in $(echo ${pools}); do echo "now pausing mcp/$pool"; oc patch --type=merge --patch='{"spec":{"paused":true}}' machineconfigpool/${pool}; done

# step-through with a progress case or yes/no lock on a loop - and for better granularity, customer must copy/paste the machine-config AND node name
# each time to ensure we target only the host they want to target

echo "beginning step-through logic"
echo "you will be prompted for the value of the LATEST rendered-machine-config that matches the target node AND the NODE NAME you want to patch"
echo "after inputting the variables and hitting return, the node will update to your target version."
echo "the script will then check the OVNkube nat tables on the target host after reboot after it comes back to ready and will print the results"
echo "you can then press return again to start the cycle for the next host node"
echo "press return to continue"
read lockvariable #wait until input is given


while true; do
echo "What is the name of the node you wish to update? (paste node name and press return to set the variable)"
read node_name #define node name
echo "what is the latest/target rendered-Machine-config-<pool>-<string> value that we are pushing to this node? (oc get mc) (paste + press return to set value)"
oc get mc --sort-by '.metadata.creationTimestamp' | grep "rendered" 
read new_value #define rendered-machine-config-<pool>-string
echo "confirming target: ${node_name} will be updated to rendered-config: ${new_value}"
echo "printing node name to confirm pools match:"
$ oc get node | grep -w "$node_name"
echo "press return to apply"
read lockvariable #wait until input is given
node_updater
echo "patch completed - node should move to NOTREADY and reboot shortly - waiting for permission to continue... (press return when node returns to READY)"
read lockvariable #wait until input is given