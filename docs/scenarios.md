# Scenario Reference

A detailed reference for all eight tf-blast-example scenarios. Each scenario
isolates one or more tf-blast capabilities using a synthetic but realistic AWS
Terraform plan.

---

## Scenario Overview

| # | Scenario | tf-blast Features Demonstrated | Default Exit Code | Key Flags |
|---|---|---|---|---|
| 01 | Greenfield VPC | CREATE analysis, LOW severity, mermaid output | 0 | `--output mermaid`, `--output json` |
| 02 | Security Group Replace | REPLACE detection, HIGH cascade, fail gates | 0 | `--fail-on-replacement`, `--config strict` |
| 03 | RDS Aurora Destroy | CRITICAL destroy, policy gate, SARIF, HTML | 1 | `--fail-on critical`, `--output sarif`, stdin |
| 04 | Multi-Module ECS Stack | Cross-module deps, large plan, interactive TUI | 0 | `--interactive`, `--output html`, `--output mermaid` |
| 05 | Drift Detection | Out-of-band drift surfacing | 0 | `--output json \| jq` |
| 06 | Tag-Only Bulk Update | LOW severity at scale, strict policy still passes | 0 | `--config strict` |
| 07 | IAM Role Replace | HIGH replace cascade, diff command | 0 | `--fail-on high`, `diff` |
| 08 | Multi-Plan Aggregate | Aggregation, diff, fail-on-destroy/replacement | 1* | `diff`, `--fail-on-destroy`, `--fail-on-replacement` |

> \* Exit 1 only when using `--fail-on-destroy` or `--fail-on-replacement`. Default policy exits 0.

---

## tf-blast Feature Coverage Matrix

| Feature | Scenarios |
|---|---|
| CREATE-only analysis | 01, 04 |
| UPDATE cascade | 02, 03, 05, 07, 08 |
| REPLACE detection | 02, 07, 08 |
| DESTROY detection | 03, 08 |
| CRITICAL severity | 03 |
| HIGH severity | 02, 04, 05, 07, 08 |
| MEDIUM severity | 06, 07 (before) |
| LOW severity | 01, 06 |
| Drift detection | 05 |
| Cross-module dependency tracing | 03, 04, 07 |
| Multi-plan aggregation | 08 |
| `tf-blast diff` | 07, 08 |
| Custom `.tf-blast.yaml` policy | all |
| `fail_on: critical` gate | 03 |
| `fail_on: high` gate | 02, 07 |
| `--fail-on-replacement` | 02, 07, 08 |
| `--fail-on-destroy` | 03, 08 |
| `max_blast` limit | 02 (with strict config) |
| `max_score` limit | 04 (with strict config) |
| `--output terminal` | all |
| `--output markdown` | 02, 03, 07, 08 |
| `--output json` | 01, 04, 05 |
| `--output mermaid` | 01, 04 |
| `--output sarif` | 03 |
| `--output html` | 03, 04, 08 |
| stdin pipe | 03 |
| `--silent` mode | 03 |
| `--interactive` TUI | 04 |
| `ignore_resources` config | all (nulls/randoms filtered) |

---

## Scenario Deep Dives

### Scenario 01: Greenfield VPC

**Risk:** None — all CREATE actions, no existing resources are being changed.

**Architecture:**

```
aws_vpc.main
  ├── aws_subnet.public[0]  (us-east-1a)
  ├── aws_subnet.public[1]  (us-east-1b)
  ├── aws_subnet.private[0] (us-east-1a)
  ├── aws_subnet.private[1] (us-east-1b)
  ├── aws_internet_gateway.main
  │     └── aws_route_table.public
  │           ├── aws_route_table_association.public[0]
  │           └── aws_route_table_association.public[1]
  └── aws_nat_gateway.main  (uses aws_eip.nat)
        └── aws_route_table.private
aws_s3_bucket.flow_logs
aws_cloudwatch_log_group.flow_logs
```

**Key concept:** A brand-new deployment has a blast radius of **0** because no
existing downstream resources depend on what is being created. tf-blast correctly
identifies this as CLEAN.

**Without tf-blast:** A reviewer might be concerned about any 13-resource plan.
tf-blast immediately confirms: no destructive actions, no existing blast radius.

