output "storage_account_properties" {
  description = "Created Storage Account properties."
  value       = azurerm_storage_account.storage
}

output "storage_account_id" {
  description = "Created Storage Account ID."
  value       = azurerm_storage_account.storage.id
}

output "storage_account_name" {
  description = "Created Storage Account name."
  value       = azurerm_storage_account.storage.name
}

output "storage_account_identity" {
  description = "Created Storage Account identity block."
  value       = azurerm_storage_account.storage.identity
}

output "storage_blob_containers" {
  description = "Created blob containers in the Storage Account."
  value       = azurerm_storage_container.container
}

output "storage_tables" {
  description = "Created tables in the Storage Account."
  value       = azurerm_storage_table.table
}