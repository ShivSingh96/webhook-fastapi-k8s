# FastAPI Kubernetes Admission Webhooks (Validating + Mutating)

---

## 🚀 Project Goal

Implement Kubernetes **Validating** and **Mutating** Admission Webhooks using **FastAPI**.  
This project showcases:
- How to build a working Admission Webhook server.
- How to create and trust certificates for secure communication.
- How to create ValidatingWebhookConfiguration and MutatingWebhookConfiguration in Kubernetes.
- Common issues faced and *how to fix them*.

---

## 🏛️ Project Structure

```
webhook-fastapi-k8s/
│
├── certs/                  # TLS Certificates (generated manually)
├── manifests/               # Kubernetes YAMLs
├── src/                     # Python code (FastAPI + business logic)
├── Dockerfile               # Docker image for FastAPI server
├── requirements.txt         # FastAPI + uvicorn requirements
├── README.md                # This guide
└── LICENSE                  # Choose your preferred OSS license
```

---

## ⚙️ How to Setup

### 1. Clone this Repository

```bash
git clone https://github.com/yourusername/webhook-fastapi-k8s.git
cd webhook-fastapi-k8s
```

---

### 2. Generate TLS Certificates

**Important:**  
Kubernetes **requires HTTPS endpoints** for admission webhooks.

We generate a **self-signed CA** and then **sign a server certificate** for the webhook's Kubernetes service DNS name.

Use the script `generate-cert.sh`:

```bash
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
```

Now run:

```bash
chmod +x generate-cert.sh
./generate-cert.sh
```

✅ It will create: `ca.crt`, `ca.key`, `server.crt`, `server.key` , `server.csr` 
While generating the CSR (Certificate Signing Request), It will sign server cert with CA including SANs.

---

### 3. Create Kubernetes Secrets for Certificates
Unlike hardcoding certs into the pod, we create Kubernetes Secrets to mount certificates securely inside the webhook pod.

Apply the secret manifest:

```bash
kubectl apply -f manifests/secret.yaml
```
This mounts the server certificates (server.crt, server.key) inside the container at runtime.

---

### 4. Dockerize the FastAPI Server

Create a `Dockerfile`:

```Dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/ .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "443", "--ssl-keyfile", "/certs/tls.key", "--ssl-certfile", "/certs/tls.crt"]
```

And `requirements.txt`:

```
fastapi
uvicorn
```

Build & push Docker image:

```bash
docker build -t yourdockerhub/webhook-server:latest .
docker push yourdockerhub/webhook-server:latest
```

---

### 4. Deploy on Kubernetes

Apply all manifests:

```bash
kubectl apply -f manifests/deployment.yaml
kubectl apply -f manifests/service.yaml
kubectl apply -f manifests/validating-webhook.yaml
kubectl apply -f manifests/mutating-webhook.yaml
```
> **Note:** Before applying the `ValidatingWebhookConfiguration` and `MutatingWebhookConfiguration`, make sure to update the `caBundle:` field with the Base64-encoded CA certificate output from the `generate-cert.sh` script.
---

### 5. Test!

Test with a **bad** pod (blocked by validating webhook):

```bash
kubectl apply -f manifests/test-pod-validation-fail.yaml
```

You should get:

```vb
Error from server: admission webhook "validate.webhook.default.svc" denied the request: Pods with 'evil: true' label are not allowed.
```

✅ **Validation Webhook worked!**

---

For **Mutation**, try applying a pod **without** a label — and after creation, describe it:

```bash
kubectl describe pod <pod-name>
```

You should see an **added label**:

```yaml
added-by-webhook: "true"
```

✅ **Mutation Webhook worked!**

---

## 📚 Problems We Faced & How We Solved Them

| Problem | Solution |
|:--------|:---------|
| **Webhook server failed** | Wrong content-type or wrong admission.k8s.io/v1 format — we fixed the FastAPI handler to correctly return AdmissionReview JSON |
| **Cert invalid error** | Earlier certs didn't match the service DNS name, then we regenerated them using `subjectAltName=DNS:webhook.default.svc` |
| **Cert SAN (Subject Alternative Name) missing** | Certificates had CN but no SAN entry | Explicitly added `subjectAltName=DNS:webhook.default.svc` in cert generation (this is critical, Kubernetes verifies SAN not just CN). |
| **Internal server error** | Webhook returned wrong response (`/Kind=`, missing `apiVersion`) — fixed response format strictly. |
| **Pod stuck creating** | FastAPI was not serving on HTTPS properly — fixed by using correct `--ssl-keyfile` and `--ssl-certfile` with Uvicorn |
| **Webhook server startup failed** | Wrong TLS key/cert or not mounted properly | Moved certs into Kubernetes Secrets and mounted at runtime cleanly. |
| **Kubernetes API rejected Webhook registration** | CA Bundle in webhook config was wrong/empty | After generating ca.crt, base64 encode it and insert into caBundle manually or dynamically.

---

## 🧠 Lessons Learned

- Always generate certs carefully with proper **SANs** matching Kubernetes Service DNS.
- Webhooks **must** respond with full `AdmissionReview` structure (apiVersion, kind, response).
- Mutating webhook needs to **base64 encode** the JSON patch.
- Debugging webhooks needs patience — look at the controller-manager and API server logs.
- FastAPI is super-fast and lightweight for webhook servers compared to heavier frameworks.

---

## 🤝 Contributions Welcome

If you find a better way to optimize this or want to extend it (e.g., dynamic webhook registrations, Helm chart support), feel free to open PRs!
