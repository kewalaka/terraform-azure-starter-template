# Troubleshooting

Common issues and solutions.

## Static Validation Failures

### Terraform format check fails

Run locally to fix:

```bash
terraform fmt -recursive iac/
```

### Terraform validate fails

Check syntax errors:

```bash
cd iac
terraform init -backend=false
terraform validate
```

### TFLint errors

Review and fix warnings:

```bash
cd iac
tflint --init
tflint
```

### Checkov security scan fails

Review findings in PR comment. To skip specific checks:

```hcl
resource "azurerm_storage_account" "example" {
  #checkov:skip=CKV_AZURE_123:Reason for skip
  # ... resource config
}
```

## Environment Plan Failures

### Authentication fails

Verify OIDC setup:

- Check federated credential subject matches: `repo:owner/repo:environment:env-name`
- Confirm `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID` are set
- Verify service principal has Contributor role

Test locally:

```bash
az login --service-principal \
  --username $ARM_CLIENT_ID \
  --tenant $ARM_TENANT_ID \
  --federated-token $(curl -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL" | jq -r .value)
```

### Backend initialization fails

Common causes:

**Storage account not accessible:**

```bash
# Verify access
az storage blob list \
  --account-name <STORAGE_ACCOUNT> \
  --container-name tfstate \
  --auth-mode login
```

**Missing role assignment:**

```bash
# Add Storage Blob Data Contributor
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee <SERVICE_PRINCIPAL_OBJECT_ID> \
  --scope /subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Storage/storageAccounts/<ACCOUNT>
```

**Wrong backend config:**

Check secrets match `iac/backend.tf` configuration.

### Plan execution fails

Review the plan output in PR comment for specific errors.

Common issues:

- Resource naming conflicts
- Quota limits reached
- Missing required variables
- Invalid tfvars values

## Deployment Failures

### Environment not found

Environment names are case-sensitive. Verify:

- Workflow uses: `dev-iac-apply`
- GitHub environment named: `dev-iac-apply`

### Approval required but no reviewers

Add required reviewers in Settings → Environments → [env-name] → Required reviewers.

### Apply fails after plan succeeds

State may have changed between plan and apply. Re-run the workflow to generate a fresh plan.

## Workflow Not Triggering

### PR workflow not running

Check trigger conditions in `terraform-pr.yml`:

```yaml
on:
  pull_request:
    branches: [main]
    paths:
      - 'iac/**'
      - '.github/workflows/**'
```

Ensure changes touch those paths.

### Deploy workflow not available

Verify workflow file exists at `.github/workflows/terraform-deploy.yml` in the main branch.

## Matrix Strategy Issues

### Only one environment runs

Check matrix syntax:

```yaml
strategy:
  matrix:
    environment: [dev, tst]  # Array, not single value
```

### Plans run sequentially not in parallel

Remove `max-parallel` constraint:

```yaml
strategy:
  fail-fast: false
  matrix:
    environment: [dev, tst]
  # Do not set max-parallel: 1
```

## Permission Errors

### Cannot create PR comments

Verify workflow permissions:

```yaml
permissions:
  contents: read
  pull-requests: write
```

### Cannot upload SARIF

Verify:

```yaml
permissions:
  security-events: write
```

## Getting Help

- Check [GitHub Actions logs](../../actions) for detailed error messages
- Review [Azure Activity Log](https://portal.azure.com/#view/Microsoft_Azure_ActivityLog) for Azure-side failures
- Verify all secrets are set correctly (no typos, correct values)

## References

- [Terraform Azure Provider Errors](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitHub Actions Troubleshooting](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows)
