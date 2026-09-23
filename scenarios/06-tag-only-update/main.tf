# Scenario 06: Tag-Only Bulk Update
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

  # Common tags applied to all resources.
  # CostCentre tag added in this PR per updated company tagging policy.
  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
    CostCentre  = "engineering-platform"
  }
}

resource "aws_vpc" "main" {
  count      = 2
  cidr_block = cidrsubnet("10.0.0.0/8", 8, count.index)
  tags       = merge(local.common_tags, { Name = "${local.name_prefix}-vpc-${count.index}" })
}

resource "aws_subnet" "app" {
  count             = 4
  vpc_id            = aws_vpc.main[floor(count.index / 2)].id
  cidr_block        = cidrsubnet("10.0.0.0/8", 12, count.index)
  availability_zone = "${var.aws_region}${["a", "b", "a", "b"][count.index]}"
  tags              = merge(local.common_tags, { Name = "${local.name_prefix}-subnet-${count.index}" })
}

resource "aws_security_group" "app" {
  count  = 2
  name   = "${local.name_prefix}-sg-${count.index}"
  vpc_id = aws_vpc.main[count.index].id
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-sg-${count.index}" })
}

resource "aws_instance" "app" {
  count         = 3
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.medium"
  tags          = merge(local.common_tags, { Name = "${local.name_prefix}-app-${count.index}" })
}

resource "aws_s3_bucket" "data" {
  count  = 2
  bucket = "${local.name_prefix}-data-${count.index}"
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-data-${count.index}" })
}

resource "aws_rds_cluster" "main" {
  cluster_identifier = "${local.name_prefix}-aurora"
  engine             = "aurora-postgresql"
  engine_version     = "15.4"
  master_username    = "admin"
  master_password    = "changeme"   # managed via Secrets Manager in practice
  tags               = merge(local.common_tags, { Name = "${local.name_prefix}-aurora" })
}

resource "aws_ecs_service" "app" {
  count           = 2
  name            = "${local.name_prefix}-svc-${count.index}"
  cluster         = "arn:aws:ecs:us-east-1:123456789012:cluster/${local.name_prefix}"
  task_definition = "arn:aws:ecs:us-east-1:123456789012:task-definition/${local.name_prefix}:1"
  desired_count   = 2
  tags            = merge(local.common_tags, { Name = "${local.name_prefix}-svc-${count.index}" })
}

resource "aws_alb" "app" {
  count    = 2
  name     = "${local.name_prefix}-alb-${count.index}"
  internal = false
  tags     = merge(local.common_tags, { Name = "${local.name_prefix}-alb-${count.index}" })
}

# To regenerate plan.json: terraform init && terraform plan -out=plan.tfplan && terraform show -json plan.tfplan > plan.json
