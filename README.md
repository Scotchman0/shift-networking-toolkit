# shift-networking-toolkit
A collection of scripts designed to aide in data gather and analysis of OpenShift Cluster traffic.

This repository and all included scripts are debugging tools provided without warranty. They offers no support from Red Hat or any other official source. Please use at your own risk.

# haproxy-gather.sh
Can be used to gather a summary output of all router-pods statistics from your cluster at once along with haproxy.config for help in understanding more about how your cluster is routing traffic to it's backend pods.

Note that router pod hit statistics being gathered are subject to intermittent log clears, and so repeated gathers may be necessary to get a fully comprehensive view of activity. Stats are not persistent even through the lifespan of a container and are cleared frequently; Assume that your visibility on hits is about 15 minutes worth of recent activity per route. 

See https://access.redhat.com/solutions/6987555 for more information on how to anlyize contents pulled by haproxy-gather, and refer to the documentation at https://docs.openshift.com/container-platform/4.11/networking/routes/route-configuration.html#nw-route-specific-annotations_route-configuration for more on how to streamline and optimize your routes. This script is designed primarily to aggregate data for easier troubleshooting efforts. 

# Analyze_stats.sh
This is a fast-analysis script that will grab the lbtot hit counter for your desired route query, the annotations recorded by haproxy.config for confirming load-balance type and similar, and will also compile a summary table for all pods associated with the route for analysis, based on information provided from haproxy-gather.sh. Run this script inside the resulting haproxy-gather/ folder, specifying the haproxy.config file you are examining (for example, default_haproxy.config) and the route you want to review: (for example, httpd-ex).
