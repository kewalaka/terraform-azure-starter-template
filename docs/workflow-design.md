# Workflow Design

Keep it small and fast. One PR workflow validates, then optionally plans all environments in parallel. Plans run automatically by default, with optional approval gate using PR labels. Deployment stays in a separate workflow that uses a shared template.

## PR workflow

- Stage 1: Static validation (no Azure auth)
  - terraform fmt (check), init -backend=false, validate, TFLint, Checkov
- Stage 1.5: Manual approval (optional, using marketplace action)
  - Only runs if `require-approval` label is present on PR
  - Creates a GitHub issue requiring approval before proceeding
  - Single approval gates all environment plans
- Stage 2: Plan (matrix, optional)
  - Runs by default after validation passes
  - Skipped if `skip-plan` label is present on PR
  - matrix: [dev, …]
  - environment: `${{ matrix.environment }}-iac-plan` (for secrets only, no approval required)
  - posts a summarized plan and full plan as a PR comment

## Label-based control

Use PR labels to control workflow behavior:

- **No label** (default): Static validation → Plan immediately
- **`require-approval`**: Static validation → Manual approval → Plan
- **`skip-plan`**: Static validation only, no plan
- **Both labels**: Static validation → Manual approval → No plan

## Add an environment

1. Create GitHub Environment: `<env>-iac-plan` and configure required secrets (no reviewers needed).
2. Create GitHub Environment: `<env>-iac-apply` and configure required secrets with reviewers for deployment protection.
3. Add tfvars file: `iac/environments/<env>.terraform.tfvars`.
4. Append `<env>` to the matrix in `.github/workflows/terraform-pr.yml`.

That's it—by default plans execute immediately after validation. Add `require-approval` label if you need manual approval before plans run.

## Why this approach

- Fast by default: Plans run automatically after validation
- Flexible approval: Add `require-approval` label when needed
- Optional skip: Add `skip-plan` label to skip plan stage
- Avoids double approvals during deployment (no approval for plan, only for apply)
- Parallel execution with environment-scoped secrets
- Inline steps for visibility and simpler debugging
- Environment protection only used for deployment apply stage

## When to use templates

- Use shared templates for apply/destroy and backend setup.
- Keep PR validation inline (project-specific, read-only).
