# Administrative Recommendation for Approval Configuration

## Summary

The implemented solution uses a **hybrid approach** combining code-based approval (marketplace action) with administrative configuration (environment settings). This provides the best balance of automation and control.

## What Was Implemented (Code)

The PR workflow now uses the `trstringer/manual-approval` marketplace action:
- Creates a GitHub issue for approval after static validation
- Single approval gates all environment plans
- No environment protection rules needed for PR approval
- Configured via workflow YAML file

## What Should Be Done Administratively (GitHub Settings)

### For PR Validation Environments

Navigate to **Settings → Environments** and configure `dev-iac-plan` (and similar):

**Remove Required Reviewers:**
- Set "Required reviewers" to 0 (none)
- Approval is now handled by the workflow action, not environment protection

**Keep Secrets:**
- All Azure authentication secrets must remain configured
- `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`
- `TF_STATE_*` secrets for backend configuration

**No Branch Restrictions:**
- Allow deployments from any branch (PRs need access)

### For Deployment Environments

Navigate to **Settings → Environments** and configure `dev-iac-apply` (and similar):

**Keep Required Reviewers:**
- Set "Required reviewers" to 1 or more (strongly recommended)
- This provides approval gate for terraform apply during deployment

**Restrict to Main Branch:**
- Set "Deployment branches" to only `main`
- Prevents accidental deployments from feature branches

**Enable Protection Features:**
- Enable "Prevent self-review" if available
- Consider wait timer if available (e.g., 5 minutes)

## Why This Approach is Recommended

### ✅ Advantages

1. **Avoids Double Approvals**
   - PR: One approval via manual-approval action
   - Deployment: One approval via environment protection (on apply only)
   - Previously: Two approvals during deployment (plan + apply)

2. **Clear Separation of Concerns**
   - PR approvals are workflow-controlled
   - Deployment approvals are environment-controlled
   - Each serves a distinct purpose

3. **Minimal Administrative Overhead**
   - No need to create duplicate environments
   - No need to manage complex branch protection rules
   - Standard GitHub features used appropriately

4. **Flexibility**
   - Approvers can be changed in workflow file without UI changes
   - Timeout and minimum approvals configurable per workflow
   - Can easily add multiple approval stages if needed

### ❌ Alternatives Considered and Rejected

**Option 1: Duplicate Environments**
- Create `dev-iac-plan-pr` and `dev-iac-plan-deploy` environments
- ❌ Doubles the number of environments to manage
- ❌ Doubles the number of secrets to maintain
- ❌ Doubles the number of OIDC credentials to configure
- ❌ Higher administrative burden

**Option 2: Branch Protection with Status Checks**
- Use branch protection rules requiring manual status checks
- ❌ Doesn't prevent the plan stage from running
- ❌ Would need custom tooling to block workflow progression
- ❌ Status checks are binary (pass/fail), not approval-based
- ❌ Doesn't address the double approval issue

**Option 3: Pure Environment Protection**
- Keep using environment protection for both PR and deployment
- ❌ Results in double approvals during deployment
- ❌ This was the original problem we're solving
- ❌ No way to distinguish PR plans from deployment plans

**Option 4: No Approval on PRs**
- Remove approval requirement from PRs entirely
- ❌ Reduces visibility and control
- ❌ Plans could run without review
- ❌ Could lead to unexpected Azure costs

## Implementation Steps for Administrators

### Immediate Actions Required

1. **Navigate to GitHub Repository Settings**
   ```
   https://github.com/<owner>/<repo>/settings/environments
   ```

2. **Update `dev-iac-plan` Environment**
   - Click on "dev-iac-plan"
   - Under "Environment protection rules"
   - Remove all required reviewers
   - Keep all environment secrets as-is
   - Save changes

3. **Verify `dev-iac-apply` Environment**
   - Click on "dev-iac-apply"
   - Ensure "Required reviewers" is set to 1 or more
   - Ensure "Deployment branches" is limited to `main`
   - Keep all environment secrets as-is
   - Save changes

4. **Test the Configuration**
   - Create a test PR with a small change
   - Verify static validation runs automatically
   - Verify approval issue is created
   - Approve via issue comment
   - Verify environment plans run successfully
   - Verify plan results posted to PR

### For Additional Environments

Repeat the above for each environment:
- `tst-iac-plan`, `tst-iac-apply`
- `uat-iac-plan`, `uat-iac-apply`
- `prod-iac-plan`, `prod-iac-apply`

## Ongoing Maintenance

### Adding/Removing Approvers

Edit `.github/workflows/terraform-pr.yml`:

```yaml
approvers: user1,user2,user3
```

This can be done via PR and doesn't require GitHub UI changes.

### Changing Approval Timeout

Edit `.github/workflows/terraform-pr.yml`:

```yaml
timeout-minutes: 120  # 2 hours instead of 1
```

### Changing Minimum Approvals

Edit `.github/workflows/terraform-pr.yml`:

```yaml
minimum-approvals: 2  # Require 2 approvers instead of 1
```

## Conclusion

This hybrid approach provides:
- Code-based approval for PR validation (flexible, version-controlled)
- Environment-based protection for deployment apply (secure, administrative)
- No double approvals during deployment
- Minimal administrative overhead
- Clear separation of concerns

The administrative configuration is a one-time setup per environment, and all subsequent changes can be made via code changes in the workflow file.
