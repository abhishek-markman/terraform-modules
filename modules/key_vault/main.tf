#---------------------------------------------------------------
# Data Sources
#---------------------------------------------------------------

data "azurerm_client_config" "current" {}

#---------------------------------------------------------------
# Resource creation: Key Vault
#---------------------------------------------------------------
resource "azurerm_key_vault" "key-vault" {
  name                            = var.key_vault_name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  enabled_for_disk_encryption     = var.enabled_for_disk_encryption
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days      = var.soft_delete_retention_days
  purge_protection_enabled        = var.purge_protection_enabled
  sku_name                        = var.sku_name
  enabled_for_deployment          = var.enabled_for_deployment
  enabled_for_template_deployment = var.enabled_for_template_deployment
  enable_rbac_authorization       = var.enable_rbac_authorization
  public_network_access_enabled   = var.public_network_access_enabled

  dynamic "network_acls" {
    for_each = var.network_acls
    iterator = acl

    content {
      bypass                     = acl.value.bypass
      default_action             = acl.value.default_action
      ip_rules                   = acl.value.ip_rules
      virtual_network_subnet_ids = acl.value.virtual_network_subnet_ids
    }
  }
}

resource "azurerm_role_assignment" "add_current_user_kv" {
  scope                = azurerm_key_vault.key-vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

#---------------------------------------------------------------
# Resource creation: Key Vault Access Policy
#---------------------------------------------------------------

resource "azurerm_key_vault_access_policy" "key_vault_access_policy" {
  for_each                = var.enable_rbac_authorization == false ? {} : var.kv_access_policy
  key_vault_id            = azurerm_key_vault.key-vault.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = data.azurerm_client_config.current.object_id
  key_permissions         = lookup(each.value, "key_permissions", null)
  secret_permissions      = lookup(each.value, "secret_permissions", null)
  storage_permissions     = lookup(each.value, "storage_permissions", null)
  certificate_permissions = lookup(each.value, "certificate_permissions", null)
  application_id          = lookup(each.value, "application_id", null)
}

#---------------------------------------------------------------
# Resource creation: Key Vault Private Endpoint
#---------------------------------------------------------------
resource "azurerm_private_endpoint" "kv-pvt-endpoint" {
  count               = var.public_network_access_enabled ? 0 : 1
  name                = "${azurerm_key_vault.key-vault.name}-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${azurerm_key_vault.key-vault.name}-privateserviceconnection"
    private_connection_resource_id = azurerm_key_vault.key-vault.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
}

# DNS A Record to resolve the Private DNS fqdn
resource "azurerm_private_dns_a_record" "dns_a_kv" {
  count               = var.public_network_access_enabled ? 0 : 1
  name                = azurerm_key_vault.key-vault.name
  zone_name           = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = azurerm_private_endpoint.kv-pvt-endpoint[0].custom_dns_configs.0.ip_addresses
  depends_on          = [azurerm_private_endpoint.kv-pvt-endpoint]
}

#---------------------------------------------------------------
# Resource creation: Key Vault Key
#---------------------------------------------------------------
resource "azurerm_key_vault_key" "kv_key" {
  for_each        = var.kv_key
  name            = each.value["name"]
  key_vault_id    = azurerm_key_vault.key-vault.id
  key_type        = each.value["key_type"]
  key_size        = each.value["key_size"]
  curve           = lookup(each.value, "curve", null)
  not_before_date = lookup(each.value, "not_before_date", null)
  expiration_date = lookup(each.value, "expiration_date", null)
  key_opts        = each.value["key_opts"]
}