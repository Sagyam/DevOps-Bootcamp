{{/* Named templates (partials). Called with {{ include "name" . }} to avoid
     repeating the same label/name logic in every manifest. */}}

{{- define "shortlink.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shortlink.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "shortlink.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Full label set — put on every object's metadata.labels */}}
{{- define "shortlink.labels" -}}
app.kubernetes.io/name: {{ include "shortlink.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{/* Selector labels — the STABLE subset used in .spec.selector (never include
     version/chart here, or rollouts break). Per-component label added inline. */}}
{{- define "shortlink.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shortlink.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
