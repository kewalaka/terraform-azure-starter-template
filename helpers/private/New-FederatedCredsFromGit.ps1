function New-FederatedCredsFromGit {
  [CmdletBinding()]
  param(
      [Parameter(Mandatory)]
      [string]$RemoteOriginLine,
      [Parameter(Mandatory)]
      [string]$ManagedIdentityName,
      [string]$GitHubEnvironmentName,
      [string]$AdoOrgGUID,
      [string]$AdoServiceConnectionName
  )

  # 1) extract URL
  $parts = $RemoteOriginLine -split '\s+' 
  if ($parts.Length -lt 2) { throw "Invalid remote line: '$RemoteOriginLine'" }
  $remoteUrl = $parts[1]
  try { $uri = [uri]$remoteUrl } catch { throw "Invalid URI: $remoteUrl" }

  # 2) infer Git host
  $subject = $issuer = $credName = $null
  switch -Wildcard ($uri.Host) {
      'github.com' {
          if (-not $GitHubEnvironmentName) { throw "EnvironmentName is required for GitHub remotes." }
          $seg = $uri.AbsolutePath.Trim('/') -split '/'
          $org  = $seg[0]
          $repo = ($seg[1] -replace '\.git$','')
          $subject  = "repo:$org/$repo:environment:$GitHubEnvironmentName"
          $issuer   = "https://token.actions.githubusercontent.com"
          $credName = "gh-oidc-$org-$repo-$GitHubEnvironmentName"
      }
      'dev.azure.com' {
          if (-not ($AdoOrgGUID -and $AdoServiceConnectionName)) {
              throw "AdoOrgGUID and AdoServiceConnectionName are required for ADO remotes."
          }
          $seg = $uri.AbsolutePath.Trim('/') -split '/'
          $adoOrg = $seg[0]
          if ($seg[1] -eq '_git') {
              $adoProject = $adoOrg
              $repoName   = $seg[2]
          }
          elseif ($seg[2] -eq '_git') {
              $adoProject = $seg[1]
              $repoName   = $seg[3]
          }
          else {
              throw "Unrecognized ADO path: '$($uri.AbsolutePath)'"
          }
          $subject  = "sc://$adoOrg/$adoProject/$AdoServiceConnectionName"
          $issuer   = "https://vstoken.dev.azure.com/$AdoOrgGUID"
          $credName = "ado-oidc-$adoOrg-$adoProject-$AdoServiceConnectionName"
      }
      Default {
          throw "Unsupported Git host: $($uri.Host)"
      }
  }

  # normalize
  $credName = $credName.ToLower() -replace '\s+','-'
  $subject  = $subject.ToLower() -replace '\s+','-'

  # create/update federated credential
  try {
    $federatedArgs = @{
        Name         = $credName
        IdentityName = $ManagedIdentityName
        Audience     = @('api://AzureADTokenExchange')
        Issuer       = $issuer
        Subject      = $subject
    }

    $existingCred = Get-AzFederatedIdentityCredential @federatedArgs -ErrorAction Stop
    if ($existingCred) {
        Update-AzFederatedIdentityCredential @federatedArgs -ErrorAction Stop
        Write-Host "✔ Federated credential '$credName' updated with supplied parameters."
        return
    }

      New-AzFederatedIdentityCredential @federatedArgs -ErrorAction Stop
      Write-Host "✔ Created federated credential '$credName'"
  }
  catch {
      Write-Warning "Failed to create federated credential: $_"
  }
}