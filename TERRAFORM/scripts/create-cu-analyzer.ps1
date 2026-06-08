#requires -Version 7.0
<#
.SYNOPSIS
    Creates an Azure Content Understanding custom invoice analyzer.

.DESCRIPTION
    Part of the AI-3008 demo backup environment. Creates a custom document
    analyzer (based on prebuilt-document) that extracts structured invoice
    fields. Uses the Content Understanding GA REST API (api-version
    2025-11-01) with key authentication, so it does NOT require `az login`.

    Invoked by Terraform (terraform_data.create_cu_analyzer) via local-exec.
    The PUT is asynchronous; the script polls the returned Operation-Location
    until the analyzer reports "succeeded". The operation is idempotent - an
    existing analyzer with the same id is replaced.

.NOTES
    Environment variables:
      CU_ENDPOINT           - Foundry / AI Services endpoint
      ANALYZER_ID           - id to give the custom analyzer
      COMPLETION_DEPLOYMENT - completion model deployment name (CU-supported, e.g. gpt-5.2)
      EMBEDDING_DEPLOYMENT  - embedding model deployment name

    Authentication: Entra ID (AAD). Company policy disables AI Services keys, so
    the script acquires a bearer token for https://cognitiveservices.azure.com
    via the Azure CLI. The running principal must hold "Cognitive Services User"
    (or higher) on the Foundry resource. A freshly created role assignment can
    take a minute or two to propagate, so the call is retried.

    Reference:
      https://learn.microsoft.com/azure/ai-services/content-understanding/tutorial/create-custom-analyzer
#>

$ErrorActionPreference = 'Stop'

function Get-RequiredEnv {
    param([Parameter(Mandatory)][string]$Name)
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required environment variable '$Name' is not set."
    }
    return $value
}

$endpoint   = (Get-RequiredEnv 'CU_ENDPOINT').TrimEnd('/')
$analyzerId = Get-RequiredEnv 'ANALYZER_ID'
$completion = Get-RequiredEnv 'COMPLETION_DEPLOYMENT'
$embedding  = Get-RequiredEnv 'EMBEDDING_DEPLOYMENT'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI ('az') was not found on PATH. Install it from https://aka.ms/azcli."
}

# Acquire an Entra ID token for the Cognitive Services data plane.
$token = az account get-access-token --resource "https://cognitiveservices.azure.com" --query accessToken -o tsv 2>$null
if ([string]::IsNullOrWhiteSpace($token)) {
    throw "Failed to acquire an Entra ID access token. Run 'az login' first."
}

$apiVersion = '2025-11-01'
$headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type'  = 'application/json'
}

# Content Understanding requires resource-level default model deployments to be
# set before any analyzer can be created. Map the model aliases to our actual
# deployment names via PATCH /contentunderstanding/defaults.
Write-Host "Setting Content Understanding default model deployments..."
$defaults = @{
    modelDeployments = @{
        'gpt-5.2'                           = $completion
        'text-embedding-3-large'            = $embedding
        'prebuilt-analyzer-completion'      = $completion
        'prebuilt-analyzer-completion-mini' = $completion
        'prebuilt-analyzer-embedding'       = $embedding
    }
}
$defaultsUri = "$endpoint/contentunderstanding/defaults?api-version=$apiVersion"
for ($attempt = 1; $attempt -le 10; $attempt++) {
    $dr = Invoke-WebRequest -Method Patch -Uri $defaultsUri -Headers $headers -Body ($defaults | ConvertTo-Json -Depth 6) -SkipHttpErrorCheck
    if ($dr.StatusCode -lt 400) { break }
    if ($dr.StatusCode -in 401, 403 -and $attempt -lt 10) {
        Write-Host "  attempt $attempt got HTTP $($dr.StatusCode) (likely RBAC propagation); retrying in 20s..."
        Start-Sleep -Seconds 20
        continue
    }
    throw "Setting CU defaults failed (HTTP $($dr.StatusCode)): $($dr.Content)"
}

