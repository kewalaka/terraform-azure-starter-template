#Requires -Version 7
<#
.SYNOPSIS
    Sets up GitHub environments for Terraform deployments.

.DESCRIPTION
    This script automates the setup of GitHub environments for Terraform deployments:
    1. Creates/updates PLAN and APPLY environments
    2. Sets required secrets for Azure authentication
    3. Configures reviewers and branch protection policies
    4. Creates a ruleset to protect the main branch

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Environment variables can be provided via .env file or set in the session:
    - PLAN_ENV_NAME: Name of the plan environment
    - APPLY_ENV_NAME: Name of the apply environment (optionally, otherwise only PLAN_ENV_NAME is used)
    - ARM_TENANT_ID, ARM_SUBSCRIPTION_ID, ARM_CLIENT_ID: Azure credentials
#>

# Default reviewers
$defaultReviewerUsers = @("kewalaka")
$defaultReviewerTeams = @()

# Source helper functions
if ($PSScriptRoot -eq "") { $root = "." } else { $root = $PSScriptRoot }
. $(Join-Path "$root" "github" "Invoke-GhCommand.ps1")
. $(Join-Path "$root" "github" "Initialise-GitHubEnvironment.ps1")
. $(Join-Path "$root" "github" "New-GitHubEnvironment.ps1")
. $(Join-Path "$root" "github" "New-GitHubBranchRuleset.ps1")
. $(Join-Path "$root" "github" "Set-GitHubEnvironmentPolicy.ps1")

# Load environment variables from .env file
if (Test-Path $EnvFilePath) {
  Get-Content $EnvFilePath | ForEach-Object {
    if ($_ -match "^(?<key>[^=]+)=(?<value>.*)$") {
        [System.Environment]::SetEnvironmentVariable($Matches['key'], $Matches['value'], 'Process')
    }
  }
}

# Initialize GitHub environment & check ARM parameters
try {
    $envFilePath = Join-Path $root ".env"
    $repoInfo = Initialise-GitHubEnvironment -EnvFilePath $envFilePath
}
catch {
    Write-Warning "Initialization failed: $_"
    return
}

$owner = $repoInfo.Owner
$repo = $repoInfo.Repo
$planEnvName = $env:PLAN_ENV_NAME
$applyEnvName = $env:APPLY_ENV_NAME -eq $null -or $env:APPLY_ENV_NAME -eq "" ? $planEnvName : $env:APPLY_ENV_NAME

if (-not $planEnvName) {
    Write-Warning "PLAN_ENV_NAME not set in .env or environment variables."
    return
}

$azureParams = @{
    ArmTenantId = $env:ARM_TENANT_ID
    ArmSubscriptionId = $env:ARM_SUBSCRIPTION_ID 
    ArmClientId = $env:ARM_CLIENT_ID # assume plan and apply use the same client id for now.
}

if ($azureParams.ArmTenantId -eq $null -or $azureParams.ArmSubscriptionId -eq $null -or $azureParams.ArmClientId -eq $null) {
    Write-Warning "One or more ARM parameters (ARM_TENANT_ID, ARM_SUBSCRIPTION_ID, ARM_CLIENT_ID) are not set.  Can't continue."
    return
}

# Create environments, first plan, then apply
if (-not (New-GitHubEnvironment -Owner $owner -Repo $repo -EnvironmentName $planEnvName @azureParams)) {
    return
}

if ($applyEnvName -ne $planEnvName) {
    if (New-GitHubEnvironment -Owner $owner -Repo $repo -EnvironmentName $applyEnvName @azureParams) { {

        Set-GitHubEnvironmentPolicy -Owner $owner -Repo $repo -EnvironmentName $applyEnvName `
            -UserReviewers $defaultReviewerUsers -TeamReviewers $defaultReviewerTeams
    }
    else {
        return
    }
}
else {
    Write-Host "`nPLAN and APPLY environments are the same. Skipping APPLY-specific configuration."
}

# Create branch ruleset for main branch
New-GitHubBranchRuleset -Owner $owner -Repo $repo

Write-Host "`nGitHub environments setup complete."