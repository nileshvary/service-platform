{{/*
Named templates — reusable snippets shared by every manifest in the chart.
This file renders nothing on its own; it defines helpers the others call.

Why it matters: labels must be IDENTICAL in the Deployment selector, the pod
template, and the Service selector. Defining them once here is how you stop
the exact selector-mismatch outage you debugged earlier.
*/}}

{{/* The service's name. Falls back to the Helm release name. */}}
{{- define "service.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
SELECTOR labels — the minimal, IMMUTABLE set used to match pods.
Kept deliberately small: a Deployment's selector cannot be changed after
creation, so anything that varies (like version) must NOT go in here.
*/}}
{{- define "service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
ALL labels — selector labels plus metadata that may change over time.
These are the community-standard app.kubernetes.io/* labels, which is what
makes dashboards, alerts and kubectl queries work consistently across
every service in the platform.
*/}}
{{- define "service.labels" -}}
{{ include "service.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}
