terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
  backend "azurerm" {
    key = "github.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main_rg" {
  name     = "test-dev-eastus-rg"
  location = "eastus"
}

output "resource_group_name" {
  value       = azurerm_resource_group.main_rg.name
  description = "Resource group name"
}

output "resource_group_id" {
  value       = azurerm_resource_group.main_rg.id
  description = "Resource group generated id"
}

output "resource_group_location" {
  value       = azurerm_resource_group.main_rg.location
  description = "Resource group location (region)"
}
