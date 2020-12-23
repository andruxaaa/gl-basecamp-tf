provider "azurerm" {
  features {}
}


#Network_config

resource "azurerm_resource_group" "Andruxa" {
  name     = "AndruxaResourceGroup"
  location = "westeurope"
}

resource "azurerm_network_security_group" "Andruxa" {
  name                = "SG"
  location            = azurerm_resource_group.Andruxa.location
  resource_group_name = azurerm_resource_group.Andruxa.name

  security_rule {
    name                       = "sg"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "sg1"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }


}


resource "azurerm_virtual_network" "Andruxa" {
  name                = "Andruxa-vnet"
  address_space       = ["172.16.1.0/24"]
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.Andruxa.name
}

resource "azurerm_subnet" "Andruxa1" {
  name                 = "Andruxa-subnet1"
  resource_group_name  = azurerm_resource_group.Andruxa.name
  virtual_network_name = azurerm_virtual_network.Andruxa.name
  address_prefixes     = ["172.16.1.0/25"]
}

resource "azurerm_subnet_network_security_group_association" "sb1_sg" {
  subnet_id                 = azurerm_subnet.Andruxa1.id
  network_security_group_id = azurerm_network_security_group.Andruxa.id
}

resource "azurerm_subnet" "Andruxa2" {
  name                 = "Andruxa-subnet2"
  resource_group_name  = azurerm_resource_group.Andruxa.name
  virtual_network_name = azurerm_virtual_network.Andruxa.name
  address_prefixes     = ["172.16.1.128/25"]
}
resource "azurerm_subnet_network_security_group_association" "sb2_sg" {
  subnet_id                 = azurerm_subnet.Andruxa2.id
  network_security_group_id = azurerm_network_security_group.Andruxa.id
}


resource "azurerm_public_ip" "Andruxa" {
  name                = "Andruxa-public-ip"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.Andruxa.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "andruxa"

}


resource "azurerm_public_ip" "vm1" {
  name                = "vm1"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.Andruxa.name
  allocation_method   = "Static"
  sku                 = "Standard"

  zones = ["1"]

}

resource "azurerm_public_ip" "vm2" {
  name                = "vm2"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.Andruxa.name
  allocation_method   = "Static"
  sku                 = "Standard"

  zones = ["2"]

}



#Load Balancer config
resource "azurerm_lb" "Andruxa" {
  name                = "Andruxa-lb"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.Andruxa.name
  sku                 = "Standard"




  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.Andruxa.id

  }

  
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  resource_group_name = azurerm_resource_group.Andruxa.name
  loadbalancer_id     = azurerm_lb.Andruxa.id
  name                = "BackEndAddressPool"

}

resource "azurerm_lb_probe" "Andruxa" {
  resource_group_name = azurerm_resource_group.Andruxa.name
  loadbalancer_id     = azurerm_lb.Andruxa.id
  name                = "ssh-running-probe"
  port                = "80"
}

resource "azurerm_lb_rule" "lbnatrule" {
  resource_group_name            = azurerm_resource_group.Andruxa.name
  loadbalancer_id                = azurerm_lb.Andruxa.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = "80"
  backend_port                   = "80"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bpepool.id
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.Andruxa.id
}



#VM1 creation
resource "azurerm_network_interface" "nic1" {
  name                = "nic1"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.Andruxa.name

  ip_configuration {
    name                          = "IPConfiguration"
    subnet_id                     = azurerm_subnet.Andruxa1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm1.id


  }
}

resource "azurerm_network_interface_backend_address_pool_association" "nic1" {
  network_interface_id    = azurerm_network_interface.nic1.id
  ip_configuration_name   = "IPConfiguration"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bpepool.id
}



resource "azurerm_virtual_machine" "Andruxa" {
  name                  = "vm1"
  location              = "westeurope"
  resource_group_name   = azurerm_resource_group.Andruxa.name
  vm_size               = "Standard_D2_v4"
  network_interface_ids = [azurerm_network_interface.nic1.id]
  zones                 = ["1"]




  delete_os_disk_on_termination = true


  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "mydisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }


  os_profile {
    computer_name  = "vmlab"
    admin_username = var.admin_user
    custom_data    = file("w1.conf")
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = file("~/.ssh/id_rsa.pub")
      path     = "/home/andruxa/.ssh/authorized_keys"
    }

  }

 
}



#VM2 creation

resource "azurerm_network_interface" "nic2" {
  name                = "nic2"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.Andruxa.name
  ip_configuration {
    name                          = "IPConfiguration2"
    subnet_id                     = azurerm_subnet.Andruxa2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm2.id


  }
}

resource "azurerm_network_interface_backend_address_pool_association" "nic2" {
  network_interface_id    = azurerm_network_interface.nic2.id
  ip_configuration_name   = "IPConfiguration2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bpepool.id
}



resource "azurerm_virtual_machine" "Andruxa2" {
  name                  = "vm2"
  location              = "westeurope"
  resource_group_name   = azurerm_resource_group.Andruxa.name
  vm_size               = "Standard_D2_v4"
  network_interface_ids = [azurerm_network_interface.nic2.id]
  zones                 = ["2"]




  delete_os_disk_on_termination = true


  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "mydisk2"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }


  os_profile {
    computer_name  = "vmlab2"
    admin_username = var.admin_user
    custom_data    = file("w2.conf")
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = file("~/.ssh/id_rsa.pub")
      path     = "/home/andruxa/.ssh/authorized_keys"
    }
  }


  
}
