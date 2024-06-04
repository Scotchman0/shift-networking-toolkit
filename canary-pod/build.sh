#!/bin/bash
#build script to deploy latest revision of dockerfile for container testing

set -e

# set variables
IMAGE_TAG=canary-pod:latest
#set NGINX_PORT
NGINX_PORT="8888"

podman build . -t ${IMAGE_TAG}

# push to quay if --push flag is passed
if [ "$1" = "--push" ]; then
    PUSH_NAME=quay.io/rhn_support_wrussell/${IMAGE_TAG}

    podman tag ${IMAGE_TAG} ${PUSH_NAME}
    echo "Tagged ${IMAGE_TAG} as ${PUSH_NAME}"

    echo "Pushing to quay..."
    podman push ${PUSH_NAME}
    echo "Pushed ${PUSH_NAME}"
fi