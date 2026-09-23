# Scenario 01: Greenfield VPC

A net-new AWS VPC deployment from scratch. Every resource is a `create` action.
No existing state, no replacements, no destroys.

## What this demonstrates

- tf-blast correctly identifies CREATE-only plans as low-risk
- Blast radius is **0** (no existing resources are downstream of the changes)
- Plan health: **CLEAN**
- New resources created from scratch have no downstream dependents to cascade to

## Infrastructure Overview

This plan creates a complete VPC networking layer:

- 1× VPC (`10.0.0.0/16`)
- 2× Public subnets (`10.0.1.0/24`, `10.0.2.0/24`) across two AZs
- 2× Private subnets (`10.0.10.0/24`, `10.0.11.0/24`) across two AZs
- 1× Internet Gateway
- 1× NAT Gateway (single-AZ for cost)
- 1× Elastic IP for NAT Gateway
- 2× Route tables (public + private) with associations
- 1× S3 bucket for VPC flow logs
- 1× CloudWatch log group for flow logs

**Total resources: 13**

## Running the Example

```bash
# Basic terminal output
tf-blast scenarios/01-greenfield-vpc/plan.json

# JSON output for scripting
tf-blast --output json scenarios/01-greenfield-vpc/plan.json | jq .summary

# Generate Mermaid dependency graph
tf-blast --output mermaid scenarios/01-greenfield-vpc/plan.json

# With strict policy (should still pass — no CRITICAL or HIGH changes)
tf-blast --config configs/strict.tf-blast.yaml scenarios/01-greenfield-vpc/plan.json
```

## Expected Output Summary

| Metric | Value |
|---|---|
| To Add | 13 |
| To Update | 0 |
| To Destroy | 0 |
| To Replace | 0 |
| Blast Radius | 0 |
| Max Severity | LOW |
| Plan Health | CLEAN |
| Exit Code | 0 |

## Terraform Source

See `main.tf` for the Terraform HCL that generated this plan.

## PR Note

Deploying new VPC stack to `us-east-1`. All resources are net-new (CREATE only).
tf-blast confirms blast radius = 0, severity = LOW. Safe to apply.
