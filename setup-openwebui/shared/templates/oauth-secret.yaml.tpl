# External Secret for OAuth Configuration
# This fetches sensitive OAuth credentials from AWS Secrets Manager and creates a Kubernetes Secret

apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: oauth-external-secret
  namespace: ${namespace}
spec:
  refreshInterval: "15m"
  secretStoreRef:
    name: aws-secretsmanager
    kind: ClusterSecretStore
  target:
    name: openwebui-oauth-credentials
    creationPolicy: Owner
  data:
  - secretKey: MICROSOFT_CLIENT_SECRET
    remoteRef:
      key: "${oauth_secret_name}"
      property: MICROSOFT_CLIENT_SECRET
  - secretKey: OAUTH_CLIENT_SECRET
    remoteRef:
      key: "${oauth_secret_name}"
      property: OAUTH_CLIENT_SECRET
  - secretKey: OPENID_PROVIDER_URL
    remoteRef:
      key: "${oauth_secret_name}"
      property: OPENID_PROVIDER_URL
