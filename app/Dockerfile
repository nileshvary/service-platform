# Multi-stage build. The builder has compilers and dev tools; the final
# image has neither. Fewer packages = fewer CVEs = a smaller attack surface.
# This is the single biggest lever on your scan results.

FROM python:3.12-alpine AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/deps -r requirements.txt

# The base image IS the security decision. Run #5 of this pipeline pinned
# python:3.9.0-alpine3.12 here; Trivy found 11 CRITICAL CVEs and the scan
# gate stopped the build before the image reached the registry.
# Keeping the base current is the cheapest CVE reduction available.
FROM python:3.12-alpine
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
