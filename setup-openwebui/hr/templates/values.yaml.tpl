# Open WebUI Helm Chart Values - GAR GPT Custom Image v0.1.0

# Use custom GAR GPT branded image with minimal approach (database compatible)
image:
  repository: public.ecr.aws/v2f5y6u4/openwebui/custom-build
  tag: v0.1.0
  pullPolicy: IfNotPresent

# Configure persistence to use S3
persistence:
  enabled: true
  provider: "s3"
  s3:
    bucket: "${s3_bucket_name}"
    region: "${region}"
    endpointUrl: "https://s3.${region}.amazonaws.com"

# Configure service account for Pod Identity
serviceAccount:
  enable: true
  name: "open-webui-pia"  # Must match the service_account in the Pod Identity association

# Configure environment variables
extraEnvVars:
  # Database configuration for PostgreSQL with pg_vector
  - name: "DATABASE_URL"
    valueFrom:
      secretKeyRef:
        name: "openwebui-db-credentials"
        key: "url"
  - name: "VECTOR_DB"
    value: "pgvector"
  
  # OAuth configuration from ConfigMap (non-sensitive)
  - name: "ENABLE_OAUTH_SIGNUP"
    valueFrom:
      configMapKeyRef:
        name: "openwebui-oauth-config"
        key: "ENABLE_OAUTH_SIGNUP"
  - name: "OAUTH_PROVIDER_NAME"
    valueFrom:
      configMapKeyRef:
        name: "openwebui-oauth-config"
        key: "OAUTH_PROVIDER_NAME"
  - name: "OAUTH_SCOPES"
    valueFrom:
      configMapKeyRef:
        name: "openwebui-oauth-config"
        key: "OAUTH_SCOPES"
  - name: "OAUTH_CLIENT_ID"
    valueFrom:
      configMapKeyRef:
        name: "openwebui-oauth-config"
        key: "OAUTH_CLIENT_ID"
  - name: "MICROSOFT_CLIENT_ID"
    valueFrom:
      configMapKeyRef:
        name: "openwebui-oauth-config"
        key: "MICROSOFT_CLIENT_ID"
  - name: "MICROSOFT_CLIENT_TENANT_ID"
    valueFrom:
      configMapKeyRef:
        name: "openwebui-oauth-config"
        key: "MICROSOFT_CLIENT_TENANT_ID"
  
  # OAuth configuration from Secrets Manager (sensitive)
  - name: "MICROSOFT_CLIENT_SECRET"
    valueFrom:
      secretKeyRef:
        name: "openwebui-oauth-credentials"
        key: "MICROSOFT_CLIENT_SECRET"
  - name: "OAUTH_CLIENT_SECRET"
    valueFrom:
      secretKeyRef:
        name: "openwebui-oauth-credentials"
        key: "OAUTH_CLIENT_SECRET"
  - name: "OPENID_PROVIDER_URL"
    valueFrom:
      secretKeyRef:
        name: "openwebui-oauth-credentials"
        key: "OPENID_PROVIDER_URL"
  
  # Apache Tika configuration for document processing
  - name: "TIKA_SERVER_URL"
    value: "http://tika.${shared_namespace}.svc.cluster.local:9998"
  
  # SearXNG Web Search Configuration (Step 5 integration)
  - name: "ENABLE_WEB_SEARCH"
    value: "True"
  - name: "ENABLE_RAG_WEB_SEARCH"
    value: "True"
  - name: "RAG_WEB_SEARCH_ENGINE"
    value: "searxng"
  - name: "RAG_WEB_SEARCH_RESULT_COUNT"
    value: "5"
  - name: "RAG_WEB_SEARCH_CONCURRENT_REQUESTS"
    value: "10"
  - name: "SEARXNG_QUERY_URL"
    value: "http://searxng.${shared_namespace}.svc.cluster.local:8080/search?q=<query>&format=json"
  

openaiBaseApiUrls: ["http://vllm-service.vllm-inference.svc.cluster.local/v1"]

# Branding assets are now embedded in the custom image v0.0.2
# No ConfigMap volume mounts needed
# extraVolumes: []
# extraVolumeMounts: []

# Configure resource limits to prevent OOM issues
# HR has additional SearXNG features requiring more resources
resources:
  requests:
    cpu: "750m"
    memory: "1.5Gi"
  limits:
    cpu: "2000m"
    memory: "3Gi"

# Enable Tika for automatic document processing
tika:
  enabled: true

# Disable the embedded Ollama chart
ollama:
  enabled: false

# Disable Pipelines persistence to avoid PVC Multi-Attach errors
pipelines:
  persistence:
    enabled: false
  resources:
    requests:
      cpu: "200m"
      memory: "128Mi"
    limits:
      cpu: "500m"
      memory: "256Mi"
