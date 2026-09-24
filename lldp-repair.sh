#!/usr/bin/env bash
# lldp bond repair as pertains to: https://access.redhat.com/solutions/7145039
# FIRE THIS LOGIC FLOW ONLY IF:
# /etc/NetworkManager/system-connections/ovs-if-phys0.nmconnection is found to rebuild the bond.
# recommended to encase this into a logic loop where it only fires if ovs-if-phys0.nmconnection is found at /etc/NetworkManager/system-connections/
# this script ASSUMES that ovs-if-phys0 exists and is intended to replace/fix the bond that used to exist in it's place.
# This script ASSUMES that ovs-if-phys0 has replaced an existing bond
set -euo pipefail

#note that bond0 is NOT a guaranteed name we need the primary bond used by br-ex
#therefore, safer to get the controller value from ovs-if-phys0 first which has mangled the bond and confirm name there before applying
#Can alternatively be pre-set to an explicit value - commented out.

#BOND=bond0
OVS_IF_PROFILE="ovs-if-phys0"
OVS_IF_FILE="/etc/NetworkManager/system-connections/${OVS_IF_PROFILE}.nmconnection"
#the below grep queries for this line: `controller=<iface-name>` and returns the bond name
BOND=$(grep controller ${OVS_IF_FILE} | awk -F '=' {'print $2'})
BACKUP_DIR="/root/nmconnection-backup-$(date +%F-%H%M%S)"

mkdir -p "$BACKUP_DIR"

#fail early if the ovs_file that means we've broken the node isn't found - we shouldn't operate on the node unless we are in 
#specific break condition case so confirm the file exists first before making changes:
#healthy node should NOT find ovs-if-phys0.nmconnection in /etc/NetworkManager/system-connections (only should be found in /run/...)

echo "===== backing up $OVS_IF_FILE ====="
if [[ ! -f "$OVS_IF_FILE" ]]; then
  echo "ERROR: expected file not found: $OVS_IF_FILE"
  exit 1
fi

cp -a "$OVS_IF_FILE" "$BACKUP_DIR"/

echo "===== discovering current ${BOND} members ====="
if [[ ! -r /sys/class/net/${BOND}/bonding/slaves ]]; then
  echo "ERROR: /sys/class/net/${BOND}/bonding/slaves not found"
  exit 1
fi

# acquire member names for bond:
MEMBERS="$(cat /sys/class/net/${BOND}/bonding/slaves)"

if [[ -z "$MEMBERS" ]]; then
  echo "ERROR: ${BOND} has no members"
  cat /proc/net/bonding/${BOND} || true
  exit 1
fi

echo "Detected ${BOND} members: $MEMBERS"

# acquire mac address to set as primary for the bond to guarantee consistent IP acquisition (may be optional for your configs but helpful for dhcp)
CLONED_MAC="$(awk -F= '/^cloned-mac-address=/{print $2; exit}' "$OVS_IF_FILE")"

if [[ -z "$CLONED_MAC" ]]; then
  echo "ERROR: cloned-mac-address not found in $OVS_IF_FILE"
  exit 1
fi

echo "Detected cloned MAC: $CLONED_MAC"

# acquire bond options
BOND_OPTIONS=$(grep -E 'lacp_rate|miimon|mode|xmit_hash_policy' $OVS_IF_FILE)
# append a comma, remove spaces:
BOND_OPTIONS_FORMATTED=$(for i in $OPTIONS; do echo -n ${i},; done)

echo "===== deleting bad OVS bond profile ====="
nmcli con delete "$OVS_IF_PROFILE" 2>/dev/null || true
rm -f "$OVS_IF_FILE"

#Rebuild the bond:
echo "===== creating plain bond0 profile ====="
#if bond is still present in nmcli, mod it to create an updated profile definition with same uuid, otherwise make a new one:
if nmcli con show "$BOND" >/dev/null 2>&1; then
  nmcli con mod "$BOND" \
    bond.options "$BOND_OPTIONS_FORMATTED" \
    ethernet.cloned-mac-address "$CLONED_MAC" \
    ipv4.method auto \
    ipv6.method disabled \
    connection.autoconnect yes \
    connection.lldp disable
else
  nmcli con add type bond \
    con-name "$BOND" \
    ifname "$BOND" \
    bond.options "$BOND_OPTIONS_FORMATTED" \
    ethernet.cloned-mac-address "$CLONED_MAC" \
    ipv4.method auto \
    ipv6.method disabled \
    connection.autoconnect yes \
    connection.lldp disable
fi

#set lldp=1 on the LINKS for the bond (still enables lldp but in compliant way regardless of openshift version)
echo "===== setting LLDP on underlying links ====="
for MEMBER in $MEMBERS; do
  echo "Enabling LLDP on $MEMBER"
  nmcli con mod "$MEMBER" connection.lldp enable-rx
done

echo "===== reloading NetworkManager connection files ====="
nmcli con reload

#confirm lldp is DISABLED on bond
echo "===== validation ====="
echo "--- ${BOND} profile LLDP ---"
nmcli -f connection.id,connection.interface-name,connection.lldp con show "$BOND" || true

#confirm lldp is ENABLED on bond links
echo "--- member profile LLDP ---"
for MEMBER in $MEMBERS; do
  nmcli -f connection.id,connection.interface-name,connection.lldp con show "$MEMBER" || true
done

echo "===== done ====="
echo "Backup saved in: $BACKUP_DIR"
echo "Reboot the node when ready."
