#!/bin/bash

# keepalived toolkit to quick-validate VIP placement, scrape details on live clusters and perform health checks
# Written by Will Russell, 2026 Red Hat
# Provided AS-IS with no warranties of any kind, explicit or inferred, used only for diagnostics purposes

#~# USAGE #~#
# ./keepalived_check.sh --help

#~# OVERVIEW #~#
# - Get current placement of keepalived VIP (who has ownership of VIP right now)
# - Get historical placement of VIP and establish timeline of VIP changes
# - On live cluster, get (on demand) config files from keepalived pods and network placement of said VIP from links
# - On live cluster, get (on demand) log files from pods for review from keepalived project namespace
# - On live cluster, get (on demand) run limited live TCPdump on VRRP traffic (5s) written to stdout to validate traffic flow
# - For API VIP, check haproxy containers logs and check for fail codes

#~# VARIABLES #~#

DATE=$(date +"%Y-%m-%d-%H-%M-%S")
TARGETDIR=./keepalive-gather-${DATE}
REPORT=${TARGETDIR}/report.out
NAMESPACES="openshift-cloud-platform-infra openshift-kni-infra openshift-nutanix-infra openshift-openstack-infra openshift-ovirt-infra openshift-vsphere-infra"

#~# FUNCTION BLOCKS #~#

#OFFLINE GATHER REPORTING:
must-gather-report(){
  #offline script iteration for must-gather analysis (requisite - assumes `omc` is installed/available)
  #(requisite: assumes must-gather loaded with: omc use /path/to/must-gather)

  #fail-fast is OMC installed and is a must-gather loaded:
  if [[ ! $(which omc) ]]
  then echo "omc not installed/found"
  exit 1
  else
    # determine if a cluster is available to be referenced:
    logincheck=$(omc get clusterversion)
    if [[ $? -ne 0 ]]
      then echo "clusterversion not reported on check - verify you have selected a cluster with `omc use <must-gather> and try again`"
      exit 1
      else echo "must-gather loaded - beginning offline cluster checks"
    fi
fi

  #overview grab:
  echo "Must-Gather reviewed: $(omc mg get | tail -n 1)" >> ${REPORT}
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
  for i in $(omc get pods -n ${TARGETNS} | grep keepalive | awk {'print $1'})
    do echo $i
      omc -n ${TARGETNS} logs pod/${i} -c keepalived | tail -n 15 | grep -Ei 'ingress|api'
  done >> ${REPORT}

  # Timeline of failover (API):
  for i in $(omc get pods -o wide -n $TARGETNS | grep keepalive  | grep master | awk {'print $1'})
    do echo $i
      omc -n ${TARGETNS} logs pod/${i} -c keepalived | grep -E "MASTER|BACKUP" | grep -Ei 'api'
  done >> $TARGETDIR/api_failover.log

  # Timeline of failover (ingress):
  for i in $(omc get pods -o wide -n $TARGETNS | grep keepalive | awk {'print $1'})
    do echo $i
      omc -n ${TARGETNS} logs pod/${i} -c keepalived | grep -E "MASTER|BACKUP" | grep -Ei 'ingress'
  done >> $TARGETDIR/ingress_failover.log
}

#BASIC OVERVIEW GATHER (LIVE CLUSTER)
overview(){
# this segment always fires regardless of report density (basic or full report)
# since this function will only be called if the cluster is live (-a or -b options selected) we need to confirm
# that the platform is accessible and can be read:

#create folder and log:
mkdir -p ${TARGETDIR}/logs

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
  done >> ${REPORT}

  echo ${DATE} >> ${REPORT}
  echo "ingress and API VIPs:" >> ${REPORT}
  oc get cm/cluster-config-v1 -n kube-system -o yaml |grep -A 1 VIP >> ${REPORT}
  echo "" >> ${REPORT}
  echo "keepalive pod name/placement" >> ${REPORT}
  oc get pods -n ${TARGETNS} -o wide >> ${REPORT}
  echo "" >> ${REPORT}
  echo "# openshift-ingress pod placement:" >> ${REPORT}
  oc get pods -n openshift-ingress -o wide >> ${REPORT}
  echo "" >> ${REPORT}
  echo "-----" >> ${REPORT}
  echo "# Who has ownership of VIP right now" >> ${REPORT}
  for i in $(oc get pods -n ${TARGETNS} | grep keepalive | awk {'print $1'})
    do echo $i
      oc -n ${TARGETNS} logs pod/${i} -c keepalived | tail -n 15 | grep -Ei 'ingress|api'
  done >> ${REPORT}
  echo "-----" >> ${REPORT}
  echo "" >> ${REPORT}
}

