#!/bin/bash
#haproxy stats parser

echo "this script will summarize and export relevant haproxy stats for fast reference"

echo "please specify which haproxy.config by inserting the filename below and pressing return"
read CONFIG

echo "what is the route you wish to look for? insert the be_backend route and press below - script will grep for this string"
read ROUTE


DATAGATHERtesting() {
	#new block testing
	echo "backend details for this route"
	echo "======================="
	cat $CONFIG | grep $ROUTE
}



DATAGATHER() {
###########START DATAGATHER#########

#LBTOT value count per pod:
echo "lbtot values -- note that these are UNIQUE values and if cookies are enabled will not increment after initial hit for that client"
echo "================================================================="
for i in $(ls ./ | grep _clean.out); do echo $i; cat $i | sed 's/|/ /' | grep $ROUTE | awk '{print $2, $26}'; done
echo "================================================================="

echo "" 

#HTTP response values:
echo "HTTP response values 1xx, 2xx, 3xx, 4xx, 5xx totals"
echo "=================================================================="
for i in $(ls ./ | grep _clean.out); do echo $i; cat $i | sed 's/|/ /' | awk '{print $2, $32, $33, $34, $35, $36}' | grep $ROUTE; done
echo "================================================================="

echo "" 

#backend LB strategy:
echo "LB strategy for this route"
echo "=================================================================="
for i in $(ls ./ | grep _clean.out); do echo $i; cat $i | sed 's/|/ /' | grep $ROUTE | grep BACKEND | awk {'print $50'}; done
echo "=================================================================="




##########end DATAGATHER#########
}






DATAGATHER
exit 0