output "container_app_fqdn" {
  description = "Container App FQDN"
  value       = module.container_app.container_app_fqdn
}

output "container_app_id" {
  description = "Container App resource ID"
  value       = module.container_app.container_app_id
}

output "container_app_principal_id" {
  description = "Container App principal ID for role assignment"
  value       = module.container_app.container_app_principal_id
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = module.key_vault.key_vault_name
}

output "app_insights_connection_string" {
  description = "Application Insights connection string"
  value       = module.monitoring.app_insights_connection_string
  sensitive   = true
}

output "acr_login_server" {
  description = "ACR login server for pipeline image push"
  value       = module.container_registry.login_server
}

