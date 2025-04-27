# Kubernetes Admission Webhook (Validation & Mutation)

This repository contains a simple example of a Kubernetes Admission Webhook server built using FastAPI.

- **Validating Webhook**: Rejects pods with specific labels (e.g., `evil`).
- **Mutating Webhook**: Automatically adds a label `added-by-webhook: true` to pods if not present.

---

## Prerequisites

- A running Kubernetes cluster (v1.20+ recommended)
- `kubectl` access configured
- `openssl` installed (for certificate generation)
- Basic knowledge of Kubernetes deployments

---

## Setup Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/admission-webhook-example.git
   cd admission-webhook-example
   ```

2. **Generate Certificates**
   ```bash
   bash generate-certs.sh
   ```
   *(This script generates a CA and server certificates with correct SANs.)*

3. **Create Kubernetes Secret for Certificates**
   ```bash
   kubectl apply -f secret.yaml
   ```

4. **Deploy the Webhook Server**
   ```bash
   kubectl apply -f deployment.yaml
   kubectl apply -f service.yaml
   ```

5. **Apply the Webhook Configurations**
   ```bash
   kubectl apply -f mutating-webhook-configuration.yaml
   kubectl apply -f validating-webhook-configuration.yaml
   ```

6. **Test the Webhooks**
   - Create a pod without labels ➔ mutation adds `added-by-webhook: true`.
   - Create a pod with label `evil` ➔ validation webhook rejects the pod.

---

## 🏛️ Project Structure

```
webhook-fastapi-k8s/
│
├── manifests/               # Kubernetes YAMLs
├── src/                     # Python code (FastAPI + business logic)
├── Dockerfile               # Docker image for FastAPI server
├── generate-certs.sh        # Generate Certificates
├── requirements.txt         # FastAPI + uvicorn requirements
└── README.md                # This guide
```

---

## Notes

- The webhook server listens on port 443 inside the cluster.
- Certificate and key files are mounted into the pod using Kubernetes secrets (created via `secret.yaml`).

---
