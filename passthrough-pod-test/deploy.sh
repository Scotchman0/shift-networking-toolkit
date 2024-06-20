oc new-project rh-testing
oc create secret tls my-wildcard-certificate --cert=/path/to/cert.pem --key=/path/to/key.pem -n rh-testing
oc create -f DeploymentConfig.yaml
