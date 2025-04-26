# FastAPI Kubernetes Admission Webhooks (Validating + Mutating)

> **A journey from scratch to success — facing real-world hurdles, solving them, and documenting them to help others.**

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

We generate a **self-signed CA** and then **sign a server certificate**.

> We first struggled because initially the certs were invalid/mismatched, so *do not skip this carefully*.

Inside `certs/`, create a `cert-gen.sh` like this:

```bash
#!/bin/bash

# Generate CA key and certificate
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -subj "/CN=admission_ca" -days 10000 -out ca.crt

# Generate Server key and CSR
openssl genrsa -out server.key 2048
openssl req -new -key server.key -subj "/CN=webhook.default.svc" -out server.csr

# Sign Server cert with CA
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 10000 -extensions v3_ext -extfile <(printf "subjectAltName=DNS:webhook.default.svc")
```

Now run:

```bash
cd certs
chmod +x cert-gen.sh
./cert-gen.sh
```

✅ It will create: `ca.crt`, `ca.key`, `server.crt`, `server.key`

---

### 3. Dockerize the FastAPI Server

Create a `Dockerfile`:

```Dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "443", "--ssl-keyfile", "/app/server.key", "--ssl-certfile", "/app/server.crt"]
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

---

### 5. Test!

Test with a **bad** pod (blocked by validating webhook):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: evil-pod
  labels:
    evil: "true"
spec:
  containers:
  - name: nginx
    image: nginx
```

```bash
kubectl apply -f manifests/test-pod.yaml
```

You should get:

```
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
| **Internal server error** | Webhook returned wrong response (`/Kind=`, missing `apiVersion`) — fixed response format strictly. |
| **Pod stuck creating** | FastAPI was not serving on HTTPS properly — fixed by using correct `--ssl-keyfile` and `--ssl-certfile` with Uvicorn |

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

---

# 🌟 This is what real learning looks like.  
Facing the mud, fighting through, and standing proud at the end.

---

---
