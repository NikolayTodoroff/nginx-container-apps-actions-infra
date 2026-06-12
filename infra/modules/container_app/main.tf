resource "azurerm_container_app_environment" "environment" {
  name                       = "cae-${var.prefix}"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  log_analytics_workspace_id = var.log_analytics_workspace_id
  tags                       = var.tags
}

resource "azurerm_container_app" "app" {
  name                         = "ca-${var.prefix}"
  container_app_environment_id = azurerm_container_app_environment.environment.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Multiple"
  tags                         = var.tags

  identity {
    type = "SystemAssigned"
  }

  registry {
    server   = var.acr_login_server
    identity = "System"
  }

  ingress {
    external_enabled = true
    target_port      = 80

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "nginx-static"
      image  = "${var.acr_login_server}/${var.docker_image_name}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = var.app_insights_connection_string
      }

      env {
        name  = "KeyVaultUri"
        value = var.key_vault_uri
      }
    }

    min_replicas = 1
    max_replicas = 1

    http_scale_rule {
      name                = "http-concurrency-scaler"
      concurrent_requests = 10
    }
  }
}