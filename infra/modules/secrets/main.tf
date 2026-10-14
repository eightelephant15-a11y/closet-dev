# Secret containers only. Values are put out-of-band (console / CLI) so they never
# land in Terraform state or this repository.
resource "aws_secretsmanager_secret" "sentry_dsn" {
  name                    = "${var.name}/sentry-dsn"
  description             = "Sentry DSN for the API (set the value manually)"
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret" "firebase_credentials" {
  name                    = "${var.name}/firebase-credentials-json"
  description             = "Firebase Admin service-account JSON (set the value manually)"
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret" "anthropic_api_key" {
  name                    = "${var.name}/anthropic-api-key"
  description             = "Anthropic API key for garment analysis in the worker (set the value manually BEFORE enabling claude_vision_enabled)"
  recovery_window_in_days = var.recovery_window_in_days
}
