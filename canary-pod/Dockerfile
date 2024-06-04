#Container to deploy custom canary-pod to alert that router configuration and calico-node is online
#Written by Will Russell for use in testing/workaround for Calico-node late start problem on infra hosts

FROM ubi8:latest

# Install curl and nginx
RUN yum update -y && yum install curl nginx -y

# Copy the shell script and nginx config
COPY canary-pod.sh /canary-pod.sh
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Make the script executable
RUN chmod +x /canary-pod.sh

#suggest exposed container port - nginx currently listening on this port
EXPOSE 8888

# Set the entrypoint
ENTRYPOINT ["/canary-pod.sh"]