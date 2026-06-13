variable "prefix" {
  description = "Resource name prefix"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for the Container App Environment"
  type        = string
}

variable "acr_login_server" {
  description = "ACR login server URL (without https://)"
  type        = string
}

variable "container_image_name" {
  description = "Docker image name and tag"
  type        = string
}

variable "key_vault_uri" {
  description = "Key Vault URI for app settings"
  type        = string
}

variable "app_insights_connection_string" {
  description = "Application Insights connection string"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}