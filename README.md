# Base Terraform Solution Template

A streamlined Terraform template for quickly provisioning Azure resources with GitHub-integrated deployments.

## Getting Started

This is designed to be used with [Az-Bootstrap](https://github.com/kewalaka/az-bootstrap)

Az-Bootstrap will create the deployment resource group, storage account for state, plan & apply identities.

To make the sample code work

1) Update the `app_name` in locals.tf to match the name of the repository.

1) Add the name of your CI runner to `.github\workflow\terraform-deploy.yml`

You should then be able to run the `Deploy Iac using Terraform` action on GitHub.

## CI/CD Workflows

This template uses a two-stage CI workflow pattern that separates fast validation from expensive terraform plans:

### Stage 1: Terraform Validation (Automatic & Fast)

The `terraform-ci-validation.yml` workflow runs automatically on all PRs that touch IaC files. It performs:
- **Terraform format checking** (`terraform fmt -check`)
- **Terraform validation** (`terraform validate`)
- **TFLint checks** for best practices and potential issues

This stage is fast (typically <1 minute) and requires no cloud access or authentication. Results are posted as a PR comment for quick review.

### Stage 2: Terraform Plan (Manual or Label-Triggered)

After validation passes and human/Copilot review, environment-specific terraform plans can be triggered:

**Per-environment workflows:**
- `terraform-ci-dev.yml` - Runs terraform plan for dev environment
- `terraform-ci-tst.yml` - Runs terraform plan for tst environment

**How to trigger:**
1. **Manual trigger**: Use the "Run workflow" button in GitHub Actions
2. **Label trigger**: Add label `run-plan-dev` or `run-plan-tst` to the PR

This two-stage approach ensures:
- ✅ Fast feedback on code quality and syntax
- ✅ Time for review before expensive cloud operations
- ✅ Explicit approval/trigger required for terraform plans
- ✅ No wasted cloud resources on invalid terraform code

### Terraform Deploy (Manual)

The `terraform-deploy.yml` workflow is manually triggered and allows you to:
- Choose the target environment (dev, tst, test, uat, or prod)
- Select the Terraform action (plan, apply, or destroy)
- Optionally destroy resources with confirmation

## Environments

This template demonstrates the pattern with two environments:
- `dev.terraform.tfvars` - Development environment
- `tst.terraform.tfvars` - Test environment

Additional environment files are included as examples:
- `test.terraform.tfvars` - Alternative test environment naming
- `uat.terraform.tfvars` - User Acceptance Testing environment
- `prod.terraform.tfvars` - Production environment

### Adding New Environments

For vending processes, new environments can be added by creating:
1. A new tfvars file (e.g., `iac/environments/stg.terraform.tfvars`)
2. A corresponding CI workflow file (e.g., `.github/workflows/terraform-ci-stg.yml`)

Both files can be managed as a single unit, with no need for complex matrix builds or dynamic environment detection.

### Alternatives to using runners

If you don't have any GitHub runners available, or don't want to use them, you can either:

- switch the Terraform Storage Account to allow public networking (check [.azbootstrap.jsonc](.azbootstrap.jsonc) for the details of the storage account)
- use the `unlock_resource_firewalls` action to dynamically unlock the firewall during CI runs - check the [README.md](https://github.com/kewalaka/github-azure-iac-templates/blob/main/.github/actions/azure-unlock-firewall/README.md) for details.
