#!/bin/bash
# Will Russell 1/4/24
# A basic script to loop a netcat against a target ip and port, log output and stop the loop once we encounter an unexpected result
# Usage: nc_socket_probe_until_error.sh <IP> <PORT>

IP="$1"
PORT="$2"
DATE=$(date +"%Y-%m-%d-%H-%M")
LOGPATH=${DATE}_nc_results.out

nc_loop() {
 while true; do
   DATE=$(date +"%Y-%m-%d-%H-%M-%S")
   # Run netcat and capture its output
   OUTPUT=$(nc -v -z -i 1 $IP $PORT 2>&1)

   # Print the output
   echo "$OUTPUT --> $DATE"
   
   # Check if the output is anything other than 'Connected to'
   if [[ $OUTPUT != *"Connected to"* ]]; then
     echo "Connection error: $OUTPUT"
     break
   fi
   
   # Log the output
   echo "$OUTPUT" >> $LOGPATH
   sleep 1
 done
}

nc_loop
