# Azure managed identity setup

For a lab environment, 'New-TerraformEnvironment.ps1', will create a resource group, storage account & a managed identity, along with appropriate permissions.

This uses federated workload identity.

## Secrets management

Terraform code must not contain sensitive variables.

Excluding the terraform service principal, secrets are to be sourced from KeyVault **only**.  

### Antipattern - avoid the use of DevOps variable groups

Variables groups not linked to a KeyVault should be avoided as changes to them can not be audited.

Secret variables linked to a KeyVault would be acceptable, but are not used because this requires more effort to bootstrap compared to the approach taken.

Non-sensitive environment-specific variables are stored in the code for similar reasons (see next section)

## Environment-specific variables

The environments folder uses '.tfvars', each environment uses a file for storing non-sensitive variables, e.g.:

* a ```<env>.terraform.tfvars``` file

The latter is for settings that are generic across all environments but which still should be parameterised.

Note that "auto.tfvars" are not used to explictly source the correct environment details.  The following example shows how these are referenced in the pipeline:

```PowerShell
terraform plan -input=false -out=tfplan `
   -var-file="./environments/dev.terraform.tfvars"
```

This approach is not-dissimiliar to Terraform workspaces (on purpose), and helps to keep the code more [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)

## Everything CLI is PowerShell

Sample documentation often mixes up AZ CLI, Bash and PowerShell.  In most cases everything herein is PowerShell.

## Updating Terraform versions

Main.tf includes logic to pin to a specific version of Terraform and providers in use (AzureRM, AzureAD & random).

To update these locally you need to use **terraform -init -upgrade**
