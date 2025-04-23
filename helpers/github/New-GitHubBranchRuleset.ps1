function New-GitHubBranchRuleset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Owner,
        
        [Parameter(Mandatory)]
        [string]$Repo,
        
        [Parameter()]
        [string]$RulesetName = "main",
        
        [Parameter()]
        [string]$TargetPattern = "main",
        
        [Parameter()]
        [int]$RequiredApprovals = 1,
        
        [Parameter()]
        [bool]$DismissStaleReviews = $true,
        
        [Parameter()]
        [bool]$RequireCodeOwnerReview = $false,
        
        [Parameter()]
        [bool]$RequireLastPushApproval = $true,
        
        [Parameter()]
        [bool]$RequireThreadResolution = $false,
        
        [Parameter()]
        [string[]]$AllowedMergeMethods = @("squash"),
        
        [Parameter()]
        [bool]$EnableCopilotReview = $true
    )
  
    # First, check if a ruleset with this name already exists
    $getRulesetsCmd = @(
        "gh", "api", "-X", "GET", "/repos/$Owner/$Repo/rulesets",
        "-H", "Accept: application/vnd.github+json",
        "-H", "X-GitHub-Api-Version: 2022-11-28"
    )
  
    try {
        $existingRulesets = Invoke-GhCommand $getRulesetsCmd | ConvertFrom-Json
        $existingRuleset = $existingRulesets | Where-Object { $_.name -eq $RulesetName }
        $rulesetExists = $null -ne $existingRuleset
    }
    catch {
        Write-Warning "Failed to query existing rulesets: $_"
        $rulesetExists = $false
    }
  
    # Prepare the ruleset payload
    $rulesetPayload = @{
        name = $RulesetName
        target = "branch"
        target_pattern = $TargetPattern 
        enforcement = "active"
        rules = @(
            @{
                type = "pull_request"
                parameters = @{
                    dismiss_stale_reviews_on_push = $DismissStaleReviews
                    require_code_owner_review = $RequireCodeOwnerReview
                    require_last_push_approval = $RequireLastPushApproval
                    required_approving_review_count = $RequiredApprovals
                    required_review_thread_resolution = $RequireThreadResolution
                    allowed_merge_methods = $AllowedMergeMethods
                    automatic_copilot_code_review_enabled = $EnableCopilotReview
                }
            }
        )
        conditions = @{
            ref_name = @{
                include = @("~DEFAULT_BRANCH")
                exclude = @()
            }
        }
    } | ConvertTo-Json -Depth 10
  
    $tempFile = New-TemporaryFile
    Set-Content -Path $tempFile -Value $rulesetPayload -Encoding UTF8
  
    # Set up the appropriate command based on whether the ruleset exists
    if ($rulesetExists) {
        # Update existing ruleset
        $rulesetCmd = @(
            "gh", "api", "-X", "PUT", "/repos/$Owner/$Repo/rulesets/$($existingRuleset.id)",
            "-H", "Accept: application/vnd.github+json",
            "-H", "X-GitHub-Api-Version: 2022-11-28",
            "--input", $tempFile
        )
        $actionMessage = "updated"
    }
    else {
        # Create new ruleset
        $rulesetCmd = @(
            "gh", "api", "-X", "POST", "/repos/$Owner/$Repo/rulesets",
            "-H", "Accept: application/vnd.github+json",
            "-H", "X-GitHub-Api-Version: 2022-11-28",
            "--input", $tempFile
        )
        $actionMessage = "created"
    }
  
    try {
        Invoke-GhCommand $rulesetCmd | Out-Null
        Write-Host "✔ Ruleset '$RulesetName' $actionMessage and enforced on the default branch."
        return $true
    }
    catch {
        Write-Warning "Failed to $actionMessage the ruleset '$RulesetName': $_"
        return $false
    }
    finally {
        Remove-Item -Path $tempFile -Force
    }
  }