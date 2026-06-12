output "container_app_id" {
  description = "Container App resource ID for diagnostic settings"
  value       = azurerm_container_app.app.id
}

output "container_app_principal_id" {
  description = "Container App system-assigned managed identity principal ID"
  value       = azurerm_container_app.app.identity[0].principal_id
}

output "container_app_fqdn" {
  description = "Container App default FQDN (ingress URL)"
  value       = azurerm_container_app.app.latest_revision_fqdn
}

output "container_app_environment_id" {
  description = "Container App Environment resource ID"
  value       = azurerm_container_app_environment.environment.id
}