#!/bin/bash
#targeted tcpdump for host ifaces

####
#variables:

IFACE1=tun0
IFACE2=vxlan_sys_4789
IFACE3=ens3

#####
#function blocks:
start_tcpdump() {

#options: -C 100 (100MB)
#options: -W 5 (5 pcaps buffer)
#options: -s 100 (snapshot length of 110 to truncate pcap size)
  tcpdump -s 110 -i $IFACE1 -C 100 -W 5 -w /tmp/$IFACE1.pcap &
  tcpdump -s 110 -i $IFACE2 -C 100 -W 5 -w /tmp/$IFACE2.pcap &
  tcpdump -s 110 -i $IFACE3 -C 100 -W 5 -w /tmp/$IFACE3.pcap &
}

stop_tcpdump() {

  pkill tcpdump

}

#####
#main logic:
echo "press return to start tcpdump capture"
read dummyfile
start_tcpdump
echo "tcpdump is now running, press return to stop capture after you observe the flapping behavior"
read dummyfile
stop_tcpdump
echo "files available at /tmp/, don't forget to move them to /host if running inside a toolbox pod/debug shell:"
ls -l /tmp/ | grep ".pcap"
exit 0
