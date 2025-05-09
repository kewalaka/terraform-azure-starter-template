function Get-GitRepositoryInfo {
  [CmdletBinding()]
  param()
  
  # Method 1: Try git remote -v first (works in normal clone scenarios)
  $remoteOutput = git remote -v 2>$null | Select-String 'origin.*\(fetch\)' | Select-Object -First 1
  
  if ($remoteOutput) {
      Write-Verbose "Repository info found via git remote -v"
      $parts = $remoteOutput -split '\s+'
      $remoteUrl = $parts[1]
      
      try {
          [uri]$uri = $remoteUrl
          
          # Only proceed if it's a GitHub or Azure DevOps URL
          if ($uri.Host -like "*github.com" -or $uri.Host -like "*dev.azure.com") {
              $segments = $uri.AbsolutePath.Trim('/') -split '/'
              
              if ($segments.Length -ge 2) {
                  $owner = $segments[0]
                  $repo = ($segments[1] -replace '\.git$', '')
                  
                  return [PSCustomObject]@{
                      RemoteUrl = $remoteUrl
                      Owner = $owner
                      Repo = $repo
                      RemoteOriginLine = $remoteOutput
                      Source = "GitRemote"
                  }
              }
          }
      }
      catch {
          Write-Verbose "Error parsing git remote URL: $_"
      }
  }
  
  # Method 2: Try GitHub Codespaces environment variables
  if ($env:GITHUB_SERVER_URL -eq "https://github.com" -and $env:GITHUB_REPOSITORY) {
      Write-Verbose "Repository info found via Codespaces environment variables"
      $repoPath = $env:GITHUB_REPOSITORY
      $segments = $repoPath -split '/'
      
      if ($segments.Length -ge 2) {
          $owner = $segments[0]
          $repo = $segments[1]
          $remoteUrl = "https://github.com/$owner/$repo"
          
          # Create a synthetic remote line in the format expected by existing functions
          $syntheticRemoteOriginLine = "origin $remoteUrl (fetch)"
          
          return [PSCustomObject]@{
              RemoteUrl = $remoteUrl
              Owner = $owner
              Repo = $repo
              RemoteOriginLine = $syntheticRemoteOriginLine
              Source = "Codespaces"
          }
      }
  }
  
  # If all methods fail
  return $null
}