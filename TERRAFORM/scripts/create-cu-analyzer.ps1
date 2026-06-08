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
      CU_API_KEY            - AI Services key
      ANALYZER_ID           - id to give the custom analyzer
      COMPLETION_DEPLOYMENT - completion model deployment name (CU-supported, e.g. gpt-5.2)
      EMBEDDING_DEPLOYMENT  - embedding model deployment name

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
$apiKey     = Get-RequiredEnv 'CU_API_KEY'
$analyzerId = Get-RequiredEnv 'ANALYZER_ID'
$completion = Get-RequiredEnv 'COMPLETION_DEPLOYMENT'
$embedding  = Get-RequiredEnv 'EMBEDDING_DEPLOYMENT'

$apiVersion = '2025-11-01'
$headers = @{
    'Ocp-Apim-Subscription-Key' = $apiKey
    'Content-Type'              = 'application/json'
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

$response = Invoke-WebRequest -Method Put -Uri $createUri -Headers $headers -Body $body -SkipHttpErrorCheck
if ($response.StatusCode -notin 200, 201) {
    throw "Analyzer create failed (HTTP $($response.StatusCode)): $($response.Content)"
}

# Poll the async operation until it finishes.
$opLocation = $response.Headers['Operation-Location']
if ($opLocation) {
    $opUri = [string]$opLocation
    Write-Host "Waiting for analyzer creation to complete..."

    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 5
        $statusResp = Invoke-RestMethod -Method Get -Uri $opUri -Headers @{ 'Ocp-Apim-Subscription-Key' = $apiKey }
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
