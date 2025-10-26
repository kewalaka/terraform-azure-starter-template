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
    B -->|Fast ~2 min| C{Pass?}
    C -->|Yes| D[Environment Plans]
    C -->|No| E[Fix Issues]
    D -->|Requires Approval| F[Post Results]
    
    style B fill:#e1f5ff
    style D fill:#fff4e1
```

PRs run two stages:

1. **Static validation** (immediate): fmt, validate, TFLint, Checkov
2. **Environment plans** (approved): Terraform plan for dev (add more via [guide](docs/adding-environments.md))

After merge, manually deploy via Actions workflow with approval.

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
- Per-environment approvals
- Azure Developer CLI compatible

## Documentation

- [Setup Guide](docs/setup.md) - Configure GitHub environments and Azure OIDC
- [Adding Environments](docs/adding-environments.md) - Scale from dev to prod
- [Workflow Design](docs/workflow-design.md) - Architecture decisions and alternatives
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions
- [Using azd locally](docs/using-azd.md) - Optional local workflow with Azure Developer CLI

## License

See [LICENSE.md](LICENSE.md)
