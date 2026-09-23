# Scenario 07: IAM Role Replacement Cascade
# This file is for reference. The pre-generated plan.json is used by tf-blast examples.

terraform {
  required_version = ">= 1.8"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = var.aws_region }

variable "aws_region"  { default = "us-east-1" }
variable "environment" { default = "prod" }
variable "project"     { default = "acme" }

locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = { Environment = var.environment, Project = var.project, ManagedBy = "terraform" }

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
    "arn:aws:iam::aws:policy/SecretsManagerReadWrite",
  ]
}

# NOTE: Changing the `name` of an IAM role forces a replacement because
# IAM role names are immutable once created. The new role gets a new ARN,
# which cascades to all policy attachments and ECS task definitions.
resource "aws_iam_role" "ecs_task_execution" {
  # Renamed to kebab-case (forces REPLACE — IAM role names are immutable)
  name = "acme-prod-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-ecs-task-execution" })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  count = length(local.managed_policy_arns)

  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = local.managed_policy_arns[count.index]
}

resource "aws_iam_policy" "ecs_secrets" {
  name = "${local.name_prefix}-ecs-secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "ssm:GetParameter"]
      Resource = "*"
    }]
  })

  tags = local.common_tags
}

module "app" {
  source        = "./modules/app"
  name_prefix   = local.name_prefix
  common_tags   = local.common_tags
  task_exec_arn = aws_iam_role.ecs_task_execution.arn
}

# To regenerate plan.json: terraform init && terraform plan -out=plan.tfplan && terraform show -json plan.tfplan > plan.json
