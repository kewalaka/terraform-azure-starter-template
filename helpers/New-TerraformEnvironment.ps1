<#

1) Under the root folder, create a file called **secrets.ps1**.  
This file exists in gitignore, please check it is greyed out and is not included with git changes.

2) Populate that file with the following obtained from Azure.

$env:ARM_TENANT_ID ='<tenantid>'
$env:ARM_SUBSCRIPTION_ID = '<subscriptionId>'

3) Set the parameters (service provider & resource group)

4) Run this code.

5) Update your secrets file with the client Id & secret

# the account that runs this script needs the following permissions:
    - Either Owner, or Contributor & User Access Administrator, on the target subscription
    - Permission to create service principals in Azure AD (e.g. the Application Administrator role)

#>

# -------------------------------------------------
# Start of customisations
#
$appname = 'keyvaultavm'
$env_code = 'dev'
$location = 'AustraliaEast'
$short_location_code = 'auea'
$tags = @{
    Company = "kewalaka"
    Project = "$appname project"
}

# does the service principal need to be able to set permissions on objects
$TerraformNeedsToSetRBAC = $true

# these depend on whether you are in a lab or a real environment
$shouldSetStorageFirewall = $false
$shouldCreateResourceLock = $false
$shouldAllowPermanentDeletion = $true # whether soft deleted blobs can be permanently deleted
$StorageBlobDeleteRetentionPolicyInDays = 1
$deletePreviousVersionsOlderThanDays = 1

# these can be tuned if needed but the defaults are fine too.
$managedIdentityName = ("id-AzDO-{0}-{1}" -f $appname, $env_code)
$resource_group_name = ("rg-{0}-{1}-{2}" -f $appname, $env_code, $short_location_code)
$storage_account_resource_group_name = $resource_group_name
$storage_account_subscription = $env:ARM_SUBSCRIPTION_ID
$storage_account_name = ("sttf{0}{1}{2}" -f $appname, $env_code, $short_location_code)
$container_name = 'tfstate'
$storageSKU = 'Standard_LRS'
#
# End of customisations
# -------------------------------------------------

Update-AzConfig -Scope Process -DisplayBreakingChangeWarning $false | Out-Null
if ($null -eq $env:ARM_TENANT_ID -or $null -eq $env:ARM_SUBSCRIPTION_ID) {
    Write-Warning "Please set the ARM_TENANT_ID and ARM_SUBSCRIPTION_ID environment variables"
    Write-Host @"

e.g.:
`$env:ARM_TENANT_ID = '0000000-0000-0000-0000-000000000000'
`$env:ARM_SUBSCRIPTION_ID = '0000000-0000-0000-0000-000000000000'

"@
    return
}

if ($storage_account_name.Length -gt 24) {
    Write-Warning ("Storage account name '$storage_account_name' must be <=24 characters but is currently {0}." -f $storage_account_name.Length)
    return
}

$subscription_id = $env:ARM_SUBSCRIPTION_ID
Import-module Az.Storage
$connection = Connect-AzAccount -Tenant $env:ARM_TENANT_ID -Subscription $subscription_id

