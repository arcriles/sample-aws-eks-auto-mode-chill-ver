resource "null_resource" "create_nodepools_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/../nodepools"
  }
}

resource "local_file" "setup_graviton" {
  content = templatefile("${path.module}/../nodepool-templates/graviton-nodepool.yaml.tpl", {
    node_iam_role_name  = module.eks.node_iam_role_name
    cluster_name = module.eks.cluster_name
  })
  filename = "${path.module}/../nodepools/graviton-nodepool.yaml"
}

resource "local_file" "setup_spot" {
  content = templatefile("${path.module}/../nodepool-templates/spot-nodepool.yaml.tpl", {
    node_iam_role_name  = module.eks.node_iam_role_name
    cluster_name = module.eks.cluster_name
  })
  filename = "${path.module}/../nodepools/spot-nodepool.yaml"
}

resource "local_file" "setup_gpu" {
  content = templatefile("${path.module}/../nodepool-templates/gpu-nodepool.yaml.tpl", {
    node_iam_role_name  = module.eks.node_iam_role_name
    cluster_name = module.eks.cluster_name
  })
  filename = "${path.module}/../nodepools/gpu-nodepool.yaml"
}

resource "local_file" "setup_neuron" {
  content = templatefile("${path.module}/../nodepool-templates/neuron-nodepool.yaml.tpl", {
    node_iam_role_name  = module.eks.node_iam_role_name
    cluster_name = module.eks.cluster_name
  })
  filename = "${path.module}/../nodepools/neuron-nodepool.yaml"
}

# Multi-Tenant OpenWebUI Setup

# Generate shared cluster secret store (once) - truly shared
resource "local_file" "setup_shared_cluster_secret_store" {
  content = templatefile("${path.module}/../setup-openwebui/shared/templates/cluster-secret-store.yaml.tpl", {
    region = var.region
  })
  filename = "${path.module}/../setup-openwebui/shared/cluster-secret-store.yaml"
}

# Generate OAuth secrets per tenant (shared template, tenant-specific files)
resource "local_file" "setup_tenant_oauth_secret" {
  for_each = var.tenants
  content = templatefile("${path.module}/../setup-openwebui/shared/templates/oauth-secret.yaml.tpl", {
    oauth_secret_name = aws_secretsmanager_secret.oauth_credentials.name
    namespace        = each.value.namespace
  })
  filename = "${path.module}/../setup-openwebui/${each.value.name}/oauth-secret.yaml"
}

# Generate tenant-specific values.yaml
resource "local_file" "setup_tenant_values" {
  for_each = var.tenants
  content = templatefile("${path.module}/../setup-openwebui/${each.value.name}/templates/values.yaml.tpl", {
    s3_bucket_name    = aws_s3_bucket.openwebui_docs[each.key].id
    region           = var.region
    rds_endpoint     = aws_db_instance.postgres.endpoint
    shared_namespace = "vllm-inference"
  })
  filename = "${path.module}/../setup-openwebui/${each.value.name}/values.yaml"
}

# Generate tenant-specific secret.yaml
resource "local_file" "setup_tenant_secret" {
  for_each = var.tenants
  content = templatefile("${path.module}/../setup-openwebui/${each.value.name}/templates/secret.yaml.tpl", {
    secret_name = aws_secretsmanager_secret.db_connection_string[each.key].name
    namespace   = each.value.namespace
  })
  filename = "${path.module}/../setup-openwebui/${each.value.name}/secret.yaml"
}

# Generate tenant-specific pgvector-job.yaml
resource "local_file" "setup_tenant_pgvector_job" {
  for_each = var.tenants
  content = templatefile("${path.module}/../setup-openwebui/${each.value.name}/templates/pgvector-job.yaml.tpl", {
    namespace = each.value.namespace
  })
  filename = "${path.module}/../setup-openwebui/${each.value.name}/pgvector-job.yaml"
}

# LiteLLM template generation
locals {
  # Read the litellm-models.yaml file and indent it properly for YAML
  litellm_models_content = fileexists("${path.module}/../litellm-models.yaml") ? file("${path.module}/../litellm-models.yaml") : "# No models configured"
  # Add proper indentation (6 spaces) for each line
  litellm_models_indented = join("\n", [for line in split("\n", local.litellm_models_content) : line != "" ? "      ${line}" : ""])
}

resource "local_file" "setup_litellm_configmap" {
  content = templatefile("${path.module}/../setup-litellm/templates/configmap.yaml.tpl", {
    model_list = local.litellm_models_indented
    # COMMENTED OUT: Redis variables - using cloud provider caching instead
    # redis_host = aws_elasticache_replication_group.litellm_redis.primary_endpoint_address
    # redis_port = aws_elasticache_replication_group.litellm_redis.port
    # redis_password = random_password.litellm_redis_password.result
  })
  filename = "${path.module}/../setup-litellm/configmap.yaml"
}

resource "local_file" "setup_litellm_secret" {
  content = templatefile("${path.module}/../setup-litellm/templates/secret.yaml.tpl", {
    litellm_master_salt_secret_name = aws_secretsmanager_secret.litellm_master_salt.name
    litellm_db_connection_secret_name = aws_secretsmanager_secret.litellm_db_connection_string.name
    litellm_api_keys_secret_name = aws_secretsmanager_secret.litellm_api_keys.name
  })
  filename = "${path.module}/../setup-litellm/secret.yaml"
}
