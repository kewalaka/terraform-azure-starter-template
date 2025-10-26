# Using Azure Developer CLI (azd)

A fast local workflow for this Terraform template using azd as a helper. CI/CD stays in GitHub Actions; azd is optional for local provisioning.

## Prerequisites

- Azure CLI and azd installed
- Access to the remote state storage (Storage Blob Data Contributor on the state account)
- Logged in with Azure CLI: `az login`

## One-time setup

- Ensure environment tfvars exist under `iac/environments/` (e.g., `dev.terraform.tfvars`, `prod.terraform.tfvars`). These hold non-secret parameters for each environment.
- `azure.yaml` is already configured to use Terraform under `iac/` and to copy the matching env tfvars to `iac/terraform.tfvars` before provisioning.

## Quick start

From the repository root:

```bash
# 1) Select or create an azd environment (maps to a set of tfvars)
cd terraform-azure-starter-template
azd env new dev --subscription <SUBSCRIPTION_ID> --location <AZURE_REGION>

# 2) Provision infrastructure via Terraform
#    This uses the current Azure CLI login by default
azd provision

# Optional: combined provision + (no app) deploy flow
# azd up
```

Notes:

- The pre-provision hook copies `iac/environments/${AZURE_ENV_NAME}.terraform.tfvars` to `iac/terraform.tfvars` for you. That file is git-ignored.
- Backend config is injected by azd using `iac/provider.conf.json`; `backend.tf` is already compatible.

## Identity used by Terraform

- By default, Terraform runs as your current Azure CLI identity (the result of `az login`).
- To run as a service principal, export the following before running azd:

```bash
export ARM_CLIENT_ID=<APP_ID>
export ARM_TENANT_ID=<TENANT_ID>
export ARM_CLIENT_SECRET=<SECRET>
export ARM_SUBSCRIPTION_ID=<SUBSCRIPTION_ID>
```

## Troubleshooting

- Authorization error on state or plan:
  - Confirm you are logged in: `az account show`
  - Ensure your identity has Storage Blob Data Contributor on the state account and appropriate RBAC on target subscription/resource group.
- Wrong environment values applied:
  - Check that `AZURE_ENV_NAME` matches a file in `iac/environments/` and that `iac/terraform.tfvars` was generated.
- Backend subscription differs from target subscription:
  - Add the state subscription ID to `iac/provider.conf.json` (e.g., `subscription_id`) and set it in your azd environment.

## Clean up

If you want to remove provisioned resources from this environment:

```bash
azd down
```

This runs Terraform destroy using the same identity and backend.
