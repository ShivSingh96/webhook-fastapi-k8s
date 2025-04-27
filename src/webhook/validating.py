def handle_validation(body):
    # Example: Reject any pod with label "evil: true"
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
