# Decision record

Decisions that shaped this platform, with the reasoning and the cost we
accepted. Superseded entries stay, marked, so the history is legible.

---

## 1. One chart shared by all stateless services

**Status:** accepted

**Context.** Services were deployed from per-service copies of the same five
manifests. Over eighteen months the copies diverged: probe timeouts differed,
three services had no resource limits, two had PDBs that could never be
satisfied. A Service selector was edited without the Deployment's pod labels,
producing a service with zero endpoints while every dashboard stayed green.

**Decision.** One chart. Per-service configuration is a values file. The
Deployment's pod labels and the Service's selector both render from a single
named template.

**Consequences.**
- A platform-wide fix is one commit instead of N pull requests.
- The selector-mismatch class of outage is structurally impossible.
- Chart changes are now high blast radius. Mitigated by the render-diff CI job.
- Services that do not fit need their own chart. We accept a small number of
  these rather than making the shared chart conditional.

---

## 2. Fail the build on CRITICAL only

**Status:** accepted

**Context.** The first iteration failed on HIGH and above. It produced 20–40
failures a day, the large majority unreachable in our context — CVEs in
packages present in the base image but never called. Within three weeks two
teams had added `continue-on-error` and a third had pinned an old scanner
version.

**Decision.** The build fails on CRITICAL with a fix available. HIGH and
MEDIUM are reported and ticketed with an SLA.

**Consequences.**
- The gate is trusted, so it is not bypassed. That is the whole value.
- A CRITICAL with no fix available does not block; it is tracked and, where
  the base image is the cause, drives a base-image upgrade.
- We accept that a HIGH finding can reach production. The alternative — a
  gate everyone routes around — is strictly worse, because it manufactures
  confidence rather than providing it.

**Also:** build-time scanning only knows today's CVEs. Deployed artifacts are
monitored continuously so a CVE published after the build still reaches us.

---

## 3. Default-deny network policy, rolled out per namespace

**Status:** accepted

**Context.** Pod networking is flat. Any pod could reach any pod in any
namespace, including production datastores from development namespaces.

**Decision.** Default-deny ingress and egress per namespace, with explicit
allows. Rolled out lowest-risk namespace first.

**Rollout method.** Documented dependency lists are never complete. We ran the
CNI in flow-log mode first and built the allow list from observed traffic,
applied the allows while traffic was still permitted by default, confirmed
nothing depended on anything unlisted, and only then applied the deny.

**Consequences.**
- Two allows are mandatory in every namespace and are part of the namespace
  template, not left to teams: DNS egress to kube-dns on UDP **and** TCP 53,
  and ingress from the monitoring namespace on the metrics port.
- The monitoring allow is the one that hurts. Without it applications keep
  serving normally while every scrape target goes DOWN and dashboards empty —
  discovered during the next incident rather than at rollout.
- Adding a service now requires declaring its edges. This is friction by
  design.
- **Verify the CNI enforces policy before relying on it.** Some accept the
  objects and ignore them.

---

## 4. Burn-rate alerting instead of SLO-breach alerting

**Status:** accepted

**Context.** Alerting on a breached 30-day SLO tells you the month is already
lost. Alerting on a raw error-rate threshold pages on brief spikes that
consume a negligible fraction of budget.

**Decision.** Multi-window, multi-burn-rate, following the Google SRE workbook.

| Burn rate | Long window | Short window | Action |
|---|---|---|---|
| 14.4x | 1h | 5m | page |
| 6x | 6h | 30m | page |
| 3x | 1d | 2h | ticket |

**Consequences.**
- Pages correlate with budget actually being consumed, so they are believed.
- The short window makes alerts resolve promptly after recovery instead of
  firing for hours while the long window still contains the bad period.
- Low-traffic services produce noisy ratios on small denominators. They get
  longer windows or no availability SLO.

---

## 5. No service mesh

**Status:** accepted, revisit at ~50 services

**Context.** Evaluated Istio and Linkerd for mTLS, retries and per-hop latency.

**Decision.** Not adopted. mTLS terminates at the ingress; NetworkPolicies
restrict lateral movement; retries and timeouts are configured client-side.

**Reasoning.** A sidecar on every pod is measurable memory and CPU across the
fleet, a harder debugging surface, and a control plane whose upgrades can
break the data plane. At our size the operational cost exceeded the benefit,
and we did not have the headcount to run it well. Running a mesh badly is
worse than not running one.

**Consequences.**
- No in-cluster mTLS. Accepted; recorded in Known Gaps.
- Per-hop latency attribution is unavailable. Tracing would address this more
  cheaply than a mesh.

---

## 6. Deploy with Helm from CI rather than GitOps

**Status:** accepted, superseding planned

**Context.** Existing pipelines already ran Helm. Introducing a reconciler was
deferred to ship the rest of the platform.

**Decision.** CI runs `helm upgrade --install --atomic`.

**Consequences.**
- Cluster state can diverge from git and nothing detects it. A manual
  `kubectl edit` during an incident survives until the next deploy overwrites
  it — or does not.
- Rollback is a pipeline run, not a git revert.
- This is the largest known gap in the platform. Argo CD is the intended
  replacement.
