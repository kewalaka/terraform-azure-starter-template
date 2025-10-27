# Terraform Azure Starter Template

Template for Azure infrastructure using Terraform with using central CI/CD workflows.

Uses shared GitHub Actions workflow here: <https://github.com/kewalaka/github-azure-iac-templates>

## Quick Start

1. **Use this template** to create your repository
1. **Set up GitHub environments and Azure OIDC** ([guide](docs/setup.md))
1. **Create a PR** - validation runs automatically
1. **Approve** - dev deployment runs on main

## How It Works

```mermaid
graph TD
    A[PR Created] --> B[Static Validation]
    B -->|Pass| C{TFPLAN_PR_APPROVAL_REQUIRED?}
    C -->|Not Set| D[Terraform Plan]
    C -->|true| E[Manual Approval Issue]
    E -->|approve| D
    E -->|deny| F[Workflow Stopped]
    D --> G[Post Plan Results]
    
    H[PR Merged to main] --> I[Deploy Workflow]
    I --> J[Terraform Plan]
    J --> K{Environment Protection}
    K -->|Approval| L[Terraform Apply]
    L --> M[Deployment Complete]
    
    style B fill:#e1f5ff
    style E fill:#ffe1e1
    style D fill:#fff4e1
    style L fill:#d4f4dd
```

PRs run automatically with auto-plan by default:

1. **Static validation** (immediate): fmt, validate, TFLint, Checkov
2. **Environment plans** (parallel, automatic): Terraform plan for dev (add more via [guide](docs/adding-environments.md))

For repository-level control, configure optional variables in Settings → Actions → Variables:

- **`TFPLAN_PR_APPROVAL_REQUIRED = true`**: Manual approval required before plans
- **`TFPLAN_SKIP_ON_PR = true`**: Skip plan stage entirely

After merge to main, the deploy workflow runs:

1. **Terraform plan** (no approval)
2. **Terraform apply** (requires environment protection approval on `*-iac-apply` environment)

## Repository Structure

```text
iac/
  ├── main.tf                    # Infrastructure code
  ├── backend.tf                 # State configuration
  └── environments/
      └── dev.terraform.tfvars   # Environment config
.github/workflows/
  ├── terraform-pr.yml           # PR validation
  └── terraform-deploy.yml       # Deployment
```

## Key Features

- Matrix-based validation across environments
- Fast static checks without auth
- OIDC authentication (no stored credentials)
- Parallel environment plans
- **Flexible approval workflow** (repository variable-controlled):
  - Auto-plan by default for PRs (fastest path)
  - Optional manual approval via `TFPLAN_PR_APPROVAL_REQUIRED` variable
  - Optional skip plan via `TFPLAN_SKIP_ON_PR` variable
  - True repository-level control, no code changes needed
- Avoids double approvals during deployment
- Environment protection only on deployment apply stage
- Azure Developer CLI compatible

## Documentation

- [Setup Guide](docs/setup.md) - Configure GitHub environments and Azure OIDC
- [PR Approval Workflow](docs/approval-pr-workflow.md) - How PR approvals work and why
- [Adding Environments](docs/adding-environments.md) - Scale from dev to prod
- [Workflow Design](docs/workflow-design.md) - Architecture decisions and alternatives
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions
- [Using azd locally](docs/using-azd.md) - Optional local workflow with Azure Developer CLI

## License

See [LICENSE.md](LICENSE.md)
