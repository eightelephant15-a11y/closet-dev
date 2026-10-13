variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "protect" {
  type        = bool
  default     = false
  description = "Deletion protection, final snapshots and longer secret recovery (prod)."
}

variable "nat_gateway_count" {
  type    = number
  default = 1
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_backup_retention_days" {
  type    = number
  default = 7
}

variable "cache_node_type" {
  type    = string
  default = "cache.t4g.micro"
}

variable "cache_nodes" {
  type    = number
  default = 1
}

variable "api_cpu" {
  type    = number
  default = 256
}

variable "api_memory" {
  type    = number
  default = 512
}

variable "api_desired_count" {
  type    = number
  default = 1
}

variable "api_max_count" {
  type    = number
  default = 4
}

variable "image_tag" {
  type    = string
  default = "bootstrap"
}

variable "certificate_arn" {
  type    = string
  default = ""
}

variable "firebase_project_id" {
  type = string
}

variable "privacy_policy_url" {
  type    = string
  default = "https://example.com/privacy"
}

variable "terms_url" {
  type    = string
  default = "https://example.com/terms"
}

variable "policy_version" {
  type    = string
  default = "2026-01"
}

variable "alert_email" {
  type    = string
  default = ""
}
