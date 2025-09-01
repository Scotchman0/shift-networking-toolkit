#!/bin/bash

# a quick analysis tool for reviewing audit logs:
# oc adm must-gather -- /usr/bin/gather_audit_logs
# Run from directory `audit_logs` so that we can iterate across all bundled + zipped logs in each subdirectory

DATE=$(date +"%Y-%m-%d-%H-%M")

# extract and expand audit logs and put a marker down to ensure it only runs once:
if [[ -f ./decompressed ]]
  then
    echo "skipping decompression"
  else
    for folder in $(ls); do echo "now unzipping ${folder}"; gunzip $folder/*; echo "done"; done
    touch ./decompressed
fi

# search for phrase on prompt
 echo "what phrase or log line are we looking for? insert a string an press return"
 read searchterm
 egrep '${searchterm}' -rc * 2>/dev/null | grep -v :0 | tee ${DATE}_report.out 
 echo "searchterm: ${searchterm} was seen in the above logs with hit count appended - <logpath>:<count>" >> ${DATE}_report.out
 echo "results available in ./${DATE}_report.out"
exit 0
