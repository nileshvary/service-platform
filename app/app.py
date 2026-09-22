"""Minimal service with the endpoints a platform expects."""
from flask import Flask, jsonify
import os

app = Flask(__name__)
VERSION = os.environ.get("APP_VERSION", "dev")


@app.route("/healthz")
def healthz():
    """Liveness: am I alive? Must NOT check dependencies — a database
    blip would otherwise restart every pod in the fleet at once."""
    return jsonify(status="ok", version=VERSION)


@app.route("/readyz")
def readyz():
    """Readiness: can I serve traffic right now? THIS is where a
    dependency check belongs — failing it removes the pod from the
    Service without restarting it."""
    return jsonify(status="ready")


@app.route("/")
def index():
    return jsonify(service="demo", version=VERSION)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
