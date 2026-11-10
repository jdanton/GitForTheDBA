terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state in an Azure Storage account. Copy backend.hcl.example to
  # backend.hcl, fill it in, then: terraform init -backend-config=backend.hcl
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Authenticates with the GITHUB_TOKEN environment variable.
# export GITHUB_TOKEN="$(gh auth token)"
provider "github" {
  owner = var.github_owner
}
