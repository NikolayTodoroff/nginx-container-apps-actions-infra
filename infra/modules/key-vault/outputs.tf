output "key_vault_id" {
  description = "Key Vault resource ID"
  value       = azurerm_key_vault.keyvault.id
}

output "key_vault_uri" {
  description = "Key Vault URI for app settings"
  value       = azurerm_key_vault.keyvault.vault_uri
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.keyvault.name
}