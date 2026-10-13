variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "staging"
}

variable "firebase_project_id" {
  type = string
}

variable "image_tag" {
  type    = string
  default = "bootstrap"
}

variable "certificate_arn" {
  type    = string
  default = ""
}

variable "alert_email" {
  type    = string
  default = ""
}

module "stack" {
  source = "../../modules/stack"

  environment         = var.environment
  region              = var.region
  firebase_project_id = var.firebase_project_id
  image_tag           = var.image_tag
  certificate_arn     = var.certificate_arn
  alert_email         = var.alert_email

  # Small and cheap: single NAT, single-AZ database, one task.
  protect           = false
  nat_gateway_count = 1
  db_instance_class = "db.t4g.micro"
  db_multi_az       = false
  cache_nodes       = 1
  api_desired_count = 1
  api_max_count     = 2
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
