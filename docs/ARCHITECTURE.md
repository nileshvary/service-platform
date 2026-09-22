# Architecture

## The chart

One chart in `charts/service/` renders five objects:

| Template | Purpose |
|---|---|
| `deployment.yaml` | the workload, with probes, resources, rollout strategy, preStop drain |
| `service.yaml` | ClusterIP, selector generated from the same helper as the pod labels |
| `configmap.yaml` | its own file so its hash covers config only |
| `pdb.yaml` | conditional — a single-replica service must not have one |
| `servicemonitor.yaml` | conditional — lets Prometheus discover the service |

### Why the labels live in a helper

`_helpers.tpl` defines `service.selectorLabels` once. The Deployment's
`selector.matchLabels`, its pod template labels, and the Service's selector
all call it.

Without that, the classic outage: someone edits the Service selector, the
pods keep their old labels, the Service ends up with zero endpoints — and
everything *looks* healthy. Pods Running, Deployment 3/3 Ready, probes
passing, dashboards green. Only `kubectl get endpointslice` shows the truth.

Selector labels are also deliberately minimal, because a Deployment's
selector is immutable after creation. Anything that changes over time —
a version label — must stay out of it.

### Why the ConfigMap is hashed

```yaml
checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

ConfigMap changes do not restart pods. `envFrom` values are injected at
container start, so running pods keep stale config indefinitely. Hashing the
ConfigMap into the pod template means a config change alters the template,
which triggers a rolling update.

It must be its own file: the include resolves by file path, and the hash must
cover only the config — otherwise editing the PDB restarts every pod for
nothing.

### Why preStop sleeps

On pod termination two things happen in parallel: kube-proxy removes the pod
from Service endpoints, and the kubelet sends SIGTERM. They race. If SIGTERM
wins, in-flight requests are dropped and users see 502s during a
"zero-downtime" deploy. The sleep lets endpoint removal propagate first.

## The policies

Apply in order; each step's breakage is the lesson.

1. **`00-default-deny`** — everything stops, including DNS.
2. **`10-allow-dns`** — names resolve again; traffic is still blocked. DNS is
   egress, on UDP *and* TCP 53 (it falls back to TCP for large responses).
3. **`20-service-to-service`** — explicit allows. NetworkPolicy needs **both
   sides**: an egress rule on the client *and* an ingress rule on the server.
4. **`30-allow-prometheus-scrape`** — without this, targets go DOWN with scrape
   timeouts and dashboards go blank while the apps keep serving. The nastiest
   failure of the four, because nothing looks broken.

Ports in policies are **pod** ports, not Service ports — policy is evaluated
after kube-proxy's DNAT.

## The pipeline

```
lint -> validate -> build -> scan -> publish -> deploy
 20s      40s        2m       1m              (gated)
```

Cheap checks first. The image is built to a local tarball and scanned
*before* it can be pushed, so a vulnerable image never reaches the registry.
