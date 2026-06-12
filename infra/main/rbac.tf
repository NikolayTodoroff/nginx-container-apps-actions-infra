resource "azurerm_role_assignment" "kv_workflow_sp" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.workflow_sp_object_id
}

resource "azurerm_role_assignment" "kv_app_secrets_user" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.app_service.app_service_principal_id
}

resource "azurerm_role_assignment" "acr_app_pull" {
  scope                = module.container_registry.acr_id
  role_definition_name = "AcrPull"
  principal_id         = module.app_service.app_service_principal_id
}
