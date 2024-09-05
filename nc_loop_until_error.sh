#!/bin/bash
#Will Russell 1/4/23
#a basic script to loop an NC call against a target IP address, log output and stop the loop once we encounter an unexpected result (e.g. fail if response != connected)
#usage: nc_loop_until_error <IP> <port>
 
URL="$1"
PORT="$2"
REPLY="Connected"
DATE=$(date +"%Y-%m-%d-%H-%M")
LOGPATH=${DATE}_nc_results.out
OPTIONS='-v -z -i 1'
 
 
nc_loop() {
 
while true; do
    
    #define nc query details
    RESPONSE=$(nc ${OPTIONS} "${URL}" "${PORT}")
    OUTPUT=$(echo "${RESPONSE}")
    echo "RESPONSE=${RESPONSE}"
    echo "OUTPUT=${OUTPUT}"
    break
 
    echo "" >> $LOGPATH
    echo "=====" >> $LOGPATH
    date >> $LOGPATH
    echo "=====" >> $LOGPATH
    echo "" >> $LOGPATH
 
    echo "$RESPONSE" >> $LOGPATH
 
    if [ "$OUTPUT" != "${REPLY}" ] ; then
        echo "unexpected reply returned: $RESPONSE"
        break
    fi
done
 
}
 
nc_loop
