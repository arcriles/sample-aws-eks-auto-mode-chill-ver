apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: postgres-external-secret
  namespace: ${namespace}
spec:
  refreshInterval: "15m"
  secretStoreRef:
    name: aws-secretsmanager
    kind: ClusterSecretStore
  target:
    name: openwebui-db-credentials
    creationPolicy: Owner
  data:
  - secretKey: url
    remoteRef:
      key: "${secret_name}"
      property: connectionString

---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: litellm-master-key-external-secret
  namespace: ${namespace}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: ClusterSecretStore
  target:
    name: litellm-master-key
    creationPolicy: Owner
    template:
      type: Opaque
      data:
        LITELLM_MASTER_KEY: "{{ .LITELLM_MASTER_KEY }}"
        OPENAI_API_KEYS: "dummy-pipeline-key;{{ .LITELLM_MASTER_KEY }};dummy-vllm-key"
  data:
  - secretKey: LITELLM_MASTER_KEY
    remoteRef:
      key: ${litellm_master_salt_secret_name}
      property: LITELLM_MASTER_KEY
