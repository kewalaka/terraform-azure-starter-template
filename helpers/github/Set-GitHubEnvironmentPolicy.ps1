
function Set-GitHubEnvironmentPolicy {
  [CmdletBinding()]
  param(
      [Parameter(Mandatory)]
      [string]$Owner,
      
      [Parameter(Mandatory)]
      [string]$Repo,
      
      [Parameter(Mandatory)]
      [string]$EnvironmentName,
      
      [Parameter()]
      [string[]]$UserReviewers = @(),
      
      [Parameter()]
      [string[]]$TeamReviewers = @()
  )

  Write-Host "`nSetting deployment branch policy on environment '$EnvironmentName'..."

  $reviewerFlags = Get-ReviewerFlags -UserReviewers $UserReviewers -TeamReviewers $TeamReviewers -Org $Owner

  $policyCmd = @(
      "gh", "api", "-X", "PUT", "/repos/$Owner/$Repo/environments/$EnvironmentName",
      "-H", "Accept: application/vnd.github+json",
      "-H", "X-GitHub-Api-Version: 2022-11-28"
  ) + $reviewerFlags + @(
      "-F", "deployment_branch_policy[protected_branches]=true",
      "-F", "deployment_branch_policy[custom_branch_policies]=false"
  )
  
  try {
      Invoke-GhCommand $policyCmd | Out-Null
      Write-Host "✔ Deployment branch policy updated on '$EnvironmentName' (protected branch: main, required reviewers set)."
      return $true
  }
  catch {
      Write-Warning "Failed to update deployment branch policy for environment '$EnvironmentName': $_"
      return $false
  }
}

function Get-UserId {
  param(
      [Parameter(Mandatory)]
      [string]$UserName
  )
  $user = gh api "/users/$UserName" | ConvertFrom-Json
  return $user.id
}

function Get-TeamId {
  param(
      [Parameter(Mandatory)]
      [string]$TeamName,
      [Parameter(Mandatory)]
      [string]$Org
  )
  $team = gh api "/orgs/$Org/teams/$TeamName" | ConvertFrom-Json
  return $team.id
}

function Get-ReviewerFlags {
  param(
      [string[]]$UserReviewers = @(),
      [string[]]$TeamReviewers = @(),
      [Parameter(Mandatory)]
      [string]$Org
  )
  $flags = @()
  foreach ($user in $UserReviewers) {
      $id = Get-UserId -UserName $user
      $flags += "-F"
      $flags += "reviewers[][type]=User"
      $flags += "-F"
      $flags += "reviewers[][id]=$id"
  }
  foreach ($team in $TeamReviewers) {
      $id = Get-TeamId -TeamName $team -Org $Org
      $flags += "-F"
      $flags += "reviewers[][type]=Team"
      $flags += "-F"
      $flags += "reviewers[][id]=$id"
  }
  return $flags
}