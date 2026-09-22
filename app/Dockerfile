# Multi-stage build. The builder has compilers and dev tools; the final
# image has neither. Fewer packages = fewer CVEs = a smaller attack surface.
# This is the single biggest lever on your scan results.

FROM python:3.12-alpine AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/deps -r requirements.txt

# ==== DELIBERATELY VULNERABLE - DO NOT MERGE ====
# Alpine 3.12 ships openssl 1.1.1g and apk-tools 2.10.5, both of which have
# CRITICAL CVEs with published fixes. The scan gate should stop this build
# before the image is pushed to the registry.
# Revert to `python:3.12-alpine` after the demonstration.
FROM python:3.9.0-alpine3.12
# Never run as root. A container escape from root is far worse than from
# an unprivileged user, and many scanners flag root as a HIGH finding.
RUN adduser -D -u 10001 appuser
WORKDIR /app
COPY --from=builder /deps /deps
COPY --chown=appuser:appuser app.py .
ENV PYTHONPATH=/deps
USER 10001
EXPOSE 8080
CMD ["python", "app.py"]
