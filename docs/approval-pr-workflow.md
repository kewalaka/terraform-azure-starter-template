# PR Approval Workflow

The PR workflow supports flexible approval options configured at the repository level via GitHub Actions variables. By default, plans run automatically after static validation passes.

## Workflow Modes

The workflow supports three modes controlled by optional repository variables:

### 1. **Auto-plan (Default)** - No variables configured
- Static validation runs automatically
- Terraform plan runs immediately after validation passes
- **This is the default behavior** - fastest path for standard PRs
- No manual intervention required
- No configuration needed

### 2. **Skip Plan** - Set `TFPLAN_SKIP_ON_PR` variable to `true`
- Static validation runs automatically
- Terraform plan is skipped entirely
- Use when you only want validation without generating a plan
- Useful for documentation-only changes

### 3. **Require Approval** - Set `TFPLAN_PR_APPROVAL_REQUIRED` variable to `true`
- Static validation runs automatically
- A GitHub issue is created requiring approval
- Terraform plan runs only after approval
- Use for sensitive changes requiring explicit review

## How to Configure

The workflow runs automatically on pull requests with default settings (auto-plan). To change the behavior, configure repository variables:

### Setting Repository Variables

1. Go to your repository → **Settings**
2. Navigate to **Secrets and variables** → **Actions**
3. Click on the **Variables** tab
4. Click **New repository variable**
5. Add one or both of these variables:

| Variable Name | Value | Effect |
|---------------|-------|--------|
| `TFPLAN_PR_APPROVAL_REQUIRED` | `true` | Requires manual approval before running plan |
| `TFPLAN_SKIP_ON_PR` | `true` | Skips the plan stage entirely |

**Note:** These variables are optional. If not set, the workflow defaults to auto-plan behavior.

### Example Configurations

**Default (no variables):**
```
# No variables configured
# Result: Static validation → Plan immediately
```

**Require approval:**
```
TFPLAN_PR_APPROVAL_REQUIRED = true
# Result: Static validation → Manual approval → Plan
```

**Skip plan:**
```
TFPLAN_SKIP_ON_PR = true
# Result: Static validation only, no plan
```

## Workflow Behavior

When a PR is created:

1. **Static validation runs automatically** (~2 minutes)
   - Terraform format check
   - Terraform validate
   - TFLint
   - Checkov security scanning

2. **Conditional approval** (only if `TFPLAN_PR_APPROVAL_REQUIRED` is set to `true`)
   - A GitHub issue is created in the repository
   - The issue includes PR details and a link to the PR
   - Configured approvers receive notifications

3. **Approver responds via issue comment** (if approval required)
   - To approve: Comment `approve` on the issue
   - To deny: Comment `deny` on the issue
   - Timeout: 60 minutes (configurable)

4. **Environment plans run in parallel** (unless `TFPLAN_SKIP_ON_PR` is set to `true`)
   - After validation (and approval if required), all environment plans execute
   - Results are posted as PR comments

## Configuration Matrix

| TFPLAN_PR_APPROVAL_REQUIRED | TFPLAN_SKIP_ON_PR | Behavior |
|------------------------------|-------------------|----------|
| Not set (default) | Not set (default) | Static validation → Plan immediately |
| Not set | `true` | Static validation only, no plan |
| `true` | Not set | Static validation → Manual approval → Plan |
| `true` | `true` | Static validation → Manual approval → No plan |
### Current Approach (Repository Variables)
- ✅ Default: Plans run automatically after validation (fastest workflow)
- ✅ Optional: Set `TFPLAN_PR_APPROVAL_REQUIRED` variable for manual approval gate
- ✅ Optional: Set `TFPLAN_SKIP_ON_PR` variable to skip plan stage
- ✅ True repository-level control via GitHub Actions variables
- ✅ Deploy workflow uses `dev-iac-plan` without reviewers (no approval needed)
- ✅ Deploy workflow uses `dev-iac-apply` with reviewers (approval for apply only)
- ✅ Clear separation: PR approval is variable-controlled, deployment approval is environment-based

## Configuration

The workflow is controlled by optional repository variables. The approval step is configured to run conditionally:

```yaml
on:
  pull_request:
    branches: [main]

approval:
  name: "Approve Terraform Plan"
  needs: static-validation
  if: vars.TFPLAN_PR_APPROVAL_REQUIRED == 'true'
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
