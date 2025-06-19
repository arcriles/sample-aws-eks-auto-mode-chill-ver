# COMMENTED OUT: ElastiCache Redis infrastructure not needed
# Cloud providers (OpenAI, Azure, Anthropic, etc.) have built-in prompt caching
# This also removes the security concern of Redis password being stored in ConfigMap

# # Redis Security Group for LiteLLM
# resource "aws_security_group" "litellm_redis_sg" {
#   name        = "${var.name}-litellm-redis-sg"
#   description = "Security group for LiteLLM Redis cluster"
#   vpc_id      = module.vpc.vpc_id

#   egress {
#     description = "Allow all outbound access"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = local.tags
# }

# # Redis Subnet Group
# resource "aws_elasticache_subnet_group" "litellm_redis_subnet_group" {
#   name        = "${var.name}-litellm-redis-subnet-group"
#   description = "Subnet group for LiteLLM Redis cluster"
#   subnet_ids  = module.vpc.private_subnets
# }

# # Redis Parameter Group
# resource "aws_elasticache_parameter_group" "litellm_redis_parameter_group" {
#   name        = "${var.name}-litellm-redis-parameter-group"
#   family      = "redis7"
#   description = "Redis parameter group for LiteLLM"
  
#   parameter {
#     name  = "timeout" 
#     value = "0"
#   }
# }

# # Random password for Redis
# resource "random_password" "litellm_redis_password" {
#   length  = 18
#   special = false
# }

# # Redis Replication Group
# resource "aws_elasticache_replication_group" "litellm_redis" {
#   replication_group_id       = "${var.name}-litellm-redis"
#   description                = "Redis for LiteLLM"
#   engine                     = "redis"
#   engine_version             = "7.1"
#   node_type                  = "cache.t3.micro"
#   num_cache_clusters         = 2
#   automatic_failover_enabled = true
#   parameter_group_name       = aws_elasticache_parameter_group.litellm_redis_parameter_group.name
#   subnet_group_name          = aws_elasticache_subnet_group.litellm_redis_subnet_group.name
#   security_group_ids         = [aws_security_group.litellm_redis_sg.id]
#   port                       = 6379
#   multi_az_enabled           = true
#   at_rest_encryption_enabled = true
#   transit_encryption_enabled = true
#   transit_encryption_mode    = "required"
#   auth_token                 = random_password.litellm_redis_password.result
#   auth_token_update_strategy = "SET"

#   depends_on = [
#     aws_elasticache_subnet_group.litellm_redis_subnet_group,
#     aws_elasticache_parameter_group.litellm_redis_parameter_group
#   ]
# }

# # Allow access from EKS nodes to Redis
# resource "aws_security_group_rule" "eks_to_redis" {
#   type                     = "ingress"
#   from_port                = 6379
#   to_port                  = 6379
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.litellm_redis_sg.id
#   source_security_group_id = module.eks.cluster_primary_security_group_id
#   description              = "Allow EKS nodes to connect to Redis"
# }