#VRRP TCPDUMP CHECK (LIVE CLUSTER)
vrrp_check(){
  #will iteratively debug into all nodes, listen for 5s for VRRP traffic, and write it to log:
  for i in $(oc get nodes | awk {'print $1'} | grep -v "NAME")
    do echo $i
      oc debug node/$i -- sh -c "timeout 5 tcpdump -nnn -i any vrrp"
        echo ""
          echo "----"
  done | tee -a $TARGETDIR/vrrp.out
}

config_yank(){
 # Acquire configs:
 echo "acquiring keepalived.conf and network status output for each host - timeout 30s on debug shell creation:"
 for i in $(oc get nodes | awk {'print $1'})
  do echo $i 
    timeout 30 oc debug node/$i -- chroot /host sh -c "cat /etc/keepalived/keepalived.conf && ip -br -4 a"
      echo "____"
        done >> $TARGETDIR/keepalive_configs.out
}

log_pull(){  
  #acquire logs (just keepalived pods)
  for i in $(oc get pod -n $TARGETNS | grep keepalive | awk {'print $1'})
    do timeout 10 oc -n $TARGETNS logs $i -c keepalived >> $TARGETDIR/logs/${i}_keepalived.log
       timeout 10 oc -n $TARGETNS logs $i -c keepalived -p >> $TARGETDIR/logs/${i}_keepalived.previous.log
  done

  # acquire logs (haproxy/coredns):
  for i in $(oc get pod -n $TARGETNS | grep -Ev 'keepalive|NAME' | awk {'print $1'})
    do timeout 10 oc -n $TARGETNS logs $i >> $TARGETDIR/logs/${i}.log
  done
  
  # Timeline of failover (API):
  for i in $(oc get pods -o wide -n $TARGETNS | grep keepalive  | grep master | awk {'print $1'})
    do echo $i
      oc -n $TARGETNS logs pod/${i} -c keepalived | grep -E "MASTER|BACKUP|FAULT" | grep -Ei 'api'
        echo "----" 
          done >> $TARGETDIR/api_failover.log
  # Timeline of failover (ingress):
  for i in $(oc get pods -o wide -n $TARGETNS | grep keepalive | grep -Ev 'master|NAME' | awk {'print $1'})
    do echo $i
      oc -n $TARGETNS logs pod/${i} -c keepalived | grep -E "MASTER|BACKUP|FAULT" | grep -Ei 'ingress'
        echo "----"
          done >> $TARGETDIR/ingress_failover.log
}

curl_tests(){
  # will probe and log router pod accessibility to endpoints, VIP throughput and router pod access
  echo "peforming curl checks..."
  echo "canary route check via VIP:" >> $TARGETDIR/curl_tests.log
  echo "-----" >> $TARGETDIR/curl_tests.log
  ROUTE=$(oc get route -n openshift-ingress-canary -ojsonpath={..host})
  echo "calling $ROUTE directly:" >> $TARGETDIR/curl_tests.log
  curl -k --noproxy '*' -w "dnslookup: %{time_namelookup} | connect: %{time_connect} | appconnect: %{time_appconnect} | pretransfer: %{time_pretransfer} | starttransfer: %{time_starttransfer} | total: %{time_total} | size: %{size_download} | response: %{response_code}\n" -o /dev/null -s https://${ROUTE} >> $TARGETDIR/curl_tests.log
  echo "" >> $TARGETDIR/curl_tests.log
  echo "calling $ROUTE via IP of router/infra nodes directly, bypassing VIP:" >> $TARGETDIR/curl_tests.log
  echo "max curl time 5s - result of 5s total time + 000 response may indicate client cannot reach router/infra IPs due to firewall policy" >> $TARGETDIR/curl_tests.log
  echo "-----" >> $TARGETDIR/curl_tests.log

  # iterate across all ingress pods, contacting the target route,
  for i in $(oc get pod -n openshift-ingress -o wide | grep -v NAME | awk {'print $6'})
    do echo "$i" 
      curl -k --noproxy '*' -m 5 -w "dnslookup: %{time_namelookup} | connect: %{time_connect} | appconnect: %{time_appconnect} | pretransfer: %{time_pretransfer} | starttransfer: %{time_starttransfer} | total: %{time_total} | size: %{size_download} | response: %{response_code}\n" -o /dev/null -s https://${ROUTE} --resolve ${ROUTE}:443:${i} 2>&1
  done >> $TARGETDIR/curl_tests.log
  echo "" >> $TARGETDIR/curl_tests.log

  #router pod to console pod accessibility checks (router to target endpoint - console pods)
  echo "router pod to console pods curl check - router to endpoint validation:" >> $TARGETDIR/curl_tests.log 
  echo "-----" >> $TARGETDIR/curl_tests.log
  oc get pod -o wide -n openshift-ingress >> $TARGETDIR/curl_tests.log
  oc get pod -o wide -n openshift-console | grep console >> $TARGETDIR/curl_tests.log
  echo "--------" >> $TARGETDIR/curl_tests.log
  echo "" >> $TARGETDIR/curl_tests.log

  #iterate across each router pod, calling each console pod directly at exposed port and write to file:
  #note if copying out to run manually - paste will change ${pod} to $\{pod\} - this will net 000 false failure response.
  for i in $(oc get pod -n openshift-ingress | awk {'print $1'} | grep -v "NAME")
    do echo $i
      for pod in $(oc get pod -n openshift-console -o wide| grep console | awk {'print $6'})
        do echo "calling destination: $pod"
          oc -n openshift-ingress rsh $i curl -k -w "dnslookup: %{time_namelookup} | connect: %{time_connect} | appconnect: %{time_appconnect} | pretransfer: %{time_pretransfer} | starttransfer: %{time_starttransfer} | total: %{time_total} | size: %{size_download} | response: %{response_code}\n" -o /dev/null -s https://${pod}:8443/healthz 2>&1
      done
  done >> $TARGETDIR/curl_tests.log
  echo "" >> $TARGETDIR/curl_tests.log
}

