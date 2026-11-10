# Entra-only authentication: no SQL logins and no sa password. The person who
# runs terraform apply is the server's Entra admin.
resource "azurerm_mssql_server" "demo" {
  name                = "sql-${var.prefix}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  version             = "12.0"
  minimum_tls_version = "1.2"
  tags                = local.tags

  azuread_administrator {
    login_username              = var.entra_admin_login
    object_id                   = data.azurerm_client_config.current.object_id
    azuread_authentication_only = true
  }
}

# Serverless General Purpose: pauses after an hour idle, so it costs almost
# nothing between demos. A paused database takes about a minute to resume.
resource "azurerm_mssql_database" "widgets" {
  name                        = var.database_name
  server_id                   = azurerm_mssql_server.demo.id
  sku_name                    = "GP_S_Gen5_1"
  min_capacity                = 0.5
  auto_pause_delay_in_minutes = 60
  max_size_gb                 = 5
  storage_account_type        = "Local"
  tags                        = local.tags
}

# The runner reaches the internet (and so Azure SQL) through a NAT gateway with
# a static public IP.
resource "azurerm_mssql_firewall_rule" "runner" {
  name             = var.runner_name
  server_id        = azurerm_mssql_server.demo.id
  start_ip_address = data.azurerm_public_ip.runner_outbound.ip_address
  end_ip_address   = data.azurerm_public_ip.runner_outbound.ip_address
}

# Your laptop, for the step below and for querying the database in the demo.
resource "azurerm_mssql_firewall_rule" "presenter" {
  name             = "presenter"
  server_id        = azurerm_mssql_server.demo.id
  start_ip_address = var.presenter_ip
  end_ip_address   = var.presenter_ip
}

# Azure SQL can only create a user for a managed identity through T-SQL, run by
# an Entra principal. This runs sqlcmd on your machine with your az login.
resource "terraform_data" "runner_db_user" {
  triggers_replace = [
    azurerm_mssql_database.widgets.id,
    local.runner_principal_id,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      for attempt in 1 2 3 4 5; do
        sqlcmd -S "${azurerm_mssql_server.demo.fully_qualified_domain_name}" \
               -d "${azurerm_mssql_database.widgets.name}" \
               --authentication-method ActiveDirectoryDefault -b -l 60 \
               -Q "IF USER_ID(N'${var.runner_name}') IS NULL
                     CREATE USER [${var.runner_name}] FROM EXTERNAL PROVIDER;
                   ALTER ROLE db_ddladmin   ADD MEMBER [${var.runner_name}];
                   ALTER ROLE db_datareader ADD MEMBER [${var.runner_name}];
                   ALTER ROLE db_datawriter ADD MEMBER [${var.runner_name}];" && exit 0
        echo "sqlcmd failed (attempt $attempt). The firewall rule may still be propagating. Retrying in 20s..."
        sleep 20
      done
      exit 1
    EOT
  }

  depends_on = [azurerm_mssql_firewall_rule.presenter]
}
