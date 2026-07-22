resource "aws_cloudwatch_event_rule" "start_rule" {
  name                = "EC2-Scheduler-Start-${local.identifier}"
  schedule_expression = "cron(${var.cron_start})"
}

resource "aws_cloudwatch_event_rule" "stop_rule" {
  name                = "EC2-Scheduler-Stop-${local.identifier}"
  schedule_expression = "cron(${var.cron_stop})"
}

resource "aws_cloudwatch_event_target" "start_target" {
  rule      = aws_cloudwatch_event_rule.start_rule.name
  arn       = aws_lambda_function.ec2_scheduler.arn
  input     = jsonencode({ action = "start" })

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 2
  }

  dead_letter_config {
    arn = aws_sqs_queue.scheduler_dlq.arn
  }
}

resource "aws_cloudwatch_event_target" "stop_target" {
  rule      = aws_cloudwatch_event_rule.stop_rule.name
  arn       = aws_lambda_function.ec2_scheduler.arn
  input     = jsonencode({ action = "stop" })

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 2
  }

  dead_letter_config {
    arn = aws_sqs_queue.scheduler_dlq.arn
  }
}

resource "aws_sqs_queue" "scheduler_dlq" {
  name                       = "EC2-Scheduler-DLQ-${local.identifier}"
  message_retention_seconds = 1209600
}

resource "aws_lambda_permission" "allow_eventbridge_start" {
  statement_id  = "AllowExecutionFromEventBridgeStart"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_rule.arn
}

resource "aws_lambda_permission" "allow_eventbridge_stop" {
  statement_id  = "AllowExecutionFromEventBridgeStop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_rule.arn
}
