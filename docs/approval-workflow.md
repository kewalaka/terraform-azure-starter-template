# PR Approval Workflow

The PR workflow uses a marketplace action (`trstringer/manual-approval`) for approvals rather than GitHub environment protection rules. This design choice provides better separation between PR validation and deployment approvals.

## How It Works

When a PR is created:

1. **Static validation runs automatically** (~2 minutes)
   - Terraform format check
   - Terraform validate
   - TFLint
   - Checkov security scanning

2. **Approval issue is created automatically**
   - A GitHub issue is created in the repository
   - The issue includes PR details and a link to the PR
   - Configured approvers receive notifications

3. **Approver responds via issue comment**
   - To approve: Comment `approve` on the issue
   - To deny: Comment `deny` on the issue
   - Timeout: 60 minutes (configurable)

4. **Environment plans run in parallel**
   - After approval, all environment plans execute simultaneously
   - Results are posted as PR comments

## Why Not Environment Protection?

Using environment protection rules for PR approvals creates a problem:

### Previous Approach (Environment Protection)
- ❌ PR uses `dev-iac-plan` environment with required reviewers
- ❌ Deploy workflow also uses `dev-iac-plan` for planning
- ❌ Results in **double approval**: once for plan, once for apply
- ❌ No way to differentiate PR plans from deployment plans

### Current Approach (Manual Approval Action)
- ✅ PR uses manual-approval action (single approval for all environments)
- ✅ Deploy workflow uses `dev-iac-plan` without reviewers (no approval needed)
- ✅ Deploy workflow uses `dev-iac-apply` with reviewers (approval for apply only)
- ✅ Clear separation: PR approval is workflow-based, deployment approval is environment-based

## Configuration

The approval step is configured in `.github/workflows/terraform-pr.yml`:

```yaml
approval:
  name: "Approve Terraform Plan"
  needs: static-validation
  runs-on: ubuntu-latest
  steps:
    - name: Wait for approval
      uses: trstringer/manual-approval@v1
      timeout-minutes: 60
      with:
        secret: ${{ github.TOKEN }}
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
