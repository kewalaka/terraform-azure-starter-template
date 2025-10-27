# Workflow Design

Keep it small and fast. One PR workflow validates, then optionally plans all environments in parallel. Plans run automatically by default. Deployment stays in a separate workflow that uses a shared template.

## PR workflow

- Stage 1: Static validation (no Azure auth)
  - terraform fmt (check), init -backend=false, validate, TFLint, Checkov
- Stage 1.5: Manual approval (optional)
  - Only runs if `TFPLAN_PR_APPROVAL_REQUIRED` variable set to `true`
  - Uses `trstringer/manual-approval` marketplace action
  - Single approval gates all environment plans
- Stage 2: Plan (matrix, optional)
  - Runs by default after validation passes
  - Skipped if `TFPLAN_SKIP_ON_PR` variable set to `true`
  - matrix: [dev, …]
  - environment: `${{ matrix.environment }}-iac-plan` (for secrets only, no approval required)
  - posts summarized plan and full plan as PR comment

## Deploy workflow

- Stage 1: Plan (no approval)
  - Uses environment `<env>-iac-plan` for secrets
- Stage 2: Apply (environment protection approval)
  - Uses environment `<env>-iac-apply` with required reviewers
  - Approval gate enforced by GitHub environment protection

## Add an environment

1. Create GitHub Environment: `<env>-iac-plan` and configure required secrets (no reviewers needed)
2. Create GitHub Environment: `<env>-iac-apply` and configure required secrets with reviewers for deployment protection
3. Add tfvars file: `iac/environments/<env>.terraform.tfvars`
4. Append `<env>` to the matrix in `.github/workflows/terraform-pr.yml`

## Why this approach

- Fast by default: Plans run automatically after validation on PRs
- Avoids double approvals during deployment (no approval for plan, only for apply)
- Parallel execution with environment-scoped secrets
- Inline steps for visibility and simpler debugging
- Environment protection only used for deployment apply stage

## When to use templates

- Use shared templates for apply/destroy and backend setup
- Keep PR validation inline (project-specific, read-only)
