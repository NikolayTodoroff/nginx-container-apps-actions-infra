data "azurerm_client_config" "current" {}

data "azurerm_policy_definition" "require_tag" {
  display_name = "Require a tag on resources"
}

data "azurerm_policy_definition" "container_apps_https_only" {
  display_name = "Container Apps should only be accessible over HTTPS"
}

data "azurerm_policy_definition" "container_apps_managed_identity" {
  display_name = "Managed Identity should be enabled for Container Apps"
}

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

resource "azurerm_application_insights_workbook" "sre_dashboard" {
  name                = "wb-sre-${local.prefix}"
  resource_group_name = azurerm_resource_group.rg_main.name
  location            = azurerm_resource_group.rg_main.location
  display_name        = "SRE Dashboard — ${local.prefix}"
  source_id           = module.monitoring.app_insights_id
  tags                = local.common_tags

  data_json = jsonencode({
    version = "Notebook/1.0"
    items = [
      {
        type = 1
        content = {
          json = "## SRE Dashboard\n\n**SLO Target:** ${local.slo_availability_target}% availability\n\n**Error Budget:** ${100 - local.slo_availability_target}% (~${format("%.1f", (100 - local.slo_availability_target) / 100 * 30 * 24)} hours per 30 days)"
        }
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query   = "availabilityResults | where timestamp > ago(24h) | summarize SuccessRate = 100.0 * countif(success == true) / count() by bin(timestamp, 1h)"
          size    = 0
          title   = "Availability — Last 24 Hours"
          timeContext = {
            durationMs = 86400000
          }
          queryType    = 0
          resourceType = "microsoft.insights/components"
          visualization = "linechart"
        }
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query   = "requests | where timestamp > ago(24h) | summarize RequestCount = count(), AvgDurationMs = avg(duration) by bin(timestamp, 1h)"
          size    = 0
          title   = "Request Volume and Latency — Last 24 Hours"
          timeContext = {
            durationMs = 86400000
          }
          queryType    = 0
          resourceType = "microsoft.insights/components"
          visualization = "linechart"
        }
      }
    ]
  })
}

resource "azurerm_resource_group_policy_assignment" "require_environment_tag" {
  name                 = "require-env-tag-${local.prefix}"
  resource_group_id    = azurerm_resource_group.rg_main.id
  policy_definition_id = data.azurerm_policy_definition.require_tag.id
  display_name         = "Require environment tag — ${local.prefix}"
  description          = "Enforces that all resources in this resource group have an 'environment' tag, supporting cost allocation and governance."

  parameters = jsonencode({
    tagName = {
      value = "environment"
    }
  })
}

resource "azurerm_resource_group_policy_assignment" "container_apps_https_only" {
  name                 = "aca-https-only-${local.prefix}"
  resource_group_id    = azurerm_resource_group.rg_main.id
  policy_definition_id = data.azurerm_policy_definition.container_apps_https_only.id
  display_name         = "Container Apps HTTPS only — ${local.prefix}"
  description          = "Audits that Container Apps in this resource group are only accessible over HTTPS."
}

resource "azurerm_resource_group_policy_assignment" "container_apps_managed_identity" {
  name                 = "aca-managed-identity-${local.prefix}"
  resource_group_id    = azurerm_resource_group.rg_main.id
  policy_definition_id = data.azurerm_policy_definition.container_apps_managed_identity.id
  display_name         = "Container Apps Managed Identity required — ${local.prefix}"
  description          = "Audits that Container Apps in this resource group use Managed Identity for authentication."
}

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