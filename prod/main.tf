locals {
  name_prefix = "${var.unique_name}-${var.environment}-${var.location}"
}

resource "azurerm_resource_group" "main_rg" {
  name     = "${local.name_prefix}-rg"
  location = var.location
}

module "vnet" {
  source = "../modules/virtual_network"

  resource_group_name = azurerm_resource_group.main_rg.name
  vnet_name           = "${local.name_prefix}-vnet"
  location            = var.location
  address_space       = ["10.1.0.0/16"]
  subnet_names = {
    subnet1 = {
      subnet_name           = "${local.name_prefix}-vnet-web-subnet"
      subnet_names_prefixes = ["10.1.1.0/24"]
    }
  }

  tags = {
    environment  = "prod"
    DeployedFrom = "terraform"
  }
}

module "storage_account" {
  source                   = "../modules/storage_account"
  sa_name                  = "${var.unique_name}${var.environment}${var.location}strg"
  location                 = var.location
  resource_group_name      = azurerm_resource_group.main_rg.name
  account_replication_type = "LRS"
  containers = [
    {
      name = "${var.unique_name}-${var.environment}"
    }
  ]
}

module "postgresql_flexible" {
  source                          = "../modules/postgresql_flexible"
  postgresql_flexible_server_name = "${local.name_prefix}-postgresql"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.main_rg.name
  tier                            = "Burstable"
  size                            = "B1ms"
  storage_mb                      = 32768
  postgresql_version              = 16
  administrator_login             = "postgresql_admin"
  backup_retention_days           = 7
  geo_redundant_backup_enabled    = false
  public_network_access_enabled   = true
  databases = {
    "${local.name_prefix}-db" = {
      collation = "en_US.utf8"
      charset   = "UTF8"
    }
  }
  allowed_ip_ranges = {
    "allow_azure" = {
      start_ip = "0.0.0.0"
      end_ip   = "0.0.0.0"
    }
  }
}

module "app_service_plan" {
  source                = "../modules/app_service_plan"
  app_service_plan_name = "${local.name_prefix}-asp"
  location              = var.location
  resource_group_name   = azurerm_resource_group.main_rg.name
  os_type               = "Linux"
  sku_name              = "B2"
  worker_count          = 2
}

module "key_vault" {
  source              = "../modules/key_vault"
  location            = var.location
  resource_group_name = azurerm_resource_group.main_rg.name
  key_vault_name      = "${local.name_prefix}-kv"
}

module "azuread_application" {
  source                        = "../modules/azuread_application"
  name                          = "${local.name_prefix}-app"
  redirect_uris                 = ["https://${local.name_prefix}-webapp.azurewebsites.net/", "https://${local.name_prefix}-webapp.azurewebsites.net/login/callback", "https://${local.name_prefix}-webapp.azurewebsites.net/accounts/microsoft/login/callback/", "https://laurel-ag.biz/", "https://laurel-ag.biz/login/callback/", "https://laurel-hsfd.onrender.com/", "http://localhost:8000/accounts/microsoft/login/callback/"]
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

module "linux_app_services" {
  source              = "../modules/linux_app_services"
  app_service_name    = "${local.name_prefix}-webapp"
  location            = var.location
  resource_group_name = azurerm_resource_group.main_rg.name
  service_plan_id     = module.app_service_plan.service_plan_id
  key_vault_id        = module.key_vault.key_vault_id
  site_config = {
    always_on = false
    application_stack = {
      python_version = "3.10"
    }
  }
  app_settings = {
    "ALLOWED_HOSTS"           = "${local.name_prefix}-webapp.azurewebsites.net,laurel-ag.biz"
    "CSRF_TRUSTED_ORIGINS"    = "https://${local.name_prefix}-webapp.azurewebsites.net,https://laurel-ag.biz"
    "AZURE_ACCOUNT_KEY"       = module.storage_account.storage_account_properties.primary_access_key
    "AZURE_ACCOUNT_NAME"      = module.storage_account.storage_account_properties.name
    "AZURE_CONTAINER"         = module.storage_account.storage_blob_containers["${var.unique_name}-${var.environment}"].name
    "DB_NAME"                 = "${local.name_prefix}-db"
    "DB_HOST"                 = module.postgresql_flexible.postgresql_flexible_fqdn
    "DB_USER"                 = module.postgresql_flexible.postgresql_flexible_administrator_login
    "DB_PASSWORD"             = module.postgresql_flexible.postgresql_flexible_administrator_password
    "DB_PORT"                 = 5432
    "DJANGO_SETTINGS_MODULE"  = "laurel.settings.${var.environment}"
    "MICROSOFT_CLIENT_ID"     = module.azuread_application.client_id
    "MICROSOFT_TENANT"        = "common"
    "MICROSOFT_TENANT_ID"     = module.azuread_application.tenant_id
    "MICROSOFT_CLIENT_SECRET" = "@Microsoft.KeyVault(SecretUri=${module.azuread_application.client_secret_id})"
  }
  app_service_logs = {
    detailed_error_messages = false
    failed_request_tracing  = false
    http_logs = {
      file_system = {
        retention_in_days = 1
        retention_in_mb   = 35
      }
    }
  }
}