---

### Scenario 02: Security Group Replacement Cascade

**Risk:** HIGH — SG name is immutable. Rename forces destroy+create, updating 6 EC2 instances.

**Architecture:**

```
aws_security_group.app_servers  ← REPLACE (name immutable)
  ├── aws_instance.web[0]       ← UPDATE (vpc_security_group_ids ref)
  ├── aws_instance.web[1]       ← UPDATE
  ├── aws_instance.web[2]       ← UPDATE
  ├── aws_instance.web[3]       ← UPDATE
  ├── aws_instance.web[4]       ← UPDATE
  └── aws_instance.web[5]       ← UPDATE
```

**Key concept:** A single REPLACE propagates to all resources that reference the
replaced resource's ID. tf-blast traces the graph edge `vpc_security_group_ids →
aws_security_group.app_servers.id` and counts 6 downstream dependents.

**Without tf-blast:** A PR description says "rename security group for cleaner naming".
Six EC2 instances experience a brief period where their SG association is undefined,
potentially dropping traffic during the destroy phase.

---

### Scenario 03: RDS Aurora Cluster Destruction

**Risk:** CRITICAL — permanent data loss potential. Exit code 1 with default policy.

**Architecture:**

```
aws_rds_cluster.aurora_pg              ← DESTROY (CRITICAL)
  ├── aws_rds_cluster_instance.aurora_pg[0]  ← DESTROY
  ├── aws_rds_cluster_instance.aurora_pg[1]  ← DESTROY
  ├── module.api.aws_ecs_service.web         ← UPDATE (db_endpoint ref lost)
  └── module.worker.aws_ecs_service.job_processor  ← UPDATE
```

**Key concept:** tf-blast tags the RDS cluster as CRITICAL (matches `*rds*` rule),
calculates blast_score=98, and exits 1 because `fail_on: critical` is active in
the root `.tf-blast.yaml`. The downstream ECS services will fail to connect to the
database once the cluster is deleted.

**Without tf-blast:** A developer removes a database from Terraform state assuming
the resource was already deleted. The plan shows "5 changes" without conveying that
3 of them are irreversible data-layer deletions affecting live services.

---

### Scenario 04: Multi-Module ECS Stack

**Risk:** HIGH score (56) but blast radius = 0 for updates — this is a largely
additive plan (32 new resources) with 4 in-place updates.

**Architecture (simplified):**

```
root
  ├── aws_vpc.main + subnets + IGW + NAT + route tables
  ├── aws_security_group.alb / .app / .db
  ├── module.app
  │     ├── aws_ecs_cluster.main
  │     ├── aws_ecs_task_definition.api / .worker
  │     ├── aws_ecs_service.api (UPDATE desired_count) / .worker (UPDATE)
  │     ├── aws_alb.main + target group + listeners
  │     ├── aws_acm_certificate.api
  │     └── aws_cloudwatch_log_group.api / .worker
  ├── module.data
  │     ├── aws_rds_cluster.postgres (UPDATE parameter_group) ← CRITICAL resource
  │     ├── aws_rds_cluster_instance.postgres[0,1]
  │     ├── aws_elasticache_cluster.redis
  │     └── aws_s3_bucket.uploads / .backups
  └── module.iam
        ├── aws_iam_role.ecs_task_execution (UPDATE assume_role_policy)
        ├── aws_iam_role.ecs_task
        ├── aws_iam_role_policy_attachment.ecs_task_execution
        ├── aws_iam_policy.s3_access
        └── aws_iam_role_policy_attachment.s3_access
```

**Key concept:** tf-blast traces cross-module dependencies. The Mermaid output is
particularly useful here to visualise the full dependency graph across modules.

---

### Scenario 05: Out-of-Band Drift Detection

**Risk:** HIGH — a rogue SSH ingress rule was manually added to a security group.
Terraform will correct it, updating 2 downstream instances.

**Architecture:**

```
aws_security_group.app  ← DRIFT + UPDATE (removing rogue port 22 rule)
  ├── aws_instance.app[0]  ← UPDATE
  └── aws_instance.app[1]  ← UPDATE
