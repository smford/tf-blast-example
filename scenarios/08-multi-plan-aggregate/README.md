# Scenario 08: Multi-Plan Aggregation and Diff

Two separate Terraform root modules are being deployed in the same release window:
`dev` (small, low-risk) and `staging` (larger, includes a DESTROY and a REPLACE).
tf-blast can aggregate both into a single combined analysis, or diff them to compare
their risk profiles.

## What this demonstrates

- `tf-blast <plan1> <plan2>` — multi-plan aggregation into one report
- `tf-blast diff <before> <after>` — comparing two plans to highlight risk delta
- Mixed severity in aggregated output (dev=HIGH, staging=HIGH/CRITICAL)
- `--fail-on-destroy` gate triggering on staging's bastion destruction
- `--fail-on-replacement` gate triggering on staging's SG rename

## Plans in this Scenario

### plan-dev.json — Development Environment

Small, routine changes:

| Resource | Action | Detail |
|---|---|---|
| `aws_instance.api[0-2]` | UPDATE | Instance type: `t3.micro` → `t3.small` |
| `aws_cloudwatch_log_group.api` | UPDATE | Retention: 7 → 14 days |
| `aws_security_group.dev_app` | UPDATE | Minor ingress rule update |

**Blast radius: 0** — instances depend on the SG but the SG update is in-place.

### plan-staging.json — Staging Environment

Higher-impact changes in the same release window:

| Resource | Action | Detail |
|---|---|---|
| `aws_rds_cluster.staging_db` | UPDATE | Engine version 15.3 → 15.4 |
| `aws_rds_cluster_instance.staging_db[0]` | UPDATE | Follows cluster update |
| `module.app.aws_ecs_service.api` | UPDATE | desired_count: 1 → 2 |
| `aws_security_group.staging_db` | **REPLACE** | `name` change is immutable |
| `aws_instance.bastion` | **DESTROY** | Bastion host being retired |

**Blast radius: 5** — ECS service and RDS instance downstream of the cluster update.

## Running the Example

```bash
# Aggregate both plans into one combined analysis
tf-blast scenarios/08-multi-plan-aggregate/plan-dev.json \
         scenarios/08-multi-plan-aggregate/plan-staging.json

# Diff dev vs staging — see the risk difference between environments
tf-blast diff scenarios/08-multi-plan-aggregate/plan-dev.json \
             scenarios/08-multi-plan-aggregate/plan-staging.json

# Diff with markdown output (suitable for a PR comment)
tf-blast diff --output markdown \
  scenarios/08-multi-plan-aggregate/plan-dev.json \
  scenarios/08-multi-plan-aggregate/plan-staging.json

# Fail if any destroy exists across either plan
tf-blast --fail-on-destroy \
  scenarios/08-multi-plan-aggregate/plan-dev.json \
  scenarios/08-multi-plan-aggregate/plan-staging.json; echo "Exit: $?"

# Fail if any replacement exists across either plan
tf-blast --fail-on-replacement \
  scenarios/08-multi-plan-aggregate/plan-dev.json \
  scenarios/08-multi-plan-aggregate/plan-staging.json; echo "Exit: $?"

# Analyse each individually
tf-blast scenarios/08-multi-plan-aggregate/plan-dev.json
tf-blast scenarios/08-multi-plan-aggregate/plan-staging.json

# HTML report for the aggregated view
tf-blast --output html --out-file combined-report.html \
  scenarios/08-multi-plan-aggregate/plan-dev.json \
  scenarios/08-multi-plan-aggregate/plan-staging.json
```

## Expected Output

| Metric | plan-dev.json | plan-staging.json | Aggregated |
|---|---|---|---|
| To Update | 5 | 3 | 8 |
| To Replace | 0 | 1 | 1 |
| To Destroy | 0 | 1 | 1 |
| Blast Radius | 0 | 5 | 5 |
| Blast Score | 33 | 47 | ~80 |
| Max Severity | HIGH | HIGH | HIGH |
| Exit (`--fail-on-destroy`) | 0 | 1 | 1 |
| Exit (`--fail-on-replacement`) | 0 | 1 | 1 |

## Why This Matters

In a monorepo or multi-environment GitOps workflow, teams often plan and apply
multiple root modules in a single pipeline run. Without aggregation, a reviewer
might approve the "safe" dev plan without realising the full blast radius includes
the staging replacement and destroy. tf-blast's multi-plan mode gives a unified,
honest picture of the total change set.
