#!/bin/bash

set -e

SERVICE="webhook"
NAMESPACE="default"
TMPDIR="./certs"

mkdir -p $TMPDIR

echo "Generating CA cert..."
openssl genrsa -out $TMPDIR/ca.key 2048
openssl req -x509 -new -nodes -key $TMPDIR/ca.key -subj "/CN=webhook-ca" -days 3650 -out $TMPDIR/ca.crt

# Create openssl config file for SAN
cat > $TMPDIR/server-openssl.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]
# empty

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${SERVICE}
DNS.2 = ${SERVICE}.${NAMESPACE}
DNS.3 = ${SERVICE}.${NAMESPACE}.svc
DNS.4 = ${SERVICE}.${NAMESPACE}.svc.cluster.local
EOF

echo "Generating server key and CSR..."
openssl genrsa -out $TMPDIR/server.key 2048
openssl req -new -key $TMPDIR/server.key -subj "/CN=${SERVICE}.${NAMESPACE}.svc" \
  -out $TMPDIR/server.csr -config $TMPDIR/server-openssl.cnf

echo "Signing server cert with CA including SANs..."
openssl x509 -req -in $TMPDIR/server.csr -CA $TMPDIR/ca.crt -CAkey $TMPDIR/ca.key \
  -CAcreateserial -out $TMPDIR/server.crt -days 3650 \
  -extensions v3_req -extfile $TMPDIR/server-openssl.cnf

echo "Done. Files:"
ls -l $TMPDIR

echo ""
echo "Base64 CA cert (for caBundle in webhook config):"
cat $TMPDIR/ca.crt | base64 | tr -d '\n'
echo ""
