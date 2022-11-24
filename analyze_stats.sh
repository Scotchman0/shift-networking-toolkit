#!/bin/bash
#haproxy stats parser
#script to gather haproxy stats from each routerpod for analysis
#provided as-is with no warranties for use in supporting Red Hat troubleshooting efforts


echo "this script will summarize and export relevant haproxy stats for fast reference"

echo "please specify which haproxy.config by inserting the filename below and pressing return"
read CONFIG

echo "what is the route you wish to look for? insert the be_backend route and press below - script will grep for this string"
read ROUTE



DATAGATHER() {
###########START DATAGATHER#########


#LBTOT value count per pod:
echo "lbtot values -- note that these are UNIQUE values and if cookies are enabled will not increment after initial hit for that client"
echo "================================================================="
for i in $(ls ./ | grep _cleaned.out); do echo $i; cat $i | sed 's/|/ /' | grep $ROUTE | awk '{print $2, $26}'; done
echo "================================================================="

echo "" 

#HTTP response values:
echo "HTTP response values 1xx, 2xx, 3xx, 4xx, 5xx totals"
echo "=================================================================="
for i in $(ls ./ | grep _cleaned.out); do echo $i; cat $i | sed 's/|/ /' | grep $ROUTE | awk '{print $2, $32, $33, $34, $35, $36}' ; done
echo "================================================================="

echo "" 

#backend LB strategy:
echo "LB strategy for this route"
echo "=================================================================="
for i in $(ls ./ | grep _cleaned.out); do echo $i; cat $i | sed 's/|/ /' | grep $ROUTE | grep BACKEND | grep -E 'random|roundrobin|leastconn|source'; done
echo "=================================================================="



##########end DATAGATHER#########
}

highlights_block () {
	#this block dumps the raw haproxy.config route detail into a separate file for independant verification based on $ROUTE
	cat $CONFIG | grep -A5 $ROUTE | grep -A5 ^backend    > config_${ROUTE}_highlight.out

	#gather raw summary bundle for verification
	#set header first:
	for i in $(ls ./ | grep _cleaned.out | head -n 1); do cat $i | head -n 1 > ${ROUTE}_highlight.out; done
	for i in $(ls ./ | grep _cleaned.out); do echo $i; cat $i | sed 's/|/ /' | grep $ROUTE >> ${ROUTE}_highlight.out; done

}





DATAGATHER
highlights_block
exit 0