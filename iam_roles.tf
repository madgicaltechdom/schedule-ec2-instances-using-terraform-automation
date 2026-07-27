resource "aws_iam_role" "lambda_ssm_role" {
  name = "Lambda-EC2-Scheduler-Role-${local.identifier}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_ssm_policy" {
  name = "Lambda-EC2-Scheduler-Policy-${local.identifier}"
  role = aws_iam_role.lambda_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [

      # Allow Lambda to manage EC2 Fleets
      {
        Effect = "Allow",
        Action = [
          "ec2:ModifyFleet",
          "ec2:DescribeFleets",
          "ec2:DescribeFleetInstances"
        ],
        Resource = "*"
      },

      # Allow Lambda to manage EC2 Instances
      {
        Effect = "Allow",
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeInstances"
        ],
        Resource = "*"
      },

      # Allow CloudWatch logging for this Lambda
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/EC2-Scheduler-${local.identifier}:*"
      },

      # Allow sending failed events to DLQ
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage"
        ],
        Resource = aws_sqs_queue.scheduler_dlq.arn
      }

    ]
  })
}
