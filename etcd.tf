resource "azurerm_network_security_group" "etcd" {
  name                = "${var.cluster_name}-${var.environment}-${random_string.id.result}-etcd"
  location            = "${data.azurerm_resource_group.main.location}"
  resource_group_name = "${data.azurerm_resource_group.main.name}"
}

resource "azurerm_network_interface" "etcd" {
  count                     = 3
  name                      = "${var.cluster_name}-${var.environment}-${random_string.id.result}-${format("etcd%d", count.index + 1)}"
  location                  = "${data.azurerm_resource_group.main.location}"
  resource_group_name       = "${data.azurerm_resource_group.main.name}"
  network_security_group_id = "${azurerm_network_security_group.etcd.id}"

  ip_configuration {
    name                          = "${var.cluster_name}-${var.environment}-${random_string.id.result}-${format("etcd%d", count.index + 1)}"
    subnet_id                     = "${data.azurerm_subnet.subnet.id}"
    private_ip_address_allocation = "dynamic"
  }
}

resource "azurerm_virtual_machine" "etcd" {
  count                            = 3
  name                             = "${var.cluster_name}-${var.environment}-${random_string.id.result}-${format("etcd%d", count.index + 1)}"
  location                         = "${data.azurerm_resource_group.main.location}"
  availability_set_id              = "${azurerm_availability_set.nodes.id}"
  resource_group_name              = "${data.azurerm_resource_group.main.name}"
  network_interface_ids            = ["${element(azurerm_network_interface.etcd.*.id, count.index)}"]
  vm_size                          = "Standard_DS2_v2"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    id = "${data.azurerm_image.k8s.id}"
  }

  storage_os_disk {
    name              = "${var.cluster_name}-${var.environment}-${random_string.id.result}-${format("etcd%d", count.index + 1)}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${format("etcd%d", count.index + 1)}"
    admin_username = "ubuntu"
    admin_password = "ef208a6b-a6b0-47f0-be8f-2d2bd2e640ba"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys = {
      path     = "/home/ubuntu/.ssh/authorized_keys"
      key_data = "${var.ssh_public_key}"
    }
  }

  tags = "${merge(var.default_tags, map(
    "environmentinfo", "T:Prod; N:${var.cluster_name}-${var.environment}-${random_string.id.result}",
    "cluster", "${var.cluster_name}-${var.environment}",
    "role", "etcd"
    ))}"
}
