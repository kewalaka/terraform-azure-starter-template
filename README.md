# Base Terraform Solution Template

A streamlined Terraform template for quickly provisioning Azure resources with GitHub-integrated deployments.

## Getting Started

1. **Clone the Template**  

   Clone the repository from GitHub:

    ```bash
    git clone https://github.com/your-org/your-repo.git
    cd your-repo
    ```

2. **Initialize the Environment**  

    Run the helper script to set up the resource group, managed identity, and federated credentials:

    ```powershell
    ./helpers/New-TerraformEnvironment.ps1
    ```

3. **Configure GitHub Environments**  

    After the above step populates your `.env` file, run the GitHub environments script to create and configure deployment environments:

    ```powershell
    ./helpers/New-GitHubEnvironments.ps1
    ```

4. **Proceed with Terraform Deployments**  

    Add content to the IaC folder.

## About the helper scripts

There are two optional script [/helpers/New-AzureEnvironment.ps1](/helpers/New-AzureEnvironment.ps1) provides a simple way to bootstrap initial resources.

Given appropriate access (see the script header) it will make:

- A resource group and managed identity for deployment
- A managed identity for deployment with appropriate permissions to the above, and federated credentials
