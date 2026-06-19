{{/* Base name, overridable. */}}
{{- define "chatdev.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Fully qualified release name. */}}
{{- define "chatdev.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "chatdev.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Common labels. */}}
{{- define "chatdev.labels" -}}
helm.sh/chart: {{ include "chatdev.chart" . }}
app.kubernetes.io/name: {{ include "chatdev.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* Component names. */}}
{{- define "chatdev.backend.fullname" -}}
{{- printf "%s-backend" (include "chatdev.fullname" .) -}}
{{- end -}}
{{- define "chatdev.frontend.fullname" -}}
{{- printf "%s-frontend" (include "chatdev.fullname" .) -}}
{{- end -}}

{{/* Per-component selector labels. */}}
{{- define "chatdev.backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chatdev.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: backend
{{- end -}}
{{- define "chatdev.frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chatdev.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: frontend
{{- end -}}

{{/* Name of the Secret holding API keys. */}}
{{- define "chatdev.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- printf "%s-secrets" (include "chatdev.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Image tag falls back to the chart version. */}}
{{- define "chatdev.backend.image" -}}
{{- printf "%s:%s" .Values.backend.image.repository (default .Chart.Version .Values.backend.image.tag) -}}
{{- end -}}
{{- define "chatdev.frontend.image" -}}
{{- printf "%s:%s" .Values.frontend.image.repository (default .Chart.Version .Values.frontend.image.tag) -}}
{{- end -}}
