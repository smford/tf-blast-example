# Scenario 05: Out-of-Band Drift Detection
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
variable "vpc_id"      { default = "vpc-0123456789abcdef0" }

locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = { Environment = var.environment, Project = var.project, ManagedBy = "terraform" }
}

# Security group — an unauthorised SSH rule (port 22, 0.0.0.0/0) was manually
# added in the AWS console. This plan corrects the drift by removing it.
resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app"
  description = "Application server security group"
  vpc_id      = var.vpc_id

  # Authorised ingress rules only — no SSH from the internet
  ingress {
    description = "Application traffic from ALB"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-app-sg" })
}

resource "aws_instance" "app" {
  count = 2

  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t3.medium"
  vpc_security_group_ids = [aws_security_group.app.id]

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-app-${count.index}" })
}

# To regenerate plan.json: terraform init && terraform plan -out=plan.tfplan && terraform show -json plan.tfplan > plan.json
