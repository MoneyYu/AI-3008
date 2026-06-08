###############################################################################
# AI-3008 - Resources for the "Extract insights from visual data" demos.
#
# Model selection is validated against the Foundry model retirement schedule
# (https://learn.microsoft.com/azure/ai-foundry/concepts/model-lifecycle-retirement)
# to avoid retired / soon-to-be-retired models. See README for the full table.
###############################################################################

###############################################################################
# Storage - holds sample data for the demos and the AI Search knowledge store.
###############################################################################
resource "azurerm_storage_account" "default" {
  name                            = "${local.class_name}${var.group_postfix}st${random_string.rid.result}"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false

  # Company policy forbids access keys - enforce Entra ID (AAD) auth only.
  shared_access_key_enabled = false

  tags = {
    environment = local.group_name
  }
}

# Sample images for the vision / Content Understanding image demos.
# Containers use storage_account_id (management plane) so they can be created
# without storage data-plane keys (which policy forbids).
resource "azurerm_storage_container" "images" {
  name                  = "sample-images"
  storage_account_id    = azurerm_storage_account.default.id
  container_access_type = "private"
}

# Sample documents/forms for Content Understanding + Document Intelligence.
resource "azurerm_storage_container" "documents" {
  name                  = "sample-documents"
  storage_account_id    = azurerm_storage_account.default.id
  container_access_type = "private"
}

# Document corpus that the AI Search knowledge mining indexer crawls.
resource "azurerm_storage_container" "knowledge_base" {
  name                  = "knowledge-base"
  storage_account_id    = azurerm_storage_account.default.id
  container_access_type = "private"
}

# Target container for the AI Search knowledge store projections.
resource "azurerm_storage_container" "knowledge_store" {
  name                  = "knowledge-store"
  storage_account_id    = azurerm_storage_account.default.id
  container_access_type = "private"
}

###############################################################################
# Role assignments for Entra ID (AAD) data-plane access.
# Because access keys are disabled, every principal that touches blob data
# needs an explicit RBAC role on the storage account.
###############################################################################

# The principal running Terraform (and the data-plane upload script) needs to
# read/write blobs via AAD.
resource "azurerm_role_assignment" "deployer_blob" {
  scope                = azurerm_storage_account.default.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

###############################################################################
# Microsoft Foundry account + project.
# kind = AIServices with project management enabled gives one resource that
# hosts Azure OpenAI model deployments AND Azure Content Understanding.
# Pattern follows the official docs:
# https://learn.microsoft.com/azure/foundry/how-to/create-resource-terraform
###############################################################################
resource "azurerm_cognitive_account" "foundry" {
  name                  = "${local.group_name_lower}-foundry-${random_string.rid.result}"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  kind                  = "AIServices"
  sku_name              = "S0"
  custom_subdomain_name = "${local.group_name_lower}-foundry-${random_string.rid.result}"

  # Company policy enforces Entra ID (AAD) auth only - keys are disabled.
  local_auth_enabled = false

  # Required for the modern Foundry (stateful) experience and projects.
  project_management_enabled = true

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = local.group_name
  }
}

# The principal running the Content Understanding data-plane script needs to
# call the AI Services data plane via AAD.
resource "azurerm_role_assignment" "deployer_cs_user" {
  scope                = azurerm_cognitive_account.foundry.id
  role_definition_name = "Cognitive Services User"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_cognitive_account_project" "project" {
  name                 = "${local.group_name_lower}-project"
  cognitive_account_id = azurerm_cognitive_account.foundry.id
  location             = azurerm_resource_group.rg.location

  identity {
    type = "SystemAssigned"
  }
}

###############################################################################
# Model deployments.
# Deployments are created one at a time (depends_on chain) because the
# Cognitive Services control plane rejects parallel deployment writes.
#
# Versions are pinned and were current/GA as of 2026-06-08. Re-check the
# retirement schedule before each delivery and bump as needed.
###############################################################################

# Chat + vision model (modules 1 & 4). Course labs use gpt-4.1 (retires
# 2026-10-14); gpt-5.4 is the forward-looking GA replacement, vision-enabled
# and Responses-API capable.
resource "azurerm_cognitive_deployment" "gpt" {
  name                 = "gpt-5.4"
  cognitive_account_id = azurerm_cognitive_account.foundry.id

  sku {
    name     = "GlobalStandard"
    capacity = var.chat_capacity
  }

  model {
    format  = "OpenAI"
    name    = "gpt-5.4"
    version = "2026-03-05"
  }
}

