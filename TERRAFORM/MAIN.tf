###############################################################################
# AI-3008 - Extract insights from visual data on Azure
# Backup / fallback demo environment (deployed, demo-ready end state).
#
# Providers and core scaffolding live here; all resources live in MOD.tf and
# outputs in OUTPUT.tf. Data-plane automation (sample data upload, Content
# Understanding analyzer, AI Search index) is wired via terraform_data in MOD.tf
# and implemented by the PowerShell scripts in ./scripts.
###############################################################################

terraform {
  required_version = ">=1.5"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # 4.x is required for the modern Foundry surface:
      # azurerm_cognitive_account.project_management_enabled and
      # azurerm_cognitive_account_project.
      version = "~>4.20"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.6"
    }
  }
}

provider "azurerm" {
  features {
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

###############################################################################
# Variables
###############################################################################

variable "group_postfix" {
  description = "Unique suffix for the class/instance (keeps resource names unique). Lowercase letters and digits only, max 10 chars (storage account names allow nothing else)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{1,10}$", var.group_postfix))
    error_message = "group_postfix must be 1-10 lowercase letters/digits only (no hyphens, underscores, or uppercase) so the storage account name stays valid (<=24 chars, lowercase alphanumeric)."
  }
}

variable "user_name" {
  type    = string
  default = "demouser"
}

variable "user_password" {
  type    = string
  default = "Azuredemo2020"
}

# Model capacities (thousands of tokens-per-minute for text models). Adjust to
# the quota available in your subscription/region before apply.
variable "chat_capacity" {
  description = "Capacity for the gpt-5.4 chat/vision deployment."
  type        = number
  default     = 50
}

variable "image_capacity" {
  description = "Capacity for the gpt-image-2 deployment."
  type        = number
  default     = 1
}

variable "embedding_capacity" {
  description = "Capacity for the text-embedding-3-large deployment."
  type        = number
  default     = 50
}

variable "cu_completion_capacity" {
  description = "Capacity for the gpt-5.2 completion deployment used by Content Understanding."
  type        = number
  default     = 50
}

# Toggle the data-plane automation (sample data, CU analyzer, AI Search index).
# Requires the Azure CLU/PowerShell scripts and an authenticated `az` session.
variable "enable_data_plane" {
  description = "Run the PowerShell data-plane scripts after the resources are created."
  type        = bool
  default     = true
}

###############################################################################
# Locals
###############################################################################

locals {
  group_name       = "AI3008-${var.group_postfix}"
  class_name       = "ai3008"
  group_name_lower = lower(local.group_name)
  location         = "eastus2"
  random_str       = "vis"
  # Object ID of the lab administrator to grant data-plane RBAC. Replace with
  # your own principal object ID if you run the data-plane scripts.
  admin_oid = "b8e50bc5-6559-4643-a003-2807a8d707f7"

  lab01_name = "lab01"
  lab02_name = "lab02"
  lab03_name = "lab03"
  lab04_name = "lab04"
  lab05_name = "lab05"
  lab06_name = "lab06"
}

data "azurerm_client_config" "current" {}

resource "random_string" "rid" {
  length  = 3
  special = false
  numeric = false
  upper   = false
}

###############################################################################
# Resource groups
###############################################################################

# Main resource group that holds the demo-ready backup environment.
resource "azurerm_resource_group" "rg" {
  name     = local.group_name
  location = local.location

  tags = {
    environment = local.group_name
  }
}

# Empty "Demo" resource group used when the trainer builds everything live
# from scratch during class.
resource "azurerm_resource_group" "demo_rg" {
  name     = "Demo${var.group_postfix}"
  location = local.location

  tags = {
    environment = local.group_name
  }
}
