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
    - APPLY_ENV_NAME: Name of the apply environment
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

# Initialize GitHub environment
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
$planEnvName = $repoInfo.PlanEnvName
$applyEnvName = $repoInfo.ApplyEnvName

if (-not $planEnvName) {
    Write-Warning "PLAN_ENV_NAME not set in .env or environment variables."
    return
}

# Create environments, first plan, then apply
if (-not (New-GitHubEnvironment -Owner $owner -Repo $repo -EnvironmentName $planEnvName)) {
    return
}

if ($applyEnvName -ne $planEnvName) {
    if (New-GitHubEnvironment -Owner $owner -Repo $repo -EnvironmentName $applyEnvName) {

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