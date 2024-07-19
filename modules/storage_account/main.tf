locals {
  storage_ip_rules = toset(flatten([for cidr in var.allowed_cidrs : (length(regexall("/3.", cidr)) > 0 ? [cidrhost(cidr, 0), cidrhost(cidr, -1)] : [cidr])]))

  pitr_enabled = (
    alltrue([var.storage_blob_data_protection.change_feed_enabled, var.storage_blob_data_protection.versioning_enabled, var.storage_blob_data_protection.container_point_in_time_restore])
    && var.storage_blob_data_protection.delete_retention_policy_in_days > 0
    && var.storage_blob_data_protection.container_delete_retention_policy_in_days > 2
    && !(var.nfsv3_enabled || var.sftp_enabled || var.account_tier == "Premium")
  )
}

resource "azurerm_storage_account" "storage" {
  name                = var.sa_name
  resource_group_name = var.resource_group_name
  location            = var.location

  access_tier              = var.account_kind == "BlockBlobStorage" && var.account_tier == "Premium" ? null : var.access_tier
  account_tier             = var.account_tier
  account_kind             = var.account_kind
  account_replication_type = var.account_replication_type

  min_tls_version                 = var.min_tls_version
  allow_nested_items_to_be_public = var.public_nested_items_allowed
  public_network_access_enabled   = var.public_network_access_enabled
  shared_access_key_enabled       = var.shared_access_key_enabled
  large_file_share_enabled        = var.account_kind != "BlockBlobStorage" && contains(["LRS", "ZRS"], var.account_replication_type)

  sftp_enabled                      = var.sftp_enabled
  nfsv3_enabled                     = var.nfsv3_enabled
  is_hns_enabled                    = var.nfsv3_enabled || var.sftp_enabled ? true : var.hns_enabled
  enable_https_traffic_only         = var.nfsv3_enabled ? false : var.https_traffic_only_enabled
  cross_tenant_replication_enabled  = var.cross_tenant_replication_enabled
  infrastructure_encryption_enabled = var.infrastructure_encryption_enabled

  dynamic "identity" {
    for_each = var.identity_type == null ? [] : ["enabled"]
    content {
      type         = var.identity_type
      identity_ids = endswith(var.identity_type, "UserAssigned") ? var.identity_ids : null
    }
  }

  dynamic "static_website" {
    for_each = var.static_website_config == null ? [] : ["enabled"]
    content {
      index_document     = var.static_website_config.index_document
      error_404_document = var.static_website_config.error_404_document
    }
  }

  dynamic "custom_domain" {
    for_each = var.custom_domain_name != null ? ["enabled"] : []
    content {
      name          = var.custom_domain_name
      use_subdomain = var.use_subdomain
    }
  }

  dynamic "customer_managed_key" {
    for_each = var.customer_managed_key[*]
    content {
      key_vault_key_id          = var.customer_managed_key.key_vault_key_id
      managed_hsm_key_id        = var.customer_managed_key.managed_hsm_key_id
      user_assigned_identity_id = var.customer_managed_key.user_assigned_identity_id
    }
  }

  dynamic "blob_properties" {
    for_each = (
      var.account_kind != "FileStorage" && (var.storage_blob_data_protection != null || length(var.storage_blob_cors_rules) > 0) ? ["enabled"] : []
    )

    content {
      change_feed_enabled      = var.nfsv3_enabled || var.sftp_enabled ? false : var.storage_blob_data_protection.change_feed_enabled
      versioning_enabled       = var.nfsv3_enabled || var.sftp_enabled ? false : var.storage_blob_data_protection.versioning_enabled
      last_access_time_enabled = var.nfsv3_enabled || var.sftp_enabled ? false : var.storage_blob_data_protection.last_access_time_enabled

      dynamic "cors_rule" {
        for_each = var.storage_blob_cors_rules
        content {
          allowed_headers    = cors_rule.value.allowed_headers
          allowed_methods    = cors_rule.value.allowed_methods
          allowed_origins    = cors_rule.value.allowed_origins
          exposed_headers    = cors_rule.value.exposed_headers
          max_age_in_seconds = cors_rule.value.max_age_in_seconds
        }
      }

      dynamic "delete_retention_policy" {
        for_each = var.storage_blob_data_protection.delete_retention_policy_in_days > 0 ? ["enabled"] : []
        content {
          days = var.storage_blob_data_protection.delete_retention_policy_in_days
        }
      }

      dynamic "container_delete_retention_policy" {
        for_each = var.storage_blob_data_protection.container_delete_retention_policy_in_days > 0 ? ["enabled"] : []
        content {
          days = var.storage_blob_data_protection.container_delete_retention_policy_in_days
        }
      }

      dynamic "restore_policy" {
        for_each = local.pitr_enabled ? ["enabled"] : []
        content {
          days = var.storage_blob_data_protection.container_delete_retention_policy_in_days - 1
        }
      }
    }
  }

  # Bug when nfsv3 is activated. The external resource azurerm_storage_account_network_rules is not taken into account
  dynamic "network_rules" {
    for_each = var.nfsv3_enabled ? ["enabled"] : []
    content {
      default_action             = "Deny"
      bypass                     = var.network_bypass
      ip_rules                   = local.storage_ip_rules
      virtual_network_subnet_ids = var.subnet_ids
      dynamic "private_link_access" {
        for_each = var.private_link_access
        content {
          endpoint_resource_id = private_link_access.value.endpoint_resource_id
          endpoint_tenant_id   = private_link_access.value.endpoint_tenant_id
        }
      }
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.account_tier != "Premium" || !local.pitr_enabled
      error_message = "Point in time restore is not supported with Premium Storage Accounts."
    }
  }
}

resource "azurerm_advanced_threat_protection" "threat_protection" {
  enabled            = var.advanced_threat_protection_enabled
  target_resource_id = azurerm_storage_account.storage.id
}

# Network rules
resource "azurerm_storage_account_network_rules" "network_rules" {
  for_each = toset(var.network_rules_enabled && !var.nfsv3_enabled ? ["enabled"] : [])

  storage_account_id = azurerm_storage_account.storage.id

  default_action             = var.default_firewall_action
  bypass                     = var.network_bypass
  ip_rules                   = local.storage_ip_rules
  virtual_network_subnet_ids = var.default_firewall_action == "Deny" ? var.subnet_ids : []
  dynamic "private_link_access" {
    for_each = var.private_link_access
    content {
      endpoint_resource_id = private_link_access.value.endpoint_resource_id
      endpoint_tenant_id   = private_link_access.value.endpoint_tenant_id
    }
  }
}

# Containers
resource "azurerm_storage_container" "container" {
  for_each = try({ for c in var.containers : c.name => c }, {})

  storage_account_name = azurerm_storage_account.storage.name

  name                  = each.key
  container_access_type = each.value.container_access_type
  metadata              = each.value.metadata
}

# Tables
resource "azurerm_storage_table" "table" {
  for_each = try({ for t in var.tables : t.name => t }, {})

  storage_account_name = azurerm_storage_account.storage.name

  name = each.key

  dynamic "acl" {
    for_each = each.value.acl != null ? each.value.acl : []

    content {
      id = acl.value.id

      access_policy {
        permissions = acl.value.permissions
        start       = acl.value.start
        expiry      = acl.value.expiry
      }
    }
  }
}
