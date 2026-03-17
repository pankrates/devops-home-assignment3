"""
Payment API stub for DevOps home assignment.
Exposes /health for liveness/readiness and a simple root endpoint.
Add tracing (e.g. OpenTelemetry) and Secret Manager access via Workload Identity as required.
"""
import os
from flask import Flask

app = Flask(__name__)


@app.route("/health")
def health():
    return {"status": "ok"}, 200


@app.route("/")
def index():
    return {"service": "payment-api", "version": "1.0.0"}, 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
