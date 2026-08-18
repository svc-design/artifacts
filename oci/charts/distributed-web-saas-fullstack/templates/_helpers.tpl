{{- define "distributed-web-saas-fullstack.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "distributed-web-saas-fullstack.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "distributed-web-saas-fullstack.componentName" -}}
{{- printf "%s-%s" (include "distributed-web-saas-fullstack.fullname" .root) .name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "distributed-web-saas-fullstack.labels" -}}
app.kubernetes.io/name: {{ include "distributed-web-saas-fullstack.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .name }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
helm.sh/chart: {{ .root.Chart.Name }}-{{ .root.Chart.Version | replace "+" "_" }}
{{- end -}}
