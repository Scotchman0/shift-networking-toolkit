#!/bin/bash
#disable 443 until calico pods are available
#provided as-is with no warranties, implied or inferred, for use with troubleshooting only
#THIS IS NOT A SUPPORTED CONFIGURATION SCRIPT, PROVIDED ONLY FOR TESTING PURPOSES
#DO NOT DEPLOY TO PRODUCTION!

#This script will check for the ready status of two pods: 
#calico-node and router-default
#it will also check for the service subnet being defined via route
#if all elements are found and in ready status, then the check will allow passthrough on port 443
#if any element is in not-ready, port 443 will be blocked for the NLB until ready status is achieved
#if the health-check time expires and the node is still not in ready, fails-open to allow traffic anyway
#in an effort to avoid scenarios where the script itself may contribute to degraded node status

#This script is written as a possible workaround to an observed behavior wherein router-default pods
#are available before calico-node is finished provisioning, leading to the node recieving traffic
#that it cannot yet redirect to other pods in the cluster.


#define NLB IP address for nftable ruleset
SOURCE=192.168.128.100 #here exampled dummy LB address to avoid breaking test cluster
counter=0 #initial count marker value for artificial block delay

block_traffic () {
#check if nftable rule exists and if not, deny traffic:
# Command to list all nftables rules
rules=$(nft list ruleset)
# Search for the specific rule in the ruleset output
if [[ ! $rules =~ "ip saddr ${SOURCE} tcp dport 443 drop" ]]; then
    # Rule not found, so add it
    nft -a insert rule ip nat PREROUTING ip saddr ${SOURCE} tcp dport 443 drop
    echo "Rule added successfully."
else
    echo "Rule already exists, skipping"
fi
}

allow_traffic() {
# Check if nftable rule exists, and if it does, remove it:
# Command to list all nftables rules
rules=$(nft list ruleset)
# Search for the specific rule in the ruleset output for our IP address
if [[ ! $rules =~ "ip saddr ${SOURCE} tcp dport 443 drop" ]]; then
    # Rule not found, nothing to do
    echo "Rule not applied, nothing to remove"
    success
else
    echo "Rule exists, removing"
    #get the handle number for the rule:
    handle=$(nft -a list chain ip nat PREROUTING | grep -w ${SOURCE} | awk {'print $10'})
    #remove the rule using the handle
    nft -a delete rule ip nat PREROUTING handle ${handle}
    success
fi
}

block_traffic_test () {
	echo "here we would have blocked traffic or validated traffic still dropped"
}

allow_traffic_test () {
	echo "here we would have allowed traffic again"
	success
}



testloop () {
# primary function block that governs the health check test
#define our target pods and target validator route
pod1="router-default"
pod2="calico-node"
route_output=$(ip route show 172.30.0.0/16 2>/dev/null)
#is router-default up? (-q quiet -w exact match to ignore "notReady")
if crictl pods | grep ${pod1} | grep -qw "Ready"; 
then #is calico-node up? (-q quiet -w exact match to ignore "notReady")
	if crictl pods | grep ${pod2} | grep -qw "Ready"
	then #is the route defined?
		if [[ -z "$route_output" ]]; then
			echo "route not ready, retrying"
			block_traffic_test #change to block_traffic for live
		else
			echo "system ready"
			allow_traffic_test #change to allow_traffic for live
		fi
	else
		echo "calico-node not ready, retrying"
		block_traffic_test #change to block_traffic for live
	fi
else
	echo "router-default not ready, retrying"
    block_traffic_test #change to block_traffic for live
fi
}

retry () {
#define logic for how long to sleep between health-validations, and how many times to try again before default exiting the script.
#This may need to be set to some not insignificant period of time, like 120 or 240 calls (seconds).
#define how many times to check status
while [ $counter -lt 30 ]; do
    testloop
    sleep 1 #how long to wait between checks
    counter=$((counter + 1))
    echo $counter
done
timeout #fail-safe at counter expiration
}

timeout (){
#a safety valve to ensure that no matter what, we exit the script cleanly to avoid a start failure condition on other services, and the nft rule is removed at the end
	echo "unable to complete check within defined timelimit, exiting cleanly anyway to avoid break/stop event"
	allow_traffic_test #change to allow_traffic for live #guarantee we removed the NFT rule.
}

success (){
#success condition should be called when we confirm all 3 conditions are met after allowing traffic again - called by allow_traffic and allow_traffic_test to escape
echo "NODE IS READY"
exit 0
}

#######SCRIPT START LOGIC:#######
#call initial script loop
retry