function New-GitHubEnvironment {
  [CmdletBinding()]
  param(
      [Parameter(Mandatory)]
      [string]$Owner,
      
      [Parameter(Mandatory)]
      [string]$Repo,
      
      [Parameter(Mandatory)]
      [string]$EnvironmentName
  )

  Write-Host "`nCreating GitHub environment '$EnvironmentName' in repo $Owner/$Repo"

  $createEnvCmd = @(
      "gh", "api", "-X", "PUT", "/repos/$Owner/$Repo/environments/$EnvironmentName"
  )
  
  try {
      Invoke-GhCommand $createEnvCmd | Out-Null
      Write-Host "✔ Environment '$EnvironmentName' created/updated."
      
      # Set ARM secrets on the environment
      Set-EnvironmentSecrets -EnvName $EnvironmentName
      
      return $true
  }
  catch {
      Write-Warning "Failed to create/update environment '$EnvironmentName': $_"
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
          & $cmd[0] $cmd[1..($cmd.Count - 1)] | Out-Null
          Write-Host "✔ Secret '$key' set for environment '$EnvName'."
      }
      catch {
          Write-Warning "Failed to set secret '$key' for environment '$EnvName': $_"
      }
  }
}


