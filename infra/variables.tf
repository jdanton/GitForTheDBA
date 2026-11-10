variable "subscription_id" {
  description = "Azure subscription to deploy into."
  type        = string
}

variable "location" {
  description = "Azure region for the SQL resources (same region as the runner)."
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Short name used in resource names."
  type        = string
  default     = "gitforthedba"
}

variable "github_owner" {
  description = "GitHub user or org that owns the repo."
  type        = string
  default     = "jdanton"
}

variable "github_repo" {
  description = "Repository name (without the owner)."
  type        = string
  default     = "GitForTheDba"
}

variable "runner_name" {
  description = "Name of the existing self-hosted runner VM. It must have a system-assigned managed identity, which becomes a database user with this name."
  type        = string
  default     = "gh-runner-lnx-1"
}

variable "runner_resource_group" {
  description = "Resource group that holds the existing runner VM."
  type        = string
  default     = "rg-github-runner-eus"
}

variable "runner_outbound_ip_name" {
  description = "Public IP of the NAT gateway the runner's subnet uses for outbound traffic."
  type        = string
  default     = "nat-pip"
}

variable "database_name" {
  description = "Azure SQL database that the workflow deploys to."
  type        = string
  default     = "WidgetDB"
}

variable "entra_admin_login" {
  description = "Display name for the Microsoft Entra admin of the SQL server (normally your UPN). The admin is whoever runs terraform apply."
  type        = string
}

variable "presenter_ip" {
  description = "Public IP of the machine running Terraform and the demo. Terraform needs it to create the runner's database user. Get it with: curl -s https://ifconfig.me"
  type        = string
}

variable "require_approval" {
  description = "Require a reviewer to approve each deployment to the production environment."
  type        = bool
  default     = true
}
