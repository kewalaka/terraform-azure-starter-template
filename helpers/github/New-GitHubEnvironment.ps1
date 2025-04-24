function New-GitHubEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Owner,
        
        [Parameter(Mandatory)]
        [string]$Repo,
        
        [Parameter(Mandatory)]
        [string]$EnvironmentName,
  
        [string]$ArmTenantId = $env:ARM_TENANT_ID,
        [string]$ArmSubscriptionId = $env:ARM_SUBSCRIPTION_ID,
        [string]$ArmClientId = $env:ARM_CLIENT_ID
    )
  
    Write-Host "`nCreating GitHub environment '$EnvironmentName' in repo $Owner/$Repo"
  
    $createEnvCmd = @(
        "gh", "api", "-X", "PUT", "/repos/$Owner/$Repo/environments/$EnvironmentName"
    )
    
    try {
        Invoke-GhCommand $createEnvCmd | Out-Null
        Write-Host "✔ Environment '$EnvironmentName' created/updated."
        
        # Pass ARM secrets to Set-EnvironmentSecrets
        Set-EnvironmentSecrets -EnvName $EnvironmentName `
            -ArmTenantId $ArmTenantId `
            -ArmSubscriptionId $ArmSubscriptionId `
            -ArmClientId $ArmClientId
        
        return $true
    }
    catch {
        Write-Warning "Failed to create/update environment '$EnvironmentName': $_"
        return $false
    }
}
  
function Set-EnvironmentSecrets {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnvName,
  
        [string]$ArmTenantId,
        [string]$ArmSubscriptionId,
        [string]$ArmClientId
    )
  
    Write-Host "`nSetting ARM environment secrets on environment '$EnvName'..."
  
    if (-not $ArmTenantId -or -not $ArmSubscriptionId -or -not $ArmClientId) {
        Write-Warning "One or more ARM parameters (ARM_TENANT_ID, ARM_SUBSCRIPTION_ID, ARM_CLIENT_ID) are not provided. Skipping secret configuration for '$EnvName'."
        return
    }
  
    $secrets = @{
        "ARM_TENANT_ID"       = $ArmTenantId
        "ARM_SUBSCRIPTION_ID" = $ArmSubscriptionId
        "ARM_CLIENT_ID"       = $ArmClientId
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