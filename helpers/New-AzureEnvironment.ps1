#Requires -Version 7
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
$appname = '<TODO YOUR APP NAME>' # used for RG and UMI names
$owner = '<TODO YOUR NAME>'
$env_code = 'dev'


$location = 'NewZealandNorth' # 'AustraliaEast'
$short_location_code = 'nzn' # 'auea'

# If you want to use ADO, you need to specify the ADO org GUID
# The other settings for GitHub and ADO are inferred from the git remote URL
$adoOrgGUID        = ''

# baseline tags
$tags = @{
    Company = "kewalaka"
    Project = "$appname project"
    Owner   = $owner
}

# does the deployment UMI need to be able to set permissions on objects
$DeploymentsNeedToSetRBAC = $true

# these can be tuned if needed but the defaults are fine too.
$managedIdentityName = ("id-azdo-{0}-{1}" -f $appname, $env_code)
$resource_group_name = ("rg-{0}-{1}-{2}" -f $appname, $env_code, $short_location_code)
$planEnvName       = "${env_code}_terraform_plan"
$applyEnvName      = "${env_code}_terraform_apply"
$adoServiceConnectionName = "sc-$managedIdentityName"

#
# End of customisations
# -------------------------------------------------
if ($PSScriptRoot -eq "") { $root = "." } else { $root = $PSScriptRoot }
. $(Join-Path "$root" "azure" "New-FederatedCredsFromGitRemote.ps1")
. $(Join-Path "$root" "azure" "Grant-RBACRole.ps1")

Update-AzConfig -Scope Process -DisplayBreakingChangeWarning $false | Out-Null # cuts down on noise from breaking change warnings
Update-AzConfig -Scope Process -LoginExperienceV2 Off | Out-Null # stops the new login experience that wants to iterate through all subscriptions
if ($null -eq $env:ARM_TENANT_ID -or $null -eq $env:ARM_SUBSCRIPTION_ID) {
    Write-Warning "Please set the ARM_TENANT_ID and ARM_SUBSCRIPTION_ID environment variables"
    Write-Host @"

e.g.:
`$env:ARM_TENANT_ID = '0000000-0000-0000-0000-000000000000'
`$env:ARM_SUBSCRIPTION_ID = '0000000-0000-0000-0000-000000000000'

"@
    return
}

$subscription_id = $env:ARM_SUBSCRIPTION_ID
try {
    Import-Module Az.Accounts, Az.ManagedServiceIdentity, Az.Resources
}
catch {
    Write-Warning "There was an issue importing required Az Modules, make sure your Az PowerShell modules are up to date: <https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell>"
    return
}

$connection = Connect-AzAccount -TenantId $env:ARM_TENANT_ID -Subscription $subscription_id -Scope Process -UseDeviceAuthentication

if ($connection) {
    Set-AzContext -SubscriptionId $env:ARM_SUBSCRIPTION_ID

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
        $params += @{ 
            Location = $location
            Tag      = $tags
        } 
        Write-Host "✔ Creating user assigned managed identity '$managedIdentityName'"
        $uaid = New-AzUserAssignedIdentity @params
    }
    else {
        Write-Host "✔ Using existing user assigned managed identity '$managedIdentityName'"
    }

    # pause for a few seconds whilst the managed id is created, otherwise role assignments can fail
    Start-Sleep -Seconds 20

    $scope = "/subscriptions/$subscription_id/resourceGroups/$resource_group_name"
    Grant-RBACRole -ObjectId $uaid.PrincipalId -Scope $scope -RoleDefinitionName 'Contributor' -ManagedIdentityName $managedIdentityName

    # if Terraform is going to be setting permissions (IAM), add the Role Based Access Control Administrator role
    if ($DeploymentsNeedToSetRBAC) {
        Grant-RBACRole -ObjectId $uaid.PrincipalId -Scope $scope -RoleDefinitionName 'Role Based Access Control Administrator' -ManagedIdentityName $managedIdentityName        
    }

    # get details from `git remote -v` and use this to make the federated credentials
    $remoteOriginLine = git remote -v | Select-String 'origin' | Select-Object -First 1
    if ($null -eq $remoteOriginLine) {
        Write-Warning "No remote origin found, if you want to use Federated Credentials, please check your `git remote -v` returns a line with 'origin'"
    }
    else 
    {
        if ($adoOrgGUID -ne "") {
            $params = @{
                ManagedIdentityName = $managedIdentityName
                ResourceGroupName = $resource_group_name
                RemoteOriginLine = "$remoteOriginLine"
                AdoOrgGUID       = $adoOrgGUID
                AdoServiceConnectionName = $adoServiceConnectionName
            }
            New-FederatedCredsFromGitRemote @params
        }
        else {
            $params = @{
                ManagedIdentityName = $managedIdentityName
                ResourceGroupName = $resource_group_name
                RemoteOriginLine   = "$remoteOriginLine"
            }
            New-FederatedCredsFromGitRemote @params -GitHubEnvironmentName $planEnvName
            if ($planEnvName -ne $applyEnvName) {
                New-FederatedCredsFromGitRemote @params -GitHubEnvironmentName $applyEnvName
            }
        }
    }
}
else {
    Write-Warning ("A connection to Azure could not be made: {0}" -f $_.Exception)
}

# write the relevant settings to an .env file so that another script can use them to set up ADO/GitHub
$envFile = "$root\.env"
$envContent = @"
ARM_TENANT_ID=$($env:ARM_TENANT_ID)
ARM_SUBSCRIPTION_ID=$($env:ARM_SUBSCRIPTION_ID)
ARM_CLIENT_ID=$($uaid.ClientId)
RESOURCE_GROUP_NAME=$resource_group_name
MANAGED_IDENTITY_NAME=$managedIdentityName
PLAN_ENV_NAME=$planEnvName
APPLY_ENV_NAME=$applyEnvName
"@
$envContent | Out-File -FilePath $envFile -Encoding utf8 -Force
Write-Host "✔ Created .env file"