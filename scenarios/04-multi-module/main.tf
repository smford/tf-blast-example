# Scenario 04: Multi-Module ECS Stack
# This file is for reference. The pre-generated plan.json is used by tf-blast examples.

terraform {
  required_version = ">= 1.8"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = var.aws_region }

variable "aws_region"   { default = "us-east-1" }
variable "environment"  { default = "prod" }
variable "project"      { default = "acme" }

locals {
  name_prefix  = "${var.project}-${var.environment}"
  common_tags  = { Environment = var.environment, Project = var.project, ManagedBy = "terraform" }
}

# --- Root module: VPC + Security Groups ---

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, count.index + 1)
  availability_zone = "${var.aws_region}${["a", "b"][count.index]}"
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-public-${count.index + 1}", Tier = "public" })
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, count.index + 10)
  availability_zone = "${var.aws_region}${["a", "b"][count.index]}"
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-private-${count.index + 1}", Tier = "private" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-igw" })
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-nat-eip" })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.main]
  tags          = merge(local.common_tags, { Name = "${local.name_prefix}-nat-gw" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route { cidr_block = "0.0.0.0/0"; gateway_id = aws_internet_gateway.main.id }
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-public-rt" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route { cidr_block = "0.0.0.0/0"; nat_gateway_id = aws_nat_gateway.main.id }
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-private-rt" })
}

resource "aws_security_group" "alb" {
  name   = "${local.name_prefix}-alb"
  vpc_id = aws_vpc.main.id
  ingress { from_port = 443; to_port = 443; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0;   to_port = 0;   protocol = "-1";  cidr_blocks = ["0.0.0.0/0"] }
  tags    = merge(local.common_tags, { Name = "${local.name_prefix}-alb-sg" })
}

resource "aws_security_group" "app" {
  name   = "${local.name_prefix}-app"
  vpc_id = aws_vpc.main.id
  ingress { from_port = 8080; to_port = 8080; protocol = "tcp"; security_groups = [aws_security_group.alb.id] }
  egress  { from_port = 0;    to_port = 0;    protocol = "-1";  cidr_blocks    = ["0.0.0.0/0"] }
  tags    = merge(local.common_tags, { Name = "${local.name_prefix}-app-sg" })
}

resource "aws_security_group" "db" {
  name   = "${local.name_prefix}-db"
  vpc_id = aws_vpc.main.id
  ingress { from_port = 5432; to_port = 5432; protocol = "tcp"; security_groups = [aws_security_group.app.id] }
  egress  { from_port = 0;    to_port = 0;    protocol = "-1";  cidr_blocks    = ["0.0.0.0/0"] }
  tags    = merge(local.common_tags, { Name = "${local.name_prefix}-db-sg" })
}

# --- module.app: ECS cluster + services ---

module "app" {
  source         = "./modules/app"
  name_prefix    = local.name_prefix
  common_tags    = local.common_tags
  vpc_id         = aws_vpc.main.id
  subnet_ids     = aws_subnet.private[*].id
  alb_sg_id      = aws_security_group.alb.id
  app_sg_id      = aws_security_group.app.id
  db_endpoint    = module.data.db_endpoint
  db_name        = module.data.db_name
  task_exec_role = module.iam.task_exec_role_arn

  # Current desired counts — scaling event triggered this plan
  api_desired_count    = 4   # scaled up for peak traffic
  worker_desired_count = 4   # scaled up for peak traffic
}

# --- module.data: Aurora + ElastiCache + S3 ---

module "data" {
  source      = "./modules/data"
  name_prefix = local.name_prefix
  common_tags = local.common_tags
  db_sg_id    = aws_security_group.db.id
  subnet_ids  = aws_subnet.private[*].id
}

# --- module.iam: roles + policies ---

module "iam" {
  source      = "./modules/iam"
  name_prefix = local.name_prefix
  common_tags = local.common_tags

  # Assume-role policy — grants ECS tasks.amazonaws.com principal
  ecs_trusted_principals = ["ecs-tasks.amazonaws.com", "application-autoscaling.amazonaws.com"]
}

# To regenerate plan.json: terraform init && terraform plan -out=plan.tfplan && terraform show -json plan.tfplan > plan.json
