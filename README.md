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

This template includes two GitHub Actions workflows:

### Terraform CI (Pull Requests)

The `terraform-ci.yml` workflow automatically runs on pull requests when IaC files change. It intelligently determines which environments to test:

- **IaC changes** (e.g., `iac/*.tf`, `iac/*.hcl`): Runs terraform plan for **all environments** (dev, test, uat, prod)
- **Environment-specific changes** (e.g., `iac/environments/dev.terraform.tfvars`): Runs terraform plan for **only the affected environment(s)**
- **Mixed changes**: If both IaC and tfvars files change, runs terraform plan for all environments

This approach ensures thorough testing while minimizing unnecessary plan runs.

### Terraform Deploy (Manual)

The `terraform-deploy.yml` workflow is manually triggered and allows you to:
- Choose the target environment (dev, test, uat, or prod)
- Select the Terraform action (plan, apply, or destroy)
- Optionally destroy resources with confirmation

## Environments

This template supports four environments, each with its own tfvars file in `iac/environments/`:
- `dev.terraform.tfvars` - Development environment
- `test.terraform.tfvars` - Testing environment
- `uat.terraform.tfvars` - User Acceptance Testing environment
- `prod.terraform.tfvars` - Production environment

### Alternatives to using runners

If you don't have any GitHub runners available, or don't want to use them, you can either:

- switch the Terraform Storage Account to allow public networking (check [.azbootstrap.jsonc](.azbootstrap.jsonc) for the details of the storage account)
- use the `unlock_resource_firewalls` action to dynamically unlock the firewall during CI runs - check the [README.md](https://github.com/kewalaka/github-azure-iac-templates/blob/main/.github/actions/azure-unlock-firewall/README.md) for details.
