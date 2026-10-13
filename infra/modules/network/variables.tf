variable "name" {
  type        = string
  description = "Name prefix, e.g. stylist-staging."
}

variable "region" {
  type = string
}

variable "cidr_block" {
  type    = string
  default = "10.20.0.0/16"
}

variable "nat_gateway_count" {
  type        = number
  default     = 1
  description = "1 = cheaper (staging); 2 = one per AZ (prod)."
  validation {
    condition     = contains([1, 2], var.nat_gateway_count)
    error_message = "nat_gateway_count must be 1 or 2."
  }
}
