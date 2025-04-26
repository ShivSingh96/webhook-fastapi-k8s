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
