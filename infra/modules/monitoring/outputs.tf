output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for diagnostic settings"
  value       = azurerm_log_analytics_workspace.log_analytics.id
}

output "app_insights_connection_string" {
  description = "Application Insights connection string for app settings"
  value       = azurerm_application_insights.app_insights.connection_string
  sensitive   = true
}

output "app_insights_id" {
  description = "Application Insights resource ID"
  value       = azurerm_application_insights.app_insights.id
}
