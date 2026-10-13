output "redis_url" {
  description = "rediss:// because in-transit encryption is on."
  value       = "rediss://${aws_elasticache_replication_group.this.primary_endpoint_address}:6379/0"
}
