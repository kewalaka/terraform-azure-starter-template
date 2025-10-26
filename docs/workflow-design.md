# Workflow Design

Keep it small and fast. One PR workflow validates, then plans all environments in parallel, each gated by its own environment approval. Deployment stays in a separate workflow that uses a shared template.

## PR workflow

- Stage 1: Static validation (no Azure auth)
  - terraform fmt (check), init -backend=false, validate, TFLint, Checkov
- Stage 2: Plan (matrix) with environment protection
  - matrix: [dev, …]
  - environment: `${{ matrix.environment }}-iac-plan`
  - posts a summarized plan and full plan as a PR comment

## Add an environment

1. Create GitHub Environment: `<env>-iac-plan` and configure required secrets.
2. Add tfvars file: `iac/environments/<env>.terraform.tfvars`.
3. Append `<env>` to the matrix in `.github/workflows/terraform-pr.yml`.

That’s it—each plan runs after approval in its corresponding `<env>-iac-plan` environment, and plans execute in parallel.

## Why this approach

- Fewer files and no labels to manage
- Parallel execution with per-environment approvals
- Inline steps for visibility and simpler debugging

## When to use templates

- Use shared templates for apply/destroy and backend setup.
- Keep PR validation inline (project-specific, read-only).
