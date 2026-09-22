# Runbooks

Linked from alert annotations. Written to be read at 3am by someone who did
not build the service.

Every runbook: what fired, what it means, what to check in order, what to do,
and when to escalate.

---

## HighErrorRate

**Fires:** 5xx ratio above 5% for 5 minutes on a service in prod.

**Means:** users are seeing failures now. This is a symptom alert — it does
not tell you the cause.

**Triage, in order:**

1. **Scope.** Is it one service or several? Several at once points at a shared
   dependency, the ingress, or the network — not application code.
   ```
   sum by (service) (rate(http_requests_total{status=~"5..",namespace="prod"}[5m]))
   ```
2. **Was there a deploy?** `helm history <release> -n prod`. A rollout inside
   the alert window is the first suspect. `helm rollback <release> <rev>` and
   confirm the error rate recovers before investigating further.
3. **One pod or all of them?** One pod is a bad replica — delete it. All pods
   is a dependency or a config change.
4. **Resources.** OOMKills (`Reason=OOMKilled`, exit 137) or CPU throttling:
   ```
   rate(container_cpu_cfs_throttled_seconds_total{namespace="prod"}[5m])
   ```
5. **Logs.** Kibana, `level:error` filtered to the service, last 15 minutes.
   Take a failing request's trace ID and search it across all services to find
   which hop actually failed.

**Mitigate first, diagnose second.** Rolling back a suspect deploy is cheap
and reversible.

**Escalate** if error rate exceeds 25%, if it spans more than three services,
or if a rollback does not recover it.

---

## SLOBurnRateCritical

**Fires:** burning error budget at 14.4x over 1h, confirmed over 5m.

**Means:** at this rate the entire 30-day budget is gone in about two days.
Faster than a normal incident — this is a sustained regression, not a blip.

**Actions:**

1. Treat as an incident. Open a channel, assign an incident lead.
2. `slo:error_budget_remaining:ratio30d` — how much is left decides how
   aggressive mitigation should be.
3. If the budget is already negative, the freeze policy applies: no feature
   deploys to the affected service until it recovers. This is not a
   negotiation, it is the agreement.
4. Postmortem required regardless of duration.

---

## PodCrashLooping

**Fires:** container restarts in a 15-minute window.

**Means:** the container is starting and dying repeatedly.

**Identify which of the four it is:**

```
kubectl describe pod <pod> -n <ns> | grep -A3 "Last State"
```

| Reason | Exit | Cause | Fix |
|---|---|---|---|
| `OOMKilled` | 137 | kernel killed it — memory limit | raise the limit or fix the leak |
| `Error` + liveness events | 137 | **the liveness probe killed it mid-startup** | add or widen `startupProbe`; check `timeoutSeconds` is not the default 1s |
| `Error` | non-zero | the app itself exited | `kubectl logs --previous` |
| `ContainerCannotRun` | — | bad command or entrypoint | check the image |

**The second row is the one that wastes hours.** A container that needs 90
seconds to start, with a liveness probe checking at 30, never starts —
forever. The restart count climbs and the logs show a clean startup that
simply stops. `Reason=Error` with liveness probe events in `describe` is the
signature.

---

## EndpointDown / targets DOWN in Prometheus

**Fires:** `probe_success == 0` for 3 minutes, or scrape targets DOWN.

**Split DNS from the network path before anything else** — "timeout" does not
distinguish them:

```
kubectl exec -n <ns> deploy/<svc> -- nslookup <target>
```

- **Resolution fails** → DNS. Under default-deny, check the namespace has the
  DNS egress allow. CoreDNS pods healthy?
- **Resolves but times out** → network path. NetworkPolicy is the first
  suspect. `context deadline exceeded` means the packet was dropped;
  `connection refused` means something answered no.
- **Scrape targets specifically** → does the namespace have the
  monitoring-ingress allow? This breaks silently: applications keep serving
  while observability goes dark.

**Service reachable but no endpoints:**

```
kubectl get endpointslice -n <ns>
```

Empty with healthy pods is a selector/label mismatch. Pods will be Running,
the Deployment Ready, probes passing, dashboards green — and every request
failing.

---

## CertExpiringIn7Days / CertAlreadyExpired

**Fires:** a certificate expires within 7 days, or already has.

1. `kubectl get certificate -A` — is cert-manager managing it?
2. If yes: `kubectl describe certificate <name>` and check the CertificateRequest
   and Order. Common causes are a failed DNS-01 challenge or a rate-limited
   ACME account.
3. If not managed: it is on a load balancer or appliance outside the cluster.
   Renewal is manual and someone owns it — find who in the inventory.
4. Already expired means clients are failing TLS handshakes now. Treat as an
   outage.

**Automation failing quietly is why this alert exists.** cert-manager renewing
is not the same as cert-manager having renewed.

---

## CertCheckJobStale

**Fires:** the expiry check job has not reported in 2 hours.

**Means:** expiry metrics are frozen at their last value and will look
reassuring indefinitely. Monitoring the monitor.

```
kubectl get cronjob certcheck -n monitoring
kubectl get jobs -n monitoring --sort-by=.metadata.creationTimestamp | tail
kubectl logs job/<latest> -n monitoring
```

Usual causes: the job cannot reach Pushgateway, or an endpoint in the target
list now hangs and the job exceeds `activeDeadlineSeconds`.
