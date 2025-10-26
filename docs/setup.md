# Setup Guide

Complete setup for GitHub environments and Azure OIDC authentication.

## Prerequisites

- Azure subscription with Owner or User Access Administrator role
- GitHub repository with Actions enabled
- Azure CLI installed locally
- Storage account for Terraform state

## 1. Create Service Principal

```bash
# Create the app registration and service principal
az ad app create --display-name "github-terraform-myproject"

# Get the application ID
APP_ID=$(az ad app list --display-name "github-terraform-myproject" --query "[0].appId" -o tsv)

# Create service principal
az ad sp create --id $APP_ID

# Get the object ID of the service principal
SP_OBJECT_ID=$(az ad sp show --id $APP_ID --query "id" -o tsv)

# Assign Contributor role at subscription level
az role assignment create \
  --role Contributor \
  --assignee-object-id $SP_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --scope /subscriptions/<SUBSCRIPTION_ID>

# Grant access to state storage
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee-object-id $SP_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/sttfstateXXXXX
```

## 2. Configure OIDC Federated Credentials

Create federated credentials for each environment:

```bash
# dev-iac-plan
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-myproject-dev-plan",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:myorg/myrepo:environment:dev-iac-plan",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# dev-iac-apply
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-myproject-dev-apply",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:myorg/myrepo:environment:dev-iac-apply",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

Repeat for each additional environment you plan to use.

## 3. Create GitHub Environments

Navigate to Settings → Environments → New environment.

### For PR Validation

Create `dev-iac-plan` with:

- Required reviewers: 1+ (optional but recommended for visibility)
- No deployment branches restriction

### For Deployment

Create `dev-iac-apply` with:

- Required reviewers: 1+ (strongly recommended)
- Deployment branches: `main` only
- Prevent self-review (if available in your plan)

## 4. Add Secrets to Environments

For each environment (`dev-iac-plan`, `dev-iac-apply`), add these secrets:

### Authentication Secrets

| Secret | Value |
|--------|-------|
| `ARM_CLIENT_ID` | Application (client) ID from step 1 |
| `ARM_TENANT_ID` | Azure AD Tenant ID |
| `ARM_SUBSCRIPTION_ID` | Target subscription ID |

### Backend Configuration Secrets

These configure where Terraform stores its state:

| Secret | Value |
|--------|-------|
| `TF_STATE_RESOURCE_GROUP_NAME` | Resource group containing state storage |
| `TF_STATE_STORAGE_ACCOUNT_NAME` | Storage account name for state |
| `TF_STATE_STORAGE_CONTAINER_NAME` | Container name (default: `tfstate`) |
| `TF_STATE_SUBSCRIPTION_ID` | Subscription for state (if different from target) |

**Note**: The workflow uses partial backend configuration. The `iac/backend.tf` file only specifies the backend type:

```hcl
terraform {
  backend "azurerm" {}
}
```

All configuration values come from GitHub environment secrets.

## 5. Verify Setup

Create a test PR:

```bash
git checkout -b test/verify-setup
echo "# Test" >> iac/main.tf
git add iac/main.tf
git commit -m "Test PR workflow"
git push origin test/verify-setup
```

Open PR and verify:

1. Static validation runs immediately
2. Plan job waits for approval
3. After approval, plan runs successfully
4. Results posted to PR

## Troubleshooting

### OIDC authentication fails

Check the federated credential subject matches exactly:

```text
repo:myorg/myrepo:environment:dev-iac-plan
```

### Backend initialization fails

Verify storage account access:

```bash
az storage blob list \
  --account-name sttfstateXXXXX \
  --container-name tfstate \
  --auth-mode login
```

### Environment not found

Ensure environment name in workflow matches exactly (case-sensitive).

## References

- [Azure OIDC with GitHub Actions](https://learn.microsoft.com/azure/developer/github/connect-from-azure)
- [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
