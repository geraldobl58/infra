{{/*
Nome curto do app (app.name preenchido em apps/<app>/values.yaml).
Cai pra .Chart.Name caso o usuário não preencha.
*/}}
{{- define "crivo-app.name" -}}
{{- default .Chart.Name .Values.app.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fullname: usado como nome de Deployment/Service/Ingress.
Mantém .Release.Name implicitamente se o chamador passar .fullnameOverride.
*/}}
{{- define "crivo-app.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "crivo-app.name" . | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "crivo-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels (usado em metadata.labels).
*/}}
{{- define "crivo-app.labels" -}}
helm.sh/chart: {{ include "crivo-app.chart" . }}
{{ include "crivo-app.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.app.environment }}
app.kubernetes.io/environment: {{ .Values.app.environment | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels (precisa ser estável – não muda entre releases).
*/}}
{{- define "crivo-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "crivo-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Renderiza .Values.env (map) como lista de {name, value}.
Aplica tpl em cada value para suportar {{ .Values.app.environment }} etc.
*/}}
{{- define "crivo-app.envVars" -}}
{{- range $k, $v := .Values.env }}
- name: {{ $k }}
  value: {{ tpl (printf "%v" $v) $ | quote }}
{{- end }}
{{- end }}
