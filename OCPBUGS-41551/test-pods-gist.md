oc apply -f nginx-daemonset.yaml
oc get pods --no-headers -o wide| awk '{print $6}' > files/ips.txt
for pod in `oc get pods -n default --no-headers | awk '{print $1}'`; do oc cp files/ $pod:/tmp; done
for pod in `oc get pods -n default --no-headers | awk '{print $1}'`; do oc exec $pod -- sh /tmp/files/curl-ip.sh >> out.txt ; done
cat out.txt | grep log                                           # Check out.txt for any non connections




__files/curl-ip.sh__
cat /tmp/files/ips.txt | while read line; do curl --retry 3 --connect-timeout 2 $line:8080 > /tmp/$line.log; done; 
faulty_connection_ips=$(ls -l /tmp| grep -v 72| grep log)       # A successful curl's log file is 72 bytes in size for our image
echo $HOSTNAME
echo "$faulty_connection_ips"


__nginx-daemonset.yaml__
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx
spec:
  selector:
    matchLabels:
      name: nginx
  template:
    metadata:
      labels:
        name: nginx
    spec:
      containers:
        - name: nginx
          image: quay.io/redhattraining/hello-world-nginx
