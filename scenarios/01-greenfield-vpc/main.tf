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
  description = "Deployment environment name (e.g. prod, staging, dev)."
  type        = string
  default     = "prod"
}

variable "project" {
  description = "Project name used for resource naming and tagging."
  type        = string
  default     = "acme"
}

locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# Greenfield VPC deployment resources will be added in PR
# (VPC, Subnets, IGW, NAT GW, Route Tables, S3 Flow Logs, CloudWatch)
