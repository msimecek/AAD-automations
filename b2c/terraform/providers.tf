terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.91.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "2.11.0"
    }
  }
  # backend "azurerm" {
  # }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

provider "azuread" {
  tenant_id = "fffab8ac-e5a4-4748-bf3d-3e99a5456a76"
}

data "azurerm_client_config" "current" {}