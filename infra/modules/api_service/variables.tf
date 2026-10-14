variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "app_security_group_id" {
  type        = string
  description = "Security group shared by API tasks and scheduled jobs."
}

variable "image_tag" {
  type        = string
  description = "ECR image tag to run (CI pushes immutable tags such as the git sha)."
  default     = "bootstrap"
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "max_count" {
  type    = number
  default = 4
}

variable "environment" {
  type        = map(string)
  description = "Plain (non-secret) container environment."
}

variable "secrets" {
  type        = map(string)
  description = "Container env name -> Secrets Manager ARN."
}

variable "export_bucket_arn" {
  type = string
}

variable "certificate_arn" {
  type    = string
  default = ""
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "protect" {
  type    = bool
  default = false
}

variable "images_bucket_arn" {
  type        = string
  description = "Private bucket for garment photos (API signs URLs for it, the worker processes into it)."
}

variable "worker_environment" {
  type        = map(string)
  default     = {}
  description = "Extra plain environment for the worker container (merged over var.environment)."
}

variable "worker_secrets" {
  type        = map(string)
  default     = {}
  description = "Extra Secrets Manager entries for the worker only (for example ANTHROPIC_API_KEY)."
}

variable "worker_cpu" {
  type    = number
  default = 512
}

variable "worker_memory" {
  type        = number
  default     = 1024
  description = "Image decoding (HEIC, 8000 px photos) needs more headroom than the API."
}

variable "worker_desired_count" {
  type    = number
  default = 1
}

variable "worker_max_count" {
  type    = number
  default = 4
}

variable "worker_concurrency" {
  type        = number
  default     = 4
  description = "Jobs one worker process runs at once (WORKER_CONCURRENCY)."
}
