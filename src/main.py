from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from webhook import validating, mutating

app = FastAPI()

@app.post("/validate")
async def validate(request: Request):
    body = await request.json()
    validation_response = validating.handle_validation(body)
    return JSONResponse({
        "apiVersion": "admission.k8s.io/v1",
        "kind": "AdmissionReview",
        **validation_response
    })

@app.post("/mutate")
async def mutate(request: Request):
    body = await request.json()
    mutation_response = mutating.handle_mutation(body)
    return JSONResponse({
        "apiVersion": "admission.k8s.io/v1",
        "kind": "AdmissionReview",
        **mutation_response
    })
