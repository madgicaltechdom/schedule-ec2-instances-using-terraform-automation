output "lambda_function_name" {
  value = aws_lambda_function.ec2_scheduler.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.ec2_scheduler.arn
}

output "iam_role_arn" {
  value = aws_iam_role.lambda_ssm_role.arn
}

output "dlq_url" {
  value = aws_sqs_queue.scheduler_dlq.url
}

output "dlq_arn" {
  value = aws_sqs_queue.scheduler_dlq.arn
}

output "start_rule_arn" {
  value = aws_cloudwatch_event_rule.start_rule.arn
}

output "stop_rule_arn" {
  value = aws_cloudwatch_event_rule.stop_rule.arn
}
