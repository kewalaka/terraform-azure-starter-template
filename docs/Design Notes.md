## Azure service principal setup

For a lab environment, 'New-ServicePrincipal.ps1', will create a resource group (RG) for your deployment & the service principal scoped to this RG.

In a corporate, it is assumed that another party will pre-create a service principal and apply permissions to the resource group.

## Secrets management

Secrets are to be sourced from KeyVault **only**.  Terraform code must not contain sensitive variables.

### Secrets for the Terraform remote state (AzureRM backend)

The pipeline task **terraform_creds_task.yml** uses AzCli to authenticate using the DevOps service connection.

The Azure DevOps service connection could be made by the same person who creates the services principal which would make it unnecessary to share the service principal secret.

This allows the Terraform state parameters to be sourced and stored for subsequent pipeline tasks without requiring additional infrastructure or configuration.


## Avoid the use of DevOps variable groups.

Rather than use "secret variables", the preferred pattern is to use an external vault (for Azure, typically KeyVault).

This allows their use & changes to be audited.

Environment specifics are stored in the code for similar reasons (see next section)

## Environment specifics

The environments folder uses '.tfvars', each environment uses two files:
* a <env>.terraform.tfvars file
* a global.terraform.tfvars

The latter is for settings that are generic across all environments but which still should be parameterised.

Note that "auto.tfvars" are not used to avoid accidentally sourcing the wrong environment details.

Within the pipeline, environment settings are quoted specifically, for example:

```PowerShell
terraform plan -input=false -out=tfplan `
   -var-file="./environments/dev.terraform.tfvars" `
   -var-file="./environments/global.terraform.tfvars"
```


## Updating Terraform versions

Main.tf includes logic to pin to a specific version of Terraform and providers in use (AzureRM, AzureAD & random).

To update these locally you need to use **terraform -init -upgrade**