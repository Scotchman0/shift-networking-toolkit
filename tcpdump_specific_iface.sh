#!/bin/bash
#targeted tcpdump for host ifaces

####
#variables 
#path overrides necessary for debug shells on openshift.
TCPDUMP=$(which tcpdump)
PKILL=$(which pkill)

IFACE1=tun0
IFACE2=vxlan_sys_4789
IFACE3=ens3
IFACE4=veth117342b2

SNAPLEN=110 #set to 0 for no byte size limit; reduced size is helpful for confirming flow only without all headers.
SIZE=100 #define max size of pcap
COUNT=5 #define number of captures
PATH=/dev/shm

OPTIONAL_FILTER='' #set to null by default but can be used to define ports or IP addresses to scope your traffic requests


#####
#kickstart tcpdumps in background processes with defined parameters on specified interfaces:
start_tcpdump() {
  $TCPDUMP -s $SNAPLEN -i $IFACE1 -C $SIZE -W $COUNT -w $PATH/$IFACE1.pcap ${OPTIONAL_FILTER} &
  $TCPDUMP -s $SNAPLEN -i $IFACE2 -C $SIZE -W $COUNT -w $PATH/$IFACE2.pcap ${OPTIONAL_FILTER} &
  $TCPDUMP -s $SNAPLEN -i $IFACE3 -C $SIZE -W $COUNT -w $PATH/$IFACE3.pcap ${OPTIONAL_FILTER} &
  $TCPDUMP -s $SNAPLEN -i $IFACE4 -C $SIZE -W $COUNT -w $PATH/$IFACE4.pcap ${OPTIONAL_FILTER} & 
}

stop_tcpdump() {

  $PKILL tcpdump

}

#####
#main logic:
echo "press return to start tcpdump capture"
read dummyfile
start_tcpdump
echo "tcpdump is now running, press return to stop capture after you observe the flapping behavior"
read dummyfile
stop_tcpdump
echo "files available at $PATH, don't forget to move them to /host/var/tmp/ if running inside a toolbox pod/debug shell:"
ls -l $PATH | grep ".pcap"
exit 0