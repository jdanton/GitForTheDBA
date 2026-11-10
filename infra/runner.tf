# The runner VM and its network already exist and are managed elsewhere.
# Terraform only reads them: the VM's system-assigned managed identity becomes
# a database user, and the NAT gateway's public IP (the VM's only way out to
# the internet) gets a SQL firewall rule.
data "azurerm_virtual_machine" "runner" {
  name                = var.runner_name
  resource_group_name = var.runner_resource_group
}

data "azurerm_public_ip" "runner_outbound" {
  name                = var.runner_outbound_ip_name
  resource_group_name = var.runner_resource_group
}

locals {
  runner_principal_id = data.azurerm_virtual_machine.runner.identity[0].principal_id
}
