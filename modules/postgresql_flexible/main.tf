resource "azurerm_postgresql_flexible_server" "postgresql_flexible_server" {
  resource_group_name = var.resource_group_name
  name                = var.postgresql_flexible_server_name
  location            = var.location

  sku_name          = join("_", [lookup(local.tier_map, var.tier, "GeneralPurpose"), "Standard", var.size])
  storage_mb        = var.storage_mb
  auto_grow_enabled = var.auto_grow_enabled
  version           = var.postgresql_version

  zone = var.zone

  public_network_access_enabled = var.public_network_access_enabled

  dynamic "high_availability" {
    for_each = var.standby_zone != null && var.tier != "Burstable" ? toset([var.standby_zone]) : toset([])

    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = high_availability.value
    }
  }

  administrator_login    = var.administrator_login
  administrator_password = local.administrator_password

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled

  dynamic "maintenance_window" {
    for_each = var.maintenance_window != null ? toset([var.maintenance_window]) : toset([])

    content {
      day_of_week  = lookup(maintenance_window.value, "day_of_week", 0)
      start_hour   = lookup(maintenance_window.value, "start_hour", 0)
      start_minute = lookup(maintenance_window.value, "start_minute", 0)
    }
  }

  private_dns_zone_id = var.private_dns_zone_id
  delegated_subnet_id = var.delegated_subnet_id

  dynamic "authentication" {
    for_each = var.authentication[*]
    content {
      active_directory_auth_enabled = authentication.value.active_directory_auth_enabled
      password_auth_enabled         = authentication.value.password_auth_enabled
      tenant_id                     = authentication.value.tenant_id
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.private_dns_zone_id != null && var.delegated_subnet_id != null || var.private_dns_zone_id == null && var.delegated_subnet_id == null
      error_message = "var.private_dns_zone_id and var.delegated_subnet_id should either both be set or none of them."
    }
  }
}

resource "random_password" "administrator_password" {
  count = var.administrator_password == null ? 1 : 0

  length  = 32
  special = true
}

#----------------------------------------------------------
# Resource creation: Key Vault Secret
#----------------------------------------------------------
resource "azurerm_key_vault_secret" "postgresql_flexible_administrator_login" {
  name         = "${var.postgresql_flexible_server_name}-login-id"
  value        = var.administrator_login
  key_vault_id = var.key_vault_id
}

#----------------------------------------------------------
# Resource creation: Key Vault Secret
#----------------------------------------------------------
resource "azurerm_key_vault_secret" "postgresql_flexible_administrator_password" {
  name         = "${var.postgresql_flexible_server_name}-password"
  value        = local.administrator_password
  key_vault_id = var.key_vault_id
}


resource "azurerm_postgresql_flexible_server_database" "postgresql_flexible_db" {
  for_each = var.databases

  name      = each.key
  server_id = azurerm_postgresql_flexible_server.postgresql_flexible_server.id
  charset   = each.value.charset
  collation = each.value.collation

}

resource "azurerm_postgresql_flexible_server_configuration" "postgresql_flexible_config" {
  for_each  = var.postgresql_configurations
  name      = each.key
  server_id = azurerm_postgresql_flexible_server.postgresql_flexible_server.id
  value     = each.value
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "firewall_rules" {
  for_each = var.allowed_ip_ranges

  name             = each.key
  server_id        = azurerm_postgresql_flexible_server.postgresql_flexible_server.id
  start_ip_address = each.value.start_ip
  end_ip_address   = each.value.end_ip
}