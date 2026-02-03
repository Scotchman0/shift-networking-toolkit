#!/bin/bash

# keepalived toolkit to quick-validate VIP placement, scrape details on live clusters and perform health checks
# Written by Will Russell, 2026 Red Hat
# Provided AS-IS with no warranties of any kind, explicit or inferred, used only for diagnostics purposes

#~# OVERVIEW #~#

# - Get current placement of keepalived VIP (who has ownership of VIP right now)
# - Get historical placement of VIP and establish timeline of VIP changes (variable time output - default 12h)
# - On live cluster, get (on demand) config files from keepalived pods
# - On live cluster, get (on demand) log files from pods (runs manual scrape from node logs if inspect isn't sufficient)
# - On live cluster, can (on demand) run limited live TCPdump on VRRP traffic + parse output to confirm flow
# - For API VIP, check haproxy containers logs and check for fail codes
# - Get Network config and validate node health with check for br-ex routing table + br-ex interface on OVNkube

#~# VARIABLES #~#

DATE=$(date +"%Y-%m-%d-%H-%M-%S")
TARGETDIR=./keepalive-gather-${DATE}
#create folder and log:
mkdir -p ${TARGETDIR}/logs

REPORT=${TARGETDIR}/report.out
NAMESPACES="openshift-cloud-platform-infra openshift-kni-infra openshift-nutanix-infra openshift-openstack-infra openshift-ovirt-infra openshift-vsphere-infra"


#~# FUNCTION BLOCKS #~#

#OFFLINE GATHER REPORTING:
must-gather-report(){
  #offline script iteration for must-gather analysis (requisite - assumes `omc` is installed/available)
  #(requisite: assumes must-gather loaded with: omc use /path/to/must-gather)

  #overview grab:
  echo "MG report:"
  for NS in $(echo $NAMESPACES); do
    if [[ $(omc get pod -n ${NS} | grep "keepalived" | wc -l) -ne 0 ]]
     then TARGETNS=${NS}
     echo "keepalived pods located in $TARGETNS"
     else 
      #set null value variable to skip output on irrelevant namespaces.
      dummyfile=1
     fi
  done

  echo ${DATE} >> ${REPORT}
  echo "ingress and API VIPs:" >> ${REPORT}
  omc get cm/cluster-config-v1 -n kube-system -o yaml |grep -A 1 VIP >> ${REPORT}
  echo "" >> ${REPORT}
  echo "keepalive pod name/placement" >> ${REPORT}
  omc get pods -n ${TARGETNS} -o wide >> ${REPORT}
  echo "" >> ${REPORT}
  echo "# openshift-ingress pod placement:" >> ${REPORT}
  omc get pods -n openshift-ingress -o wide >> ${REPORT}
  echo "" >> ${REPORT}
  echo "-----" >> ${REPORT}
  echo "# Who has ownership of VIP right now" >> ${REPORT}
  for i in $(omc get pods -n ${TARGETNS} | grep keepalive | awk {'print $1'}); do echo $i; omc -n ${TARGETNS} logs pod/${i} -c keepalived | tail -n 15 | grep -Ei 'ingress|api'; done | tee -a ${REPORT}
  echo "-----" >> ${REPORT}
  echo "" >> ${REPORT}

  
  #advanced report grab:
  # Timeline of failover (API):
  for i in $(omc get pods -o wide -n $TARGETNS | grep keepalive  | grep master | awk {'print $1'}); do echo $i; omc logs pod/${i} -c keepalived | grep -E "MASTER|BACKUP" | grep -Ei 'api'; done >> $TARGETDIR/api_failover.log

  # Timeline of failover (ingress):
  for i in $(omc get pods -o wide -n $TARGETNS | grep keepalive | awk {'print $1'}); do echo $i; omc logs pod/${i} -c keepalived | grep -E "MASTER|BACKUP" | grep -Ei 'ingress'; done >> $TARGETDIR/ingress_failover.log
}

