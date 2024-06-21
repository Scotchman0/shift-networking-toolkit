# Use UBI8 as the base image
FROM registry.access.redhat.com/ubi8/ubi-minimal:latest

# Set the working directory in the container
WORKDIR /app

# Copy package.json and package-lock.json (if available)
#COPY package*.json./

# Install dependencies
RUN microdnf install -y nodejs npm && \
    microdnf clean all

# Copy the rest of the application code
#COPY

# Expose port 80
EXPOSE 80

# Start the application
CMD ["node", "server.js"]