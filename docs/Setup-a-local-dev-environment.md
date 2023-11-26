# Set up local development environment

## Why

A local development environment allows you to test changes before committing them to a repository.

It is still considered good practice to commit often, this provides more visibility to collaborators,
and smaller more frequent changes are typically easier to review and rollback from.

## How

Under the "environments" folder, create a file called **secrets.local.ps1**.  This file is referenced in the gitignore file to ensure it is not committed to the repository.

Populate this file with the following, substituting with the actual values for your target environment:

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
    -backend-config="storage_account_name=sttfstuff023" `
    -backend-config="resource_group_name=rg-terraform-playground"
```

From that point on you can run the following to validate and run plans:

```Powershell
# this will return 'Success' or indicate errors
terraform validate
# this will run tf plan from your workstation
terraform plan -input=false -out=tfplan `
   -var-file="./environments/dev.terraform.tfvars" `
```

Use of ```terraform apply``` must be via a DevOps pipeline.

Before you commit code to the repository, check it is formatted correctly:

```Powershell
# run this from the root of the repository
terraform fmt -recursive 
```

## Design considerations

When creating pipeline, try to mimic tasks that can be repeated on the local development machine.

As an example, use powershell or bash rather than components from the Visual Studio Marketplace
such as 'Terraform'.

This serves two purposes:

1) it makes it easier to troubleshoot the activities a pipeline is carrying out, and
2) it makes it easier test changes locally prior to committing them.
