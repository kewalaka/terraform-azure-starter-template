# Testing the New PR Approval Workflow

This document provides a testing guide to validate that the new approval workflow functions correctly.

## Prerequisites

Before testing, ensure the following administrative setup is complete:

1. **Remove reviewers from plan environments:**
   - Navigate to Settings → Environments → `dev-iac-plan`
   - Remove all required reviewers
   - Keep all secrets configured

2. **Verify reviewers on apply environments:**
   - Navigate to Settings → Environments → `dev-iac-apply`
   - Ensure at least 1 required reviewer is configured
   - Ensure deployment branches limited to `main`

## Test Scenario 1: PR Workflow with Approval

### Expected Behavior

1. Create a PR with changes to `iac/` directory
2. Static validation runs automatically (~2 minutes)
3. If validation passes, an approval issue is created automatically
4. Workflow waits for approval (timeout: 60 minutes)
5. Approver comments `approve` on the issue
6. Environment plans run in parallel
7. Plan results posted to PR

### Steps to Test

```bash
# 1. Create a test branch
git checkout -b test/pr-approval-workflow

# 2. Make a small change to trigger workflow
echo "# Test change" >> iac/main.tf

# 3. Commit and push
git add iac/main.tf
git commit -m "Test: PR approval workflow"
git push origin test/pr-approval-workflow

# 4. Create PR via GitHub UI or gh CLI
gh pr create --title "Test: PR approval workflow" --body "Testing new approval mechanism"
```

### Validation Checklist

- [ ] PR created successfully
- [ ] Static validation job starts automatically
- [ ] Static validation completes (check for fmt, validate, tflint, checkov)
- [ ] Static validation results posted as PR comment
- [ ] Approval job starts after static validation
- [ ] GitHub issue created with title "Approve Terraform Plan for PR #X"
- [ ] Issue contains PR details and instructions
- [ ] Workflow shows "Waiting for approval" status
- [ ] Can navigate to approval issue from workflow
- [ ] Commenting `approve` on issue continues workflow
- [ ] Plan-environments job starts after approval
- [ ] Plans run for all environments in matrix
- [ ] Plan results posted to PR as comments
- [ ] Workflow completes successfully

## Test Scenario 2: Approval Denial

### Expected Behavior

1. Create a PR with intentionally problematic changes
2. Static validation runs
3. Approval issue created
4. Approver comments `deny` on the issue
5. Workflow fails and stops
6. No plans are executed

### Steps to Test

```bash
# 1. Create another test branch
git checkout -b test/pr-approval-denial

# 2. Make a change
echo "# Another test" >> iac/main.tf

# 3. Commit and push
git add iac/main.tf
git commit -m "Test: PR approval denial"
git push origin test/pr-approval-denial

# 4. Create PR
gh pr create --title "Test: PR approval denial" --body "Testing denial mechanism"

# 5. Wait for approval issue to be created
# 6. Comment "deny" on the issue
```

### Validation Checklist

- [ ] PR created successfully
- [ ] Static validation completes
- [ ] Approval issue created
- [ ] Commenting `deny` on issue fails the workflow
- [ ] Workflow stops without running plans
- [ ] No plan results posted to PR
- [ ] Workflow marked as failed

## Test Scenario 3: Approval Timeout

### Expected Behavior

1. Create a PR
2. Static validation runs
3. Approval issue created
4. No one approves within timeout (60 minutes)
5. Workflow times out and fails
6. No plans are executed

### Steps to Test

**Note:** This test requires waiting 60 minutes. To test faster:

1. Temporarily reduce timeout in workflow:
   ```yaml
   timeout-minutes: 2  # 2 minutes for testing
   ```

2. Create a PR and wait for timeout

3. Revert timeout change after testing

### Validation Checklist

- [ ] Approval issue created
- [ ] Workflow waits for configured timeout period
- [ ] After timeout, workflow fails
- [ ] No plans executed
- [ ] Can push new commit to trigger new approval

## Test Scenario 4: Deploy Workflow (No Double Approval)

### Expected Behavior

