terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.21.1"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "2.28.1"
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