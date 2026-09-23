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
# DECOMMISSIONED: Aurora PostgreSQL cluster removed from Terraform management
# Decommissioned per infrastructure modernization mandate (migrated to managed Aurora Serverless v2)
# aws_rds_cluster.aurora_pg: DESTROY
# aws_rds_cluster_instance.aurora_pg[0-1]: DESTROY

module "api" {
  source      = "./modules/api"
  db_endpoint = "migrated-aurora.acme.internal" # updated to new managed cluster endpoint
  db_name     = "${var.project}db"
}

module "worker" {
  source      = "./modules/worker"
  db_endpoint = "migrated-aurora.acme.internal" # updated to new managed cluster endpoint
  db_name     = "${var.project}db"
}

# To regenerate plan.json: terraform init && terraform plan -out=plan.tfplan && terraform show -json plan.tfplan > plan.json
