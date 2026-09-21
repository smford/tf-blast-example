# tf-blast-example: Working Status

> Last updated: 2026-09-21
> Repository: `/Users/asc/git/tf-blast-example`

This document tracks the build progress of the `tf-blast-example` repository.

---

## Repository Structure

```
tf-blast-example/
├── README.md                           ✅ Created
├── LICENSE                             ✅ Created
├── .gitignore                          ✅ Created
├── .tf-blast.yaml                      ✅ Created (root policy config)
├── configs/
│   ├── strict.tf-blast.yaml            ✅ Created
│   ├── permissive.tf-blast.yaml        ✅ Created
│   └── no-databases.tf-blast.yaml      ✅ Created
├── scenarios/
│   ├── 01-greenfield-vpc/
│   │   ├── README.md                   ✅ Created
│   │   ├── main.tf                     ✅ Created
│   │   └── plan.json                   ⚠️  Parse error (see below)
│   ├── 02-security-group-replace/
│   │   ├── README.md                   ✅ Created
│   │   ├── main.tf                     ✅ Created
│   │   └── plan.json                   ✅ Valid — tf-blast parses and runs
│   ├── 03-rds-destroy/
│   │   ├── README.md                   ✅ Created
│   │   ├── main.tf                     ✅ Created
│   │   └── plan.json                   ✅ Valid — exits 1 (CRITICAL, expected)
│   ├── 04-multi-module/
│   │   ├── README.md                   ✅ Created
│   │   └── plan.json                   ✅ Valid — tf-blast parses and runs
│   ├── 05-drift-detection/
│   │   ├── README.md                   ✅ Created
│   │   └── plan.json                   ✅ Valid — drift_count=1 detected
│   ├── 06-tag-only-update/
│   │   ├── README.md                   ✅ Created
│   │   └── plan.json                   ✅ Valid — tf-blast parses and runs
│   ├── 07-iam-role-replace/            ❌ Not yet created
│   │   ├── README.md
│   │   ├── plan.json
│   │   └── plan-before.json
│   └── 08-multi-plan-aggregate/        ❌ Not yet created
│       ├── README.md
│       ├── plan-dev.json
│       └── plan-staging.json
├── docs/
│   └── scenarios.md                    ❌ Not yet created
└── .github/
    └── workflows/
        ├── tf-blast-check.yml          ❌ Not yet created
        └── validate-plans.yml          ❌ Not yet created
```

---

## Validated Plan Results (Actual tf-blast Output)

| Scenario | Parse | Exit Code | to_add | to_update | to_destroy | to_replace | blast_radius | blast_score | max_severity | plan_health |
|---|---|---|---|---|---|---|---|---|---|---|
| 01-greenfield-vpc | ⚠️ Error | — | — | — | — | — | — | — | — | — |
| 02-security-group-replace | ✅ | 0 | 0 | 6 | 0 | 1 | 2 | 28 | HIGH | HIGH BLAST RADIUS DETECTED |
| 03-rds-destroy | ✅ | 1 | 0 | 2 | 3 | 0 | 4 | 98 | CRITICAL | CRITICAL BLAST RADIUS DETECTED |
| 04-multi-module | ✅ | 0 | 32 | 4 | 0 | 0 | 0 | 56 | HIGH | HIGH BLAST RADIUS DETECTED |
| 05-drift-detection | ✅ | 0 | 0 | 3 | 0 | 0 | 0 | 22 | HIGH | (drift_count=1) |
| 06-tag-only-update | ✅ | 0 | 0 | 20 | 0 | 0 | 0 | 40 | MEDIUM | MODERATE BLAST RADIUS DETECTED |
| 07-iam-role-replace | ❌ Missing | — | — | — | — | — | — | — | — | — |
| 08-multi-plan-aggregate | ❌ Missing | — | — | — | — | — | — | — | — | — |

---

## Outstanding Issues

### 01-greenfield-vpc/plan.json — Parse Error

**Error:**
```
failed to decode terraform json plan: json: cannot unmarshal array into Go struct
field ConfigResource.configuration.root_module.resources.expressions of type parser.Expression
```

**Root cause:** The `expressions` field in `configuration.root_module.resources` contains an array value where tf-blast expects an `Expression` object (`{"references": [...], "constant_value": ...}`). Fix by ensuring all expression values in the config section are objects, not arrays.

**Fix needed:** Review and fix `scenarios/01-greenfield-vpc/plan.json` — specifically the `configuration.root_module.resources[].expressions` block.

---

## Still To Create

### Scenario 07: IAM Role Replacement Cascade
- `scenarios/07-iam-role-replace/README.md`
- `scenarios/07-iam-role-replace/plan.json` — IAM role REPLACE cascading to 4 policy attachments + 3 ECS task definitions
- `scenarios/07-iam-role-replace/plan-before.json` — baseline tag-only update (for `tf-blast diff`)

### Scenario 08: Multi-Plan Aggregation
- `scenarios/08-multi-plan-aggregate/README.md`
- `scenarios/08-multi-plan-aggregate/plan-dev.json` — small dev changes (3 instance type updates, 1 SG update)
- `scenarios/08-multi-plan-aggregate/plan-staging.json` — staging with DESTROY (bastion) + REPLACE (SG) + CRITICAL (RDS update)

### Docs
- `docs/scenarios.md` — feature coverage matrix, per-scenario deep dives

### GitHub Actions Workflows
- `.github/workflows/tf-blast-check.yml` — runs tf-blast on 3 representative scenarios
- `.github/workflows/validate-plans.yml` — validates all plan JSONs on every push/PR

---

## Commands to Test What's Working Now

```bash
cd /Users/asc/git/tf-blast-example

# Scenario 02 — SG replacement, should show HIGH blast radius
tf-blast scenarios/02-security-group-replace/plan.json

# Scenario 03 — RDS destroy, exits 1 (CRITICAL policy gate)
tf-blast scenarios/03-rds-destroy/plan.json; echo "Exit: $?"

# Scenario 03 — via stdin
cat scenarios/03-rds-destroy/plan.json | tf-blast --fail-on critical; echo "Exit: $?"

# Scenario 03 — SARIF output
tf-blast --output sarif --out-file /tmp/rds-destroy.sarif scenarios/03-rds-destroy/plan.json

# Scenario 04 — multi-module, mermaid dependency graph
tf-blast --output mermaid scenarios/04-multi-module/plan.json

# Scenario 05 — drift detection, JSON output showing drift
tf-blast --output json scenarios/05-drift-detection/plan.json | python3 -c "import json,sys; r=json.load(sys.stdin); [print(x['address'], x.get('drift_details','')) for x in r['resources'] if x.get('has_drift')]"

# Scenario 06 — tag-only, strict policy still passes
tf-blast --config configs/strict.tf-blast.yaml scenarios/06-tag-only-update/plan.json; echo "Exit: $?"

# Scenario 02 — strict policy fails (blast > max_blast=10 or fail_on=high)
tf-blast --config configs/strict.tf-blast.yaml scenarios/02-security-group-replace/plan.json; echo "Exit: $?"
```

---

## Next Steps

1. **Fix** `scenarios/01-greenfield-vpc/plan.json` — expressions parse error
2. **Create** scenario 07 files (IAM role replace)
3. **Create** scenario 08 files (multi-plan aggregation + diff)
4. **Create** `docs/scenarios.md`
5. **Create** `.github/workflows/tf-blast-check.yml`
6. **Create** `.github/workflows/validate-plans.yml`
7. **Run** full validation sweep (`tf-blast --silent` on all plans)
8. **Git commit** initial state and push to GitHub