# Custom analyzer definition: extract the key fields from an invoice.
$analyzer = @{
    description    = 'AI-3008 demo - extract structured data from invoices.'
    baseAnalyzerId = 'prebuilt-document'
    models         = @{
        completion = $completion
        embedding  = $embedding
    }
    config         = @{
        returnDetails                    = $true
        estimateFieldSourceAndConfidence = $true
        tableFormat                      = 'html'
    }
    fieldSchema    = @{
        fields = @{
            VendorName    = @{ type = 'string'; method = 'extract'; description = 'Name of the vendor issuing the invoice' }
            CustomerName  = @{ type = 'string'; method = 'extract'; description = 'Name of the customer being billed' }
            InvoiceNumber = @{ type = 'string'; method = 'extract'; description = 'Invoice number / identifier' }
            InvoiceDate   = @{ type = 'string'; method = 'extract'; description = 'Date the invoice was issued' }
            Items         = @{
                type   = 'array'
                method = 'extract'
                items  = @{
                    type       = 'object'
                    properties = @{
                        Description = @{ type = 'string'; method = 'extract'; description = 'Line item description' }
                        Quantity    = @{ type = 'number'; method = 'extract'; description = 'Quantity ordered' }
                        UnitPrice   = @{ type = 'number'; method = 'extract'; description = 'Price per unit' }
                        Amount      = @{ type = 'number'; method = 'extract'; description = 'Line item total amount' }
                    }
                }
            }
            SubTotal      = @{ type = 'number'; method = 'extract'; description = 'Invoice subtotal before tax' }
            Tax           = @{ type = 'number'; method = 'extract'; description = 'Tax amount' }
            Total         = @{ type = 'number'; method = 'extract'; description = 'Invoice grand total' }
            Summary       = @{ type = 'string'; method = 'generate'; description = 'One-sentence summary of the invoice' }
        }
    }
}

$body = $analyzer | ConvertTo-Json -Depth 12
# allowReplace=true makes re-runs idempotent (replaces an existing analyzer).
$createUri = "$endpoint/contentunderstanding/analyzers/$($analyzerId)?api-version=$apiVersion&allowReplace=true"

Write-Host "Creating Content Understanding analyzer '$analyzerId'..."

# Retry to absorb RBAC role-assignment propagation delay (401/403).
$response = $null
$maxAttempts = 10
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    $response = Invoke-WebRequest -Method Put -Uri $createUri -Headers $headers -Body $body -SkipHttpErrorCheck
    if ($response.StatusCode -in 200, 201) { break }
    if ($response.StatusCode -in 401, 403 -and $attempt -lt $maxAttempts) {
        Write-Host "  attempt $attempt got HTTP $($response.StatusCode) (likely RBAC propagation); retrying in 20s..."
        Start-Sleep -Seconds 20
        continue
    }
    throw "Analyzer create failed (HTTP $($response.StatusCode)): $($response.Content)"
}

# Poll the async operation until it finishes.
$opLocation = $response.Headers['Operation-Location']
if ($opLocation) {
    $opUri = [string]$opLocation
    Write-Host "Waiting for analyzer creation to complete..."

    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 5
        $statusResp = Invoke-RestMethod -Method Get -Uri $opUri -Headers @{ 'Authorization' = "Bearer $token" }
        $status = "$($statusResp.status)".ToLower()
        Write-Host "  status: $status"

        switch ($status) {
            'succeeded' { Write-Host "Analyzer '$analyzerId' created." -ForegroundColor Green; exit 0 }
            'failed'    { throw "Analyzer creation failed: $($statusResp | ConvertTo-Json -Depth 8)" }
            'canceled'  { throw "Analyzer creation was canceled." }
        }
    }
    throw "Timed out waiting for analyzer '$analyzerId' to be created."
}

Write-Host "Analyzer '$analyzerId' created (synchronous response)." -ForegroundColor Green
