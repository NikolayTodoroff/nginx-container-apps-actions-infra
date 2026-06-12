resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "log-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_days
  tags                = var.tags
}

resource "azurerm_application_insights" "app_insights" {
  name                = "appi-${var.prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.log_analytics.id
  application_type    = "web"
  tags                = var.tags
}