1. Merge PR to main
2. Deploy workflow triggered (or run manually)
3. Plan stage runs WITHOUT approval (no pause)
4. Apply stage requires approval via environment protection
5. Only ONE approval needed (not two)

### Steps to Test

```bash
# 1. Merge one of the test PRs to main
gh pr merge <pr-number> --squash

# 2. Or trigger manually
gh workflow run "Deploy IaC using Terraform" \
  --field terraform_action=apply \
  --field target_environment=dev \
  --field destroy_resources=false

# 3. Watch the workflow execution
gh run watch
```

### Validation Checklist

- [ ] Deploy workflow starts automatically (on push) or manually
- [ ] Plan stage starts immediately (no approval needed)
- [ ] Plan completes successfully
- [ ] Apply stage waits for environment protection approval
- [ ] Only ONE approval required (for apply, not for plan)
- [ ] After approval, apply runs successfully
- [ ] Total approvals during deployment: 1 (not 2)

## Test Scenario 5: Multiple Environments

### Expected Behavior

If you have multiple environments in the matrix (e.g., `[dev, tst, uat]`):

1. Single approval gates ALL environment plans
2. All plans run in parallel after approval
3. Each environment uses its own secrets from environment

### Steps to Test

**Prerequisites:** Add more environments to matrix in workflow file

```yaml
matrix:
  environment: [dev, tst, uat]
```

### Validation Checklist

- [ ] Single approval issue created (not one per environment)
- [ ] After approval, all environment plans start simultaneously
- [ ] Plans run in parallel (check job timing)
- [ ] Each plan uses correct environment secrets
- [ ] All plan results posted to PR
- [ ] If one fails, others continue (fail-fast: false)

## Troubleshooting Tests

### Issue Not Created

**Symptoms:** Approval job starts but no issue appears

**Checks:**
- Verify `issues: write` permission in workflow
- Check workflow run logs for errors
- Verify `github.TOKEN` has required scopes
- Check repository Issues tab is enabled

### Approval Not Recognized

**Symptoms:** Commenting "approve" doesn't continue workflow

**Checks:**
- Verify commenter is in `approvers` list
- Check comment is exactly `approve` (case-insensitive)
- Look for typos in issue comment
- Verify workflow is still running (not timed out)

### Environment Secrets Not Found

**Symptoms:** Plan stage fails with missing secrets

**Checks:**
- Verify environment name matches exactly
- Check environment secrets are configured
- Verify environment exists in repository settings
- Confirm secret names match workflow expectations

### Plan Still Requires Approval in Deploy

**Symptoms:** Deploy workflow pauses at plan stage

**Checks:**
- Verify `dev-iac-plan` has NO required reviewers
- Check environment protection rules
- Confirm correct environment name used
- Look for any wait timer configured

## Expected Outcomes Summary

| Workflow | Stage | Approval Required | Approval Method |
|----------|-------|-------------------|-----------------|
| PR | Static Validation | No | Automatic |
| PR | Approval | Yes (1) | Issue comment |
| PR | Plans | No | Automatic after approval |
| Deploy | Plan | No | Automatic |
| Deploy | Apply | Yes (1) | Environment protection |

**Total Approvals:**
- Per PR: 1 approval (via issue)
- Per Deployment: 1 approval (via environment protection on apply)
- Previously: 1 for PR + 2 for deployment (plan + apply) = 3 total
- Now: 1 for PR + 1 for deployment (apply only) = 2 total

## Cleanup After Testing

```bash
# Delete test branches
git branch -D test/pr-approval-workflow test/pr-approval-denial

# Close test PRs if not merged
gh pr close <pr-number>

# Delete remote branches
git push origin --delete test/pr-approval-workflow
git push origin --delete test/pr-approval-denial

# Close approval issues
gh issue close <issue-number>
```

## Success Criteria

All test scenarios pass with these results:

✅ PR approval works via issue comment  
✅ Denial properly stops workflow  
✅ Timeout properly fails workflow  
✅ Deploy workflow requires only one approval (on apply)  
✅ Multiple environments share single approval  
✅ No double approvals during deployment  
✅ Environment protection still works for apply stage  

If all criteria are met, the implementation is successful and ready for production use.
