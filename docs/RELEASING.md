# Releasing the chart

The chart is a shared dependency. Every service consumes it. Treat a release
the way you would treat a library used by twenty teams.

## Versioning

`Chart.yaml` carries two independent versions:

- **`version`** — the chart's own. Bump on any template or default change.
- **`appVersion`** — the default application image tag. Bump when the
  reference image changes. Does not imply a chart change.

Semver, and the minor/major boundary is about operational impact:

| Change | Bump |
|---|---|
| Comment, docs, non-default value added | patch |
| New optional feature, changed default | **minor — announce it** |
| Selector labels, removed value, renamed key | **major — requires a migration plan** |

A changed default is not a patch. It reaches every namespace on the next
deploy of every service.

## Before releasing

1. Render every values file in the repo, old chart vs new, and diff. CI does
   this; read the artifact.
2. Confirm no rendered `selector.matchLabels` changed. If one did, stop — that
   field is immutable and the change requires deleting and recreating every
   Deployment.
3. `helm lint` with every values file, not just defaults.
4. Install into staging and run `helm test`.

## Publishing

```bash
helm package charts/service
helm push service-<version>.tgz oci://ghcr.io/<org>/charts
```

Published chart versions are immutable. A bad release is fixed by publishing
a new version, never by overwriting.

## Rollback

Consumers pin versions, so a bad release does not propagate on its own — it
propagates as teams upgrade. Announce the bad version, publish the fix, and
tell teams which version to move to. Do not delete the bad version; something
is pinned to it and deleting breaks their deploys at the worst moment.
