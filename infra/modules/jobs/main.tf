# Scheduled one-off tasks reusing the API task definition with a command override:
#   purge   -> hard-deletes accounts whose 30-day deletion window has passed (daily)
#   exports -> finishes any data-export job the API process did not complete (every 15 min)
data "aws_iam_policy_document" "events_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "events" {
  name               = "${var.name}-jobs-events"
  assume_role_policy = data.aws_iam_policy_document.events_assume.json
}

data "aws_iam_policy_document" "events" {
  statement {
    actions   = ["ecs:RunTask"]
    resources = ["${var.task_definition_arn_without_revision}:*", var.task_definition_arn_without_revision]
    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [var.cluster_arn]
    }
  }
  statement {
    actions   = ["iam:PassRole"]
    resources = [var.task_role_arn, var.execution_role_arn]
  }
}

resource "aws_iam_role_policy" "events" {
  name   = "run-jobs"
  role   = aws_iam_role.events.id
  policy = data.aws_iam_policy_document.events.json
}

locals {
  jobs = {
    purge   = { schedule = "cron(0 7 * * ? *)", command = ["python", "-m", "app.jobs", "purge"] }
    exports = { schedule = "rate(15 minutes)", command = ["python", "-m", "app.jobs", "exports"] }
  }
}

resource "aws_cloudwatch_event_rule" "job" {
  for_each            = local.jobs
  name                = "${var.name}-job-${each.key}"
  schedule_expression = each.value.schedule
}

resource "aws_cloudwatch_event_target" "job" {
  for_each  = local.jobs
  rule      = aws_cloudwatch_event_rule.job[each.key].name
  target_id = each.key
  arn       = var.cluster_arn
  role_arn  = aws_iam_role.events.arn

  ecs_target {
    launch_type         = "FARGATE"
    task_count          = 1
    task_definition_arn = var.task_definition_arn_without_revision

    network_configuration {
      subnets          = var.private_subnet_ids
      security_groups  = [var.app_security_group_id]
      assign_public_ip = false
    }
  }

  input = jsonencode({
    containerOverrides = [{ name = "api", command = each.value.command }]
  })
}
