import base64
import json

def handle_mutation(body):
    request = body["request"]
    patch = []

    metadata = request.get("object", {}).get("metadata", {})
    
    # Only mutate if 'labels' field is missing entirely
    if "labels" not in metadata:
        patch.append({
            "op": "add",
            "path": "/metadata/labels",
            "value": {
                "added-by-webhook": "true"
            }
        })

    return {
        "response": {
            "uid": request["uid"],
            "allowed": True,
            "patchType": "JSONPatch" if patch else None,
            "patch": base64.b64encode(json.dumps(patch).encode()).decode() if patch else None
        }
    }
