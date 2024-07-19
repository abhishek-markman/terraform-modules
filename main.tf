locals {
  name_prefix = "${var.unique_name}-${var.environment}-${var.location}"
}

resource "azurerm_resource_group" "main_rg" {
  name     = "${local.name_prefix}-rg"
  location = var.location
}

module "vnet" {
  source = "./modules/virtual_network"

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
  source                   = "./modules/storage_account"
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
  source                          = "./modules/postgresql_flexible"
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
  allowed_cidrs = {
    "1" = "10.0.0.0/16"
  }
}

module "app_service_plan" {
  source                = "./modules/app_service_plan"
  app_service_plan_name = "${local.name_prefix}-asp"
  location              = var.location
  resource_group_name   = azurerm_resource_group.main_rg.name
  os_type               = "Linux"
  sku_name              = "B1"
}

module "linux_app_services" {
  source              = "./modules/linux_app_services"
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
    "DB_HOST"     = module.postgresql_flexible.postgresql_flexible_fqdn
    "DB_NAME"     = "${local.name_prefix}-db"
    "DB_USER"     = module.postgresql_flexible.postgresql_flexible_administrator_login
    "DB_PASSWORD" = module.postgresql_flexible.postgresql_flexible_administrator_password
    "DB_PORT"     = 5432
  }
}