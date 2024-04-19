#!/bin/bash
#Will Russell 9/22/23
#a basic script to loop a curl against a target url, log output and stop the loop once we encounter an unexpected result (e.g. fail if http_response != 200)
#usage: $ curl_loop_until_error.sh <url> (can also just update the script manually below)


export SSLKEYLOGFILE=./sslkeylog.txt #so that we get the keys to decipher client traffic. Path can be changed.
#define the URL you want to call here as the first argument.
URL="$1"
#define the expected response code - script will exit if it does not get this response back:
CODE=200
DATE=$(date +"%Y-%m-%d-%H-%M")
LOGPATH=${DATE}_curl_results.out
#define curl report options to be visible on exit:
OPTIONS='\n\nLocal port: %{local_port}\nHTTP Code: %{http_code}\nTime appconnect: %{time_appconnect}\nTime connect: %{time_connect}\nTime namelookup: %{time_namelookup}\nTime pretransfer: %{time_pretransfer}\nTime redirect: %{time_redirect}\nTime starttransfer: %{time_starttransfer}\nTime total: %{time_total}\n'


curl_loop() {

while true; do
    #define curl that injects POST request with neutral payload. - commented out by default: use/modify if you need to inject a payload to get a 200:
    #response=$(curl -kw ${OPTIONS} --location --request POST "${URL}" --header 'Content-Type: application/json' --data '{"code": 0}';sleep .2)
    
    #define curl details (default config, if using POST/headers comment this out and use `response` above
    response=$(curl -kw "${OPTIONS}" "${URL}" ; sleep .2 )
   
    #get the response code for validation 
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