if ($connection) {
    Set-AzContext -SubscriptionId $env:ARM_SUBSCRIPTION_ID

    $availabilityResult = Get-AzStorageAccountNameAvailability -Name $storage_account_name

    if ($availabilityResult.NameAvailable) {
        Write-Host "The storage account name '$storage_account_name' is available."
    }
    else {
        Write-Warning "The storage account name '$storage_account_name' is not available. Reason: $($availabilityResult.Message)"
    }

    # create resource group
    try {
        $rg = (Get-AzResourceGroup -Name $resource_group_name -location $location -ErrorAction SilentlyContinue).resourceid
    }
    catch {}
    if ($null -eq $rg) {
        Write-Host "Creating resource group: $resource_group_name"
        New-AzResourceGroup -Name $resource_group_name -location $location -tags $Tags
    }

    # create the managed identity
    $params = @{
        Name              = $managedIdentityName
        ResourceGroupName = $resource_group_name
        Location          = $location
        SubscriptionId    = $subscription_id
    }
    $uaid = New-AzUserAssignedIdentity @params
    Write-Host "User assigned managed identity '$managedIdentityName' created"

    $scope = "/subscriptions/$subscription_id/resourceGroups/$resource_group_name"
    New-AzRoleAssignment -ObjectId $uaid.PrincipalId -Scope $scope -RoleDefinitionName 'Contributor' | Out-Null
    Write-Host "Contributor granted to managed identity '$managedIdentityName' at scope '$scope'"

    # if Terraform is going to be setting permissions (IAM), add the User Access Administrator role
    if ($TerraformNeedsToSetRBAC) {
        New-AzRoleAssignment -ObjectId $uaid.PrincipalId -Scope $scope -RoleDefinitionName 'User Access Administrator' | Out-Null
        Write-Host "User Access Administrator granted to managed identity '$managedIdentityName' at scope '$scope'"        
    }

    ## TODO pass in DevOps Org issuer token GUID, org name & project name then can set up federated credential.

    # Create storage account
    # create resource group
    if ($storage_account_subscription -ne $env:ARM_SUBSCRIPTION_ID) {
        Write-Host "Changing subscription to $storage_account_subscription for storage account creation."
        Set-AzContext -SubscriptionName $storage_account_subscription
    }
    $tags += @{ Purpose = "Terraform State" }
    try {
        $rg = Get-AzResourceGroup -Name $storage_account_resource_group_name -ErrorAction SilentlyContinue
    }
    catch {}
    if ($null -eq $rg) {
        Write-Host "Creating storage account resource group: $storage_account_resource_group_name in location $location"
        try {
            $rg = New-AzResourceGroup -Name $storage_account_resource_group_name -location $location -Tags $tags
        }
        catch {
            throw ("Can't create resource group - {0}" -f $_.Exception)
        }
    }
    else {
        Write-Host "Using existing storage account resource group: $storage_account_resource_group_name"
    }

    try {
        $sa = Get-AzStorageAccount -resourcegroup $storage_account_resource_group_name -name $storage_account_name -ErrorAction SilentlyContinue
    }
    catch {}
    if ($null -eq $sa) {
        Write-Host "Creating storage account: $storage_account_name"
        try {
            $params = @{
                ResourceGroupName      = $storage_account_resource_group_name
                Name                   = $storage_account_name
                Location               = $location
                SkuName                = $storageSKU
                Kind                   = 'BlobStorage'
                AccessTier             = 'Hot'
                EnableHttpsTrafficOnly = $true
                EnableLocalUser        = $false
                EnableNfsV3            = $false
                EnableSftp             = $false
                AllowBlobPublicAccess  = $false
                AllowSharedKeyAccess   = $true # this will be set to 'false' at the end after the necessary container & permissions are set.
                MinimumTlsVersion      = 'TLS1_2'
                Tag                    = $tags
            }
            $sa = New-AzStorageAccount @params
        }
        catch {
            throw ("Can't create storage account - {0}" -f $_.Exception)
        }
    }
    else {
        Write-Host "Using existing storage account: $storage_account_name"
    }

    # Enable versioning (required for immutability lock)
    $params = @{    
        ResourceGroupName  = $storage_account_resource_group_name
        StorageAccountName = $storage_account_name
    }
    Update-AzStorageBlobServiceProperty @params -IsVersioningEnabled $true -EnableChangeFeed $true | Out-Null
    Enable-AzStorageBlobDeleteRetentionPolicy @params -RetentionDays $StorageBlobDeleteRetentionPolicyInDays -AllowPermanentDelete:$shouldAllowPermanentDeletion | Out-Null
   
    # enable this for lifecycle management (aging out old versions)
    Enable-AzStorageBlobLastAccessTimeTracking  @params -PassThru | Out-Null
    $action = Add-AzStorageAccountManagementPolicyAction -BlobVersionAction Delete -DaysAfterCreationGreaterThan $deletePreviousVersionsOlderThanDays
    $filter = New-AzStorageAccountManagementPolicyFilter -BlobType blockBlob
    $rule = New-AzStorageAccountManagementPolicyRule -Name rule-delete-older-versions -Action $action -Filter $filter
    Set-AzStorageAccountManagementPolicy @params -Rule $rule | Out-Null

    $account_key = (Get-AzStorageAccountKey -ResourceGroupName $storage_account_resource_group_name -Name $sa.StorageAccountName)[0].Value
    $sac = New-AzStorageContext -StorageAccountName $storage_account_name  -StorageAccountKey $account_key # -UseConnectedAccount can't be used until access is set.
    # create container
    if ($null -eq (Get-AzstorageContainer -context $sac | Where-Object Name -eq $container_name)) {
        Write-Host "Creating storage container: $container_name"
        try {
            New-AzStorageContainer -name $container_name -Context $sac
        }
        catch {
            throw ("Can't create storage container - {0}" -f $_.Exception)
        }
    }
    else {
        Write-Host "Using existing storage container: $container_name"
    }

    # apply SP permissions to the container
    $scope = "$($sa.Id)/blobServices/default/containers/$container_name"
    Write-Host "Add Storage Blob Data Contributor role assignment for $managedIdentityName at scope $scope"
    New-AzRoleAssignment -ObjectId $uaid.PrincipalId -Scope $scope -RoleDefinitionName 'Storage Blob Data Contributor' | Out-Null

    # turn off access via shared keys
    $params = @{
        ResourceGroupName    = $storage_account_resource_group_name
        Name                 = $storage_account_name
        # requires setting 'use_azuread_auth = true' in the backend provider
        AllowSharedKeyAccess = $false
    }
    Set-AzStorageAccount @params | Out-Null

    if ($shouldSetStorageFirewall) {
        # The actual permission required is 'Microsoft.Storage/storageAccounts/write', but this is the closest built-in role.
        Write-Host "Grant the service principal Storage Account Contributor role assignment to be able to set the storage account firewall rules. "
        New-AzRoleAssignment -ObjectId $adsp.Id -Scope $sa.id -RoleDefinitionName 'Storage Account Contributor' | Out-Null
        Write-Host "Setting the 'Deny' default action on the storage account firewall '$storage_account_name'."
        Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $storage_account_resource_group_name -Name $storage_account_name -DefaultAction Deny -Bypass None | Out-Null
    } 

    if ($shouldCreateResourceLock) {
        Write-Host "Creating CanNotDelete resource lock for storage account '$storage_account_name'."
        $params = @{
            LockName          = "lck-$storage_account_name"
            LockLevel         = 'CanNotDelete'
            ResourceName      = $storage_account_name
            ResourceType      = 'Microsoft.Storage/storageAccounts'
            ResourceGroupName = $storage_account_resource_group_name
        }
        New-AzResourceLock @params -Force | Out-Null
    }

    Write-Host @"
`n
Process completed!

------------------
Service Connection
------------------

Here are the details for the service connection:

Subscription Id:             $($connection.context.subscription.id)
Subscription Name:           $($connection.context.subscription.name)
Service Principal Id:        $($uaid.ClientId)
Tenant Id:                   $($connection.context.tenant.id)
Suggested Name:              "azurerm-$($uaid.Name.ToLower())"
Suggested Description:       Azure Resource Manager Service Connection for Terraform to resource group $resource_group_name.

To adhere to least privilege, do not select "Grant access permission to all pipelines" when creating the service connection.

------------------
Pipeline Variables
------------------

Then, update the pipeline variables in /iac/pipelines/variables/dev.vars.yaml with:

variables:
  # this service connection is created in DevOps and used to authenticate to Azure
  azureSubscription: "azurerm-$($uaid.Name.ToLower())" # this is the AzureRM service connection to Azure
  # this is the location of the tfState file (AzureRM backend) in this environment
  tf-state-resource-group: "$storage_account_resource_group_name"
  tf-state-blob-account: "$storage_account_name"
  # these are the environment specific settings that relate to the infrastructure being deployed.  
  tf-var-file: "environments/$env_code.terraform.tfvars"

-------------------------------
Terraform environment variables
-------------------------------

Update the infrastructure variables in /iac/environments/$env_code.terraform.tfvars with:

short_appname = "$appname" # this is used for resource with a short length limit.
appname       = "$appname" # a longer name can optionally be used here.
env_code      = "$env_code"

..and update the tags as appropriate for your solution.

"@
    
}
else {
    Write-Warning ("A connection to Azure could not be made: {0}" -f $_.Exception)
}
