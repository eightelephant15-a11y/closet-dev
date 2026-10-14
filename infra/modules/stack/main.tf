# One complete environment. envs/staging and envs/prod differ only in sizing and protection.
data "aws_caller_identity" "current" {}

locals {
  name = "stylist-${var.environment}"
}

module "network" {
  source            = "../network"
  name              = local.name
  region            = var.region
  nat_gateway_count = var.nat_gateway_count
}

# Shared by API tasks and scheduled jobs; DB and cache only accept this group.
resource "aws_security_group" "app" {
  name_prefix = "${local.name}-app-"
  vpc_id      = module.network.vpc_id
  description = "API tasks and jobs"

  egress {
    description = "Outbound (Firebase, Sentry, PostHog, AWS APIs)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

module "database" {
  source                     = "../database"
  name                       = local.name
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_subnet_ids
  allowed_security_group_ids = [aws_security_group.app.id]
  instance_class             = var.db_instance_class
  allocated_storage          = var.db_allocated_storage
  multi_az                   = var.db_multi_az
  backup_retention_days      = var.db_backup_retention_days
  deletion_protection        = var.protect
}

module "cache" {
  source                     = "../cache"
  name                       = local.name
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_subnet_ids
  allowed_security_group_ids = [aws_security_group.app.id]
  node_type                  = var.cache_node_type
  num_cache_clusters         = var.cache_nodes
}

module "storage" {
  source     = "../storage"
  name       = local.name
  account_id = data.aws_caller_identity.current.account_id
  protect    = var.protect
}

module "secrets" {
  source                  = "../secrets"
  name                    = local.name
  recovery_window_in_days = var.protect ? 30 : 0
}

module "api" {
  source                = "../api_service"
  name                  = local.name
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  private_subnet_ids    = module.network.private_subnet_ids
  app_security_group_id = aws_security_group.app.id
  image_tag             = var.image_tag
  cpu                   = var.api_cpu
  memory                = var.api_memory
  desired_count         = var.api_desired_count
  max_count             = var.api_max_count
  certificate_arn       = var.certificate_arn
  export_bucket_arn     = module.storage.bucket_arn
  images_bucket_arn     = module.storage.images_bucket_arn
  protect               = var.protect
  worker_cpu            = var.worker_cpu
  worker_memory         = var.worker_memory
  worker_desired_count  = var.worker_desired_count
  worker_max_count      = var.worker_max_count

  environment = {
    APP_ENV             = var.environment
    REDIS_URL           = module.cache.redis_url
    EXPORT_BUCKET       = module.storage.bucket_name
    STORAGE_BACKEND     = "s3"
    IMAGES_BUCKET       = module.storage.images_bucket_name
    AWS_REGION          = var.region
    QUEUE_BACKEND       = "arq"
    FIREBASE_PROJECT_ID = var.firebase_project_id
    PRIVACY_POLICY_URL  = var.privacy_policy_url
    TERMS_URL           = var.terms_url
    POLICY_VERSION      = var.policy_version
  }

  secrets = {
    DATABASE_URL              = module.database.database_url_secret_arn
    SENTRY_DSN                = module.secrets.sentry_dsn_secret_arn
    FIREBASE_CREDENTIALS_JSON = module.secrets.firebase_credentials_secret_arn
  }

  worker_environment = {
    VISION_MODEL = var.vision_model
  }

  # The key reaches the worker only when explicitly enabled; the container would fail to start while the
  # secret has no value. The remote-config flag vision_provider still decides whether Claude is used.
  worker_secrets = var.claude_vision_enabled ? {
    ANTHROPIC_API_KEY = module.secrets.anthropic_api_key_secret_arn
  } : {}
}

module "jobs" {
  source                               = "../jobs"
  name                                 = local.name
  cluster_arn                          = module.api.cluster_arn
  task_definition_arn_without_revision = module.api.task_definition_arn_without_revision
  task_role_arn                        = module.api.task_role_arn
  execution_role_arn                   = module.api.execution_role_arn
  private_subnet_ids                   = module.network.private_subnet_ids
  app_security_group_id                = aws_security_group.app.id
}

module "observability" {
  source                  = "../observability"
  name                    = local.name
  alert_email             = var.alert_email
  alb_arn_suffix          = module.api.alb_arn_suffix
  target_group_arn_suffix = module.api.target_group_arn_suffix
  cluster_name            = module.api.cluster_name
  service_name            = module.api.service_name
  db_identifier           = module.database.identifier
  worker_service_name     = module.api.worker_service_name
  worker_metric_namespace = module.api.dead_jobs_metric_namespace
}
