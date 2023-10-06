#basic script to deploy a webhost at a local directory to validate egress is successful, via egress pod

echo "Hello Egress traffic is Working" > /tmp/test-egress.txt
firewall-cmd --zone=public --add-port=8080/tcp
python -m http.server --directory /tmp 8080
