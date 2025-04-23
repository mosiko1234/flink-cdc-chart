# _helpers.tpl
---
{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "flink-cdc.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "flink-cdc.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "flink-cdc.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "flink-cdc.labels" -}}
helm.sh/chart: {{ include "flink-cdc.chart" . }}
{{ include "flink-cdc.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "flink-cdc.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flink-cdc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
JobManager selector labels
*/}}
{{- define "flink-cdc.jobmanager.selectorLabels" -}}
{{ include "flink-cdc.selectorLabels" . }}
app.kubernetes.io/component: jobmanager
{{- end }}

{{/*
TaskManager selector labels
*/}}
{{- define "flink-cdc.taskmanager.selectorLabels" -}}
{{ include "flink-cdc.selectorLabels" . }}
app.kubernetes.io/component: taskmanager
{{- end }}

{{/*
SQL Gateway selector labels
*/}}
{{- define "flink-cdc.sqlgateway.selectorLabels" -}}
{{ include "flink-cdc.selectorLabels" . }}
app.kubernetes.io/component: sqlgateway
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "flink-cdc.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "flink-cdc.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
---