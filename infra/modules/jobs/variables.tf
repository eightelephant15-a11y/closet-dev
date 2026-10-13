variable "name" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "task_definition_arn_without_revision" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "execution_role_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "app_security_group_id" {
  type = string
}
