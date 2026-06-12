locals {
  prefix = "${var.app_name}-${var.environment}"

  common_tags = {
    environment = var.environment
    app         = var.app_name
    managed_by  = "terraform"
  }

  slo_availability_target = 99.5
}