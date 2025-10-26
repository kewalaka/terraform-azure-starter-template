# Workflow Design Philosophy

## Overview

This starter template uses a radical simplification approach to CI/CD workflows, favoring inline steps with matrix strategies over abstracted reusable workflow calls for PR validation.

## Design Decisions

### Why Inline PR Validation Instead of Reusable Templates

The problem with template-based PR validation:

- Cannot use matrix strategies across reusable workflow calls
- Hidden complexity makes debugging harder
- Requires environment secrets even for read-only validation
- More abstraction does not equal better in this case

The solution uses inline steps with matrix:

```yaml
jobs:
  static-validation:
    # Inline steps - simple, fast, visible
    
  plan-environments:
    strategy:
      matrix:
        environment: [dev, tst]  # Runs all environments in parallel
```

### Architecture: Two-Stage PR Flow

```text
┌────────────────────────────────────────────────┐
│ Stage 1: Static Validation                    │
│ • No Azure auth required                       │
│ • No tfvars needed                            │
│ • Fast (< 2 minutes)                          │
│ • Auto-runs on every PR                       │
│ • Inline steps for maximum visibility         │
└────────────────────────────────────────────────┘
                    ↓
                 (if pass)
                    ↓
┌────────────────────────────────────────────────┐
│ Stage 2: Environment Plans (Matrix)            │
│ • Pauses for approval via environment rules    │
│ • Runs ALL environments in parallel           │
│ • Single approval → all plans execute         │
│ • Matrix: [dev, tst, uat, prod, ...]         │
│ • Inline steps with matrix strategy           │
└────────────────────────────────────────────────┘
```

### When to Use Templates vs Inline

| Use Case | Approach | Rationale |
|----------|----------|-----------|
| PR Validation | Inline + Matrix | Simple, visible, parallelizable |
| Terraform Apply | Template | Complex state management, locking needed |
| Terraform Destroy | Template | High-risk operation needs consistent logic |
| Backend Setup | Template | Reusable across multiple projects |

### Benefits of This Approach

#### True Multi-Environment Validation

```yaml
strategy:
  matrix:
    environment: [dev, tst]
```

Benefits:

- ALL environments validated with single approval
- Runs in parallel (faster)
- Easy to add/remove environments

#### Zero Manual Overhead

- No labels to manage
- No per-environment workflow files
- No separate approvals per environment
- Just create PR, review, approve once

#### Complete Visibility

- Entire PR workflow logic in ONE file
- No hidden abstraction layers
- Easy to customize per project
- Simpler debugging

#### Scales Effortlessly

- Adding environment: Change 1 line in matrix
- Old approach: Create new workflow file + secrets + labels

### Comparison: Old vs New

#### Old Approach (Label-Based, Per-Environment)

```text
.github/workflows/
├── terraform-ci-validation.yml   # Static checks
├── terraform-ci-dev.yml           # Dev plan (label: run-plan-dev)
├── terraform-ci-tst.yml           # Tst plan (label: run-plan-tst)
├── terraform-ci-uat.yml           # UAT plan (label: run-plan-uat)
└── terraform-ci-prod.yml          # Prod plan (label: run-plan-prod)
```

Issues:

- 5 workflow files
- Manual label management
- No parallelization
- Separate approvals
- Complex to maintain

#### New Approach (Matrix-Based, Single File)

```text
.github/workflows/
├── terraform-pr.yml        # Static + ALL environments (matrix)
└── terraform-deploy.yml    # Deployment (uses template)
```

Benefits:

- 2 workflow files
- Zero manual steps
- Full parallelization
- Single approval gate
- Simple to maintain

### Environment Protection Rules

The approval gate works via GitHub Environment protection:

```yaml
environment: ${{ matrix.environment }}-iac-plan
```

How it works:

1. PR created and static validation runs automatically
2. Workflow reaches matrix job and pauses for approval
3. Reviewer sees: "Approval required for dev-iac-plan, tst-iac-plan"
4. Approve once and ALL environment plans execute in parallel
5. Results posted to PR

Configuration:

- Create environments: `dev-iac-plan`, `tst-iac-plan`, etc.
- Add required reviewers (optional but recommended)
- Secrets configured per environment

### Cost Optimization

Old approach problems:

- Need to trigger each environment separately
- Duplicate API calls for static validation
- Secrets accessed multiple times

New approach benefits:

- Static validation runs once
- Azure auth happens only for plan stage
- Parallel execution reduces wait time
- Single approval reduces friction

### Adding New Environments

Old way:

1. Copy `terraform-ci-dev.yml` to `terraform-ci-staging.yml`
2. Update environment references (3-5 places)
3. Create new GitHub environment
4. Configure secrets
5. Document the new label
6. Update README

New way:

1. Add `staging` to matrix array
2. Create GitHub environment
3. Configure secrets

Done.

### Testing Strategy

Static validation (no auth):

- Format checking
- Syntax validation
- TFLint rules
- Checkov security scan

Environment plans (with auth):

- Full terraform plan
- Resource change preview
- Cost implications (if integrated)
- Posted to PR for review

### Trade-offs and Considerations

Pros:

- Simpler mental model
- Less YAML to maintain
- Faster execution (parallel)
- Better visibility
- Easier to customize
- Standard GitHub features

Cons:

- Cannot easily share PR validation logic across multiple repos
  - Mitigation: Template this starter repo itself
- Changes to PR flow require editing consuming repo
  - Mitigation: Rare, and easier to understand when needed
- Each repo has full workflow definition
  - Mitigation: Better for debugging and customization

### When to Use Centralized Templates

Keep using templates for:

- Deployment operations (terraform apply/destroy)
- Backend management (state storage setup)
- Complex multi-step processes (blue/green deployments)
- Organizational policies (must use central audit logic)

Do not use templates for:

- PR validation (simple, read-only, project-specific)
- Static analysis (no state, no side effects)
- One-off workflows (too simple to abstract)

## Migration Path

If you have existing per-environment workflows:

1. Backup existing workflows
2. Create new `terraform-pr.yml` with matrix
3. Test on feature branch
4. Delete old per-environment workflows
5. Update documentation

## Future Enhancements

Potential additions to this approach:

1. Conditional matrix - Skip certain environments based on file changes
2. Cost estimation - Integrate Infracost for cost preview
3. Policy as Code - Add OPA/Sentinel validation
4. Drift detection - Schedule plans to detect configuration drift

## Summary

This design prioritizes:

- Simplicity over abstraction
- Visibility over hiding complexity
- Automation over manual steps
- Standard patterns over custom solutions

The result is a CI/CD flow that is easier to understand, faster to execute, and simpler to maintain.
