function Ensure-GhCli {
    [CmdletBinding()]
    param()
    try {
        & gh --version | Out-Null
        Write-Verbose "GitHub CLI found in PATH"
        return $true
    } catch {
        Write-Host "GitHub CLI not found in PATH. Attempting to download locally..."
    }
    $isLinux = $true
    $is64bit = [System.Environment]::Is64BitOperatingSystem
    $localPath = Join-Path $PWD ".gh-cli"
    if (-not (Test-Path $localPath)) {
        New-Item -Path $localPath -ItemType Directory -Force | Out-Null
    }
    $releaseApiUrl = "https://api.github.com/repos/cli/cli/releases/latest"
    try {
        $release = Invoke-RestMethod -Uri $releaseApiUrl -Method Get -ErrorAction Stop
        $assetPattern = $is64bit ? "*linux_amd64.tar.gz" : "*linux_386.tar.gz"
        $asset = $release.assets | Where-Object { $_.name -like $assetPattern } | Select-Object -First 1
        if ($null -eq $asset) {
            Write-Warning "Could not find appropriate GitHub CLI download for your system."
            return $false
        }
        $downloadUrl = $asset.browser_download_url
        $downloadPath = Join-Path $localPath $asset.name
        Write-Host "Downloading GitHub CLI from $downloadUrl"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -ErrorAction Stop
        $extractPath = Join-Path $localPath "extracted"
        if (-not (Test-Path $extractPath)) {
            New-Item -Path $extractPath -ItemType Directory -Force | Out-Null
        }
        & tar -xzf $downloadPath -C $extractPath
        $ghExe = Get-ChildItem -Path $extractPath -Recurse -Filter "gh" | Select-Object -First 1
        if ($null -eq $ghExe) {
            Write-Warning "Could not find gh binary in the extracted files."
            return $false
        }
        $ghPath = $ghExe.FullName
        & chmod +x $ghPath
        $env:PATH = (Split-Path -Parent $ghPath) + ":$env:PATH"
        try {
            & $ghPath --version | Out-Null
            Write-Host "✅ GitHub CLI successfully installed to $ghPath"
            return $true
        } catch {
            Write-Warning "GitHub CLI was downloaded but failed to execute: $_"
            return $false
        }
    } catch {
        Write-Warning "Failed to download GitHub CLI: $_"
        return $false
    }
}

function Grant-RBACRole {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][string]$PrincipalId,
        [Parameter(Mandatory)][string]$RoleDefinitionId
    )
    $scope = (az group show --name $ResourceGroupName | ConvertFrom-Json).id
    az role assignment create --assignee $PrincipalId --role $RoleDefinitionId --scope $scope | Out-Null
}

function Initialise-GitHubEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PlanEnvName,
        [Parameter(Mandatory)]
        [string]$ApplyEnvName
    )
  
    # Check for GH CLI dependency
    if (-not (Ensure-GhCli)) {
        throw "GH CLI is not installed and could not be downloaded. Please install it manually."
    }
  
    # Ensure GH CLI is authenticated
    try {
        & gh auth status | Out-Null
    }
    catch {
        throw "GH CLI does not appear to be authenticated. Please run 'gh auth login' and try again."
    }
  
    # Get repository info using our helper (which supports Codespaces)
    $repoInfo = Get-GitRepositoryInfo
    if (-not $repoInfo) {
        throw "Could not determine repository information. Neither git remote nor Codespaces environment variables provided enough information."
    }
  
    # Return repository information with environment names
    return @{
        Owner = $repoInfo.Owner
        Repo = $repoInfo.Repo
        PlanEnvName = $PlanEnvName
        ApplyEnvName = $ApplyEnvName
    }
}