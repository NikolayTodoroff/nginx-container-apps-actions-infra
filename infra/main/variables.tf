variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, prod)"
  type        = string
}

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "workflow_sp_object_id" {
  description = "Workflow service principal object ID for Key Vault RBAC"
  type        = string
}

variable "log_analytics_sku" {
  description = "Log Analytics Workspace SKU"
  type        = string
  default     = "PerGB2018"
}

variable "log_analytics_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 30
}

variable "container_image_name" {
  description = "Docker image name and tag"
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "admin_email" {
  description = "Email address for admin alerts"
  type        = string
}