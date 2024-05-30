FROM ubi8:latest

# Install curl and nginx
RUN yum update -y && yum install curl nginx -y

# Copy the shell script and nginx config
COPY canary-pod.sh /canary-pod.sh
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Make the script executable
RUN chmod +x /canary-pod.sh

# Set the entrypoint
ENTRYPOINT ["/canary-pod.sh"]