#BASIC OVERVIEW GATHER (LIVE CLUSTER)
overview(){
# this segment always fires regardless of report density (basic or full report)
# since this function will only be called if the cluster is live (-a or -b options selected) we need to confirm
# that the platform is accessible and can be read:
# failfast if oc not found + kicklaunch
if [[ ! $(which oc) ]]
  then echo "oc not installed/found"
  exit 1
  else
    # determine if we're logged into a cluster or not and assume that if we're logged in we must want live data
    logincheck=$(oc whoami)
    if [[ $? -ne 0 ]]
      then echo "not logged in to the cluster"
      exit 1
      else echo "logged in - beginning local cluster checks"
    fi
fi

  # determine which namespace holds keepalived pods:
  for NS in $(echo $NAMESPACES); do
    if [[ $(oc get pod -n ${NS} | grep "keepalived" | wc -l) -ne 0 ]]
     then TARGETNS=${NS}
     echo "keepalived pods located in $TARGETNS"
     else 
      dummyfile=1
     fi
  done

  echo ${DATE} >> ${REPORT}
  echo "ingress and API VIPs:" >> $REPORT
  oc get cm/cluster-config-v1 -n kube-system -o yaml |grep -A 1 VIP >> ${REPORT}
  echo "" >> $REPORT
  echo "keepalive pod name/placement" >> ${REPORT}
  oc get pods -n ${TARGETNS} -o wide >> ${REPORT}
  echo "" >> $REPORT
  echo "# openshift-ingress pod placement:" >> ${REPORT}
  oc get pods -n openshift-ingress -o wide >> ${REPORT}
  echo "" >> $REPORT
  echo "-----" >> ${REPORT}
  echo "# Who has ownership of VIP right now" >> ${REPORT}
  for i in $(oc get pods -n ${TARGETNS} | grep keepalive | awk {'print $1'}); do echo $i; oc -n ${TARGETNS} logs pod/${i} -c keepalived | tail -n 15 | grep -Ei 'ingress|api'; done | tee -a ${REPORT}
  echo "-----" >> ${REPORT}
  echo "" >> $REPORT
}

#VRRP TCPDUMP CHECK (LIVE CLUSTER)
vrrp_check(){
  #will iteratively debug into all nodes, listen for 5s for VRRP traffic, and write it to log:
  for i in $(oc get nodes | awk {'print $1'} | grep -v "NAME"); do echo $i; oc debug node/$i -- sh -c "timeout 5 tcpdump -nnn -i any vrrp"; echo ""; echo "----"; done | tee -a $TARGETDIR/vrrp.out
}

curl_tests(){
  # will probe and log router pod accessibility to endpoints, VIP throughput and router pod access
  echo "canary route check via VIP:" >> $TARGETDIR/curl_tests.log
  echo "-----"
  ROUTE=$(oc get route -n openshift-ingress-canary -ojsonpath={..host})
  ROUTER=$(oc get pod -n openshift-ingress -o wide | grep -v NAME | grep Running | grep router-default | awk {'print $6'} | head -n 1)
  curl -k --noproxy '*' -w "dnslookup: %{time_namelookup} | connect: %{time_connect} | appconnect: %{time_appconnect} | pretransfer: %{time_pretransfer} | starttransfer: %{time_starttransfer} | total: %{time_total} | size: %{size_download} | response: %{response_code}\n" -o /dev/null -s https://${ROUTE}
  echo ""
  echo "-----"
  echo "canary route check - skipping VIP (router pods only)"
  echo "-----"
  for i in $(oc get pod -n openshift-ingress -o wide | grep -v NAME | awk {'print $6'})
    do echo "$i"
      curl -k --noproxy '*' -w "dnslookup: %{time_namelookup} | connect: %{time_connect} | appconnect: %{time_appconnect} | pretransfer: %{time_pretransfer} | starttransfer: %{time_starttransfer} | total: %{time_total} | size: %{size_download} | response: %{response_code}\n" -o /dev/null -s https://${ROUTE} --resolve ${ROUTE}:443:${i}
  done
  echo ""

  #router pod to console pod accessibility checks (router to target endpoint - console pods)
  echo "router pod to console pods curl check:"
  oc get pod -o wide -n openshift-ingress >> $TARGETDIR/curl_tests.log
  oc get pod -o wide -n openshift-console >> $TARGETDIR/curl_tests.log
  echo "--------" >> $TARGETDIR/curl_tests.log
  echo "" >> $TARGETDIR/curl_tests.log
  #iterate across each router pod, calling each console pod directly at exposed port and write to file:
  #note if copying out to run manually - paste will change ${pod} to $\{pod\} - this will net 000 false failure response.
  for i in $(oc get pod -n openshift-ingress | awk {'print $1'} | grep -v "NAME")
    do echo $i
      for pod in $(oc get pod -n openshift-console -o wide| grep console | awk {'print $6'})
        do oc -n openshift-ingress rsh $i curl -k -w "dnslookup: %{time_namelookup} | connect: %{time_connect} | appconnect: %{time_appconnect} | pretransfer: %{time_pretransfer} | starttransfer: %{time_starttransfer} | total: %{time_total} | size: %{size_download} | response: %{response_code}\n" -o /dev/null -s https://${pod}:8443/healthz 
      done
  done 2>&1 | tee -a $TARGETDIR/curl_tests.log
}

