terraform {

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.25.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.29.0"
    }
  }

  # remote backend for terraform
  backend "azurerm" {
    # The resource_group_name storage_account_name & container_name will come from pipeline as 
    # these are environment specific.
    # These can not be set as variables as that is not supported for a backend configuration block:
    # https://www.terraform.io/docs/language/settings/backends/configuration.html#using-a-backend-block

    key = "terraform.tfstate"
  }

  # version of Terraform to use
  required_version = ">= 1.3.0"
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    key_vault {
      recover_soft_deleted_key_vaults = false
      purge_soft_delete_on_destroy    = false
    }
  }
  skip_provider_registration = "true"
}

# get info about the Azure tenant
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "primary" {}

# get info about the service principal.
data "azuread_service_principal" "logged_in_app" {
  application_id = data.azurerm_client_config.current.client_id
}

# Get info about the resource group the solution is deployed into
data "azurerm_resource_group" "rg_terraform" {
  name = var.resource_group_name
}

resource "azurerm_resource_provider_registration" "provider_registration_policy_insights" {
  name = "Microsoft.PolicyInsights"
}