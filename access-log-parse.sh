#!/bin/bash
#access log parsing tool for analysis asistance and filtered outputs


#define variables:
ROUTE="$1"

echo "STATUS CODE, TERM STATE, TR '/' Tw '/' Tc '/' Tr '/' Ta* " 
oc logs router-default-<name> -c logs | grep $ROUTE | grep -Evwi "200|404|stopped|stopping|started|starting" | awk {'print $11,$15,$16'}


# Status Code: The HTTP status code returned to the client. Generally set by the server but if the server is unreachable can be set by HAProxy.
# Termination State: Condition the session was in when it was ending, indicates session state, which side ended the session and the reason
# https://docs.haproxy.org/2.8/configuration.html#:~:text=The%20most%20common%20termination%20flags%20combinations%20are%20indicated%20below.%20They%20are

# TR: The total time in milliseconds spent waiting for the full HTTP request from the client. This time starts after the first byte is received. A large value could be indicative of network issues or latency. A value of -1 indicates the connection was aborted
# Tw: Total time in milliseconds spent waiting in various queues. Value of -1 indicates connection was aborted
# Tc: Total time in milliseconds spent waiting for connection to establish to final server including retries. A value of -1 indicates connection was aborted
# Tr: Total time in milliseconds spent waiting for the server to send a full HTTP response. A value of -1 indicates a connection was aborted. Generally matches the servers processing time.
# Ta: Time the request remains active in HAProxy. Total time elapsed between when the first byte is received and when is the last byte is received. Covers all processing time except handshake and idle time.

