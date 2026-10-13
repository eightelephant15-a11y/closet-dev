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
