# Introduction 

## Azure service principal setup

Check out 'New-ServicePrincipal.ps1', this code will create a resource group (RG) for your deployment & the service principal scoped to this RG.

## Set up local development environment

Under the "environments" folder, create a file called **secrets.local.ps1**.  This file exists in gitignore, please check it is greyed out and is not included with git changes.

Populate that file with the following:

```Powershell
#####
# Each time you restart VSCode you'll need to run this to create these environment vars
#
$env:ARM_TENANT_ID ='<tenantid>'
$env:ARM_CLIENT_ID = '<devops service principal appId>'
$env:ARM_CLIENT_SECRET = '<devops service principal secret'
$env:ARM_SUBSCRIPTION_ID = '<subscriptionId>'
```

Next, after cloning the repository, from the root folder, initialise Terraform.  This is one time operation that only needs repeating when you need to update Terraform or Terraform provider versions.

```PowerShell
# example for dev
# - the storage account and resource group is environment specific
terraform init -reconfigure `
    -backend-config="container_name=terraform" `
    -backend-config="storage_account_name=uocstdataplatformdev" `
    -backend-config="resource_group_name=rg-dataplatform-dev-eastau-001"
```

From that point on you can run the following to validate and run plans:

```Powershell
# this will return 'Success' or indicate errors
terraform validate
# this will run tf plan from your workstation
terraform plan -input=false -out=tfplan `
   -var-file="./environments/dev.terraform.settings" `
   -var-file="./environments/global.settings"
```

Use of ```terraform apply``` must be via a DevOps pipeline.

Before you commit code to the repository, check it is formated correctly:

```Powershell
# run this from the root of the repository
terraform fmt -recursive 
```

## Secrets management

Secrets are to be sourced from KeyVault **only**.  Terrafrom code must not contain sensitive variables.

### Secrets for the Terraform remote state (AzureRM backend)

The pipeline task **terraform_creds_task.yml** uses AzCli to authenticate using the DevOps service connection.

This allows the Terraform state parameters to be sourced and stored for subsequent pipeline tasks without requiring additional infrastructure or configuration.

## Environment specifics

The environments folder uses '.settings', each environment uses two files:
* a <env>.terraform.settings file
* a global.settings

The latter is for settings that are generic across all environments but which still should be parameterised.

A '.settings' file is used to avoid accidently sourcing tfvar files, and also by default tfvar files are in gitignore.


## Updating Terraform versions

Main.tf includes logic to pin to a specific version of Terraform and providers in use (AzureRM & AzureAD).