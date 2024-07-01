#!/bin/bash
#script to loop a curl to a known url via localhost for router pod resolution on same node:
#provided for use in diagnostics as a method to work around a late calico-node deployment to delay router access

#code logic overview:
#This script will curl against the localhost of the node (this container must be deployed as hostNetworked)
#when the localhost resolves the default/existing canary route for the cluster, it will return a 200 response
#this 200 will imply the following:
# 1. router-default pod is online and can route traffic.
# 2. calico-node is READY and has deployed internal routing tables sufficiently to redirect traffic to backends from routerpod
# 3. infra node is now available to host traffic from upstream NLB/loadbalancer
# When the 200 response arrives, call (healthprobe) - which will init the nginx server and expose the URI that the NLB/LB can call
# the nginx server in this container will serve a 200 back to the NLB/LB informing that this host can accept traffic to the router pods
# it is expected that this pod will be deployed at a separate test port on the host that is used only for liveness probes.
# after nginx starts, call secondary health function (liveness) to confirm that the pod is serving traffic at it's local port
# liveness will also call the localhost function to ensure router-pods remain up.
# if a failure occurs at either route remove file "healthy" from /tmp/ which is how kubelet will be validating the node is available


##---- SET VARIABLES ----##

#expected response:
CODE=200
#port exposed on nginx container
LOCALPORT=8888
#url to check:
#TODO: change URL to dynamic detect on /etc/resolv.conf output injected domain for canary-openshift-ingress-canary.apps.*${domain}
#CHANGE THIS URL TO MATCH YOUR CLUSTER'S CANARY ROUTE: `oc get route -n openshift-ingress-canary`
URL=canary-openshift-ingress-canary.apps.shrocp4upi412ovn.lab.upshift.rdu2.redhat.com
#TEST_ROUTE is defined in canary-pod-deployment.yaml as an env var

#OPTIONS is necessary to pull the response_code value for the script
OPTIONS='HTTP Code: %{http_code}\n'


##---- SET FUNCTIONS ----##

fail_state (){
    #call this function if error condition is presented to signal kubelet the container is NotReady and should be restarted
    rm /tmp/healthy
    #stop nginx to mark the host as unavailable for the NLB (stop publishing the URI)
    nginx -s stop
    sleep 5 #delay timer for ready probe fail externally for events
    #restart curl_loop init probes to self-recover if possible
    curl_loop 
}


healthprobe (){
    #subsequent calls (post nginx start/curl-loop success, which is used to confirm continued health of routes/set pod ready status)
while sleep 2; do    
    #define curl details - call router-pod
    response=$(curl -kw "$OPTIONS" --resolve ${URL}:443:localhost https://${URL}; sleep .2 )
    #define curl details - call self at healthz/ready entrypoint
    response2=$(curl -kw "${OPTIONS}" http://127.0.0.1:${LOCALPORT}/healthz/ready)

#get the result of said curls:
    http_code=$(echo "${response}" | awk '/HTTP Code:/ {print $3}')
    http_code2=$(echo "${response2}" | awk '/HTTP Code:/ {print $3}')

#set conditional reply to exit the loop only when the reply is a 200
    if [[ "$http_code" = "${CODE}" && "$http_code2" = "${CODE}" ]] ; then
        #previously called $response values, calling instead http_code values to reduce loglevel noise
        echo "HEALTHPROBE: successful reply returned from router pod: $http_code"
        echo "HEALTHPROBE: successful reply returned from self: $http_code2"
        touch /tmp/healthy
        sleep 5
    else
        echo "HEALTHPROBE: node not ready, waiting for routing to be established..."
        fail_state #call fail_state function to exit nginx
        sleep 5
        break
    fi
done
}

expose_healthpath () {
#this function starts nginx which makes our target URI accessible once the script gets the desired result back.
    exec nginx -g "daemon off;" &
    sleep 5 #allow time for nginx to start
    healthprobe #call ongoing self-check loop to ensure routes stay up
}

curl_loop() {
#curl indefinitely until you get a 200 response from this route, at which point run the expose_healthpath function to modify + start nginx
while sleep 2; do    
    #define curl details
    response=$(curl -kw "$OPTIONS" --resolve ${URL}:443:localhost https://${URL}; sleep .2 )


#get the result of said curl:
    http_code=$(echo "${response}" | awk '/HTTP Code:/ {print $3}')

    #DEBUG:
    echo $http_code

#set conditional reply to exit the loop only when the reply is a 200
    if [ "$http_code" = "${CODE}" ] ; then
    	echo "INITPROBE: successful reply returned: $response"
        touch /tmp/healthy
        expose_healthpath #start nginx and then start health-checking in the container for follow up health checks.
        break
    else
        echo "INITPROBE: node not ready, waiting for routing to be established..."
        sleep 5
    fi
done
}


##------START CONTAINER SCRIPT LOGIC------##

#initial config deployment to confirm the pod came online successfully - is removed if fail condition is encountered
touch /tmp/healthy 

curl_loop
