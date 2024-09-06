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
  address_space       = ["10.0.0.0/16"]
  subnet_names = {
    subnet1 = {
      subnet_name           = "${local.name_prefix}-vnet-web-subnet"
      subnet_names_prefixes = ["10.0.1.0/24"]
    }
  }

  tags = {
    environment  = "dev"
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
      name = "container1"
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
  # allowed_cidrs = {
  #   "1" = "10.0.0.0/16"
  # }
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

module "linux_app_services" {
  source              = "../modules/linux_app_services"
  app_service_name    = "${local.name_prefix}-webapp"
  location            = var.location
  resource_group_name = azurerm_resource_group.main_rg.name
  service_plan_id     = module.app_service_plan.service_plan_id
  site_config = {
    always_on = false
    application_stack = {
      python_version = "3.10"
    }
  }
  app_settings = {
    "ALLOWED_HOSTS"           = "${local.name_prefix}-webapp.azurewebsites.net,laurel-ag.biz"
    CSRF_TRUSTED_ORIGINS      = "https://${local.name_prefix}-webapp.azurewebsites.net,https://laurel-ag.biz"
    AZURE_ACCOUNT_KEY         = module.storage_account.storage_account_properties.primary_access_key
    AZURE_ACCOUNT_NAME        = module.storage_account.storage_account_properties.name
    AZURE_CONTAINER           = "laurel-ag"
    "DB_HOST"                 = module.postgresql_flexible.postgresql_flexible_fqdn
    "DB_NAME"                 = "dev_db"
    "DB_USER"                 = module.postgresql_flexible.postgresql_flexible_administrator_login
    "DB_PASSWORD"             = module.postgresql_flexible.postgresql_flexible_administrator_password
    "DB_PORT"                 = 5432
    DJANGO_SETTINGS_MODULE    = "laurel.settings.dev"
    "MICROSOFT_CLIENT_ID"     = "6fc8501d-2e9c-4bf2-8e34-e9dffb86d3b6"
    "MICROSOFT_TENANT"        = "common"
    "MICROSOFT_TENANT_ID"     = "11855f13-2464-464a-8e0a-b51873160cd3"
    #"DB_NAME"     = "${local.name_prefix}-db"
    #AZURE_CONTAINER           = module.storage_account.storage_blob_containers["container1"].name
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
