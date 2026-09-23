# Scenario 08: Multi-Plan Aggregation and Diff
# This file is for reference. The pre-generated plan JSONs are used by tf-blast examples.
# Two root modules are deployed in the same release window: dev and staging.

terraform {
  required_version = ">= 1.8"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = var.aws_region }

variable "aws_region"  { default = "us-east-1" }
variable "environment" { default = "dev" }   # overridden to "staging" for second plan
variable "project"     { default = "acme" }

locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = { Environment = var.environment, Project = var.project, ManagedBy = "terraform" }
}

# --- DEV environment ---
# API instances: currently t3.micro — being upgraded to t3.small
resource "aws_instance" "api" {
  count = 3

  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"   # upgrading to t3.small in this PR

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-api-${count.index}" })
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/${local.name_prefix}/api"
  retention_in_days = 7   # increasing to 14 days in this PR

  tags = local.common_tags
}

resource "aws_security_group" "dev_app" {
  name   = "${local.name_prefix}-app"
  vpc_id = "vpc-dev0123456789abcdef"

  ingress {
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

# --- STAGING environment (separate root module, shown here for reference) ---

# Bastion host — being decommissioned in this PR (DESTROY)
resource "aws_instance" "bastion" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  key_name      = "${local.name_prefix}-bastion"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-bastion", Role = "bastion" })
}

# Staging DB Security Group — renaming name forces REPLACE, cascades to RDS cluster
resource "aws_security_group" "staging_db" {
  name   = "acme-staging-db"   # renaming to "acme-staging-database" in this PR
  vpc_id = "vpc-stg0123456789abcdef"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "acme-staging-db-sg" })
}

resource "aws_rds_cluster" "staging_db" {
  cluster_identifier     = "acme-staging-db"
  vpc_security_group_ids = [aws_security_group.staging_db.id]
  engine                 = "aurora-postgresql"
  tags                   = merge(local.common_tags, { Name = "acme-staging-db" })
}

resource "aws_rds_cluster_instance" "staging_db" {
  count              = 1
  cluster_identifier = aws_rds_cluster.staging_db.id
  instance_class     = "db.r6g.large"
  engine             = aws_rds_cluster.staging_db.engine
}

# To regenerate plan JSONs:
#   Dev:     terraform plan -var="environment=dev"     -out=plan.tfplan && terraform show -json plan.tfplan > plan-dev.json
#   Staging: terraform plan -var="environment=staging" -out=plan.tfplan && terraform show -json plan.tfplan > plan-staging.json
