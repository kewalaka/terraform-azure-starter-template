<#
This script does the following:

1. Checks for the GH CLI. If missing, a message is printed telling the user how to install it.
2. Checks GitHub authentication status (using gh auth status); if not authenticated, instructs the user to run gh auth login.
3. Gets the current repository’s origin from git remote -v and extracts the owner and repo.
4. Reads the .env file in the same folder to obtain PLAN_ENV_NAME and APPLY_ENV_NAME.
5. Creates/updates the PLAN environment.
6. If APPLY_ENV_NAME is different from PLAN_ENV_NAME, creates/updates the APPLY environment and then:
   - Adds a default reviewer (kewalaka) to the APPLY environment.
   - Sets a protection rule that requires PRs to the main branch.
7. Sets ARM environment secrets (ARM_TENANT_ID, ARM_SUBSCRIPTION_ID, ARM_CLIENT_ID) on both environments.
#>

function Check-GhCli {
  try {
      & gh --version | Out-Null
      return $true
  }
  catch {
      return $false
  }
}

function Set-EnvironmentSecrets {
  param(
      [Parameter(Mandatory)]
      [string]$EnvName
  )

  Write-Host "`nSetting ARM environment secrets on environment '$EnvName'..."

  if (-not $env:ARM_TENANT_ID -or -not $env:ARM_SUBSCRIPTION_ID -or -not $env:ARM_CLIENT_ID) {
      Write-Warning "One or more ARM environment variables (ARM_TENANT_ID, ARM_SUBSCRIPTION_ID, ARM_CLIENT_ID) are not set in the session. Skipping secret configuration for '$EnvName'."
      return
  }

  $secrets = @{
      "ARM_TENANT_ID"       = $env:ARM_TENANT_ID
      "ARM_SUBSCRIPTION_ID" = $env:ARM_SUBSCRIPTION_ID
      "ARM_CLIENT_ID"       = $env:ARM_CLIENT_ID
  }

  foreach ($key in $secrets.Keys) {
      $cmd = @("gh", "secret", "set", $key, "--env", $EnvName, "-b", $secrets[$key])
      try {
          & $cmd | Out-Null
          Write-Host "✔ Secret '$key' set for environment '$EnvName'."
      }
      catch {
          Write-Warning "Failed to set secret '$key' for environment '$EnvName': $_"
      }
  }
}

# Step 1: Check for GH CLI dependency
if (-not (Check-GhCli)) {
  Write-Warning "GH CLI is not installed. On Windows, you can install via:
winget install --id GitHub.cli --source winget

Or download from:
https://github.com/cli/cli/releases/latest"
  return
}

# Step 2: Ensure GH CLI is authenticated
try {
  & gh auth status | Out-Null
}
catch {
  Write-Warning "GH CLI does not appear to be authenticated. Please run 'gh auth login' and try again."
  return
}

# Step 3: Get the remote origin URL and extract owner/repo
$remoteOutput = git remote -v | Select-String 'origin.*\(fetch\)' | Select-Object -First 1
if (-not $remoteOutput) {
  Write-Warning "No remote origin found. Make sure your repo is connected to GitHub."
  return
}
# Assuming the output line is like:
# origin  https://github.com/owner/repo.git (fetch)
$parts = $remoteOutput -split '\s+'
$remoteUrl = $parts[1]
try {
  [uri]$uri = $remoteUrl
}
catch {
  Write-Warning "Remote URL '$remoteUrl' is not a valid URI."
  return
}

if ($uri.Host -notlike "*github.com") {
  Write-Warning "This script only works with GitHub repositories (remote host was $($uri.Host))."
  return
}

# extract owner and repo (remove trailing .git if present)
$segments = $uri.AbsolutePath.TrimStart('/') -split '/'
if ($segments.Length -lt 2) {
  Write-Warning "Unable to determine owner and repo from remote URL: $remoteUrl"
  return
}
$owner = $segments[0]
$repo  = ($segments[1] -replace '\.git$', '')

# Step 4: Read environment names from .env file (assumes file is in $PSScriptRoot)
$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) {
  Write-Warning ".env file not found at $envFile"
  return
}
$envData = Get-Content $envFile
$planEnvName = ($envData | Where-Object { $_ -match "PLAN_ENV_NAME=(.+)$" } | ForEach-Object { $Matches[1].Trim() })
$applyEnvName = ($envData | Where-Object { $_ -match "APPLY_ENV_NAME=(.+)$" } | ForEach-Object { $Matches[1].Trim() })

if (-not $planEnvName) {
  Write-Warning "PLAN_ENV_NAME not set in .env"
  return
}
if (-not $applyEnvName) {
  Write-Warning "APPLY_ENV_NAME not set in .env"
  return
}

Write-Host "`nCreating GitHub environment '$planEnvName' in repo $owner/$repo"

# Step 5: Create or update the PLAN environment using GH CLI.
$createPlanCmd = @(
  "gh", "api", "-X", "PUT", "/repos/$owner/$repo/environments/$planEnvName"
)
try {
  & $createPlanCmd | Out-Null
  Write-Host "✔ PLAN environment '$planEnvName' created/updated."
}
catch {
  Write-Warning "Failed to create/update PLAN environment '$planEnvName': $_"
  return
}

# Set ARM secrets on PLAN environment.
Set-EnvironmentSecrets -EnvName $planEnvName

# Step 6: If APPLY environment is different, create/update it and add reviewer/protection rule.
if ($applyEnvName -ne $planEnvName) {
  Write-Host "`nCreating GitHub environment '$applyEnvName' in repo $owner/$repo"
  $createApplyCmd = @(
      "gh", "api", "-X", "PUT", "/repos/$owner/$repo/environments/$applyEnvName"
  )
  try {
      & $createApplyCmd | Out-Null
      Write-Host "✔ APPLY environment '$applyEnvName' created/updated."
  }
  catch {
      Write-Warning "Failed to create/update APPLY environment '$applyEnvName': $_"
      return
  }

  # For the APPLY environment, add a reviewer and a branch protection rule that requires PRs to main.
  $reviewer = "kewalaka"
  Write-Host "`nSetting deployment branch policy on environment '$applyEnvName'..."

  $payload = @{
      protected_branches = @("main")
      reviewers          = @($reviewer)
  } | ConvertTo-Json

  $policyCmd = @(
      "gh", "api", "-X", "PUT", "/repos/$owner/$repo/environments/$applyEnvName/deployment-branch-policy",
      "-f", "payload=$payload"
  )
  try {
      & $policyCmd | Out-Null
      Write-Host "✔ Deployment branch policy set on '$applyEnvName' (protected branch: main, reviewer: $reviewer)."
  }
  catch {
      Write-Warning "Failed to update deployment branch policy for environment '$applyEnvName': $_"
      return
  }

  # Set ARM secrets on APPLY environment.
  Set-EnvironmentSecrets -EnvName $applyEnvName
}
else {
  Write-Host "`nPLAN and APPLY environments are the same. Skipping APPLY-specific configuration."
}

Write-Host "`nGitHub environments setup complete."