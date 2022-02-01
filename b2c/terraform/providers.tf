terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.94.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "2.16.0"
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