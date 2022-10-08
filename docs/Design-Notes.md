## Azure service principal setup

For a lab environment, 'New-ServicePrincipal.ps1', will create a resource group (RG) for your deployment & the service principal scoped to this RG.

In a corporate, it is assumed that another party will pre-create a service principal and apply permissions to the resource group.

## Secrets management

Terraform code must not contain sensitive variables.

Excluding the terraform service principal, secrets are to be sourced from KeyVault **only**.  

### Source the terraform service principal from an Azure DevOps (ADO) service connection.

The pipeline task [terraform_creds_task.yml](/pipelines/tasks/terraform_creds_task.yml) uses AzCli to authenticate using the ADO service connection.  This provides the following benefits:

* The ADO service connection could be made by the same person who creates the services principal which would make it unnecessary to share the service principal secret.
* Sourcing the service principal details from the ADO service connection avoids the bootstrap problem for KeyVault.
* If provided permissions, the pipeline can initialise the remote state (particularly useful in a lab).

### Antipattern - avoid the use of DevOps variable groups.

Secret variables linked to a KeyVault would be acceptable, but are not used because this requires more effort to bootstrap compared to the approach taken.

Variables groups not linked to a KeyVault should be avoided as changes to them can not be audited.

Non-sensitive environment-specific variables are stored in the code for similar reasons (see next section)

## Environment-specific variables

The environments folder uses '.tfvars', each environment uses two files for storing non-sensitive variables:
* a <env>.terraform.tfvars file
* a global.terraform.tfvars

The latter is for settings that are generic across all environments but which still should be parameterised.

Note that "auto.tfvars" are not used to explictly source the correct environment details.  The following example shows how these are referenced in the pipeline:

```PowerShell
terraform plan -input=false -out=tfplan `
   -var-file="./environments/dev.terraform.tfvars" `
   -var-file="./environments/global.terraform.tfvars"
```

## Everything CLI is PowerShell

Sample documentation often mixes up AZ CLI, Bash and PowerShell.  In most cases everything herein is PowerShell.

## Updating Terraform versions

Main.tf includes logic to pin to a specific version of Terraform and providers in use (AzureRM, AzureAD & random).

To update these locally you need to use **terraform -init -upgrade**