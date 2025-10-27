# PR Approval Workflow

The PR workflow supports flexible approval options configured at the repository level via GitHub Actions variables. By default, plans run automatically after static validation passes.

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
| `TFPLAN_SKIP_ON_PR` | `true` | Skips the plan during PR stage entirely |

**Note:** These variables are optional. If not set, the workflow defaults to auto-plan behavior.

## Workflow Behavior

When a PR is created:

1. **Static validation runs automatically** (~2 minutes)
   - Terraform format check
   - Terraform validate
   - TFLint
   - Checkov security scanning

2. **Optional approval for Terraform plan** (only if `TFPLAN_PR_APPROVAL_REQUIRED` is set to `true`)
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

### Customization Options for optional approval

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

## References

- [trstringer/manual-approval action](https://github.com/trstringer/manual-approval)
- [GitHub Environments documentation](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
