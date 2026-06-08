###############################################################################
# AI-3008 - Outputs (endpoints, keys, names).
# Sensitive values are flagged; retrieve with `terraform output -raw <name>`.
###############################################################################

output "resource_group_name" {
  description = "Main resource group for the demo environment."
  value       = azurerm_resource_group.rg.name
}

output "location" {
  value = local.location
}

# --- Microsoft Foundry (AI Services) -----------------------------------------
output "foundry_name" {
  value = azurerm_cognitive_account.foundry.name
}

output "foundry_endpoint" {
  description = "Endpoint used for Azure OpenAI and Content Understanding calls."
  value       = azurerm_cognitive_account.foundry.endpoint
}

output "foundry_key" {
  value     = azurerm_cognitive_account.foundry.primary_access_key
  sensitive = true
}

output "foundry_project_name" {
  value = azurerm_cognitive_account_project.project.name
}

# --- Model deployments -------------------------------------------------------
output "chat_deployment" {
  value = azurerm_cognitive_deployment.gpt.name
}

output "image_deployment" {
  value = azurerm_cognitive_deployment.image.name
}

output "embedding_deployment" {
  value = azurerm_cognitive_deployment.embedding.name
}

output "cu_completion_deployment" {
  description = "gpt-5.2 deployment used by Content Understanding."
  value       = azurerm_cognitive_deployment.cu_completion.name
}

# --- Azure AI Search ---------------------------------------------------------
output "search_endpoint" {
  value = "https://${azurerm_search_service.search.name}.search.windows.net"
}

output "search_admin_key" {
  value     = azurerm_search_service.search.primary_key
  sensitive = true
}

output "search_index_name" {
  value = local.search_index
}

# --- Storage -----------------------------------------------------------------
output "storage_account_name" {
  value = azurerm_storage_account.default.name
}

output "storage_primary_key" {
  value     = azurerm_storage_account.default.primary_access_key
  sensitive = true
}

# --- Azure Document Intelligence ---------------------------------------------
output "docintel_endpoint" {
  value = azurerm_cognitive_account.docintel.endpoint
}

output "docintel_key" {
  value     = azurerm_cognitive_account.docintel.primary_access_key
  sensitive = true
}

# --- Content Understanding analyzer ------------------------------------------
output "cu_analyzer_id" {
  value = local.cu_analyzer_id
}
