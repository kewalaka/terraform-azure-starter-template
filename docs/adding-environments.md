# Adding New Environments

This guide shows how to add additional environments (tst, uat, prod) to your Terraform deployment pipeline.

## Quick Start

The repository starts with a single `dev` environment. To add more environments, follow these three steps:

### 1. Create the tfvars file

Copy the dev template and customize for your new environment:

```bash
cp iac/environments/dev.terraform.tfvars iac/environments/prod.terraform.tfvars
```

Edit the new file with environment-specific values (resource names, SKUs, etc.).

### 2. Update the PR workflow

Edit `.github/workflows/terraform-pr.yml` and add your environment to the matrix:

```yaml
strategy:
  fail-fast: false
  matrix:
    environment: [dev, prod]  # Add prod here
```

### 3. Configure GitHub Environments

Create two GitHub environments for the new environment:

#### prod-iac-plan (for PR validation)

1. Go to Settings → Environments → New environment
2. Name: `prod-iac-plan`
3. Add required reviewers (1+ people who must approve before plan runs)
4. Add these secrets:
   - `ARM_CLIENT_ID`
   - `ARM_SUBSCRIPTION_ID`
   - `ARM_TENANT_ID`
   - `TF_STATE_RESOURCE_GROUP_NAME`
   - `TF_STATE_STORAGE_ACCOUNT_NAME`
   - `TF_STATE_STORAGE_CONTAINER_NAME` (optional, defaults to 'tfstate')
   - `TF_STATE_SUBSCRIPTION_ID` (optional, defaults to ARM_SUBSCRIPTION_ID)

#### prod-iac-apply (for deployment)

1. Go to Settings → Environments → New environment
2. Name: `prod-iac-apply`
3. Add required reviewers (1+ people who must approve before apply runs)
4. Add the same secrets as above

## How It Works

### PR Workflow (terraform-pr.yml)

When you open a PR, the workflow:

1. **Static validation** runs immediately (no approval needed):
   - Terraform fmt, validate
   - TFLint
   - Checkov security scan

2. **Environment plans** run in parallel after approval:
   - Each environment in the matrix requires approval via its `-iac-plan` environment
   - Plans run simultaneously once approved
   - Results are posted as PR comments

### Deploy Workflow (terraform-deploy.yml)

After merging to main, manually trigger deployment:

1. Go to Actions → Terraform Deploy
2. Click "Run workflow"
3. Select environment (dev, prod, etc.)
4. Approve via the `-iac-apply` environment protection rule
5. Terraform applies changes

## Example: Adding Test and Production

```yaml
# .github/workflows/terraform-pr.yml
matrix:
  environment: [dev, tst, prod]
```

With this configuration:

- PRs will validate all three environments in parallel
- Each environment requires separate approval before plan runs
- Reviewers can see all environment impacts before merging
- After merge, deploy each environment independently

## Benefits of This Pattern

- **Gradual rollout**: Start with dev, add environments as confidence grows
- **Parallel validation**: All environments validate simultaneously, reducing wait time
- **Independent approvals**: Different teams can approve different environments
- **Consistent process**: Same workflow pattern scales from 1 to N environments
