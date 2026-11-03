
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "devops-lambda-tfstate-eu-central-1"
    key          = "devops-lambda-project/bootstrap/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-central-1"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "devops-lambda-tfstate-eu-central-1"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project     = "devops-lambda-project"
    Environment = "learning"
    Purpose     = "terraform-state"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

#Git Hub Actions Workflow for CI/CD
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]
  tags = {
    Project = "devops-lambda-project"
    Purpose = "github-actions-oidc"
  }
}

resource "aws_iam_role" "github_actions" {
  name = "GitHubActionsTerraformRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = var.github_oid_provider_url
          }
        }
      }
    ]
  })

  tags = {
    Project     = "devops-lambda-project"
    Environment = "learning"
    Purpose     = "github-actions-deployment"
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "GitHubActionsLambdaDeployPolicy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      # 1. List only the main Terraform state path
      {
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = aws_s3_bucket.terraform_state.arn

        Condition = {
          StringLike = {
            "s3:prefix" = [
              "devops-lambda-project/terraform.tfstate*"
            ]
          }
        }
      },

      # 2. Read and update the main Terraform state
      {
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]

        Resource = [
          "${aws_s3_bucket.terraform_state.arn}/devops-lambda-project/terraform.tfstate"
        ]
      },

      # 3. Manage the Terraform state lockfile
      {
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = [
          "${aws_s3_bucket.terraform_state.arn}/devops-lambda-project/terraform.tfstate.tflock"
        ]
      },

      # 4. Read and update the existing Lambda
      {
        Effect = "Allow"

        Action = [
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:ListTags",
          "lambda:ListVersionsByFunction",
          "lambda:GetFunctionCodeSigningConfig"
        ]

        Resource = "arn:aws:lambda:eu-central-1:${data.aws_caller_identity.current.account_id}:function:devops-lambda-project"
      },

      # 5. Read the Lambda CloudWatch log group
      {
        Effect = "Allow"

        Action = [
          "logs:DescribeLogGroups",
          "logs:ListTagsForResource"
        ]

        Resource = "*"
      },

      # 6. Read the existing Lambda execution role
      {
        Effect = "Allow"

        Action = [
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:ListRoleTags"
        ]

        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/devops-lambda-project-execution-role",
          "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
        ]
      },

      # 7. Pass only the Lambda execution role to Lambda
      {
        Effect = "Allow"

        Action = [
          "iam:PassRole"
        ]

        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/devops-lambda-project-execution-role"

        Condition = {
          StringEquals = {
            "iam:PassedToService" = "lambda.amazonaws.com"
          }
        }
      }
    ]
  })
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}
