# Workflow Design

Keep it small and fast. One PR workflow validates, then optionally plans all environments in parallel. Plans run automatically by default, with optional approval gate using workflow inputs. Deployment stays in a separate workflow that uses a shared template.

## PR workflow

- Stage 1: Static validation (no Azure auth)
  - terraform fmt (check), init -backend=false, validate, TFLint, Checkov
- Stage 1.5: Manual approval (optional, using marketplace action)
  - Only runs if `require_approval` workflow input is true
  - Creates a GitHub issue requiring approval before proceeding
  - Single approval gates all environment plans
- Stage 2: Plan (matrix, optional)
  - Runs by default after validation passes for pull_request events
  - Skipped if `skip_plan` workflow input is true
  - matrix: [dev, …]
  - environment: `${{ matrix.environment }}-iac-plan` (for secrets only, no approval required)
  - posts a summarized plan and full plan as a PR comment

## Workflow input control

Control workflow behavior via inputs when manually triggering:

- **Auto (default for PRs)**: Static validation → Plan immediately
- **`require_approval: true`**: Static validation → Manual approval → Plan
- **`skip_plan: true`**: Static validation only, no plan
- **Both true**: Static validation → Manual approval → No plan

## Add an environment

1. Create GitHub Environment: `<env>-iac-plan` and configure required secrets (no reviewers needed).
2. Create GitHub Environment: `<env>-iac-apply` and configure required secrets with reviewers for deployment protection.
3. Add tfvars file: `iac/environments/<env>.terraform.tfvars`.
4. Append `<env>` to the matrix in `.github/workflows/terraform-pr.yml`.

That's it—by default plans execute immediately after validation on PRs. Manually trigger with `require_approval: true` if you need approval before plans run.

## Why this approach

- Fast by default: Plans run automatically after validation on PRs
- Flexible approval: Set `require_approval: true` when manually triggering
- Optional skip: Set `skip_plan: true` to skip plan stage
- Repository-level decision, not per-PR management
- Avoids double approvals during deployment (no approval for plan, only for apply)
- Parallel execution with environment-scoped secrets
- Inline steps for visibility and simpler debugging
- Environment protection only used for deployment apply stage

## When to use templates

- Use shared templates for apply/destroy and backend setup.
- Keep PR validation inline (project-specific, read-only).
