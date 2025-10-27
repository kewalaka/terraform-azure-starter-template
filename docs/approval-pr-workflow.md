# PR Approval Workflow

The PR workflow supports flexible approval options configured at the repository level via workflow settings. By default, plans run automatically after static validation passes.

## Workflow Modes

The workflow supports three modes configured when manually triggering the workflow:

### 1. **Auto-plan (Default)** - Default behavior for pull_request events
- Static validation runs automatically
- Terraform plan runs immediately after validation passes
- **This is the default behavior** - fastest path for standard PRs
- No manual intervention required

### 2. **Skip Plan** - Set `skip_plan: true` when manually running
- Static validation runs automatically
- Terraform plan is skipped entirely
- Use when you only want validation without generating a plan
- Useful for documentation-only changes

### 3. **Require Approval** - Set `require_approval: true` when manually running
- Static validation runs automatically
- A GitHub issue is created requiring approval
- Terraform plan runs only after approval
- Use for sensitive changes requiring explicit review

## How to Configure

The workflow runs automatically on pull requests with default settings (auto-plan). To use different modes, manually trigger the workflow:

### Via GitHub UI

1. Go to Actions → Terraform PR Validation
2. Click "Run workflow"
3. Select the branch
4. Configure options:
   - **Require manual approval before running plan**: Check to enable approval gate
   - **Skip the Terraform plan stage**: Check to skip plan
5. Click "Run workflow"

### Via GitHub CLI

```bash
# Default: Auto-plan (runs automatically on PR)
# No action needed

# Manually trigger with approval required
gh workflow run "Terraform PR Validation" \
  --field require_approval=true \
  --field skip_plan=false

# Manually trigger with plan skipped
gh workflow run "Terraform PR Validation" \
  --field require_approval=false \
  --field skip_plan=true
```

## Workflow Behavior

When a PR is created (automatic trigger):

1. **Static validation runs automatically** (~2 minutes)
   - Terraform format check
   - Terraform validate
   - TFLint
   - Checkov security scanning

2. **Terraform plan runs immediately** (default)
   - After validation passes, all environment plans execute in parallel
   - Results are posted as PR comments

When manually triggered with options:

1. **Static validation runs automatically** (~2 minutes)

2. **Conditional approval** (only if `require_approval` is true)
   - A GitHub issue is created in the repository
   - The issue includes PR details and a link to the PR
   - Configured approvers receive notifications

3. **Approver responds via issue comment** (if approval required)
   - To approve: Comment `approve` on the issue
   - To deny: Comment `deny` on the issue
   - Timeout: 60 minutes (configurable)

4. **Environment plans run in parallel** (unless `skip_plan` is true)
   - After validation (and approval if required), all environment plans execute
   - Results are posted as PR comments

## Configuration Matrix

| Trigger Type | require_approval | skip_plan | Behavior |
|--------------|------------------|-----------|----------|
| pull_request (auto) | false | false | Static validation → Plan immediately |
| workflow_dispatch | false | true | Static validation only, no plan |
| workflow_dispatch | true | false | Static validation → Manual approval → Plan |
| workflow_dispatch | true | true | Static validation → Manual approval → No plan |

## Why Not Environment Protection?

Using environment protection rules for PR approvals creates a problem:

### Previous Approach (Environment Protection)
- ❌ PR uses `dev-iac-plan` environment with required reviewers
- ❌ Deploy workflow also uses `dev-iac-plan` for planning
- ❌ Results in **double approval**: once for plan, once for apply
- ❌ No way to differentiate PR plans from deployment plans

### Current Approach (Workflow Input Control)
- ✅ Default: Plans run automatically after validation (fastest workflow)
- ✅ Optional: Set `require_approval` input for manual approval gate
- ✅ Optional: Set `skip_plan` input to skip plan stage
- ✅ Repository-level decision, not per-PR management
- ✅ Deploy workflow uses `dev-iac-plan` without reviewers (no approval needed)
- ✅ Deploy workflow uses `dev-iac-apply` with reviewers (approval for apply only)
- ✅ Clear separation: PR approval is workflow-controlled, deployment approval is environment-based

## Configuration

The workflow is controlled by workflow inputs. The approval step is configured to run conditionally:

```yaml
on:
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      require_approval:
        description: 'Require manual approval before running plan'
        type: boolean
        default: false
      skip_plan:
        description: 'Skip the Terraform plan stage'
        type: boolean
        default: false

approval:
  name: "Approve Terraform Plan"
  needs: static-validation
  if: inputs.require_approval == true
  runs-on: ubuntu-latest
  steps:
    - name: Wait for approval
      uses: trstringer/manual-approval@v1
      timeout-minutes: 60
      with:
        secret: ${{ secrets.GITHUB_TOKEN }}
        approvers: ${{ github.repository_owner }}
        minimum-approvals: 1
```

### Customization Options

**Change approvers:** Modify the `approvers` field to a comma-separated list of GitHub usernames:

```yaml
approvers: user1,user2,user3
```

**Change timeout:** Adjust `timeout-minutes` (default: 60):

```yaml
timeout-minutes: 120  # 2 hours
```

**Change minimum approvals:** Require multiple approvers:

```yaml
minimum-approvals: 2
```

**Customize issue content:** Modify `issue-title` and `issue-body` in the workflow file.

## Approval Process for Repository Administrators

### As an Approver

1. You'll receive a notification when an approval issue is created
2. Review the PR:
   - Check the static validation results in PR comments
   - Review the code changes
   - Verify the purpose and scope of changes
3. Navigate to the approval issue
4. Add a comment:
   - Type `approve` to proceed with plans
   - Type `deny` to reject and stop the workflow

### What Happens After Approval

- The workflow continues to the `plan-environments` job
- All environments in the matrix are planned in parallel
- Plan results are posted as PR comments
- If approved, the PR can be merged

### What Happens After Denial

- The workflow fails and stops immediately
- No plans are executed
- The PR author can address feedback and push new commits
- A new approval issue will be created for the updated PR

## Administrative Setup via GitHub UI

While the approval mechanism is code-based, environment configuration should be done administratively:

### For PR Validation Environments

Create environments like `dev-iac-plan`:
- **Required reviewers:** None (approval is handled by the workflow action)
- **Deployment branches:** No restriction
- **Secrets:** Configure all required Azure secrets

### For Deployment Environments

Create environments like `dev-iac-apply`:
- **Required reviewers:** 1+ (strongly recommended)
- **Deployment branches:** Limit to `main` only
- **Prevent self-review:** Enable if available
- **Secrets:** Configure all required Azure secrets

This ensures:
- PRs get one approval via the manual-approval action
- Deployments get one approval via environment protection (on apply only)
- No double approvals during deployment

## Troubleshooting

### Approval issue not created

Check that the workflow has `issues: write` permission:

```yaml
permissions:
  issues: write
```

### Approval not recognized

- Ensure the comment is exactly `approve` or `deny` (case-insensitive)
- Verify the commenter is listed in the `approvers` configuration
- Check the approval issue for workflow logs

### Timeout occurred

- Default timeout is 60 minutes
- If needed, increase `timeout-minutes` in the workflow
- A new approval issue will be created on subsequent commits

## References

- [trstringer/manual-approval action](https://github.com/trstringer/manual-approval)
- [GitHub Environments documentation](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
