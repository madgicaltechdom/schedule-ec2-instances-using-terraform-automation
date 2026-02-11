data "aws_instances" "qa_instances" {
  instance_tags = {
    environment = local.environment
  }
  instance_state_names = ["running", "stopped"]
}

resource "aws_cloudwatch_event_rule" "EC2_stop" {
  count               = var.enable ? 1 : 0
  name                = "EC2-scheduler-${local.identifier}-stop"
  description         = "Stops EC2 instance on a schedule"
  schedule_expression = "cron(${var.cron_stop})"
}

resource "aws_cloudwatch_event_target" "EC2_stop" {
  count = var.enable ? 1 : 0

  arn      = "arn:aws:ssm:${data.aws_region.current.name}::automation-definition/AWS-StopEC2Instance:$DEFAULT"
  role_arn = aws_iam_role.event[0].arn
  rule     = aws_cloudwatch_event_rule.EC2_stop[0].name
  target_id = "EC2-scheduler-${local.identifier}-stop"

  input = jsonencode({
    AutomationAssumeRole = aws_iam_role.ssm_automation[0].arn
    InstanceIds          = data.aws_instances.qa_instances.ids
  })
}

resource "aws_cloudwatch_event_rule" "EC2_start" {
  count               = var.enable ? 1 : 0
  name                = "EC2-scheduler-${local.identifier}-start"
  description         = "Starts EC2 instance on a schedule"
  schedule_expression = "cron(${var.cron_start})"
}

resource "aws_cloudwatch_event_target" "EC2_start" {
  count = var.enable ? 1 : 0

  arn      = "arn:aws:ssm:${data.aws_region.current.name}::automation-definition/AWS-StartEC2Instance:$DEFAULT"
  role_arn = aws_iam_role.event[0].arn
  rule     = aws_cloudwatch_event_rule.EC2_start[0].name
  target_id = "EC2-scheduler-${local.identifier}-start"

  input = jsonencode({
    AutomationAssumeRole = aws_iam_role.ssm_automation[0].arn
    InstanceIds          = data.aws_instances.qa_instances.ids
  })
}

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
}

resource "aws_cloudwatch_event_target" "stop_target" {
  rule      = aws_cloudwatch_event_rule.stop_rule.name
  arn       = aws_lambda_function.ec2_scheduler.arn
  input     = jsonencode({ action = "stop" })
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