# Image generation model (module 2). Default gpt-image-2 (latest GA); the
# model name/version are variables so you can switch to a model your
# subscription has quota for (e.g. gpt-image-1.5) without editing this file.
resource "azurerm_cognitive_deployment" "image" {
  name                 = var.image_model_name
  cognitive_account_id = azurerm_cognitive_account.foundry.id

  sku {
    name     = "GlobalStandard"
    capacity = var.image_capacity
  }

  model {
    format  = "OpenAI"
    name    = var.image_model_name
    version = var.image_model_version
  }

  depends_on = [azurerm_cognitive_deployment.gpt]
}

# Embedding model (module 8) for AI Search integrated vectorization.
resource "azurerm_cognitive_deployment" "embedding" {
  name                 = "text-embedding-3-large"
  cognitive_account_id = azurerm_cognitive_account.foundry.id

  sku {
    name     = "Standard"
    capacity = var.embedding_capacity
  }

  model {
    format  = "OpenAI"
    name    = "text-embedding-3-large"
    version = "1"
  }

  depends_on = [azurerm_cognitive_deployment.image]
}

# Dedicated completion model for Content Understanding (modules 4-6).
# NOTE: Content Understanding GA only supports a specific set of completion
# models (as of 2026-06-08: gpt-4.1 and gpt-5.2). gpt-5.4 (used for the chat /
# vision demos) is NOT yet supported by CU, so CU gets its own gpt-5.2
# deployment (the CU-recommended model). Re-check the CU supported-models list
# and bump this when CU adds newer models:
# https://learn.microsoft.com/azure/ai-services/content-understanding/concepts/models-deployments
resource "azurerm_cognitive_deployment" "cu_completion" {
  name                 = "gpt-5.2"
  cognitive_account_id = azurerm_cognitive_account.foundry.id

  sku {
    name     = "GlobalStandard"
    capacity = var.cu_completion_capacity
  }

  model {
    format  = "OpenAI"
    name    = "gpt-5.2"
    version = "2025-12-11"
  }

  depends_on = [azurerm_cognitive_deployment.embedding]
}
# These are preview / quota-constrained and are deployed in the Foundry portal:
#
#   - sora-2            (version 2025-12-08) - video generation (module 3).
#                       Preview-only; the 2025-10-06 version retires 2026-07-15,
#                       so always pick the 2025-12-08 version.
#   - FLUX.2-pro        - alternative image model (Black Forest Labs), GA.
#   - Phi-4-multimodal-instruct - shown in the ChatCompletions example, GA.
###############################################################################

###############################################################################
# Azure AI Search - knowledge mining (module 8).
###############################################################################
resource "azurerm_search_service" "search" {
  name                = "${local.group_name_lower}-search-${random_string.rid.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = local.search_location
  sku                 = "standard"

  # Company policy enforces Entra ID (AAD) auth only - disable api-key auth
  # and use Azure RBAC for the data plane.
  local_authentication_enabled = false

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = local.group_name
  }
}

# The AI Search managed identity needs to read the source blobs (indexer) and
# write knowledge-store projections - via AAD, since keys are disabled.
resource "azurerm_role_assignment" "search_blob" {
  scope                = azurerm_storage_account.default.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_search_service.search.identity[0].principal_id
}

# The AI Search managed identity calls AI Services (built-in skills) via its
# identity (the skillset uses AIServicesByIdentity), so it needs this role.
resource "azurerm_role_assignment" "search_cs_user" {
  scope                = azurerm_cognitive_account.foundry.id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_search_service.search.identity[0].principal_id
}

# The principal running the build-search-index script manages Search objects
# (data source, skillset, index, indexer) via AAD.
resource "azurerm_role_assignment" "deployer_search_contributor" {
  scope                = azurerm_search_service.search.id
  role_definition_name = "Search Service Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "deployer_search_data" {
  scope                = azurerm_search_service.search.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

###############################################################################
# Azure Document Intelligence (module 7).
###############################################################################
resource "azurerm_cognitive_account" "docintel" {
  name                = "${local.group_name_lower}-docintel-${random_string.rid.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "FormRecognizer"
  sku_name            = "S0"

  # Company policy enforces Entra ID (AAD) auth only - keys are disabled.
  local_auth_enabled = false

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = local.group_name
  }
}