#BASIC REPORT FLOW (LIVE CLUSTER)
basic_report(){
  # just pull the overview report and skip additional logging - good for basic validation of setup
  overview
}

#FULL REPORT FLOW (LIVE CLUSTER)
full_report(){
 overview
 #pull namespace inspect:
 oc adm inspect namespace $TARGETNS openshift-ingress --dest-dir=$TARGETDIR

 # Timeline of failover (API):
 for i in $(oc get pods -o wide -n $TARGETNS | grep keepalive  | grep master | awk {'print $1'}); do echo $i; oc logs pod/${i} -c keepalived | grep -E "MASTER|BACKUP" | grep -Ei 'api'; done >> $TARGETDIR/api_failover.log
 # Timeline of failover (ingress):
 for i in $(oc get pods -o wide -n $TARGETNS | grep keepalive | awk {'print $1'}); do echo $i; oc logs pod/${i} -c keepalived | grep -E "MASTER|BACKUP" | grep -Ei 'ingress'; done >> $TARGETDIR/ingress_failover.log
 
 # Acquire configs:
 for i in $(oc get nodes | awk {'print $1'}); do echo $i; oc debug node/$i -- chroot /host sh -c "cat /etc/keepalived/keepalived.conf && ip -br -4 a"; echo "____"; done | tee keepalive_configs.out
}


#~#~#~#~#~#~#~#~#~#~#~#~# SCRIPT LOGIC START #~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#

  # General data-get script and executes on must-gathers or live-clusters alike:
  while test $# -gt 0; do #general while loop to lock behavior surrounding case options. 
    case "$1" in
      -h|--help|help)
        echo ""
        echo "Usage and arguments overview - review documentation for more details"
        echo "-h|--help) - print brief help details"
        echo "--full) - run full report (includes namespace inspects, config extracts - more thorough)"
        echo "--basic) - run basic report - default will also fire if no args included"
        echo "--must-gather|--offline) - run report on static must-gather loaded with omc (omc use <mustgather>)"
        echo "--vrrp) - run a brief 5s tcpdump on all nodes for VRRP traffic to log for cross-talk confirmation"
        echo "--validate) - run curl validation to confirm throughput of VIP and routers (ingress check)"
        echo ""
        exit 0
        ;;

      --full)
        echo ""
        echo "running full report"
        full_report
        exit 0
        ;;

      --basic)
        echo ""
        echo "running basic report"
        basic_report
        exit 0
        ;;

      --vrrp)
        echo ""
        echo "running brief vrrp validation check"
        vrrp_check
        exit 0
        ;;

      --must-gather)
        echo ""
        echo "running offline analysis report"
        must-gather-report
        exit 0
        ;;

      --validate)
        echo ""
        echo "running health probe validation"
        curl_tests
        exit 0
        ;;

      *)
      # If no arguments supplied exit the loop and continue the report conditional below
      echo "this script requires arguments - re-run with keepalive-gather.sh --help"
        break
      #fi
        ;;
    esac
  done
