# Multi-stage build. The builder has compilers and dev tools; the final
# image has neither. Fewer packages = fewer CVEs = a smaller attack surface.
# This is the single biggest lever on your scan results.

FROM python:3.12-alpine AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/deps -r requirements.txt

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
