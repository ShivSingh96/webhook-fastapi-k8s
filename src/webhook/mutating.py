import base64
import json

def handle_mutation(body):
    request = body["request"]
    patch = []
    
    metadata = request.get("object", {}).get("metadata", {})
    labels = metadata.get("labels")

    if labels is None:
        # Add the entire labels dict first
        patch.append({
            "op": "add",
            "path": "/metadata/labels",
            "value": {
                "added-by-webhook": "true"
            }
        })
    else:
        # Only add the new label
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
