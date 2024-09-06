terraform {
  required_version = ">= 1.4"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "2.53.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4.3"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "cffda582-a060-4e87-994f-9cff463aa651"
}

resource "azurerm_resource_group" "main_rg" {
  name     = "test-rg"
  location = "eastus"
}

module "key_vault" {
  source              = "./modules/key_vault"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.main_rg.name
  key_vault_name      = "test-kv"
}

module "azuread_application" {
  source                        = "./modules/azuread_application"
  name                          = "test-app"
  redirect_uris                 = ["https://test-webapp.azurewebsites.net/", "https://test-webapp.azurewebsites.net/login/callback", "https://dev.laurel-ag.biz/", "https://dev.laurel-ag.biz/login/callback/", "https://laurel-hsfd.onrender.com/", "http://localhost:8000/accounts/microsoft/login/callback/"]
  access_token_issuance_enabled = true
  id_token_issuance_enabled     = true
  key_vault_id                  = module.key_vault.key_vault_id
  required_resource_access = [
    {
      resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
      resource_access = [
        {
          id   = "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0" # email permission
          type = "Scope"
        },
        {
          id   = "14dad69e-099b-42c9-810b-d002981feec1" # profile permission
          type = "Scope"
        },
        {
          id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # user.read permission
          type = "Scope"
        }
      ]
    }
  ]
  access_token = [
    {
      name = "email"
    },
    {
      name = "upn"
    },
    {
      name = "family_name"
    },
    {
      name = "given_name"
    }
  ]
}