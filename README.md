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

This template uses a simple per-environment CI workflow pattern:

### Terraform CI (Pull Requests)

Each environment has its own dedicated CI workflow (e.g., `terraform-ci-dev.yml`, `terraform-ci-tst.yml`) that automatically runs terraform plan when:
- The environment's specific tfvars file changes (e.g., `iac/environments/dev.terraform.tfvars`)
- Any IaC files change (e.g., `iac/**/*.tf`, `iac/**/*.hcl`)

**Example environments:**
- `terraform-ci-dev.yml` - Runs plan for dev environment
- `terraform-ci-tst.yml` - Runs plan for tst (test) environment

This pattern is ideal for vending processes where new environments can be added by simply:
1. Creating a new tfvars file (e.g., `iac/environments/stg.terraform.tfvars`)
2. Creating a corresponding CI workflow file (e.g., `.github/workflows/terraform-ci-stg.yml`)

The vending process can manage both files as a single unit, eliminating the need for complex matrix builds or dynamic environment detection.

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

### Alternatives to using runners

If you don't have any GitHub runners available, or don't want to use them, you can either:

- switch the Terraform Storage Account to allow public networking (check [.azbootstrap.jsonc](.azbootstrap.jsonc) for the details of the storage account)
- use the `unlock_resource_firewalls` action to dynamically unlock the firewall during CI runs - check the [README.md](https://github.com/kewalaka/github-azure-iac-templates/blob/main/.github/actions/azure-unlock-firewall/README.md) for details.
