# Scenario 04: Multi-Module ECS Stack

A complex multi-module Terraform deployment covering VPC networking, ALB, ECS cluster and services, RDS Aurora, ElastiCache, S3, and IAM — across four modules: root, `module.app`, `module.data`, and `module.iam`. This is the most resource-rich scenario in the repository.

## What this demonstrates

- **Cross-module dependency tracing**: tf-blast traces how `module.app.aws_ecs_service` depends on `module.data.aws_rds_cluster.postgres.endpoint` and `module.iam.aws_iam_role.ecs_task_execution.arn`
- **30+ resource plans**: tf-blast handles large plans gracefully and surfaces the highest-risk resources first
- **Mermaid dependency graph**: The `--output mermaid` flag generates a visual graph of the full resource dependency tree
- **Interactive TUI**: `--interactive` lets engineers explore the dependency tree interactively before approving
- **HTML audit report**: `--output html` generates a shareable audit report for stakeholder review

## Infrastructure Overview

**Root module** (12 resources, CREATE):
- VPC, 4 subnets, IGW, NAT Gateway, EIP, 2 route tables, 3 security groups (ALB, app, DB)

**module.app** (12 resources, mixed CREATE/UPDATE):
- ECS cluster, 2 task definitions, 2 ECS services, ALB, 2 target groups, 2 ALB listeners, ACM certificate, 2 CloudWatch log groups
- 2 of the ECS services are UPDATE (desired count changes)

**module.data** (6 resources, CREATE):
- Aurora PostgreSQL cluster + 2 instances, ElastiCache Redis cluster, 2 S3 buckets

**module.iam** (5 resources, CREATE/UPDATE):
- 2 IAM roles, 2 role policy attachments, 1 IAM policy
- 1 IAM role is UPDATE (assume_role_policy change)

## Running the Example

```bash
# Terminal tree output
tf-blast scenarios/04-multi-module/plan.json

# Mermaid dependency graph (paste into mermaid.live)
tf-blast --output mermaid scenarios/04-multi-module/plan.json

# Interactive TUI explorer
tf-blast --interactive scenarios/04-multi-module/plan.json

# HTML audit report
tf-blast --output html --out-file multi-module-report.html scenarios/04-multi-module/plan.json

# JSON output for CI artifact
tf-blast --output json scenarios/04-multi-module/plan.json > multi-module-analysis.json
```

## Expected Output Summary

| Metric | Value |
|---|---|
| To Add | 28 |
| To Update | 4 |
| Total Changes | 32 |
| Blast Radius | 18 |
| Max Severity | HIGH |
| Plan Health | AT RISK |
| Exit Code (default policy) | 0 |
| Exit Code (strict config) | 1 |

## Terraform Source

The HCL source is split across module directories. See the module structure under `scenarios/04-multi-module/`.

## PR Note

Scale up ECS services and update IAM trust relationships across multi-module infrastructure:
- `module.app.aws_ecs_service.api`: desired_count 2 -> 4
- `module.app.aws_ecs_service.worker`: desired_count 2 -> 4
- `module.iam.aws_iam_role.ecs_task`: assume_role_policy update to add autoscaling principal

tf-blast: 36 resources, blast=2, severity=HIGH.
