openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout private-key.pem -out wildcard-cert.pem -subj "/C=US/ST=State/L=City/O=Organization/CN=*.myexample.mydomain.com"
