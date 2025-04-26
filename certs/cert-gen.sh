#!/bin/bash

set -e

SERVICE="webhook"
NAMESPACE="default"
TMPDIR=$(mktemp -d)

echo "Generating CA cert..."
openssl genrsa -out $TMPDIR/ca.key 2048
openssl req -x509 -new -nodes -key $TMPDIR/ca.key -subj "/CN=webhook-ca" -days 3650 -out $TMPDIR/ca.crt

echo "Generating server cert signed by CA..."
openssl genrsa -out $TMPDIR/server.key 2048
openssl req -new -key $TMPDIR/server.key -subj "/CN=${SERVICE}.${NAMESPACE}.svc" -out $TMPDIR/server.csr
openssl x509 -req -in $TMPDIR/server.csr -CA $TMPDIR/ca.crt -CAkey $TMPDIR/ca.key -CAcreateserial -out $TMPDIR/server.crt -days 3650

echo "Done. Files:"
ls -l $TMPDIR

echo ""
echo "Base64 CA cert (for caBundle):"
cat $TMPDIR/ca.crt | base64 | tr -d '\n'
echo ""
