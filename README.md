# shift-networking-toolkit
A collection of scripts designed to aide in data gather and analysis of OpenShift Cluster traffic.

# haproxy-gather.sh
Can be used to gather a summary output of all router-pods statistics from your cluster at once along with haproxy.config for help in understanding more about how your cluster is routing traffic to it's backend pods.

See https://access.redhat.com/solutions/6987555 for more information on how to anlyize contents pulled by haproxy-gather, and refer to the documentation at https://docs.openshift.com/container-platform/4.11/networking/routes/route-configuration.html#nw-route-specific-annotations_route-configuration for more on how to streamline and optimize your routes. This script is designed primarily to aggregate data for easier troubleshooting efforts. 

