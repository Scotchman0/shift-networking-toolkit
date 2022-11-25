#!/bin/bash
# haproxy config baseline output script for reviewing a general overview of the expected workload on a haproxy config
# provided as-is with no warranties for use in supporting Red Hat troubleshooting efforts

echo "this tool is designed to review and summarize how many routes you have of each type for a given haproxy.config"
echo "The following information may help illustrate whether or not your router pods are overloaded and require sharding"
echo "Please open a support case for a more thorough understanding of limits and tolerances on your router pod configuration"
echo ""
echo "Please specify path to haproxy.config and press return to continue"
read CONFIG

echo "default haproxy cluster backend totals:"
echo "Dynamic-cookie-key: " cat $CONFIG | grep dynamic-cookie-key | wc -l
echo "server-templates: " cat $CONFIG | grep server-template | wc -l
echo "be_http: " cat $CONFIG | grep be_http | wc -l
echo "be_tcp: " cat $CONFIG | grep be_tcp | wc -l
echo "be_sni: " cat $CONFIG | grep be_sni | wc -l
echo "be_no_sni: " cat $CONFIG | grep be_no_sni | wc -l
echo "be_edge_http: " cat $CONFIG | grep be_edge_http | wc -l

exit 0
