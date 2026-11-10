output "resource_group" {
  value = azurerm_resource_group.demo.name
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.demo.fully_qualified_domain_name
}

output "database_name" {
  value = azurerm_mssql_database.widgets.name
}

output "runner_principal_id" {
  value = local.runner_principal_id
}

output "runner_name" {
  value = data.azurerm_virtual_machine.runner.name
}

output "query_command" {
  description = "Query the demo database from your laptop."
  value       = "sqlcmd -S ${azurerm_mssql_server.demo.fully_qualified_domain_name} -d ${azurerm_mssql_database.widgets.name} --authentication-method ActiveDirectoryDefault"
}
