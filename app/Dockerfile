# ---------- build stage ----------
FROM python:3.11-slim AS builder

WORKDIR /build
COPY requirements.txt .
# hadolint ignore=DL3013
RUN pip install --no-cache-dir pip==26.0.1 setuptools==82.0.1 wheel==0.46.3 && \
    pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---------- runtime stage ----------
FROM python:3.11-slim

# hadolint ignore=DL3013
RUN pip install --no-cache-dir pip==26.0.1 setuptools==82.0.1 wheel==0.46.3 && \
    groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

WORKDIR /app
COPY --from=builder /install /usr/local
COPY . .

RUN chown -R appuser:appuser /app
USER appuser

ENV PORT=8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"]

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1"]
