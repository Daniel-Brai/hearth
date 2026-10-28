{{- define "hearth.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "hearth.fullname" -}}
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

{{- define "hearth.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "hearth.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "hearth.selector" -}}
app.kubernetes.io/name: {{ include "hearth.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "hearth.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "hearth.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "hearth.apiImage" -}}
{{ .Values.images.api.repository }}:{{ default .Chart.AppVersion .Values.images.api.tag }}
{{- end }}

{{- define "hearth.webImage" -}}
{{ .Values.images.web.repository }}:{{ default .Chart.AppVersion .Values.images.web.tag }}
{{- end }}

{{- define "hearth.cookieSecret" -}}
{{- default (printf "%s-cookie" (include "hearth.fullname" .)) .Values.cluster.existingSecret }}
{{- end }}

{{/*
Nodes name themselves after their pod address so DNSCluster can reach hearth@<ip>
*/}}
{{- define "hearth.apiEnv" -}}
- name: POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
- name: RELEASE_DISTRIBUTION
  value: name
- name: RELEASE_NODE
  value: hearth@$(POD_IP)
- name: RELEASE_COOKIE
  valueFrom:
    secretKeyRef:
      name: {{ include "hearth.cookieSecret" . }}
      key: cookie
- name: RELEASE_TMP
  value: /tmp
- name: TMPDIR
  value: /tmp
- name: DNS_CLUSTER_QUERY
  value: {{ printf "%s-cluster.%s.svc.cluster.local" (include "hearth.fullname" .) .Release.Namespace }}
- name: PUBLIC_URL
  value: {{ .Values.publicUrl | quote }}
- name: PORT
  value: {{ .Values.api.port | quote }}
- name: METRICS_PORT
  value: {{ .Values.api.metricsPort | quote }}
{{- if eq .Values.secrets.source "vault" }}
- name: SECRETS_FILE
  value: /etc/hearth/secrets.yml
- name: SECRETS_ENV
  value: {{ .Values.secrets.env | quote }}
- name: VAULT_ADDR
  value: {{ required "vault.address is needed when secrets.source is vault" .Values.vault.address | quote }}
- name: VAULT_AUTH
  value: {{ .Values.vault.auth | quote }}
- name: VAULT_ROLE
  value: {{ .Values.vault.role | quote }}
{{- with .Values.vault.authMount }}
- name: VAULT_AUTH_MOUNT
  value: {{ . | quote }}
{{- end }}
{{- with .Values.vault.namespace }}
- name: VAULT_NAMESPACE
  value: {{ . | quote }}
{{- end }}
{{- end }}
{{- end }}

{{- define "hearth.apiEnvFrom" -}}
- configMapRef:
    name: {{ include "hearth.fullname" . }}-config
{{- if eq .Values.secrets.source "kubernetes" }}
- secretRef:
    name: {{ required "secrets.existingSecret is needed when secrets.source is kubernetes" .Values.secrets.existingSecret }}
{{- end }}
{{- end }}

{{- define "hearth.apiVolumeMounts" -}}
- name: tmp
  mountPath: /tmp
{{- if eq .Values.secrets.source "vault" }}
- name: secrets-map
  mountPath: /etc/hearth
  readOnly: true
{{- end }}
{{- end }}

{{- define "hearth.apiVolumes" -}}
- name: tmp
  emptyDir:
    sizeLimit: {{ .Values.api.tmpSize }}
{{- if eq .Values.secrets.source "vault" }}
- name: secrets-map
  configMap:
    name: {{ include "hearth.fullname" . }}-secrets-map
{{- end }}
{{- end }}
