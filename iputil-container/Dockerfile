#minimal Dockerfile to deploy a network testing container on OpenShift
#hosted at QUAY: quay.io/rhn_support_wrussell/iputils-container:latest
from ubi8:latest
#install ip/curl/ping/dig/arp/netstat/ss/netcat/socat
RUN yum update -y && yum install iputils iproute net-tools bind-utils iproute nc socat -y
RUN echo "available tools: ip, curl, ping, dig, arp, netstat, ss, netcat socat.  Container does not include a default shell entrypoint" >> /README.md
ENTRYPOINT ["tail", "-f", "/dev/null"]
