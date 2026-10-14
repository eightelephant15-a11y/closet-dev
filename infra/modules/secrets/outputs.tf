output "sentry_dsn_secret_arn" {
  value = aws_secretsmanager_secret.sentry_dsn.arn
}

output "firebase_credentials_secret_arn" {
  value = aws_secretsmanager_secret.firebase_credentials.arn
}

output "anthropic_api_key_secret_arn" {
  value = aws_secretsmanager_secret.anthropic_api_key.arn
}
