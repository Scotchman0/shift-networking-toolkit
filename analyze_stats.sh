#!/bin/bash
#haproxy stats parser
#script to gather haproxy stats from each routerpod for brief (most-common) analysis
#provided as-is with no warranties for use in supporting Red Hat troubleshooting efforts

echo "this script will summarize and export relevant haproxy stats for fast reference: lbtot (hits) and http response values"
echo "this script will run a lookup on every file with matching '_cleaned.out' filename in this folder, please run this script inside haproxy-gather/"
echo ""
echo "please specify which haproxy.config we need to examine by inserting the '<filename>_haproxy.config' below and pressing return"
read CONFIG

echo "what is the route you wish to look for? insert the route name and press return - script will grep for this string"
read ROUTE

DATAGATHER() {
#LBTOT value count per pod:
echo "lbtot values -- note that these are UNIQUE values and if cookies are enabled will not increment after initial hit for that client"
echo "================================================================="
for i in $(ls ./ | grep _cleaned.out); do echo $i; cat $i | sed 's/|/ /' | grep $ROUTE | awk '{print $2, $26}'; done
echo "================================================================="

echo "" 

#HTTP response values:
echo "HTTP response values 1xx, 2xx, 3xx, 4xx, 5xx totals"
echo "alignment is not always perfect here due to nature of stats gather, refer to generated ${ROUTE}_highlight.out for complete table."
echo "=================================================================="
for i in $(ls ./ | grep _cleaned.out); do echo $i; cat $i | sed 's/|/ /' | grep $ROUTE | awk '{print $2, $32, $33, $34, $35, $36}' ; done
echo "================================================================="

echo ""
}

highlights_block () {
    #this block dumps the raw haproxy.config route detail into a separate file for independant verification based on $ROUTE
    cat $CONFIG | grep -A5 $ROUTE | grep -A5 ^backend > config_${ROUTE}_highlight.out

    if [[ $(echo $CONFIG | grep default) ]]
        then
            #gather raw summary bundle for verification
            #set header first:
            for i in $(ls ./ | grep _cleaned.out | grep default |  head -n 1); do echo $i; cat $i | sed 's/|/ /' | head -n 1 > ${ROUTE}_highlight.out; done
            #export the route string sets (total) into summary highlight.
            for i in $(ls ./ | grep _cleaned.out); do cat $i | sed 's/|/ /' | grep $ROUTE >> ${ROUTE}_highlight.out; done
        else
            #based on config, confirm which router pods are relevant
            echo "non-default haproxy.config found, please confirm which set of sharded router pods you wish to examine"
            echo "please provide a greppable string for <your-shard> that will be used to scope the search to router-<your-shard>-*_cleaned.out files and press return"
            #get variable to search for
            read SHARDNAME
            # get header alignment from sharded routerpod stats output
            for i in $(ls ./ | grep _cleaned.out | grep ${SHARDNAME} |  head -n 1); do echo $i; cat $i | sed 's/|/ /' | head -n 1 > ${ROUTE}_highlight.out; done
            # get route/pod stats from sharded instance
            for i in $(ls ./ | grep _cleaned.out | grep ${SHARDNAME}); do echo $i; cat $i | sed 's/|/ /' | grep $ROUTE >> ${ROUTE}_highlight.out; done


    fi

	
	echo "filenames ${ROUTE}_highlight.out and config_${ROUTE}_highlight.out have been created for your convenience"
	echo "open with less and type -S to chop lines, or with vim and use :set nowrap to view the route highlight block"
	echo "config_*_highlight.out is the annotation highlight for this backend (what strategy is in use)"
	echo "refer to https://access.redhat.com/solutions/6987555 for more information on analyzing this information"

}

DATAGATHER
highlights_block
exit 0
