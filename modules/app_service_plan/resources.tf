resource "azurerm_service_plan" "plan" {
  name                         = var.app_service_plan_name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  os_type                      = var.os_type
  sku_name                     = var.sku_name
  zone_balancing_enabled       = local.zone_balancing_enabled
  worker_count                 = local.worker_count
  maximum_elastic_worker_count = var.maximum_elastic_worker_count
  app_service_environment_id   = var.app_service_environment_id
  per_site_scaling_enabled     = var.per_site_scaling_enabled
  tags                         = var.tags
}

locals {
  zone_balancing_enabled = var.sku_name == "Y1" ? false : var.zone_balancing_enabled
  worker_count           = var.sku_name == "Y1" ? null : var.worker_count
}
