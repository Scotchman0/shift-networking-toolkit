#!/bin/bash
#Script to analyze and summarize lifespan average of haproxy pids, and backtrace the connections that remain in 
#established for the longest time

 #@#@#@#@#@#@@#@#@#@#@#@#@#@#@#@#@#

 #get pod IP list
 oc get pod -o wide -A | gre

#within sosreport top level dir:
# pull all active pids and sub-connections, plus creation date of pid:
#for pid in `awk '/.*haproxy/{print $2}' ps`; do echo "process $pid connections"; grep "$pid" ps | awk '{print $9}'; grep "ESTABLISHED.*$pid" netstat; done
for pid in `ps -axe -o start_time,pid,ppid,comm  | awk '/haproxy/{counter++;print $2; if (counter == 10) exit}'`; do echo "\-\-\-\- Process $pid connection list \-\-\-\-"; netstat -tnp | grep $pid; done 



#while on a node running HaProxy:
# pull all active pids and sub-connections, plus creation date of pid:
#for pid in `ps auxwwwm | awk '/.*haproxy/{print $2}'`; do echo "process $pid connections"; ps auxwwwm | grep "$pid" | awk '{print $9}'; netstat -antpu | grep "ESTABLISHED.*$pid" ; done | tee report.out
for pid in `ps -axe --sort=start_time  -o start_time,pid,ppid,comm  | awk '/haproxy/{counter++;print $2; if (counter == 10) exit}'`; doecho "\-\-\-\- Process $pid conneetion list \-\-\-\-"; ps auxwwwm | grep "$pid" | awk '{print $9}';  netstat -tnp | grep $pid; done


