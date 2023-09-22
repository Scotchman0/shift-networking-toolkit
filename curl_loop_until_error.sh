#!/bin/bash
#Will Russell 9/22/23
#a basic script to loop a curl against a target url, log output and stop the loop once we encounter an unexpected result (e.g. fail if http_response != 200)
#usage: curl_loop_until_error <http_code> <url> (can also just update the script manually below)


export SSLKEYLOGFILE=/tmp/sslkeylog.txt #so that we get the keys to decipher client traffic. Path can be changed.
URL="$1"
CODE=200
DATE=$(date +"%Y-%m-%d-%H-%M")
LOGPATH=${DATE}_curl_results.out
OPTIONS='\n\nLocal port: %{local_port}\nHTTP Code: %{http_code}\nTime appconnect: %{time_appconnect}\nTime connect: %{time_connect}\nTime namelookup: %{time_namelookup}\nTime pretransfer: %{time_pretransfer}\nTime redirect: %{time_redirect}\nTime starttransfer: %{time_starttransfer}\nTime total: %{time_total}\n'


curl_loop() {

while true; do
	#define curl that injects POST request with neutral payload
	#response=$(curl -kw ${OPTIONS} --location --request POST "${URL}" --header 'Content-Type: application/json' --data '{"code": 0}';sleep .2)
    
    #define curl details
    response=$(curl -kw "${OPTIONS}" "${URL}" ; sleep .2 )
    http_code=$(echo "$response" | awk '/HTTP Code:/ {print $3}')
    
    echo "" >> $LOGPATH
    echo "=====" >> $LOGPATH
    date >> $LOGPATH
    echo "=====" >> $LOGPATH
    echo "" >> $LOGPATH

    echo "$response" >> $LOGPATH

    if [ "$http_code" != "${CODE}" ] ; then
    	echo "unexpected reply returned: $response"
    	break
    fi
done

}

curl_loop