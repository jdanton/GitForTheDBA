data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

locals {
  tags = {
    project = var.prefix
    purpose = "Git for the DBA demo"
  }
}

resource "azurerm_resource_group" "demo" {
  name     = "rg-${var.prefix}"
  location = var.location
  tags     = local.tags
}
