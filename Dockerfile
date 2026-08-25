# Dockerfile for deploying the Vaidyum Flask backend to Google Cloud Run.
# Place this in the same folder as app.py and requirements.txt (repo root).

FROM python:3.10-slim

WORKDIR /app

# Install dependencies first (better layer caching - only reinstalls if
# requirements.txt actually changes).
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the project (app.py, models/, data/, etc.)
COPY . .

# Cloud Run injects the actual port to listen on via $PORT at runtime
# (defaults to 8080) - this ENV/EXPOSE is just documentation/local-testing
# convenience, Cloud Run overrides it regardless.
ENV PORT=8080
EXPOSE 8080

# Single worker process (the two transformer models load once at import
# time, so multiple worker PROCESSES would each load their own copy and
# multiply memory usage). --worker-class gthread with multiple threads
# lets that one process still handle concurrent requests.
# gthread (not the default "sync" worker) is required here - gunicorn's
# sync worker has a known HTTP-parsing incompatibility with Cloud Run's
# proxy layer that produces "Error while deserializing header: header
# too large" and crash-loops the worker; gthread does not have this issue.
CMD exec gunicorn app:app --bind 0.0.0.0:$PORT --workers 1 --threads 4 --worker-class gthread --timeout 120