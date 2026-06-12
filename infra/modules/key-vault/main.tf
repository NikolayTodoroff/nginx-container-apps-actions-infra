resource "azurerm_key_vault" "keyvault" {
  name                          = "kv-${var.prefix}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  public_network_access_enabled = true
  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  tags                          = var.tags

  lifecycle {
    prevent_destroy = true
  }
}