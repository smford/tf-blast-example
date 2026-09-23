# Scenario 05: Out-of-Band Drift Detection

Someone manually added a permissive ingress rule (port 22 from `0.0.0.0/0`) to a security group directly in the AWS console — bypassing Terraform entirely. When `terraform plan` was run, it detected this out-of-band change and included a `resource_drift` block in the plan JSON.

## What this demonstrates

- tf-blast surfaces `resource_drift` blocks alongside planned changes
- The drift itself is **HIGH** severity — an unexpected open SSH port is a security risk
- tf-blast's output clearly distinguishes between drift (what changed outside Terraform) and planned changes (what Terraform will do about it)
- The planned changes correct the drift by removing the rogue rule and updating the two downstream instances

## Why this matters

Without tf-blast, engineers reviewing a plan might only see the planned changes (`1 update` to the SG, `2 updates` to instances) and miss that there was a drift event. tf-blast highlights the drift context, explaining *why* the security group is being updated and what the original unauthorized change was.

## Infrastructure Overview

**Drift detected:**
- `aws_security_group.app` — manually modified in console; rogue ingress rule on port 22 from `0.0.0.0/0` added

**Planned changes (Terraform correcting the drift):**
- `aws_security_group.app` — UPDATE to remove the unauthorized rule
- `aws_instance.app[0]` — UPDATE cascade (SG rule change propagates to instance)
- `aws_instance.app[1]` — UPDATE cascade

## Running the Example

```bash
# Standard run showing drift context
tf-blast scenarios/05-drift-detection/plan.json

# JSON output — filter for resources with drift
tf-blast --output json scenarios/05-drift-detection/plan.json | jq '.resources[] | select(.has_drift==true)'

# Markdown output for PR comment
tf-blast --output markdown scenarios/05-drift-detection/plan.json
```

## Expected Output Summary

| Metric | Value |
|---|---|
| Drift Count | 1 |
| To Update | 3 |
| Total Changes | 3 |
| Blast Radius | 2 |
| Max Severity | HIGH |
| Plan Health | AT RISK |
| Exit Code (default policy) | 0 |
| Exit Code (strict config) | 1 |

## Terraform Source

The Terraform HCL for this scenario does not have a separate `main.tf` — the drift is detected from existing state.

## PR Note

Remediate security group drift detected during routine terraform plan:
- An out-of-band SSH rule (`0.0.0.0/0:22`) was manually created in AWS console
- Applying this plan removes the rogue rule and restores known state
- Added `revoke_rules_on_delete = true` and `Compliance = "cis-benchmark-remediated"` tag

tf-blast: drift_count=1, severity=HIGH, blast=2 (downstream instances updated).
