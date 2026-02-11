data "aws_iam_policy_document" "event" {
  count = var.enable ? 1 : 0
  statement {
    effect    = "Allow"
    actions   = ["ssm:StartAutomationExecution"]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.ssm_automation[0].arn]
  }
}

data "aws_iam_policy_document" "event_trust" {
  count = var.enable ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

# Generate a random string to add it to the name of the Target Group
resource "random_string" "iam_suffix" {
  length = 12
  min_numeric = 12
}

resource "aws_iam_role" "event" {
  count              = var.enable ? 1 : 0
  name               = substr("EC2-scheduler-${local.identifier}-${random_string.iam_suffix.result}", 0, 64)
  assume_role_policy = data.aws_iam_policy_document.event_trust[0].json
}

resource "aws_iam_role_policy" "event" {
  count  = var.enable ? 1 : 0
  name   = substr("EC2-scheduler-${local.identifier}-${random_string.iam_suffix.result}", 0, 64)
  policy = data.aws_iam_policy_document.event[0].json
  role   = aws_iam_role.event[0].name
}

data "aws_iam_policy_document" "ssm_automation_trust" {
  count = var.enable ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm_automation" {
  count              = var.enable ? 1 : 0
  name               = substr("EC2-scheduler-ssm-${local.identifier}-${random_string.iam_suffix.result}", 0, 64)
  assume_role_policy = data.aws_iam_policy_document.ssm_automation_trust[0].json
}

resource "aws_iam_role_policy" "ssm_automation" {
  count  = var.enable ? 1 : 0
  name   = substr("EC2-scheduler-ssm-${local.identifier}-${random_string.iam_suffix.result}", 0, 64)
  role   = aws_iam_role.ssm_automation[0].name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ec2:DescribeInstances"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ssm_automation" {
  count      = var.enable ? 1 : 0
  role       = aws_iam_role.ssm_automation[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole"
}

resource "aws_iam_role" "lambda_ssm_role" {
  name = "Lambda-SSM-Role-${local.identifier}"
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
  name = "Lambda-SSM-Policy-${local.identifier}"
  role = aws_iam_role.lambda_ssm_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:StartAutomationExecution",
          "ec2:DescribeInstances"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_ssm_ec2_policy" {
  name = "Lambda-SSM-EC2-Policy-qa"
  role = aws_iam_role.lambda_ssm_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus"
        ]
        Resource = "*"
      }
    ]
  })
}

