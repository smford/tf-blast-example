# Scenario 02: Security Group Replacement Cascade

A security group `name` attribute change forces a **replace** (destroy+create) because security group names are immutable in AWS. The 6 EC2 instances that reference this SG via `vpc_security_group_ids` are all updated in-place as a downstream cascade.

## What this demonstrates

- A security group name change triggers a `["delete", "create"]` replace action
- **Blast radius: 6** — the 6 dependent EC2 instances are all flagged as downstream casualties
- **Max severity: HIGH** — `aws_security_group` matches the `*security_group*` high rule
- `--fail-on-replacement` can be used to gate pipelines on any resource replacement
- The strict config (`max_blast=10`) will block this plan because total changes (7) exceed no limit, but HIGH severity causes a fail
- A seemingly innocent SG rename can have significant blast-radius implications

## Why this matters

Infrastructure engineers frequently rename security groups to follow new naming conventions or add version suffixes. Without tf-blast, this change might appear safe in a plan summary (`1 to add, 1 to destroy, 6 to update`). tf-blast surfaces that the replacement cascades to all 6 EC2 instances, revealing the true operational risk.

## Infrastructure Overview

- 1× `aws_security_group.app_servers` — replaced due to immutable `name` attribute
- 6× `aws_instance.web[0-5]` — updated in-place as the new SG ID propagates

## Running the Example

```bash
# Basic terminal output
tf-blast scenarios/02-security-group-replace/plan.json

# Fail on any replacement (exit code 1)
tf-blast --fail-on-replacement scenarios/02-security-group-replace/plan.json

# With strict config (exit code 1 — HIGH severity)
tf-blast --config configs/strict.tf-blast.yaml scenarios/02-security-group-replace/plan.json

# Markdown output (useful for PR comments)
tf-blast --output markdown scenarios/02-security-group-replace/plan.json
```

## Expected Output Summary

| Metric | Value |
|---|---|
| To Replace | 1 |
| To Update | 6 |
| Total Changes | 7 |
| Blast Radius | 6 |
| Max Severity | HIGH |
| Plan Health | AT RISK |
| Exit Code (default policy) | 0 |
| Exit Code (--fail-on-replacement) | 1 |
| Exit Code (strict config) | 1 |

## Terraform Source

See `main.tf` for the Terraform HCL that generated this plan.

## PR Note

Renaming SG from `app-servers-sg` -> `app-servers-sg-v2` to align with new
naming standard. **AWS SG names are immutable** — this forces a REPLACE
(destroy + create) of the SG and cascades to all 6 EC2 instances referencing it.

tf-blast: blast=6, severity=HIGH — review and sign-off required.
