#!/bin/bash
#disable 443 until calico pods are available
#provided as-is with no warranties, implied or inferred, for use with troubleshooting only
#THIS IS NOT A SUPPORTED CONFIGURATION SCRIPT, PROVIDED ONLY FOR TESTING PURPOSES
#DO NOT DEPLOY TO PRODUCTION!

#define NLB IP address for nftable ruleset
SOURCE=192.168.128.100 #here exampled dummy LB address
counter=0 #initial count marker value

#check if nftable rule exists and if not, deny traffic:
block_traffic () {
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

## currently NOT functional to re-enable traffic
allow_traffic() {
# Command to list all nftables rules
rules=$(nft list ruleset)

# Search for the specific rule in the ruleset output
if [[ ! $rules =~ "ip saddr ${SOURCE} tcp dport 443 drop" ]]; then
    # Rule not found, nothing to do
    echo "Rule not applied, nothing to remove"
else
    echo "Rule exists, removing"
    #get the handle number for the rule:
    handle=$(nft -a list chain ip nat PREROUTING | grep 192.168.128.100 | awk {'print $10'})
    nft -a delete rule ip nat PREROUTING handle ${handle}
fi
}

block_traffic_test () {
	echo "here we would have blocked traffic or validated traffic still dropped"
}

allow_traffic_test () {
	echo "here we would have allowed traffic again"
}


testloop () {

pod1="router-default"
pod2="ovnkube-node" #change to calico-node
route_output=$(ip route show 172.20.0.0/16 2>/dev/null) #change to 172.30

if crictl pods | grep ${pod1} | grep -q "Ready"; 
then
	if crictl pods | grep ${pod2} | grep -q "Ready"
	then
		if [[ -z "$route_output" ]]; then

			echo "route not ready, retrying"
			block_traffic_test
			#retry
		else
			echo "system ready"
			allow_traffic_test
		fi
	else
		echo "calico-node not ready, retrying"
		block_traffic_test
		#retry
	fi
else
	echo "router-default not ready, retrying"
    block_traffic_test
	#retry
fi
}


#define logic for how long to sleep between health-validations, and how many times to try again before default exiting the script.
#This may need to be set to some not insignificant period of time, like 120 or 240 calls.

retry () {
#define how long to loop
while [ $counter -lt 30 ]; do
    testloop
    sleep 1 #how long to wait between checks
    counter=$((counter + 1))
    echo $counter
done

fail
}


fail (){
	echo "unable to complete check within defined timelimit, exiting cleanly anyway to avoid break/stop event"
	exit 0
}

#call initial script loop
retry
echo "NODE IS READY"
exit 0