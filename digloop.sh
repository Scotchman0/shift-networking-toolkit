#!/bin/bash
#Will Russell 3/19/26
#A script to dig a target domain periodically until we encounter an unexpected result (no IPV4 returned) and then fire a trace to log the errant result.
FQDN="$1"
DATE=$(date +"%Y-%m-%d-%H-%M")
LOGPATH=${DATE}_dig_results.out
SLEEPVAL=5
VERBOSE=true

echo "Now running dig loop against ${FQDN}, with a sleep of every ${SLEEPVAL} seconds"
echo "This script will check for IPV4 results in the dig and will only log output if a result is NOT returned, and include a TRACE result"
echo "The script will also stdout to console as well as a log file at ${LOGPATH} which will only generate in the event of a failed lookup"
echo "will run until manually stopped with 'ctrl +c' unless additional ARG '--autostop' is appended as argument 2"
echo "usage: digloop.sh <FQDN> [--autostop(optional)]"
echo "set VERBOSE=false in the parameters to silence console output excepting fail conditions"

digloop(){
while true; do
	#define dig request:
	QUERY=$(dig ${FQDN})
	#set result to the output of the dig where we got an IPV4 result (any) - and omit localhost/metaserver
	#TODO: Improve this check, currently will give extra data if performed on a platform that uses a different local nameserver
	#than the ones being omitted and will give false positive results (return nameserver IP and not target A-record)
	#grep only valid IPv4 results (range-limited match grep, with -o to print only the string literal not preceding text).
	IPV4RESULT=$(echo ${QUERY} | grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" | grep -vE '127.0.0.53|169.254.169.254')

	if [ -z ${IPV4RESULT} ]
	  then 
	    echo "=====" | tee -a $LOGPATH
	    date | tee -a $LOGPATH
	  	echo "A-record not found!" | tee -a $LOGPATH
	  	echo "running trace" | tee -a $LOGPATH
	  	#define trace flow:
	  	QUERYTRACE=$(dig ${FQDN} +trace)
	  	#write the full original dig to log that failed:
	  	echo ${QUERY} | tee -a $LOGPATH
	  	#write the latest trace to log:
	  	echo ${QUERYTRACE} | tee -a $LOGPATH
	  	echo "=====" | tee -a $LOGPATH
	  	## define exit condition
	  	if $2="--autostop"
	  	  then
	  	    echo "unexpected result returned! logging output and exiting script!" | tee -a $LOGPATH
	  		exit 0
	  	  else
	  		nullvar=""
	  	fi
      else 
      	#noisemaker - if you want to see that we are getting IPV4 results we'll write to log if VERBOSE is set to true.
      	#disable this in the variable definitions before running if you want to squelch (not written to the log just stdout)
      	if $VERBOSE=true
      	  echo "IPV4 returned"
      	  echo $IPV4RESULT
      	else 
      		#define empty variable to skip loop as the IPV4 result was returned and we only want to log failures.
          nullvar=""
      fi

    fi
    #arbitrary wait between queries.
    sleep $SLEEPVAL
done
}

#call the function (separated this way so in the future can expand to verbose optional handling, case exceptions, etc)
digloop

