apiVersion: v1
kind: ConfigMap
metadata:
  name: litellm-config
  namespace: litellm
data:
  config.yaml: |
    model_list:
${model_list}

    litellm_settings:
      cache: false

    general_settings:
      # master_key and database_url will be set via environment variables
      disable_spend_logs: false
      disable_usage_tracking: false
      disable_telemetry: true
      routing_strategy: "simple-shuffle"
      num_retries: 3
      allowed_origins: ["*"]
