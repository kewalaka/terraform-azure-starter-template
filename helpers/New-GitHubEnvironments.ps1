# write code that does the following

# gets the current repo origin from git remote -v

# connects and auths to github - using git credential manager if possible

# if is is missing suggest installing it via winget for windows (use current user profile) or from the github release page for non-windows
# example of latest - https://github.com/cli/cli/releases/tag/v2.70.0

# creates a new environment from PLAN_ENV_NAME in .env
# creates a new environment from APPLY_ENV_NAME in .env if not the same as PLAN_ENV_NAME
# add a reviewer check the apply environment (default kewalaka)
# add a ruleset that requires PRs to the main branch


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

if (-not (Check-GhCli)) {
  Write-Warning "GH CLI is not installed. On Windows, you can install via:
winget install --id GitHub.cli --source winget

Or download from:
https://github.com/cli/cli/releases/latest"
  return
}

try {
  & gh auth status | Out-Null
}
catch {
  Write-Warning "GH CLI does not appear to be authenticated. Please run 'gh auth login' and try again."
  return
}

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
# GitHub’s API creates/updates an environment via a PUT request.
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

  # For the APPLY environment, add a reviewer and add a branch protection rule that requires PR to main.
  # For reviewers and environment protection, we use GitHub API calls.
  $reviewer = "kewalaka"
  Write-Host "`nSetting deployment branch policy on environment '$applyEnvName'..."

  # Define JSON payload for updating deployment branch policy.
  # This example sets main as the protected branch and includes a reviewer.
  # Adjust the payload structure as required by your repository's requirements.
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
}
else {
  Write-Host "`nPLAN and APPLY environments are the same. Skipping APPLY-specific configuration."
}

Write-Host "`nGitHub environments setup complete."