# tf-blast-example

Synthetic AWS Terraform examples demonstrating tf-blast blast-radius analysis

[![tf-blast](https://img.shields.io/badge/tf--blast-examples-orange)](https://github.com/smford/tf-blast) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Overview

This is a collection of synthetic, runnable (plan-only) Terraform AWS infrastructure scenarios designed to demonstrate every major feature of [tf-blast](https://github.com/smford/tf-blast). No real AWS credentials are required — all examples use the `null` or mocked provider backends. Pre-generated Terraform plan JSON files are included so you can run `tf-blast` immediately without even installing Terraform.

Each scenario is crafted to highlight a specific blast-radius risk pattern: from zero-risk greenfield deployments through to catastrophic critical-severity database destructions with downstream cascade effects. The included policy configuration files (`configs/`) show how `tf-blast` can be tuned from permissive development gates to strict production pipelines.

---

## Prerequisites

- **tf-blast** >= v1.2.0
- **Terraform** >= 1.8 *(optional — only required to regenerate plan JSON files)*
- **AWS credentials** *(optional — only required for real plan generation against live infrastructure)*

---

## Repository Structure

```
tf-blast-example/
├── README.md
├── LICENSE
├── .tf-blast.yaml              # Root policy config (used by all examples)
├── scenarios/
│   ├── 01-greenfield-vpc/      # Simple net-new CREATE plan — low blast radius
│   ├── 02-security-group-replace/  # SG replacement cascades to 6 dependent EC2 instances
│   ├── 03-rds-destroy/         # CRITICAL: database destruction with downstream cascade
│   ├── 04-multi-module/        # Multi-module ECS+RDS+ALB stack with 30+ resources
│   ├── 05-drift-detection/     # Out-of-band drift detected in state file
│   ├── 06-tag-only-update/     # Low-risk tag-only change across 20 resources
│   ├── 07-iam-role-replace/    # HIGH: IAM role replacement, downstream policy cascade
│   └── 08-multi-plan-aggregate/  # Aggregating two separate plans (dev + staging)
├── configs/
│   ├── strict.tf-blast.yaml    # Strict policy: fail on high, max_blast=10
│   ├── permissive.tf-blast.yaml # Permissive: fail on critical only, no blast limit
│   └── no-databases.tf-blast.yaml  # Custom: extends critical rules for all DB types
└── docs/
    └── scenarios.md            # Detailed explanation of each scenario
```

---

## Quick Start

```bash
# Install tf-blast
brew install smford/tap/tf-blast

# Run a simple greenfield analysis
tf-blast scenarios/01-greenfield-vpc/plan.json

# Run a critical database destroy scenario
tf-blast scenarios/03-rds-destroy/plan.json

# Use strict policy config
tf-blast --config configs/strict.tf-blast.yaml scenarios/02-security-group-replace/plan.json

# Generate HTML report
tf-blast --output html --out-file report.html scenarios/04-multi-module/plan.json

# Generate Mermaid dependency graph
tf-blast --output mermaid scenarios/04-multi-module/plan.json

# Diff two plans (dev vs staging)
tf-blast diff scenarios/08-multi-plan-aggregate/plan-dev.json scenarios/08-multi-plan-aggregate/plan-staging.json

# Aggregate multiple plans into one analysis
tf-blast scenarios/08-multi-plan-aggregate/plan-dev.json scenarios/08-multi-plan-aggregate/plan-staging.json

# Pipe plan via stdin
cat scenarios/03-rds-destroy/plan.json | tf-blast --fail-on critical

# Interactive TUI explorer
tf-blast --interactive scenarios/04-multi-module/plan.json
```

---

## Scenarios

| Scenario | Description | Action Types | Max Severity | Blast Radius Estimate |
|---|---|---|---|---|
| 01-greenfield-vpc | New VPC, subnets, IGW, route tables from scratch | CREATE only | LOW | ~0 |
| 02-security-group-replace | SG name change forces replacement, cascades to 6 EC2 instances | REPLACE, UPDATE | HIGH | 6 |
| 03-rds-destroy | Aurora cluster deletion cascades to ECS services depending on DB endpoint | DESTROY, UPDATE | CRITICAL | 4 |
| 04-multi-module | Full ECS+RDS+ALB+VPC stack across 3 modules | CREATE, UPDATE | HIGH | 18 |
| 05-drift-detection | Manually changed SG rule detected as drift in state | UPDATE (drift) | HIGH | 3 |
| 06-tag-only-update | Bulk tag update across 20 resources — no structural change | UPDATE | LOW | 0 |
| 07-iam-role-replace | IAM role ARN change forces replacement, invalidates 4 attached policies | REPLACE | HIGH | 4 |
| 08-multi-plan-aggregate | dev + staging plans with different change sets | CREATE, UPDATE, DESTROY | CRITICAL | 12 |

---

## Policy Configs

Three pre-built policy configurations are provided in `configs/` to demonstrate how `tf-blast` can be tuned for different risk tolerances:

| Config | Description | fail_on | max_blast |
|---|---|---|---|
| `strict.tf-blast.yaml` | For production-gated pipelines. Fails on HIGH or above, hard blast radius cap of 10. Any structural risk blocks deployment. | `high` | `10` |
| `permissive.tf-blast.yaml` | For development environments. Only fails on CRITICAL (data stores). No blast radius limits. Tolerates structural churn. | `critical` | `0` (disabled) |
| `no-databases.tf-blast.yaml` | Extended database protection. Classifies all database-related resource types as CRITICAL. Suitable for strict data residency or compliance requirements. | `critical` | `50` |

The root `.tf-blast.yaml` in this repository is a sensible default: `fail_on: critical`, no blast radius cap, with a comprehensive set of rules covering all major AWS resource categories.

---

## Regenerating Plans

If you want to regenerate the `plan.json` files from the Terraform HCL sources (requires Terraform >= 1.8 and AWS credentials):

```bash
cd scenarios/01-greenfield-vpc
terraform init
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan > plan.json
```

Repeat for each scenario directory. Note that scenarios 03, 07, and 08 require existing state to produce destroy/replace plans — the pre-generated files are the recommended way to run these examples.

---

## License

MIT — see [LICENSE](LICENSE) for full text.

---

## Related

- [tf-blast](https://github.com/smford/tf-blast) — the blast-radius analysis tool this repository demonstrates
- [tf-blast documentation](https://stephenford.org/tf-blast/) — full reference documentation
