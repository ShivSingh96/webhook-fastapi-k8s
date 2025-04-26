---

# Kubernetes Validating & Mutating Webhooks Using FastAPI

---

## 📜 Objective

- Build a **Validating** and **Mutating** Webhook server using **FastAPI**.
- Purpose:
  - **Validation Webhook**: Reject pods with label `evil: true`.
  - **Mutation Webhook**: Add a label `added-by-webhook: true` to all pods if missing.

---

## 🛠️ Architecture

- FastAPI Server with two endpoints:
  - `/validate` → Validation logic.
  - `/mutate` → Mutation logic.
- Kubernetes:
  - `ValidatingWebhookConfiguration`
  - `MutatingWebhookConfiguration`
- TLS enabled using self-signed certificates.

---

## 🚀 FastAPI Server Code

<details>
<summary><strong>main.py</strong></summary>

```python
from fastapi import FastAPI, Request
from webhook import validating, mutating

app = FastAPI()

@app.post("/validate")
async def validate(request: Request):
    body = await request.json()
    return validating.handle_validation(body)

@app.post("/mutate")
async def mutate(request: Request):
    body = await request.json()
    return mutating.handle_mutation(body)
```
</details>

<details>
<summary><strong>validating.py</strong></summary>

```python
def handle_validation(body):
    request = body["request"]
    labels = request.get("object", {}).get("metadata", {}).get("labels", {})

    if labels.get("evil") == "true":
        return {
            "response": {
                "uid": request["uid"],
                "allowed": False,
                "status": {
                    "message": "Pods with 'evil: true' label are not allowed."
                }
            }
        }

    return {
        "response": {
            "uid": request["uid"],
            "allowed": True
        }
    }
```
</details>

<details>
<summary><strong>mutating.py</strong></summary>

```python
import base64
import json

def handle_mutation(body):
    request = body["request"]
    patch = []

    labels = request.get("object", {}).get("metadata", {}).get("labels", {})
    if "added-by-webhook" not in labels:
        patch.append({
            "op": "add",
            "path": "/metadata/labels/added-by-webhook",
            "value": "true"
        })

    return {
        "response": {
            "uid": request["uid"],
            "allowed": True,
            "patchType": "JSONPatch",
            "patch": base64.b64encode(json.dumps(patch).encode()).decode()
        }
    }
```
</details>

---

## 🗺️ Kubernetes Manifests

<details>
<summary><strong>Deployment & Service (webhook.yaml)</strong></summary>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webhook
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webhook
  template:
    metadata:
      labels:
        app: webhook
    spec:
      containers:
      - name: webhook
        image: your-image:tag
        ports:
        - containerPort: 443

---

apiVersion: v1
kind: Service
metadata:
  name: webhook
spec:
  selector:
    app: webhook
  ports:
  - port: 443
    targetPort: 443
```
</details>

<details>
<summary><strong>ValidatingWebhookConfiguration</strong></summary>

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: validating-webhook
webhooks:
- name: validate.webhook.default.svc
  clientConfig:
    service:
      name: webhook
      namespace: default
      path: "/validate"
    caBundle: <base64-ca-cert>
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    operations: ["CREATE"]
    resources: ["pods"]
  admissionReviewVersions: ["v1"]
  sideEffects: None
```
</details>

<details>
<summary><strong>MutatingWebhookConfiguration</strong></summary>

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: mutating-webhook
webhooks:
- name: mutate.webhook.default.svc
  clientConfig:
    service:
      name: webhook
      namespace: default
      path: "/mutate"
    caBundle: <base64-ca-cert>
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    operations: ["CREATE"]
    resources: ["pods"]
  admissionReviewVersions: ["v1"]
  sideEffects: None
```
</details>

---

## 🧱 Problems Faced & How We Solved Them

| Problem | Root Cause | Solution |
|:--------|:-----------|:---------|
| YAML Parsing Errors (`%` character) | Corrupt YAML due to extra characters | Fixed YAML format carefully |
| Invalid AdmissionReview Response | FastAPI returned wrong format | Corrected response JSON structure manually |
| Patch Errors in Mutation | Patch was not Base64 encoded | Encoded JSONPatch in base64 |
| TLS Certificates Requirement | Kubernetes demands secure webhook communication | Generated self-signed certs and configured in Deployment |
| Testing Mutations | Hard to verify label addition | Used `kubectl get pod --show-labels` |

---

## 🧪 Testing Results

- Validation Webhook successfully **rejected pods** with label `evil: true`.
- Mutation Webhook successfully **added a label** `added-by-webhook: true` to all created pods.

Commands used:
```bash
kubectl apply -f test-pod.yaml
kubectl get pod test-pod -o jsonpath='{.metadata.labels}'
```

---

## 🧠 Key Learnings

- Admission Webhooks **must** respond with strict `AdmissionReview` format.
- **Base64 encoding** is mandatory for Mutating patches.
- Even for local development, Kubernetes expects **TLS secured endpoints**.
- Kubernetes is **unforgiving** for any misconfiguration — attention to detail is critical.

---

## 📜 Timeless Principles Followed

- **Start Small** → Validate before mutate.
- **Fail Fast** → Test after each deployment.
- **Trust the Logs** → Investigate Kubernetes admission logs deeply.
- **Respect TLS** → Always!

---

# 🏁 Conclusion

> *"A system that works is a system that was built, broken, and rebuilt."*

This journey was a perfect example of learning by doing — getting our hands dirty, failing with dignity, and succeeding with wisdom.

---

# 🎯 Next Steps
- Add proper `healthz` endpoint for webhook server.
- Explore dynamic webhook configurations.
- Set up proper certificate management (Cert-Manager, not manual).

---

# ✨ Bonus: Useful References
- [Kubernetes Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Admission Webhooks Explained - Official Docs](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)

---

<<<<<<< HEAD
# 🧱 Future Improvements (Optional)

Integrate with cert-manager to automate cert generation.

- Support multiple webhook versions (v1, v1beta1).
- Handle dynamic mutation based on request fields.
- Add unit tests for validation/mutation logic.
=======
# 💬 Author's Note

If this helped you, **star** this repository and feel free to open issues or improvements! 🚀

---

---

---

Would you also like me to give you a **project folder structure** recommendation for this webhook repo, just to make it even more clean and production-grade? 🎯  
(Let’s make it so good that even a Kubernetes Architect would nod in approval.) 🚀🌟

🧱 Future Improvements (Optional)
Integrate with cert-manager to automate cert generation.

Support multiple webhook versions (v1, v1beta1).

Handle dynamic mutation based on request fields.

Add unit tests for validation/mutation logic.
>>>>>>> main
