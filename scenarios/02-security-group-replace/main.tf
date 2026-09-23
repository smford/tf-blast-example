# This file is for reference only. The pre-generated plan.json is used directly by tf-blast examples.

terraform {
  required_version = ">= 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"
}

variable "project" {
  description = "Project name used for resource naming and tagging."
  type        = string
  default     = "acme"
}

variable "vpc_id" {
  description = "VPC ID to deploy the security group into."
  type        = string
  default     = "vpc-0123456789abcdef0"
}

# NOTE: Changing the `name` of a security group forces a replacement
# because AWS security group names are immutable once created.
# This replacement cascades to all EC2 instances using this SG.
resource "aws_security_group" "app_servers" {
  name        = "app-servers-sg"
  description = "Application servers security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "Application traffic"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-app-servers"
    Environment = var.environment
    Project     = var.project
  }
}

# 6 EC2 instances that reference the security group.
# When the SG is replaced, all 6 instances are updated in-place
# with the new security group ID.
resource "aws_instance" "web" {
  count = 6

  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t3.medium"
  key_name               = "${var.project}-${var.environment}"
  vpc_security_group_ids = [aws_security_group.app_servers.id]

  tags = {
    Name        = "${var.project}-${var.environment}-web-${count.index}"
    Environment = var.environment
    Project     = var.project
  }
}

# To regenerate plan.json: terraform init && terraform plan -out=plan.tfplan && terraform show -json plan.tfplan > plan.json
