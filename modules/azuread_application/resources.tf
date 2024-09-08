resource "random_uuid" "app_roles_id" {
  for_each = { for r in var.app_roles : r.value => r }
}

data "azuread_client_config" "current" {}

resource "time_rotating" "rotation_days" {
  rotation_days = var.rotation_days
}

# Azure AD Application
resource "azuread_application" "main" {
  display_name                   = var.name
  identifier_uris                = var.identifier_uris
  owners                         = [data.azuread_client_config.current.object_id]
  sign_in_audience               = var.sign_in_audience
  group_membership_claims        = var.group_membership_claims
  fallback_public_client_enabled = null
  device_only_auth_enabled       = null

  api {
    requested_access_token_version = 2
  }
  optional_claims {
    dynamic "access_token" {
      for_each = var.access_token
      iterator = access_token
      content {
        name                  = access_token.value.name
        essential             = access_token.value.essential
        source                = access_token.value.source
        additional_properties = access_token.value.additional_properties
      }
    }
  }

  web {
    homepage_url  = var.homepage
    redirect_uris = var.redirect_uris

    implicit_grant {
      access_token_issuance_enabled = var.access_token_issuance_enabled
      id_token_issuance_enabled     = var.id_token_issuance_enabled
    }
  }

  dynamic "required_resource_access" {
    for_each = var.required_resource_access
    iterator = resource
    content {
      resource_app_id = resource.value.resource_app_id

      dynamic "resource_access" {
        for_each = resource.value.resource_access
        iterator = access
        content {
          id   = access.value.id
          type = access.value.type
        }
      }
    }
  }

  dynamic "app_role" {
    for_each = var.app_roles
    iterator = resource
    content {
      enabled              = true
      allowed_member_types = resource.value.allowed_member_types
      description          = resource.value.description
      display_name         = resource.value.display_name
      value                = resource.value.value
      id                   = random_uuid.app_roles_id[resource.value.value].result
    }
  }
}

# Service Principal for the Application
resource "azuread_service_principal" "main" {
  client_id                    = azuread_application.main.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

# Grant API Permissions to the Service Principal (optional for automation purposes)
resource "azuread_service_principal_delegated_permission_grant" "this" {
  service_principal_object_id          = azuread_service_principal.main.id
  resource_service_principal_object_id = azuread_service_principal.main.object_id
  claim_values                         = ["email", "profile", "User.Read"]
}

# Service Principal Client secret for the Application
resource "azuread_application_password" "main" {
  application_id = azuread_application.main.id
  display_name   = "${var.name}-key"
  start_date     = time_rotating.rotation_days.id
  end_date       = timeadd(time_rotating.rotation_days.id, "4320h")
}

resource "time_sleep" "wait_for_azuread_secret_creation" {
create_duration = "30s"
depends_on      = [azuread_application_password.main]
}

#----------------------------------------------------------
# Resource creation: Key Vault Secret
#----------------------------------------------------------
resource "azurerm_key_vault_secret" "azuread_application_client_secret" {
  name         = "${var.name}-app-secret"
  value        = azuread_application_password.main.value
  key_vault_id = var.key_vault_id
  depends_on = [ time_sleep.wait_for_azuread_secret_creation ]
}

