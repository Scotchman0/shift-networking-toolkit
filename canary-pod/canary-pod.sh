#!/bin/bash
#script to loop a curl to a known url via localhost for router pod resolution on same node:
#expected response:
CODE=200
#url to check:
URL=canary-openshift-ingress-canary.apps.shrocp4upi412ovn.lab.upshift.rdu2.redhat.com

expose_healthpath () {

    exec nginx -g "daemon off;"

}

curl_loop() {
#curl indefinitely until you get a 200 response from this route, at which point run the expose_healthpath function to modify + start nginx
while true; do    
    #define curl details
    response=$(curl -kw --resolve "${URL}":443:127.0.0.1 https://"${URL}")

#get the result of said curl:
    http_code=$(echo "$response" | awk '/HTTP Code:/ {print $3}')

#set conditional reply to exit the loop only when the reply is a 200
    if [ "$http_code" = "${CODE}" ] ; then
    	echo "successful reply returned: $response"
    	break
        expose_healthpath #call the expose uri function
    else
        echo "waiting for routing to be established"
        sleep 5
    fi
done
}

curl_loop
