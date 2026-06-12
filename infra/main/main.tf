data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg_main" {
  name     = "rg-main-${local.prefix}"
  location = var.location

  lifecycle {
    prevent_destroy = true
  }
}

module "container_registry" {
  source = "../modules/container-registry"

  prefix              = local.prefix
  resource_group_name = azurerm_resource_group.rg_main.name
  location            = azurerm_resource_group.rg_main.location
  tags                = local.common_tags
}

module "key_vault" {
  source = "../modules/key-vault"

  prefix              = local.prefix
  resource_group_name = azurerm_resource_group.rg_main.name
  location            = azurerm_resource_group.rg_main.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.common_tags
}

module "monitoring" {
  source = "../modules/monitoring"

  prefix                       = local.prefix
  resource_group_name          = azurerm_resource_group.rg_main.name
  location                     = azurerm_resource_group.rg_main.location
  log_analytics_sku            = var.log_analytics_sku
  log_analytics_retention_days = var.log_analytics_retention_days
  tags                         = local.common_tags
}

module "container_app" {
  source = "../modules/container-app"

  prefix              = local.prefix
  resource_group_name = azurerm_resource_group.rg_main.name
  location            = azurerm_resource_group.rg_main.location
  docker_image_name   = var.docker_image_name

  log_analytics_workspace_id     = module.monitoring.log_analytics_workspace_id
  acr_login_server               = module.container_registry.login_server
  key_vault_uri                  = module.key_vault.key_vault_uri
  app_insights_connection_string = module.monitoring.app_insights_connection_string

  tags = local.common_tags
}

# Key Diagnostic setting — KV needs log analytics id, lives here not in key-vault module
resource "azurerm_monitor_diagnostic_setting" "keyvault_diagnostics" {
  name                       = "kv-diag-${local.prefix}"
  target_resource_id         = module.key_vault.key_vault_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Diagnostic setting — Container App needs log analytics id, lives here not in container-app module
resource "azurerm_monitor_diagnostic_setting" "app_diagnostics" {
  name                       = "diag-app-${local.prefix}"
  target_resource_id         = module.container_app.container_app_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_log {
    category = "AppServiceAppLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_application_insights_standard_web_test" "availability" {
  name                    = "avail-${local.prefix}"
  resource_group_name     = azurerm_resource_group.rg_main.name
  location                = azurerm_resource_group.rg_main.location
  application_insights_id = azurerm_application_insights.app_insights.id
  frequency               = 300
  timeout                 = 30
  enabled                 = true
  geo_locations           = ["emea-nl-ams-azr", "emea-gb-db3-azr"]

  request {
    url = "https://${module.container_app.container_app_fqdn}"
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "availability_alert" {
  name                = "alert-avail-${local.prefix}"
  resource_group_name = azurerm_resource_group.rg_main.name
  scopes              = [azurerm_application_insights.app_insights.id]
  description         = "Alert when availability drops below 100%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "availabilityResults/availabilityPercentage"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 100
  }

  action {
    action_group_id = azurerm_monitor_action_group.email_alert.id
  }
}

resource "azurerm_monitor_action_group" "email_alert" {
  name                = "ag-${local.prefix}"
  resource_group_name = azurerm_resource_group.rg_main.name
  short_name          = "avail-alert"

  email_receiver {
    name          = "admin"
    email_address = var.admin_email
  }

  tags = local.common_tags
}