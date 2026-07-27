resource "aws_lambda_function" "ec2_scheduler" {
  filename         = "lambda.zip"
  function_name    = "EC2-Scheduler-${local.identifier}"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_ssm_role.arn
  source_code_hash = filebase64sha256("lambda.zip")
  timeout          = 300

  environment {
    variables = {
      ENV_TAG = local.environment
    }
  }
}
