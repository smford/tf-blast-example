# Scenario 06: Tag-Only Bulk Update

The company's tagging policy changed — the `CostCentre` tag is being added to all 20 resources across the VPC, compute, and data tiers. Every single change is an in-place UPDATE affecting only the `tags` attribute. There are no structural changes whatsoever.

## What this demonstrates

- tf-blast correctly classifies tag-only changes as **LOW** severity
- **Blast radius is 0** — tag changes have no downstream cascade effect on other resources
- Even with 20 resources changing, no exit code 1 is produced (even with strict policy)
- This is the ideal example of a high-volume but low-risk plan
- Demonstrates that tf-blast does not produce false positives on routine operational changes

## Why this matters

Without a blast-radius tool, a plan showing "20 resources to update" might trigger unnecessary review overhead or pipeline delays. tf-blast immediately signals that these are LOW severity, blast-radius 0 changes — safe to apply automatically.

## Infrastructure Overview

Resources receiving the `CostCentre: "engineering-platform"` tag:

| Resource Type | Count |
|---|---|
| aws_vpc | 2 |
| aws_subnet | 4 |
| aws_security_group | 2 |
| aws_instance | 3 |
| aws_s3_bucket | 2 |
| aws_rds_cluster | 1 |
| aws_ecs_service | 2 |
| aws_alb | 2 |
| aws_cloudwatch_log_group | 2 |
| **Total** | **20** |

## Running the Example

```bash
# Basic run
tf-blast scenarios/06-tag-only-update/plan.json

# With strict config (should still exit 0 — no HIGH or CRITICAL changes)
tf-blast --config configs/strict.tf-blast.yaml scenarios/06-tag-only-update/plan.json

# JSON summary
tf-blast --output json scenarios/06-tag-only-update/plan.json | jq .summary
```

## Expected Output Summary

| Metric | Value |
|---|---|
| To Add | 0 |
| To Update | 20 |
| To Destroy | 0 |
| To Replace | 0 |
| Blast Radius | 0 |
| Max Severity | LOW |
| Plan Health | CLEAN |
| Exit Code | 0 |

## PR Note

Bulk tagging rollout: adding `CostCentre: "engineering-platform"` across all 20 resources.
All changes are tag-only in-place UPDATEs.
No structural changes, no replacements, no destroys.

tf-blast: blast=0, severity=LOW, exit=0 — safe to auto-approve.
