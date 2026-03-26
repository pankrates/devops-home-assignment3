"""Payment API — FastAPI app with health/ready endpoints, structured logging,
OpenTelemetry tracing (Cloud Trace), and Secret Manager integration."""

import logging
import os
import sys

from pythonjsonlogger import jsonlogger
from fastapi import FastAPI
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

# ---------------------------------------------------------------------------
# Structured JSON logging
# ---------------------------------------------------------------------------
handler = logging.StreamHandler(sys.stdout)
formatter = jsonlogger.JsonFormatter(
    fmt="%(asctime)s %(levelname)s %(name)s %(message)s",
    rename_fields={"asctime": "timestamp", "levelname": "severity"},
)
handler.setFormatter(formatter)
logging.root.handlers = [handler]
logging.root.setLevel(logging.INFO)

logger = logging.getLogger("payment-api")

# ---------------------------------------------------------------------------
# OpenTelemetry → Cloud Trace
# ---------------------------------------------------------------------------
try:
    from opentelemetry.exporter.cloud_trace import CloudTraceSpanExporter

    provider = TracerProvider()
    provider.add_span_processor(BatchSpanProcessor(CloudTraceSpanExporter()))
    trace.set_tracer_provider(provider)
    logger.info("Cloud Trace exporter initialised")
except Exception as exc:
    # Graceful fallback when not running on GCP (local dev, CI, etc.)
    provider = TracerProvider()
    trace.set_tracer_provider(provider)
    logger.warning("Cloud Trace exporter unavailable, tracing is no-op: %s", exc)

tracer = trace.get_tracer(__name__)

# ---------------------------------------------------------------------------
# Secret Manager — read secret at startup via Workload Identity
# ---------------------------------------------------------------------------
SECRET_VALUE: str | None = None

def _load_secret() -> str | None:
    project = os.getenv("GCP_PROJECT_ID")
    secret_name = os.getenv("SECRET_NAME", "payment-api-key")
    if not project:
        logger.warning("GCP_PROJECT_ID not set — skipping Secret Manager lookup")
        return None
    try:
        from google.cloud import secretmanager

        client = secretmanager.SecretManagerServiceClient()
        name = f"projects/{project}/secrets/{secret_name}/versions/latest"
        response = client.access_secret_version(request={"name": name})
        logger.info("Secret '%s' loaded from Secret Manager", secret_name)
        return response.payload.data.decode("utf-8")
    except Exception as exc:
        logger.error("Failed to load secret: %s", exc)
        return None

SECRET_VALUE = _load_secret()

# ---------------------------------------------------------------------------
# FastAPI application
# ---------------------------------------------------------------------------
app = FastAPI(title="Payment API", version="1.0.0")
FastAPIInstrumentor.instrument_app(app)


@app.get("/health")
def health():
    """Liveness probe."""
    return {"status": "ok"}


@app.get("/ready")
def ready():
    """Readiness probe — confirms the app can serve traffic."""
    return {"status": "ready", "secret_loaded": SECRET_VALUE is not None}


@app.get("/")
def index():
    with tracer.start_as_current_span("index"):
        return {"service": "payment-api", "version": "1.0.0"}


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", "8080"))
    uvicorn.run(app, host="0.0.0.0", port=port)
