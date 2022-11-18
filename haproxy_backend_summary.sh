#!/bin/bash
# haproxy config baseline output script for reviewing a general overview of the expected workload on a haproxy config

echo "haproxy backend report, please specify haproxy.config name and press return to continue"
read $haproxy_1

echo "default haproxy cluster backend totals:"
echo "Dynamic-cookie-key: " cat $haproxy_1 | grep dynamic-cookie-key | wc -l
echo "server-templates: " cat $haproxy_1 | grep server-template | wc -l
echo "be_http: " cat $haproxy_1 | grep be_http | wc -l
echo "be_tcp: " cat $haproxy_1 | grep be_tcp | wc -l
echo "be_sni: " cat $haproxy_1 | grep be_sni | wc -l
echo "be_no_sni: " cat $haproxy_1 | grep be_no_sni | wc -l
echo "be_edge_http: " cat $haproxy_1 | grep be_edge_http | wc -l