###############################################################################
# Data-plane automation.
# Brings the environment to a "completed" demo-ready state:
#   1. upload sample data to blob storage
#   2. create a Content Understanding analyzer
#   3. build + run the AI Search data source / skillset / index / indexer
#
# Each step runs a PowerShell script (PowerShell + az CLI). Requires an
# authenticated `az` session. Gated by var.enable_data_plane.
###############################################################################

locals {
  pwsh           = "pwsh"
  pwsh_args      = ["-NoProfile", "-File"]
  scripts_dir    = "${path.module}/scripts"
  sampledata_dir = "${path.module}/sample-data"
  cu_analyzer_id = "ai3008invoiceanalyzer"
  search_index   = "knowledge-mining"
}

resource "terraform_data" "upload_sample_data" {
  count = var.enable_data_plane ? 1 : 0

  triggers_replace = [
    azurerm_storage_account.default.id,
    filesha256("${local.scripts_dir}/upload-sample-data.ps1"),
  ]

  depends_on = [
    azurerm_storage_container.images,
    azurerm_storage_container.documents,
    azurerm_storage_container.knowledge_base,
    azurerm_role_assignment.deployer_blob,
  ]

  provisioner "local-exec" {
    interpreter = concat([local.pwsh], local.pwsh_args)
    command     = "${local.scripts_dir}/upload-sample-data.ps1"

    environment = {
      STORAGE_ACCOUNT  = azurerm_storage_account.default.name
      SAMPLE_DATA_PATH = local.sampledata_dir
    }
  }
}

resource "terraform_data" "create_cu_analyzer" {
  count = var.enable_data_plane ? 1 : 0

  triggers_replace = [
    azurerm_cognitive_account.foundry.id,
    filesha256("${local.scripts_dir}/create-cu-analyzer.ps1"),
  ]

  depends_on = [
    terraform_data.upload_sample_data,
    azurerm_cognitive_deployment.cu_completion,
    azurerm_cognitive_deployment.embedding,
    azurerm_role_assignment.deployer_cs_user,
  ]

  provisioner "local-exec" {
    interpreter = concat([local.pwsh], local.pwsh_args)
    command     = "${local.scripts_dir}/create-cu-analyzer.ps1"

    environment = {
      CU_ENDPOINT           = azurerm_cognitive_account.foundry.endpoint
      ANALYZER_ID           = local.cu_analyzer_id
      COMPLETION_DEPLOYMENT = azurerm_cognitive_deployment.cu_completion.name
      EMBEDDING_DEPLOYMENT  = azurerm_cognitive_deployment.embedding.name
    }
  }
}

resource "terraform_data" "build_search_index" {
  count = var.enable_data_plane ? 1 : 0

  triggers_replace = [
    azurerm_search_service.search.id,
    filesha256("${local.scripts_dir}/build-search-index.ps1"),
  ]

  depends_on = [
    terraform_data.upload_sample_data,
    azurerm_cognitive_deployment.embedding,
    azurerm_role_assignment.search_blob,
    azurerm_role_assignment.search_cs_user,
    azurerm_role_assignment.deployer_search_contributor,
    azurerm_role_assignment.deployer_search_data,
  ]

  provisioner "local-exec" {
    interpreter = concat([local.pwsh], local.pwsh_args)
    command     = "${local.scripts_dir}/build-search-index.ps1"

    environment = {
      SEARCH_ENDPOINT      = "https://${azurerm_search_service.search.name}.search.windows.net"
      STORAGE_RESOURCE_ID  = azurerm_storage_account.default.id
      KB_CONTAINER         = azurerm_storage_container.knowledge_base.name
      KS_CONTAINER         = azurerm_storage_container.knowledge_store.name
      AISERVICES_SUBDOMAIN = azurerm_cognitive_account.foundry.endpoint
      INDEX_NAME           = local.search_index
    }
  }
}
