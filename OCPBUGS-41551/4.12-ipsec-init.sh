#!/bin/bash
          set -exuo pipefail

          # Every time we restart this container, we will create a new key pair if
          # we are close to key expiration or if we do not already have a signed key pair.
          #
          # Each node has a key pair which is used by OVS to encrypt/decrypt/authenticate traffic
          # between each node. The CA cert is used as the root of trust for all certs so we need
          # the CA to sign our certificate signing requests with the CA private key. In this way,
          # we can validate that any signed certificates that we receive from other nodes are
          # authentic.
          echo "Configuring IPsec keys"

          # If the certificate does not exist or it will expire in the next 6 months
          # (15770000 seconds), we will generate a new one.
          if [ ! -e /etc/openvswitch/keys/ipsec-cert.pem ] || [ ! openssl x509 -noout -dates -checkend 15770000 ];
          then
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

            csr_64=$(cat /etc/openvswitch/keys/ipsec-req.pem | base64 | tr -d "\n")

            # The signer controller does not allow re-signing a key. We will
            # delete the old key to be sure it is not there
            kubectl delete --ignore-not-found=true csr/$(hostname)

            # Request that our generated certificate signing request is
            # signed by the "network.openshift.io/signer" signer that is
            # implemented by the CNO signer controller. This will sign the
            # certificate signing request using the signer-ca which has been
            # set up by the OperatorPKI. In this way, we have a signed certificate
            # and our private key has remained private on this host.
            cat <<EOF | kubectl apply -f -
            apiVersion: certificates.k8s.io/v1
            kind: CertificateSigningRequest
            metadata:
              name: $(hostname)
            spec:
              request: ${csr_64}
              signerName: network.openshift.io/signer
              usages:
              - ipsec tunnel
          EOF

            # Wait until the certificate signing request has been signed.
            counter=0
            until [ ! -z $(kubectl get csr/$(hostname) -o jsonpath='{.status.certificate}' 2>/dev/null) ]
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
            kubectl get csr/$(hostname) -o jsonpath='{.status.certificate}' | base64 -d | openssl x509 -outform pem -text -out /etc/openvswitch/keys/ipsec-cert.pem

            kubectl delete csr/$(hostname)

            # Get the CA certificate so we can authenticate peer nodes.
            cat /signer-ca/ca-bundle.crt | openssl x509 -outform pem -text > /etc/openvswitch/keys/ipsec-cacert.pem
          fi

          # Configure OVS with the relevant keys for this node. This is required by ovs-monitor-ipsec.
          #
          # Updating the certificates does not need to be an atomic operation as
          # the will get read and loaded into NSS by the ovs-monitor-ipsec process
          # which has not started yet.
          ovs-vsctl --retry -t 60 set Open_vSwitch . other_config:certificate=/etc/openvswitch/keys/ipsec-cert.pem \
                                                     other_config:private_key=/etc/openvswitch/keys/ipsec-privkey.pem \
                                                     other_config:ca_cert=/etc/openvswitch/keys/ipsec-cacert.pem