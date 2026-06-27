#!/bin/bash 
#provided as-is with no warranties for help in debugging/mitigating OVN-kube failure condition on OpenShift
#output is provided in sections group by client pod
#the number of failres over the number of connection attempts will be reported for each target for any given client
#specific details about failed connections will be logged to the file specified by $PROBEERR
#Reasons for error condition may include: IPSEC configuration issues, OVN-kube db fragmentation/issues,
#6081/UDP port denial between peer nodes or between host infrastructure, or ACL/firewall rule packet denials
#This script validates that geneve traffic can flow between nodes

usage() {
  echo "Usage: $0 <attempts>"
  echo ""
  echo "Tests TCP connectivity between dns-default pods in the openshift-dns namespace."
  echo ""
  echo "Arguments"
  echo "----"
  echo "    attempts - The number of connection attempts to make between a source pod and target pod (default: 3)"
}

ATTEMPTS="${1:-3}"

if ! [[ "${ATTEMPTS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "Invalid number of attempts: ${ATTEMPTS}"
  usage
  exit 1
fi

DATE=$(date +"%Y-%m-%d-%H-%M") 
PROBELOG=${DATE}_healthprobe.out
PROBEERR=${DATE}_healthprobe.err

#handle signals with exit codes aligning with the gentleman's agreement described at https://tldp.org/LDP/abs/html/exitcodes.html
#immediately exit on SIGINT to regain control of the shell
trap "exit 130" INT
 
healthprobe() { 
##https://everything.curl.dev/cmdline/exitcode.html 
## Operation timeout. The specified time-out period was reached according to the conditions. 
##curl offers several timeouts, and this exit code tells one of those timeout limits were reached. 
##Extend the timeout or try changing something else that allows curl to finish its operation faster. 
##Often, this happens due to network and remote server situations that you cannot affect locally. 

echo "now querying all dns-peers for cross-talk capacity..."
echo ""

#pre-fetch the name, IP, and node info from all dns-default pods in the cluster
DNSPODS="$(oc get pod -n openshift-dns -l dns.operator.openshift.io/daemonset-dns=default -o jsonpath='{range .items[*]}{@.metadata.name}{":"}{@.status.podIP}{":"}{@.spec.nodeName}{"\n"}{end}')"

#iterate over all peer pods; get the exit result of a connection; log the number of failed connection attempts for each peer 
for SOURCE in ${DNSPODS}; do
  #define source info:
  SOURCEPOD="$(echo ${SOURCE} | cut -d ':' -f 1)"
  SOURCEIP="$(echo ${SOURCE} | cut -d ':' -f 2)"
  SOURCEHOST="$(echo ${SOURCE} | cut -d ':' -f 3)"

  echo "===="
  echo "Current client pod: ${SOURCEPOD} (${SOURCEIP}) on host ${SOURCEHOST}"
  echo "===="

  for TARGET in ${DNSPODS}; do
    # skip self chatter
    if [[ "${TARGET}" = "${SOURCE}" ]]
    then
      continue
    fi

    #define target info:
    TARGETPOD="$(echo ${TARGET} | cut -d ':' -f 1)"
    TARGETIP="$(echo ${TARGET} | cut -d ':' -f 2)"
    TARGETHOST="$(echo ${TARGET} | cut -d ':' -f 3)"

    #check conditional call to peer
    FAILURE="0"
    for i in $(seq 1 ${ATTEMPTS})
    do
      RESULT="$(oc -n openshift-dns -c dns exec "${SOURCEPOD}" -- curl --connect-timeout 1 -kv -s http://"${TARGETIP}":8080/health 2>&1)"
      CODE="$?"
      if [[ "${CODE}" -ne 0 ]]
      then
        FAILURE="$(expr "${FAILURE}" + 1)"

        echo "----" >&2
        echo "Source: ${SOURCEPOD} (${SOURCEIP}) - ${SOURCEHOST}" >&2
        echo "Target: ${TARGETPOD} (${TARGETIP}) - ${TARGETHOST}" >&2
        echo "Attempt: ${i}" >&2
        echo "Exit Code: ${CODE}" >&2
        echo "" >&2
        echo "${RESULT}" >&2
        echo "----" >&2
        echo "" >&2
      fi
    done

    #conditional alerting - only announce failures if there are some so that it's clear at a glance that there are no issues
    if [[ ${FAILURE} = 0 ]]
      then 
            echo "${TARGETPOD} (${TARGETIP}) on host ${TARGETHOST} - Success"
      else
            echo "${TARGETPOD} (${TARGETIP}) on host ${TARGETHOST} - Connection Failures: ${FAILURE} / ${ATTEMPTS}"
    fi
  done

  echo "";
done 2> $PROBEERR  | tee $PROBELOG

NEW_DNSPODS="$(oc get pod -n openshift-dns -l dns.operator.openshift.io/daemonset-dns=default -o jsonpath='{range .items[*]}{@.metadata.name}{":"}{@.status.podIP}{":"}{@.spec.nodeName}{"\n"}{end}')"

if [[ "${NEW_DNSPODS}" != "${DNSPODS}" ]]
then
  echo "WARNING: dns-default pods changed during the execution of this script, results may not be completely accurate"
fi
}

healthprobe
echo "script completed - see ${PROBELOG} and ${PROBEERR} for report details"
exit 0
