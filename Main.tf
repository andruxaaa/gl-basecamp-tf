resource "azurerm_resource_group" "ex1" {
  name     = "ex1-resources"
  location = "East US"
}

resource "azurerm_virtual_network" "avn1" {
  name                = "acctvn"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.ex1.location
  resource_group_name = azurerm_resource_group.ex1.name
}
