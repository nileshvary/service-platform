# Service Platform

The deployment and reliability baseline for stateless services on Kubernetes.
One chart, one policy model, one alerting contract — applied identically
across every service and every environment.

Owned by the platform team. Service teams consume it; they do not fork it.

---

## What a service gets

Onboarding a service means adding a values file. Everything below comes with
it, correct by default, with no per-team decisions to make:

- Rolling updates with `maxUnavailable: 0` and a `preStop` drain
- Startup, liveness and readiness probes with explicit timeouts
- Resource requests and limits, and a QoS class that survives eviction
- PodDisruptionBudget, so node maintenance does not take the service down
- ConfigMap changes that actually roll pods
- A ServiceMonitor, so metrics are collected without a monitoring ticket
- Default-deny network posture with explicit, reviewed allows
- SLO recording rules and burn-rate alerts

## Consuming the chart

```bash
helm upgrade --install <release> oci://ghcr.io/<org>/charts/service \
  --version 0.1.0 \
  -f values/<service>-<env>.yaml \
  -n <namespace> \
  --atomic --wait --timeout 5m
```

Pin the chart version. Unpinned means your deploy changes when the platform
team publishes, which is how a Friday becomes interesting.

A values file is ~20 lines. See `values/orders-prod.yaml`.

### Adding a service

1. Copy an existing values file, set `nameOverride`, replicas and resources
2. Add the service to the relevant policy in `policies/20-service-to-service.yaml`
3. Open a PR — CI renders both the current and proposed manifests and attaches
   the diff

Step 2 is not optional. Under default-deny a new service can reach nothing
until its edges are declared.

### When the chart does not fit

Stateful workloads, batch jobs and anything needing a sidecar get their own
chart. Forcing them through this one produces a values file full of
conditionals that nobody can reason about. Roughly three services in twenty
justify the exception; if the number climbs, the chart is wrong.

---

## Repository layout

```
charts/service/     the shared chart (semver, published to OCI)
values/             per service, per environment
policies/           NetworkPolicy: default-deny plus the declared allows
monitoring/         PrometheusRule: platform alerts, probes, SLO burn rate
app/                reference service used to exercise the pipeline
docs/               architecture, decisions, runbooks, on-call notes
```

## Documentation

| Document | Read it when |
|---|---|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | changing the chart or the policy model |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | questioning why something is the way it is |
| [`docs/RUNBOOKS.md`](docs/RUNBOOKS.md) | an alert just fired |
| [`docs/RELEASING.md`](docs/RELEASING.md) | publishing a chart version |

---

## Operational contract

**Chart changes are breaking changes until proven otherwise.** Every service
consumes this chart. A default altered here reaches every namespace on the
next deploy. Bump the minor version, render the diff for every values file in
the repo, and announce it.

**The chart's selector labels are immutable.** A Deployment's `selector` cannot
be changed after creation. Altering `service.selectorLabels` requires deleting
and recreating every Deployment — a full outage. It is not a routine change.

**Policies are applied by the platform team, not by service teams.** A service
team opening a hole in its own namespace defeats the point.

---

## Known gaps

Recorded so nobody rediscovers them during an incident:

| Gap | Impact | Direction |
|---|---|---|
| No GitOps — CI pushes with Helm | cluster can drift from git; no drift detection | Argo CD, app-of-apps per environment |
| No distributed tracing | cross-service latency attribution is manual, via trace IDs in logs | OpenTelemetry SDK, then Tempo |
| Blackbox probes run in-cluster only | proves the service is up, not that a user in another region can reach it | external probe location or a third-party checker |
| No mTLS between services | traffic inside the cluster is plaintext | evaluated a mesh; rejected on operational cost — see DECISIONS |
| Chart not signed | supply-chain integrity relies on registry access control | cosign signing in the publish job |

## License

MIT