```

**Key concept:** tf-blast surfaces the `resource_drift` section from the plan JSON.
The JSON output `has_drift: true` and `drift_details` field identify which resources
drifted and what changed.

**Without tf-blast:** The plan shows "3 changes" and a diff that removes an ingress
rule. Without context, a reviewer might approve a security group change without
understanding it is correcting an out-of-band modification — a potential indicator
of a security incident.

---

### Scenario 06: Tag-Only Bulk Update

**Risk:** LOW — 20 resources updated with only tag changes. No structural impact.

**Key concept:** Even at scale (20 resources), tf-blast correctly identifies that
tag-only updates have a blast radius of **0**. The `max_severity` is MEDIUM (some
resources like `aws_rds_cluster` have CRITICAL underlying type but their
*action* is a benign tag update). Even the strict policy config exits 0.

**Without tf-blast:** A bulk tag-update PR touching 20 resources looks alarming in
a plain `terraform plan` output. tf-blast immediately categorises it as safe.

---

### Scenario 07: IAM Role Replacement Cascade

**Risk:** HIGH — immutable `name` attribute forces role replacement, cascading to
4 policy attachments and 3 task definitions. The `tf-blast diff` command shows the
risk jump from the safe baseline.

**Architecture:**

```
aws_iam_role.ecs_task_execution                    ← REPLACE (name immutable)
  ├── aws_iam_role_policy_attachment.[0]            ← UPDATE (role ref)
  ├── aws_iam_role_policy_attachment.[1]            ← UPDATE
  ├── aws_iam_role_policy_attachment.[2]            ← UPDATE
  ├── aws_iam_role_policy_attachment.[3]            ← UPDATE
  ├── module.app.aws_ecs_task_definition.api        ← UPDATE (execution_role_arn)
  ├── module.app.aws_ecs_task_definition.worker     ← UPDATE
  └── module.app.aws_ecs_task_definition.scheduler  ← UPDATE
```

**Key concept:** The `diff` subcommand compares `plan-before.json` (tag-only, safe)
against `plan.json` (replacement, risky) and highlights the blast radius increase
(0→5) and severity escalation (MEDIUM→HIGH).

---

### Scenario 08: Multi-Plan Aggregation

**Risk:** Combined HIGH — dev plan is routine; staging plan contains a DESTROY
(bastion) and a REPLACE (security group rename).

**Key concept:** tf-blast accepts multiple plan files as positional arguments and
aggregates them into a unified blast-radius report. This is critical for monorepo
and multi-environment pipelines where several root modules are planned simultaneously.

**Without tf-blast:** Each plan is reviewed in isolation. The dev plan is approved
as routine. The staging plan's bastion destroy is noted but considered acceptable
(it is being retired). Nobody notices that combined, this release window includes
a REPLACE on a DB security group, an RDS engine version change, and a destroy —
a HIGH combined risk requiring coordinated rollout.

---

## Policy Configurations

### configs/strict.tf-blast.yaml

**Intent:** Use in production deployment pipelines as a hard gate.

- `fail_on: high` — any HIGH or above severity resource causes exit 1
- `max_blast: 10` — more than 10 downstream blast radius resources causes exit 1
- `max_score: 100` — weighted score cap

**Scenarios it fails:** 02 (HIGH SG), 03 (CRITICAL RDS), 04 (score=56 < 100, passes),
07 (HIGH IAM), 08 (HIGH combined)

### configs/permissive.tf-blast.yaml

**Intent:** Use in development environments where structural churn is normal.

- `fail_on: critical` — only data store destruction triggers exit 1
- No blast radius or score limits

**Scenarios it fails:** 03 only (CRITICAL RDS destroy)

### configs/no-databases.tf-blast.yaml

**Intent:** Environments with strict data residency or compliance requirements.
Extends the CRITICAL tier to cover every AWS database service including Redshift,
OpenSearch, Neptune, Timestream, and Keyspaces.

- `fail_on: critical`
- `max_blast: 50`
- Extended CRITICAL rules covering 12 database resource patterns

**Scenarios it fails:** 03, and would also flag 04 (elasticache, rds) and 08 (rds cluster update)
