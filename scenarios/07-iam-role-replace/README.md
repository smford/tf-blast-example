# Scenario 07: IAM Role Replacement Cascade

An IAM role's `name` attribute is being changed from the legacy pascal-case
`AcmeECSTaskExecutionRole` to a kebab-case `acme-prod-ecs-task-execution`. Because
IAM role names are **immutable** in AWS, Terraform must destroy the old role and
create a new one — a **REPLACE** action. The new role gets a new ARN, which
invalidates all 4 attached policy bindings and forces 3 ECS task definition
revisions to be published with the updated `execution_role_arn`.

## What this demonstrates

- `REPLACE` detection on an immutable IAM attribute
- Downstream cascade: 4 policy attachments + 3 task definition updates forced by a single rename
- HIGH severity classification matching `*iam_role*` rule
- `--fail-on high` gate triggering exit code 1
- `tf-blast diff` comparison: before (tag-only, safe) vs. after (replacement, risky)

## Infrastructure Affected

| Resource | Action | Reason |
|---|---|---|
| `aws_iam_role.ecs_task_execution` | **REPLACE** | `name` is immutable — new ARN issued |
| `aws_iam_role_policy_attachment.ecs_task_execution_policy[0-3]` | UPDATE | Role name reference changes |
| `module.app.aws_ecs_task_definition.api` | UPDATE | `execution_role_arn` now unknown |
| `module.app.aws_ecs_task_definition.worker` | UPDATE | `execution_role_arn` now unknown |
| `module.app.aws_ecs_task_definition.scheduler` | UPDATE | `execution_role_arn` now unknown |

**Total blast radius: 7** (4 policy attachments + 3 task definitions downstream of the replaced role)

## Running the Example

```bash
# Default policy — exits 0 (fail_on=critical, IAM is HIGH)
tf-blast scenarios/07-iam-role-replace/plan.json

# Fail on HIGH severity — exits 1
tf-blast --fail-on high scenarios/07-iam-role-replace/plan.json; echo "Exit: $?"

# Strict config — exits 1 (fail_on=high)
tf-blast --config configs/strict.tf-blast.yaml scenarios/07-iam-role-replace/plan.json; echo "Exit: $?"

# Markdown output for PR comment
tf-blast --output markdown scenarios/07-iam-role-replace/plan.json

# Show the risk increase vs. a safe baseline using tf-blast diff
tf-blast diff scenarios/07-iam-role-replace/plan-before.json scenarios/07-iam-role-replace/plan.json

# Diff with markdown output
tf-blast diff --output markdown \
  scenarios/07-iam-role-replace/plan-before.json \
  scenarios/07-iam-role-replace/plan.json

# JSON output for automation
tf-blast --output json scenarios/07-iam-role-replace/plan.json | jq '{severity: .summary.max_severity, blast: .summary.total_blast_radius, failed: .failed}'
```

## Expected Output

| Metric | plan-before.json | plan.json |
|---|---|---|
| To Replace | 0 | 1 |
| To Update | 1 | 7 |
| Blast Radius | 0 | 5 |
| Blast Score | 5 | 51 |
| Max Severity | MEDIUM | HIGH |
| Exit Code (default policy) | 0 | 0 |
| Exit Code (`--fail-on high`) | 0 | 1 |

> The `tf-blast diff` output will highlight the jump from blast_radius=0 to blast_radius=5
> and the severity escalation from MEDIUM to HIGH between the two plans.

## Why This Matters Without tf-blast

A developer sees "rename IAM role" and assumes it is a cosmetic, zero-risk change.
Without blast-radius analysis they would not see that:

1. The role ARN changes — every resource referencing `execution_role_arn` is now stale
2. During the replace window, running ECS tasks may fail to pull ECR images (no execution role)
3. The 4 policy attachments are briefly detached during the destroy+create cycle

tf-blast surfaces this cascade instantly so the team can plan a maintenance window
or use `create_before_destroy` lifecycle rules.

## Terraform Source

See `main.tf` (not included in this scenario — the plan JSON is the primary artifact).
In a real project the rename would appear as a change to the `name` argument in
`aws_iam_role.ecs_task_execution`.

## PR Note

Renaming IAM role `AcmeECSTaskExecutionRole` to kebab-case `acme-prod-ecs-task-execution`.
Because IAM role names are immutable in AWS:
- Old role will be DESTROYED and new role CREATED (REPLACE)
- New ARN causes cascading updates to 4 policy attachments and 3 ECS task definitions

tf-blast: blast=7, severity=HIGH — requires SRE review and scheduled deployment window.
