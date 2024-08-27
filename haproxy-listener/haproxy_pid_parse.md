#!/bin/bash
#Script to analyze and summarize lifespan average of haproxy pids, and backtrace the connections that remain in 
#established for the longest time

 #@#@#@#@#@#@@#@#@#@#@#@#@#@#@#@#@#

 #https://access.redhat.com/solutions/7082862
 exit 0

 #get pod IP list
 ~~~
 oc get pod -o wide -A | grep -E '<IP>|<IP>'
~~~
git ad
# within sosreport top level dir:
#pull all active pids and sub-connections, plus creation date of pid:
~~~
for pid in `awk '/.*haproxy/{print $2}' ps`; do echo "process $pid connections"; grep "$pid" ps | awk '{print $9}'; grep "ESTABLISHED.*$pid" netstat; done
~~~

#get all connection types:
~~~
for pid in `awk '/.*haproxy/{print $2}' ps`; do echo "process $pid connections"; grep "$pid" ps | awk '{print $9}'; grep ".*$pid" netstat; done
~~~

#get connections in CLOSE_WAIT
~~~
for pid in `awk '/.*haproxy/{print $2}' ps`; do echo "process $pid connections"; grep "$pid" ps | awk '{print $9}'; grep "CLOSE_WAIT.*$pid" netstat; done
~~~

#get number of hits per container IP connection (append to end of string call)
~~~
<output> | awk {'print $5'} | awk -F : '{print $1}' |sort | uniq -c
~~~


# while on a node running HaProxy:


#get connections in ESTABLISHED:
~~~
for pid in `ps auxwwwm | awk '/.*haproxy/{print $2}'`; do echo "process $pid connections"; ps auxwwwm | grep "$pid" | awk '{print $9}'; netstat -neopa | grep "ESTABLISHED.*$pid"; done
~~~

#get connections in any socket state:
~~~
for pid in `ps auxwwwm | awk '/.*haproxy/{print $2}'`; do echo "process $pid connections"; ps auxwwwm | grep "$pid" | awk '{print $9}'; netstat -neopa | grep ".*$pid"; done
~~~