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
    - Either Owner, or Contributor & Role Based Access Control Administrator, on the target subscription
    - Permission to create service principals in Azure AD (e.g. the Application Administrator role)

#>

# -------------------------------------------------
# Start of customisations
#
$appname = 'appsample'
$env_code = 'dev'
$location = 'AustraliaEast'
$short_location_code = 'auea'
$tags = @{
    Company = "kewalaka"
    Project = "$appname project"
    Owner   = "kewalaka"
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


function Grant-RBACAdministratorRole {
    param(
        [string]$ObjectId,
        [string]$Scope,
        [string]$RoleDefinitionName,
        [string]$ManagedIdentityName
    )

    try {
        $ra = Get-AzRoleAssignment -ObjectId $ObjectId -Scope $Scope -RoleDefinitionName $RoleDefinitionName
    }
    catch {}
    if ($null -eq $ra) {
        New-AzRoleAssignment -ObjectId $ObjectId -Scope $Scope -RoleDefinitionName $RoleDefinitionName | Out-Null
        Write-Host "Role '$RoleDefinitionName' granted to managed identity '$ManagedIdentityName' at scope '$Scope'"
    }
    else {
        Write-Host "Role '$RoleDefinitionName' already exists for identity '$ManagedIdentityName' at scope '$Scope'"
    }
}

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
try {
    Import-Module Az.Accounts, Az.ManagedServiceIdentity, Az.Resources, Az.Storage
}
catch {
    Write-Warning "There was an issue importing required Az Modules, make sure your Az PowerShell modules are up to date: <https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell>"
    return
}

$connection = Connect-AzAccount -TenantId $env:ARM_TENANT_ID -Subscription $subscription_id -Scope Process

if ($connection) {
    Set-AzContext -SubscriptionId $env:ARM_SUBSCRIPTION_ID

    $availabilityResult = Get-AzStorageAccountNameAvailability -Name $storage_account_name

    if ($availabilityResult.NameAvailable) {
        Write-Host "The storage account name '$storage_account_name' is available."
    }
    else {
        # if the storage account already exists, check it is connected to this project
        $sa = Get-AzStorageAccount -resourcegroup $storage_account_resource_group_name -name $storage_account_name -ErrorAction SilentlyContinue
        if ($null -eq $sa) {
            Write-Warning "The storage account name '$storage_account_name' is not available, consider adjusting the supplied app name '$appname'. Reason: $($availabilityResult.Message)"
            return
        }
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
    else {
        Write-Host "Using existing resource group: $resource_group_name"
    }

    # create the managed identity
    $params = @{
        Name              = $managedIdentityName
        ResourceGroupName = $resource_group_name
        SubscriptionId    = $subscription_id
    }
    try {
        $uaid = Get-AzUserAssignedIdentity @params -ErrorAction SilentlyContinue
    }
    catch {}
    if ($null -eq $uaid) {    
        $params += @{ Location = $location } 
        Write-Host "Creating user assigned managed identity '$managedIdentityName'"
        $uaid = New-AzUserAssignedIdentity @params
    }
    else {
        Write-Host "Using existing user assigned managed identity '$managedIdentityName'"
    }

    # pause for a few seconds whilst the managed id is created, otherwise role assignments can fail
    Start-Sleep -Seconds 20

    $scope = "/subscriptions/$subscription_id/resourceGroups/$resource_group_name"
    Grant-RBACAdministratorRole -ObjectId $uaid.PrincipalId -Scope $scope -RoleDefinitionName 'Contributor' -ManagedIdentityName $managedIdentityName
    Write-Host "Contributor granted to managed identity '$managedIdentityName' at scope '$scope'"

    # if Terraform is going to be setting permissions (IAM), add the Role Based Access Control Administrator role
    if ($TerraformNeedsToSetRBAC) {
        Grant-RBACAdministratorRole -ObjectId $uaid.PrincipalId -Scope $scope -RoleDefinitionName 'Role Based Access Control Administrator' -ManagedIdentityName $managedIdentityName        
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
        # temporarily enable access via shared keys (this is reversed further on)
        $params = @{
            ResourceGroupName    = $storage_account_resource_group_name
            Name                 = $storage_account_name
            AllowSharedKeyAccess = $true
        }
        Set-AzStorageAccount @params | Out-Null
                
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
    Grant-RBACAdministratorRole -ObjectId $uaid.PrincipalId -Scope $scope -RoleDefinitionName 'Storage Blob Data Contributor' -ManagedIdentityName $managedIdentityName        

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
        Grant-RBACAdministratorRole -ObjectId $adsp.Id -Scope $sa.id -RoleDefinitionName 'Storage Account Contributor' -ManagedIdentityName $managedIdentityName        
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

Suggested Name:              "azurerm-$($uaid.Name.ToLower())"
Suggested Description:       Azure Resource Manager Service Connection for Terraform to resource group $resource_group_name.

Subscription Id:       $($connection.context.subscription.id)
Subscription Name:     $($connection.context.subscription.name)
Service Principal Id:  $($uaid.ClientId)
Tenant Id:             $($connection.context.tenant.id)

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
  tf-var-file: "./environments/dev.terraform.tfvars"

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
