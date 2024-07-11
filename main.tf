locals {
  name_prefix = "${var.unique_name}-${var.location}-${var.location}"
}

resource "azurerm_resource_group" "main_rg" {
  name     = "${local.name_prefix}-rg"
  location = var.location
}

module "vnet" {
  source = "./modules/virtual_network"

  resource_group_name = azurerm_resource_group.main_rg.name
  use_for_each        = var.use_for_each
  vnet_name           = "${local.name_prefix}-vnet"
  vnet_location       = var.location
  address_space       = ["10.0.0.0/16"]
  subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  subnet_names        = ["subnet1", "subnet2", "subnet3"]

  tags = {
    environment  = "dev"
    DeployedFrom = "terraform"
  }
}