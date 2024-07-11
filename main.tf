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
  vnet_location       = var.location
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