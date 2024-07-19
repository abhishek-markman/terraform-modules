resource "azurerm_virtual_network" "vnet" {
  address_space       = var.address_space
  location            = var.location
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
  bgp_community       = var.bgp_community
  dns_servers         = var.dns_servers
  tags                = var.tags

  dynamic "ddos_protection_plan" {
    for_each = var.ddos_protection_plan != null ? [var.ddos_protection_plan] : []

    content {
      enable = ddos_protection_plan.value.enable
      id     = ddos_protection_plan.value.id
    }
  }
}

resource "azurerm_subnet" "subnet" {
  for_each = var.subnet_names

  address_prefixes                              = each.value.subnet_names_prefixes
  name                                          = each.value.subnet_name
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = azurerm_virtual_network.vnet.name
  service_endpoints                             = try(each.value.subnet_service_endpoints, null)
  private_endpoint_network_policies             = try(each.value.private_link_endpoint_enabled, "Disabled")
  private_link_service_network_policies_enabled = try(each.value.private_link_endpoint_enabled, false)

  dynamic "delegation" {
    for_each = try(each.value.subnet_delegation, {})

    content {
      name = delegation.key

      service_delegation {
        name    = lookup(delegation.value, "service_name")
        actions = lookup(delegation.value, "service_actions", [])
      }
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "subnet_association" {
  for_each                  = var.nsg_subnet_association
  subnet_id                 = azurerm_subnet.subnet[each.value.subnet_key].id
  network_security_group_id = each.value.network_security_group_id
}

resource "azurerm_subnet_route_table_association" "route_table_association" {
  for_each       = var.subnet_route_table_association
  subnet_id      = azurerm_subnet.subnet[each.value.subnet_key].id
  route_table_id = each.value.route_table_id
}