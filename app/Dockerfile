# Stub: Multi-stage optional. Use non-root user in production.
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && pip install gunicorn

COPY . .

# Expose port used by values.yaml (8080)
ENV PORT=8080
EXPOSE 8080

# Run with gunicorn for production-style process
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "main:app"]
