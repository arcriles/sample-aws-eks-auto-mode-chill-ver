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