#BASIC REPORT FLOW (LIVE CLUSTER)
basic_report(){
  # just pull the overview report and skip additional checks - good for basic validation of setup
  overview
  #acquire logs:
  log_pull
  #acquire configs:
  config_yank
}

#FULL REPORT FLOW (LIVE CLUSTER)
full_report(){
  #runs all tests and gathers all logs (most comprehensive tests for diagnostics)
  overview
  #get logs:
  log_pull
  #get configs:
  config_yank
  #perform validation tests:
  curl_tests
  #perform vrrp tests:
  vrrp_check
}


#~#~#~#~#~#~#~#~#~#~#~#~# SCRIPT LOGIC START #~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#

  # General data-get script and executes on must-gathers or live-clusters alike:
  while test $# -gt 0; do #general while loop to lock behavior surrounding case options. 
    case "$1" in
      -h|--help|help)
        echo ""
        echo "Usage and arguments overview - review documentation for more details"
        echo "all commands can be run separately for simplified reporting, --full flag is best for diagnostics and support"
        echo "-h|--help) - print brief help details"
        echo "--full) - Run comprehensive analysis report (all tooling - uses debug shell)"
        echo "--basic) - run basic report (log gather, failover history and current vip placement overview)"
        echo "--vrrp) - run a brief 5s tcpdump on all nodes for VRRP (uses debug shell)"
        echo "--validate) - run curl validation to confirm throughput of VIP and routers (ingress check)"
        echo "--logs) - pull pod logs from keepalived project namespace for review"
        echo "--configs) - pull keepalived configs from nodes for review (uses debug shell)"
        echo "--must-gather) - run report on static must-gather loaded with omc (omc use <mustgather>)"
        echo ""
        exit 0
        ;;

      --full)
        echo ""
        echo "running full report"
        #create folder:
        mkdir ${TARGETDIR}
        full_report
        break
        ;;

      --basic)
        echo ""
        echo "running basic report"
        #create folder:
        mkdir ${TARGETDIR}
        basic_report
        break
        ;;

      --vrrp)
        echo ""
        echo "running brief vrrp validation check"
        #create folder:
        mkdir ${TARGETDIR}
        vrrp_check
        break
        ;;

      --must-gather)
        echo ""
        echo "running offline analysis report"
        #create folder:
        mkdir ${TARGETDIR}
        must-gather-report
        break
        ;;

      --validate)
        echo ""
        echo "running health probe validation"
        #create folder:
        mkdir ${TARGETDIR}
        curl_tests
        break
        ;;

      --logs)
        echo ""
        echo "pulling logs for review"
        # have to determine which namespace holds logs here if called separately/not part of basic check:
        # determine which namespace holds keepalived pods:
        for NS in $(echo $NAMESPACES); do
          if [[ $(oc get pod -n ${NS} | grep "keepalived" | wc -l) -ne 0 ]]
            then TARGETNS=${NS}
              echo "keepalived pods located in $TARGETNS"
          else 
            dummyfile=1
          fi
        done
        #create folder
        mkdir -p ${TARGETDIR}/logs
        log_pull
        break
        ;;

      --configs)
        echo ""
        echo "pulling config for review"
        #create folder
        mkdir ${TARGETDIR}
        config_yank
        break
        ;;

      *)
        # If invalid arguments supplied exit the loop and continue the report conditional below
        echo "invalid arg; re-run with keepalived_check.sh --help"
        exit 1
        ;;
    esac
  done

if [ -d $TARGETDIR ]
 then
   echo "report complete - now compiling tarball at $TARGETDIR.tar.gz"
   tar czf ${TARGETDIR}.tar.gz $TARGETDIR/
 else
  echo "no options selected or file bundle not generated, this script requires arguments. See: keepalived_check.sh --help"
  exit 0
fi

exit 0