#!/bin/bash
#network-sos.sh 
#Will Russell
#https://github.com/Scotchman0/shift-networking-toolkit/blob/main/network-sos.sh
#supplemental manual pull for sosreport for networking/ss/ethtool capture on target host
#largely attempting to replicate sos's network.py script for one-off gathers.
#Run as root on host node (not from within toolbox container, we're not escaping the chroot for these calls).

DATE=$(date +"%Y-%m-%d-%H-%M-%S")
TARGETDIR=./sos-netdump-${DATE}

mkdir $TARGETDIR && cd $TARGETDIR
#get ethtool output for every device:

for x in $(ip l l | grep mtu | tr ":@" " " | awk '{print $2}'); do
  ethtool --phy-statistics $x > ethtool_--phy-statistics_${x};
  ethtool --show-priv-flags $x > ethtool_--show-priv-flags_${x};
  ethtool --show-eee $x > ethtool_--show-eee_${x};
  ethtool $x > ethtool_${x};
  #skip by default because can hang but can enable manually:
  #ethtool -e $x > ethtool_-e_${x};
  ethtool -i $x > ethtool_-i_${x};
  ethtool -k $x > ethtool_-k_${x};
  ethtool -S $x > ethtool_-S_${x};
  ethtool -m $x > ethtool_-m_${x};
  ethtool -P $x > ethtool_-P_${x};
  ethtool -l $x > ethtool_-l_${x};
  ethtool -g $x > ethtool_-g_${x};
  ethtool -a $x > ethtool_-a_${x};
  ethtool -c $x > ethtool_-c_${x};
  ethtool -d $x > ethtool_-d_${x};
  ethtool -T $x > ethtool_-T_${x};
  tc -s filter show dev $x > tc_-s_filter_show_dev_${x};
  tc -s filter show dev $x ingress > tc_-s_filter_show_dev_ingress_${x};
done


#get general IP data information from the host:
ip -d address show > ip_-d_address_show
ip -o addr > ip_-o_addr
ip route show table all > ip_route_show_table_all
ip -s -s neigh show > ip_-s_-s_neigh_show
ip -4 rule list > ip_-4_rule_list
ip -6 rule list > ip_-6_rule_list
ip vrf show > ip_vrf_show
sysctl -a > sysctl_-a
netstat -neopa > netstat_-neopa
netstat -s > netstat_-s
netstat -agn > netstat_-agn
#netstat -zas > netstat_-zas
iptables-save > iptables_-save
ip6tables-save > ip6tables_-save
#networkctl status -a > networkctl_status_-a
ip -6 route show table all > ip_-6_route_show_table_all
ip -d route show cache > ip_-d_route_show_cache
ip -d -6 route show cache > ip_-d_-6_show_cache
ip -d address > ip_-d_address
ip -s -d link > ip_-s_-d_link
ifenslave -a > ifenslave_-a
ip mroute show > ip_mroute_show
ip -s -s neigh show > ip_-s_-s_neigh_show
ip neigh show nud noarp > ip_neigh_show_nud_noarp
#biosdevname -d > biosdevname_-d
tc -s qdisc show > tc_-s_qdisc_show
nmstatectl show 2>/dev/null > nmstatectl_show
nmstatectl show --running-config 2>/dev/null > nmstatectl_show_--running-config


#pull devlink data:
devlink dev param show > devlink_dev_param_show
devlink dev info > devlink_dev_info
devlink port show > devlink_port_show
devlink sb show > devlink_sb_show
devlink sb pool show > devlink_sb_pool_show
devlink sb port pool show > devlink_sb_port_pool_show
devlink sb tc bind show > devlink_sb_tc_bind_show
devlink -s -v trap show > devlink_-s_-v_trap_show

#get ss data from the host:
ss -peaonmi > ss_-peaonmi
ss -s > ss_-s

#exit the folder, tarball the contents
cd ..
tar -czf $TARGETDIR.tar.gz ./$TARGETDIR

echo "export complete, please attach the resulting tarball"
ls | grep $TARGETDIR.tar.gz
