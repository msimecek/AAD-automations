resource "azurerm_resource_group" "deployment" {
  name     = var.rg_name
  location = var.location
}

resource "azurerm_aadb2c_directory" "tenant" {
  country_code            = "CZ"
  data_residency_location = "Europe"
  display_name            = var.rg_name
  domain_name             = "${var.rg_name}.onmicrosoft.com"
  resource_group_name     = azurerm_resource_group.deployment.name
  sku_name                = "PremiumP1"
}

output "tenant_id" {
  value = azurerm_aadb2c_directory.tenant.tenant_id
}