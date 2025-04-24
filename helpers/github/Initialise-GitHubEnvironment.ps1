function Initialise-GitHubEnvironment {

  # Check for GH CLI dependency
  if (-not (Check-GhCli)) {
      throw "GH CLI is not installed. On Windows, you can install via:
winget install --id GitHub.cli --source winget

Or download from:
https://github.com/cli/cli/releases/latest"
  }

  # Ensure GH CLI is authenticated
  try {
      & gh auth status | Out-Null
  }
  catch {
      throw "GH CLI does not appear to be authenticated. Please run 'gh auth login' and try again."
  }

  # Get the remote origin URL and extract owner/repo
  $remoteOutput = git remote -v | Select-String 'origin.*\(fetch\)' | Select-Object -First 1
  if (-not $remoteOutput) {
      throw "No remote origin found. Make sure your repo is connected to GitHub."
  }
  
  $parts = $remoteOutput -split '\s+'
  $remoteUrl = $parts[1]
  try {
      [uri]$uri = $remoteUrl
  }
  catch {
      throw "Remote URL '$remoteUrl' is not a valid URI."
  }

  if ($uri.Host -notlike "*github.com") {
      throw "This script only works with GitHub repositories (remote host was $($uri.Host))."
  }

  # extract owner and repo (remove trailing .git if present)
  $segments = $uri.AbsolutePath.TrimStart('/') -split '/'
  if ($segments.Length -lt 2) {
      throw "Unable to determine owner and repo from remote URL: $remoteUrl"
  }
  
  $owner = $segments[0]
  $repo  = ($segments[1] -replace '\.git$', '')

  # Return repository information
  return @{
      Owner = $owner
      Repo = $repo
  }
}

function Check-GhCli {
  try {
      & gh --version | Out-Null
      return $true
  }
  catch {
      return $false
  }
}

