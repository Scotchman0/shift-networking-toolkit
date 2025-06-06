#!/bin/bash
# keepalived toolkit to quick-validate VIP placement, scrape details on live clusters and perform health checks
# Written by Will Russell, 2025 Red Hat
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

# determine if we're logged into a cluster or not and assume that if we're logged in we must want live data
if [[ $(oc whoami | grep "(Forbidden)") ]]


#  sunbro@apollo  ~  oc whoami
# wrussell
#  sunbro@apollo  ~  oc logout
# Logged "wrussell" out on "https://api.shrocp4upi416ovn.lab.upshift.rdu2.redhat.com:6443"
#  sunbro@apollo  ~  oc whoami 
# Error from server (Forbidden): users.user.openshift.io "~" is forbidden: User "system:anonymous" cannot get resource "users" in API group "user.openshift.io" at the cluster scope
# sunbro@apollo:~/.kube$ oc whoami
# error: Missing or incomplete configuration info.  Please point to an existing, complete config file:


#   1. Via the command-line flag --kubeconfig
#   2. Via the KUBECONFIG environment variable
#   3. In your home directory as ~/.kube/config

# To view or setup config directly use the 'config' command.


#~# FUNCTION BLOCKS #~#

# General data-get script and executes on must-gathers or live-clusters alike:
basic_report(){


}

#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#

# SCRIPT LOGICAL FLOW START #

# while test $# -gt 0; do #general while loop to lock behavior surrounding case options. 
  case "$1" in
    -h|--help)
      echo ""
      echo "Usage and arguments overview - review documentation for more details"
      echo "-h|--help) - print brief help details"
      echo ""
      exit 0
      ;;

    *)
    # If no arguments supplied, run the basic_report script, or output a warning that specific flags are needed to do more
    if test $# -gt 0; then
      basic_report
      break
    else
      echo "This script will run without any input, but accepts specific arguments, review 'keepalive_check.sh help' for usage syntax"
      break
    fi
      ;;
  esac
done