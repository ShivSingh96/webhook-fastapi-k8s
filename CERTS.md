---

# 📜 TLS Certificate Generation for Kubernetes Webhooks

Kubernetes **Admission Webhooks must** use **HTTPS (TLS)** communication.  
Self-signed certificates are acceptable **only if** we also **trust the CA** by embedding its public certificate into the webhook configuration.

Thus, we must:
1. Create a **Certificate Authority (CA)** — our own signer.
2. Use the CA to **sign a server certificate** for the webhook service.
3. Encode the **CA cert** into the webhook's `caBundle`.

---

# 🛠️ Steps to Generate CA and Server Certificates

---

### 1. Create a private key for the CA

```bash
openssl genrsa -out ca.key 2048
```

- `ca.key`: private key of our **Certificate Authority**.

---

### 2. Create a self-signed CA certificate

```bash
openssl req -x509 -new -nodes -key ca.key -subj "/CN=webhook-ca" -days 3650 -out ca.crt
```

- `ca.crt`: public cert of our CA.
- `-subj "/CN=webhook-ca"`: Common Name (CN) for the CA.
- Valid for **10 years** (`-days 3650`).

---

### 3. Create a private key for the server (webhook service)

```bash
openssl genrsa -out server.key 2048
```

- `server.key`: private key for our webhook server.

---

### 4. Create a Certificate Signing Request (CSR) for the server

```bash
openssl req -new -key server.key -subj "/CN=webhook.default.svc" -out server.csr
```

- `-subj "/CN=webhook.default.svc"`: **Important!**
  - **This CN must match the Kubernetes service name** exactly (`<service>.<namespace>.svc`).
  - If this doesn't match, Kubernetes will reject the server cert when connecting.

---

### 5. Create a server certificate signed by our CA

```bash
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 3650
```

- `server.crt`: server certificate signed by our CA.

---

# 📦 Final Files Generated:

| File | Purpose |
|:-----|:--------|
| `ca.key` | CA private key (keep secret) |
| `ca.crt` | CA public cert (embed into WebhookConfiguration) |
| `server.key` | Server private key (mounted to FastAPI pod) |
| `server.crt` | Server certificate (mounted to FastAPI pod) |

---

# 🏗️ How to Use These Certs

1. Mount `server.crt` and `server.key` into the webhook Deployment (`/etc/certs/` path).
2. Configure FastAPI server (like `uvicorn`) to use SSL:
   
```bash
uvicorn main:app --host 0.0.0.0 --port 443 --ssl-keyfile=/etc/certs/server.key --ssl-certfile=/etc/certs/server.crt
```

3. In your `ValidatingWebhookConfiguration` and `MutatingWebhookConfiguration`, you must **base64 encode the `ca.crt`** and paste it into the `caBundle` field.

Example:

```bash
cat ca.crt | base64 | tr -d '\n'
```

Use the output inside your YAML like:

```yaml
clientConfig:
  service:
    name: webhook
    namespace: default
    path: "/validate"
  caBundle: <base64-of-ca.crt>
```

---

# ❗ Why This Is Important

- Kubernetes **validates** the server’s TLS cert against the CA in `caBundle`.
- If **not trusted**, Kubernetes **rejects** the webhook communication silently with TLS handshake errors.
- **You must not** just use any self-signed cert randomly — the CA has to match.

---

# 🔥 Lessons from Our Hard-Won Battle

| Mistake | Reality |
|:--------|:--------|
| Trying to use random certs without CA | Kubernetes needs trusted CAs, not random self-signed certs |
| Not matching CN with service name | Must exactly match `service.namespace.svc` |
| Forgetting to Base64 encode CA cert | Webhook will fail if `caBundle` is wrong |
| Thinking HTTPS can be disabled | Kubernetes **forces** HTTPS for Admission Webhooks — no shortcuts |

---

# 📋 Final Pro Tips

- Always double-check the **Common Name (CN)** during cert creation.
- Use `openssl x509 -in server.crt -text -noout` to inspect your cert and verify CN.
- Automate this process using a simple shell script if you are doing it often.
- In production, prefer **Cert-Manager** to automate certs inside Kubernetes.

---

# 🛡️ Bonus: Simple Shell Script for Quick Cert Generation

<details>
<summary><strong>cert-gen.sh</strong></summary>

```bash
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
```
</details>

Run it:

```bash
bash cert-gen.sh
```

---

# 🏁 Conclusion

> *"In Kubernetes, trust is earned — not given. Certs are your passport to admission."*

This certificate process is the **invisible spine** of the webhook setup. Without it, **no matter how perfect your code**, Kubernetes will simply refuse to speak with you.

---
  
# 📜 Steps to Create this YAML Properly:
Base64 encode the server.crt and server.key files:

```bash
# Encode certificate
cat certs/server.crt | base64 | tr -d '\n'

# Encode private key
cat certs/server.key | base64 | tr -d '\n'
```
Copy the base64 outputs and paste them into the YAML:

```yaml
  tls.crt: LS0tLS1CRUdJTiBDRVJUS... (your cert base64 content)
  tls.key: LS0tLS1CRUdJTiBSU0EgUF... (your key base64 content)
```
---