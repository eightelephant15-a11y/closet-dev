variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "firebase_project_id" {
  type = string
}

variable "image_tag" {
  type    = string
  default = "bootstrap"
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate for the API domain. Required in prod: HTTP is redirected to HTTPS."

  validation {
    condition     = length(var.certificate_arn) > 0
    error_message = "prod requires an ACM certificate_arn."
  }
}

variable "alert_email" {
  type = string
}

variable "privacy_policy_url" {
  type = string
}

variable "terms_url" {
  type = string
}

module "stack" {
  source = "../../modules/stack"

  environment         = var.environment
  region              = var.region
  firebase_project_id = var.firebase_project_id
  image_tag           = var.image_tag
  certificate_arn     = var.certificate_arn
  alert_email         = var.alert_email
  privacy_policy_url  = var.privacy_policy_url
  terms_url           = var.terms_url

  # Resilient: NAT per AZ, Multi-AZ database with longer backups, replicated cache, 2+ tasks.
  protect                  = true
  nat_gateway_count        = 2
  db_instance_class        = "db.t4g.small"
  db_allocated_storage     = 50
  db_multi_az              = true
  db_backup_retention_days = 14
  cache_node_type          = "cache.t4g.small"
  cache_nodes              = 2
  api_cpu                  = 512
  api_memory               = 1024
  api_desired_count        = 2
  api_max_count            = 8
}

output "alb_dns_name" {
  value = module.stack.alb_dns_name
}

output "ecr_repository_url" {
  value = module.stack.ecr_repository_url
}

output "ecs_cluster_name" {
  value = module.stack.ecs_cluster_name
}

output "ecs_service_name" {
  value = module.stack.ecs_service_name
}

output "sentry_dsn_secret_arn" {
  value = module.stack.sentry_dsn_secret_arn
}

output "firebase_credentials_secret_arn" {
  value = module.stack.firebase_credentials_secret_arn
}
