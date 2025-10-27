# Workflow Design

Keep it small and fast. One PR workflow validates, then plans all environments in parallel, each gated by a single manual approval. Deployment stays in a separate workflow that uses a shared template.

## PR workflow

- Stage 1: Static validation (no Azure auth)
  - terraform fmt (check), init -backend=false, validate, TFLint, Checkov
- Stage 1.5: Manual approval (using marketplace action)
  - Creates a GitHub issue requiring approval before proceeding
  - Single approval gates all environment plans
- Stage 2: Plan (matrix)
  - matrix: [dev, …]
  - environment: `${{ matrix.environment }}-iac-plan` (for secrets only, no approval required)
  - posts a summarized plan and full plan as a PR comment

## Add an environment

1. Create GitHub Environment: `<env>-iac-plan` and configure required secrets (no reviewers needed).
2. Create GitHub Environment: `<env>-iac-apply` and configure required secrets with reviewers for deployment protection.
3. Add tfvars file: `iac/environments/<env>.terraform.tfvars`.
4. Append `<env>` to the matrix in `.github/workflows/terraform-pr.yml`.

That's it—the PR workflow will create a single approval issue, and after approval all environment plans execute in parallel.

## Why this approach

- Single approval for all PR plans using manual-approval marketplace action
- Avoids double approvals during deployment (no approval for plan, only for apply)
- Parallel execution with environment-scoped secrets
- Inline steps for visibility and simpler debugging
- Environment protection only used for deployment apply stage

## When to use templates

- Use shared templates for apply/destroy and backend setup.
- Keep PR validation inline (project-specific, read-only).
