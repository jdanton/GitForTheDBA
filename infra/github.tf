# Not secrets: the runner authenticates with its managed identity.
resource "github_actions_variable" "sql_server" {
  repository    = var.github_repo
  variable_name = "SQL_SERVER"
  value         = azurerm_mssql_server.demo.fully_qualified_domain_name
}

resource "github_actions_variable" "sql_database" {
  repository    = var.github_repo
  variable_name = "SQL_DATABASE"
  value         = azurerm_mssql_database.widgets.name
}

# The deploy job targets this environment. It requires your approval and only
# accepts deployments from main.
data "github_user" "me" {
  username = "" # empty = the account that owns GITHUB_TOKEN
}

resource "github_repository_environment" "production" {
  repository  = var.github_repo
  environment = "production"

  dynamic "reviewers" {
    for_each = var.require_approval ? [1] : []
    content {
      users = [tonumber(data.github_user.me.id)]
    }
  }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "main_only" {
  repository     = var.github_repo
  environment    = github_repository_environment.production.environment
  branch_pattern = "main"
}
