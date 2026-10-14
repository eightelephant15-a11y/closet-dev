output "alb_dns_name" {
  value = module.api.alb_dns_name
}

output "ecr_repository_url" {
  value = module.api.ecr_repository_url
}

output "ecs_cluster_name" {
  value = module.api.cluster_name
}

output "ecs_service_name" {
  value = module.api.service_name
}

output "exports_bucket" {
  value = module.storage.bucket_name
}

output "sentry_dsn_secret_arn" {
  value = module.secrets.sentry_dsn_secret_arn
}

output "firebase_credentials_secret_arn" {
  value = module.secrets.firebase_credentials_secret_arn
}

output "images_bucket" {
  value = module.storage.images_bucket_name
}

output "worker_service" {
  value = module.api.worker_service_name
}
