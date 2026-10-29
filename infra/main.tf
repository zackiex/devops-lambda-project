terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-central-1"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../dist/index.js"
  output_path = "${path.module}/dist/lambda.zip"
}

output "lambda_package_path" {
  value = data.archive_file.lambda_zip.output_path
}

resource "aws_iam_role" "lambda_role" {
  name = "devops-lambda-project-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  tags = {
    Project     = "devops-lambda-project"
    Environment = "learning"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/devops-lambda-project"
  retention_in_days = 7

  tags = {
    Project = "devops-lambda-project"
  }
}

resource "aws_lambda_function" "app" {
  function_name = "devops-lambda-project"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "nodejs24.x"
  handler       = "index.handler"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda
  ]

  tags = {
    Project     = "devops-lambda-project"
    Environment = "learning"
  }
}
