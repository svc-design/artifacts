{{- define "model-serving.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "model-serving.svcname" -}}
{{- printf "%s-svc" (include "model-serving.fullname" .) -}}
{{- end -}}

{{- define "model-serving.image" -}}
{{- $reg := .Values.global.imageRegistry -}}
{{- $img := .image -}}
{{- $tag := .tag | default "latest" -}}
{{- printf "%s/%s:%s" $reg $img $tag -}}
{{- end -}}
