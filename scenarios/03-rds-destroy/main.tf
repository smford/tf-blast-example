# WARNING: This scenario demonstrates a CRITICAL blast-radius event.
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
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "prod"
}

variable "project" {
  description = "Project name."
  type        = string
  default     = "acme"
}

variable "db_master_username" {
  description = "RDS master username."
  type        = string
  sensitive   = true
}

variable "db_master_password" {
  description = "RDS master password."
  type        = string
  sensitive   = true
}

# NOTE: In this scenario, deletion_protection is set to false to demonstrate
# what happens when the safeguard is intentionally removed.
resource "aws_rds_cluster" "aurora_pg" {
  cluster_identifier      = "${var.project}-aurora-${var.environment}"
  engine                  = "aurora-postgresql"
  engine_version          = "15.4"
  database_name           = "${var.project}db"
  master_username         = var.db_master_username
  master_password         = var.db_master_password
  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"
  storage_encrypted       = true

  # Production safeguard: deletion_protection is active on main
  deletion_protection = true
  skip_final_snapshot = false

  tags = {
    Name        = "${var.project}-aurora-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_rds_cluster_instance" "aurora_pg" {
  count = 2

  identifier         = "${var.project}-aurora-${var.environment}-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora_pg.id
  instance_class     = "db.r6g.large"
  engine             = aws_rds_cluster.aurora_pg.engine
  engine_version     = aws_rds_cluster.aurora_pg.engine_version

  tags = {
    Name        = "${var.project}-aurora-${var.environment}-${count.index}"
    Environment = var.environment
    Project     = var.project
  }
}

module "api" {
  source      = "./modules/api"
  db_endpoint = aws_rds_cluster.aurora_pg.endpoint
  db_name     = aws_rds_cluster.aurora_pg.database_name
}

module "worker" {
  source      = "./modules/worker"
  db_endpoint = aws_rds_cluster.aurora_pg.endpoint
  db_name     = aws_rds_cluster.aurora_pg.database_name
}

# To regenerate plan.json: terraform init && terraform plan -out=plan.tfplan && terraform show -json plan.tfplan > plan.json
