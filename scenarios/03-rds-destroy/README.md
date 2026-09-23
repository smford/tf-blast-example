# Scenario 03: RDS Aurora Cluster Destruction

An Aurora PostgreSQL cluster is being destroyed — removed entirely from Terraform state. This is the highest-risk category of Terraform operation.

## What this demonstrates

- The Aurora cluster (`aws_rds_cluster.aurora_pg`) is classified **CRITICAL** severity, matching the `*rds*` rule
- Two cluster instances (`aws_rds_cluster_instance.aurora_pg[0]` and `[1]`) are also destroyed
- Two downstream ECS services (`module.api.aws_ecs_service.web` and `module.worker.aws_ecs_service.job_processor`) that reference the database endpoint are flagged as **updated** (blast radius casualties)
- **Blast radius: 4** (2 cluster instances + 2 ECS services downstream)
- **Exit code 1** with the default policy (`fail_on: critical`)
- Demonstrates how tf-blast prevents accidental data loss by blocking the pipeline immediately

## Why this matters

A DESTROY action on an RDS cluster is permanent. Without `deletion_protection` and without a blast-radius gate, a misplaced `terraform apply` in a CI pipeline could silently destroy a production database. tf-blast exits with code 1 on the `plan` step, blocking the apply from ever running.

## Infrastructure Overview

Resources being destroyed:
- 1× `aws_rds_cluster.aurora_pg` — Aurora PostgreSQL 15.4, CRITICAL
- 2× `aws_rds_cluster_instance.aurora_pg[0,1]` — db.r6g.large instances, CRITICAL

Downstream cascade (UPDATE):
- `module.api.aws_ecs_service.web` — depends on `aws_rds_cluster.aurora_pg.endpoint`
- `module.worker.aws_ecs_service.job_processor` — depends on `aws_rds_cluster.aurora_pg.endpoint`

## Running the Example

```bash
# Basic run (exit code 1 — CRITICAL severity detected)
tf-blast scenarios/03-rds-destroy/plan.json

# Pipe via stdin
cat scenarios/03-rds-destroy/plan.json | tf-blast --fail-on critical

# Silent mode — useful for CI checks where you only care about exit code
tf-blast --silent --fail-on critical scenarios/03-rds-destroy/plan.json; echo "Exit: $?"

# SARIF output for GitHub Code Scanning integration
tf-blast --output sarif --out-file rds-destroy.sarif scenarios/03-rds-destroy/plan.json

# HTML audit report
tf-blast --output html --out-file rds-destroy.html scenarios/03-rds-destroy/plan.json

# Override with permissive config to suppress exit (not recommended for prod)
tf-blast --config configs/permissive.tf-blast.yaml scenarios/03-rds-destroy/plan.json
```

## Expected Output Summary

| Metric | Value |
|---|---|
| To Destroy | 3 |
| To Update | 2 |
| Total Changes | 5 |
| Blast Radius | 4 |
| Max Severity | CRITICAL |
| Plan Health | CRITICAL |
| Exit Code | 1 |

> **Note:** Using `--config configs/permissive.tf-blast.yaml` will also trigger exit code 1 for this scenario because the permissive config still treats `*rds*` as CRITICAL.

## Terraform Source

See `main.tf` for the Terraform HCL that generated this plan.

## PR Note

⚠️ **CRITICAL** — Decommissioning the Aurora PostgreSQL cluster from Terraform state.
- Removes `aws_rds_cluster.aurora_pg` and 2x `aws_rds_cluster_instance` (DESTROY)
- Updates downstream `module.api` and `module.worker` to point to migrated endpoint

tf-blast: blast=4, severity=CRITICAL, exit=1 — **pipeline gate blocks merge.**
