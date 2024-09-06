output "object_id" {
  description = "The object id of application. Can be used to assign roles to user."
  value       = azuread_application.main.object_id
}

output "client_id" {
  description = "The application id of AzureAD application created."
  value       = azuread_application.main.client_id
}

output "client_secret_id" {
  description = "Client secret stored in Key vault secret ID."
  value       = azurerm_key_vault_secret.azuread_application_client_secret.id
  sensitive = true
}

output "tenant_id" {
  description = "The Tenant id of Entra ID."
  value       = data.azuread_client_config.current.tenant_id
}