#!/bin/bash
echo "starting initial delay timer"
sleep 5m
echo "Running IKE heal loop..."
# Path to the ipsec configuration file and control socket
IPSEC_CONF="/etc/ipsec.conf"
PLUTO_CTL="/run/pluto/pluto.ctl"
# Function to get active connections from Libreswan (pluto)
get_active_connections() {
  # Get the list of active IKE connections
  ipsec status | grep ESTABLISHED_IKE| grep -Eo 'ovn-[-A-Za-z0-9]+' | sed -E 's/-(in|out)-[0-9]+$//'
}
# Function to get defined connections from ipsec.conf
get_defined_connections() {
 # Extract connection names from ipsec.conf
 grep '^conn ovn-' "$IPSEC_CONF" | awk '{print $2}' | sort
}
# Function to replace the connection
replace_connection() {
 local conn_name="$1"
 echo "$(date): Replacing missing connection: $conn_name"
 ipsec auto --config "$IPSEC_CONF" --ctlsocket "$PLUTO_CTL" --replace "$conn_name"
 ipsec auto --config "$IPSEC_CONF" --ctlsocket "$PLUTO_CTL" --up "$conn_name"
}
heal_ike() {
 # Get the lists of active and defined connections
 active_connections=$(get_active_connections)
 defined_connections=$(get_defined_connections)
 # Compare defined connections with active ones
 for conn in $defined_connections; do
     parsed_conn=$(echo $conn | sed -E 's/-(in|out)-[0-9]+$//')
     if ! echo "$active_connections" | grep -q "$parsed_conn"; then
         already_parsed=0
         for item in "${replaced_parsed_conns[@]}"; do
             if [[ "$item" == "$parsed_conn" ]]; then
                 already_parsed=1
                 break
             fi
         done
        if [[ $already_parsed -eq 1 ]]; then
            continue
        fi
        # Connection is missing, so replace it
        replaced_parsed_conns+=("$parsed_conn")
        replace_connection "$conn"
     fi
 done
}
# Main loop
while true; do
  heal_ike
  sleep 300
done