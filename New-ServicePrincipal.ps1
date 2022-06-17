<#

First time Azure setup

This follows a typical pattern seen in enterprises, where a service principal for DevOps is created and scope to a resource group.

Instructions
------------

1) Under the "environments" folder, create a file called **secrets.local.ps1**.  
This file exists in gitignore, please check it is greyed out and is not included with git changes.

2) Populate that file with the following obtained from Azure.

$env:ARM_TENANT_ID ='<tenantid>'
$env:ARM_SUBSCRIPTION_ID = '<subscriptionId>'

3) Set the parameters (service provider & resource group)

4) Run this code.

5) Update your secrets file with the client Id & secret

#>

# Variables
# choose names for the service provider & resource group
$servicePrincipalDisplayName = 'sp_ADO_Terraform_CICD_YAMLTemplates'
$resource_group_name = 'rg-terraform-playground'
$location = 'AustraliaEast'
$TerraformNeedsToSetRBAC = $true

$subscription_id = $env:ARM_SUBSCRIPTION_ID
Import-module Az
$connection = Connect-AzAccount -Tenant $env:ARM_TENANT_ID -Subscription $subscription_id
if ($connection) {
    # create resource group
    try {
        $rg = (Get-AzResourceGroup -Name $resource_group_name -location $location -ErrorAction SilentlyContinue).resourceid
    }
    catch {}
    if ($null -eq $rg) {
        Write-Host "Creating resource group: $resource_group_name"
        New-AzResourceGroup -Name $resource_group_name -location $location
    }

    $params = @{
        DisplayName = $servicePrincipalDisplayName
        Scope       = "/subscriptions/$subscription_id/resourceGroups/$resource_group_name"
        Role        = 'Contributor'
    }
    $sp = New-AzAdServicePrincipal @params

    if ($TerraformNeedsToSetRBAC) {
        # add user access administrator if Terraform is going to be setting access permissions
        New-AzRoleAssignment -ObjectId $sp.Id -Scope $params.Scope -RoleDefinitionName 'User Access Administrator'
    }

    $env:ARM_CLIENT_ID = $sp.ApplicationId
    $env:ARM_CLIENT_SECRET = $sp.Secret | ConvertFrom-SecureString -AsPlainText
    Write-Host "Service principal $servicePrincipalDisplayName created"
    Write-Host @"
If you're intending to develop locally, add the following to secrets.local.ps1:

`$env:ARM_CLIENT_ID       = `'$($sp.ApplicationId)`'
`$env:ARM_CLIENT_SECRET   = `'$($sp.Secret | ConvertFrom-SecureString -AsPlainText)`'
"@
}
else {
    Write-Warning ("A connection to Azure could not be made: {0}" -f $_.Exception)
}
