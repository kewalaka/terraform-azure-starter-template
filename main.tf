terraform {

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.8.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.22.0"
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
  required_version = ">= 1.2.1"
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

# Get info about the resource group the solution is deployed into
data "azurerm_resource_group" "rg_terraform" {
  name = var.resource_group_name
}
