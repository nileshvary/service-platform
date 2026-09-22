# Changelog

Chart versions. Consumers pin, so anything that changes rendered output for an
existing values file is called out explicitly.

## [0.1.0]

Initial release.

**Chart**
- Deployment with startup/liveness/readiness probes, explicit `timeoutSeconds`
  on all three (the default of 1s produces false positives under load)
- `maxUnavailable: 0` / `maxSurge: 1` rolling update
- `preStop` sleep so endpoint removal wins the race against SIGTERM
- ConfigMap hashed into a pod-template annotation, so config changes roll pods
- Conditional PodDisruptionBudget
- Conditional ServiceMonitor
- `helm test` hook that calls the Service and fails on a selector mismatch

**Operational notes for consumers**
- `service.selectorLabels` renders `app.kubernetes.io/name` and
  `app.kubernetes.io/instance` only. A Deployment's selector is immutable;
  changing this in a future version requires recreating every Deployment.
- `podDisruptionBudget.enabled` defaults to `true`. Single-replica releases
  must set it to `false` — a PDB that cannot be satisfied blocks node drains
  indefinitely.
