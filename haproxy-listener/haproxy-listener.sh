#!/bin/bash

#custom script to poll periodically for haproxy pids + tie existing application sessions to them
#log the content in a local DB + expose the stats via socket
#prometheus will be configured to listen to this pod's report for promql tie in

#version:
version=0.1

#mainainer: Will Russell 
#presented as-is without warranty or expectation of support

### THOUGHT PROCESS BLOCK ###
# okay so this will be running in a container, scoped to each infra node with a valid router pod