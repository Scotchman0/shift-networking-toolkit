#!/bin/bash
          set -exuo pipefail
{{ if .NETWORK_NODE_IDENTITY_ENABLE }}
          # When NETWORK_NODE_IDENTITY_ENABLE is true, use the per-node certificate to create a kubeconfig
          # that will be used to talk to the API


          # Wait for cert file
          retries=0
          tries=20
          key_cert="/etc/ovn/ovnkube-node-certs/ovnkube-client-current.pem"
          while [ ! -f "${key_cert}" ]; do
            (( retries += 1 ))
            if [[ "${retries}" -gt ${tries} ]]; then
              echo "$(date -Iseconds) - ERROR - ${key_cert} not found"
              return 1
            fi
            sleep 1
          done

          cat << EOF > /var/run/ovnkube-kubeconfig
          apiVersion: v1
          clusters:
            - cluster:
                certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
                server: {{.K8S_APISERVER}}
              name: default-cluster
          contexts:
            - context:
                cluster: default-cluster
                namespace: default
                user: default-auth
              name: default-context
          current-context: default-context
          kind: Config
          preferences: {}
          users:
            - name: default-auth
              user:
                client-certificate: /etc/ovn/ovnkube-node-certs/ovnkube-client-current.pem
                client-key: /etc/ovn/ovnkube-node-certs/ovnkube-client-current.pem
          EOF
          export KUBECONFIG=/var/run/ovnkube-kubeconfig
{{ end }}

          if rpm --dbpath=/usr/share/rpm -q libreswan; then
            echo "host has libreswan and therefore ipsec will be configured by ipsec daemonset, this ovn ipsec container doesnt need to init anything"
            exit 0
          fi

          # Every time we restart this container, we will create a new key pair if
          # we are close to key expiration or if we do not already have a signed key pair.
          #
          # Each node has a key pair which is used by OVS to encrypt/decrypt/authenticate traffic
          # between each node. The CA cert is used as the root of trust for all certs so we need
          # the CA to sign our certificate signing requests with the CA private key. In this way,
          # we can validate that any signed certificates that we receive from other nodes are
          # authentic.
          echo "Configuring IPsec keys"

          cert_pem=/etc/openvswitch/keys/ipsec-cert.pem

          # If the certificate does not exist or it will expire in the next 6 months
          # (15770000 seconds), we will generate a new one.
          if ! openssl x509 -noout -dates -checkend 15770000 -in $cert_pem; then
            # We use the system-id as the CN for our certificate signing request. This
            # is a requirement by OVN.
            cn=$(ovs-vsctl --retry -t 60 get Open_vSwitch . external-ids:system-id | tr -d "\"")

            mkdir -p /etc/openvswitch/keys

            # Generate an SSL private key and use the key to create a certitificate signing request
            umask 077 && openssl genrsa -out /etc/openvswitch/keys/ipsec-privkey.pem 2048
            openssl req -new -text \
                        -extensions v3_req \
                        -addext "subjectAltName = DNS:${cn}" \
                        -subj "/C=US/O=ovnkubernetes/OU=kind/CN=${cn}" \
                        -key /etc/openvswitch/keys/ipsec-privkey.pem \
                        -out /etc/openvswitch/keys/ipsec-req.pem

            csr_64=$(base64 -w0 /etc/openvswitch/keys/ipsec-req.pem) # -w0 to avoid line-wrap

            # Request that our generated certificate signing request is
            # signed by the "network.openshift.io/signer" signer that is
            # implemented by the CNO signer controller. This will sign the
            # certificate signing request using the signer-ca which has been
            # set up by the OperatorPKI. In this way, we have a signed certificate
            # and our private key has remained private on this host.
            cat <<EOF | kubectl create -f -
            apiVersion: certificates.k8s.io/v1
            kind: CertificateSigningRequest
            metadata:
              generateName: ipsec-csr-$(hostname)-
              labels:
                k8s.ovn.org/ipsec-csr: $(hostname)
            spec:
              request: ${csr_64}
              signerName: network.openshift.io/signer
              usages:
              - ipsec tunnel
          EOF
            # Wait until the certificate signing request has been signed.
            counter=0
            until [ -n $(kubectl get csr -lk8s.ovn.org/ipsec-csr=$(hostname) --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].status.certificate}' 2>/dev/null) ]
            do
              counter=$((counter+1))
              sleep 1
              if [ $counter -gt 60 ];
              then
                      echo "Unable to sign certificate after $counter seconds"
                      exit 1
              fi
            done

            # Decode the signed certificate.
            kubectl get csr -lk8s.ovn.org/ipsec-csr=$(hostname) --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].status.certificate}' | base64 -d | openssl x509 -outform pem -text -out $cert_pem

            # Get the CA certificate so we can authenticate peer nodes.
            openssl x509 -in /signer-ca/ca-bundle.crt -outform pem -text -out /etc/openvswitch/keys/ipsec-cacert.pem
          fi

          # Configure OVS with the relevant keys for this node. This is required by ovs-monitor-ipsec.
          #
          # Updating the certificates does not need to be an atomic operation as
          # the will get read and loaded into NSS by the ovs-monitor-ipsec process
          # which has not started yet.
          ovs-vsctl --retry -t 60 set Open_vSwitch . other_config:certificate=$cert_pem \
                                                     other_config:private_key=/etc/openvswitch/keys/ipsec-privkey.pem \
                                                     other_config:ca_cert=/etc/openvswitch/keys/ipsec-cacert.pem