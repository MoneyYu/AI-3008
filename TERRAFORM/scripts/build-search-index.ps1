#requires -Version 7.0
<#
.SYNOPSIS
    Builds and runs an Azure AI Search knowledge-mining pipeline.

.DESCRIPTION
    Part of the AI-3008 demo backup environment. Creates (idempotently) a blob
    data source, an AI-enrichment skillset (language detection, key phrase
    extraction, entity recognition) with a knowledge store projection, an index,
    and an indexer, then runs the indexer so the knowledge-mining demo already
    returns enriched, searchable results.

    Uses the Azure AI Search REST API with the admin key, so it does NOT require
    `az login`. Invoked by Terraform (terraform_data.build_search_index).

.NOTES
    Environment variables:
      SEARCH_ENDPOINT       - https://<service>.search.windows.net
      SEARCH_ADMIN_KEY      - search admin key
      STORAGE_RESOURCE_ID   - storage account ARM resource ID (managed-identity connection)
      KB_CONTAINER          - blob container with the document corpus
      KS_CONTAINER          - blob container for knowledge-store projections
      AISERVICES_KEY        - AI Services key (binds billable built-in skills)
      INDEX_NAME            - name to give the index/indexer/skillset/datasource

    Authentication: the data source and knowledge store use the AI Search
    service's system-assigned managed identity (ResourceId= connection string),
    because company policy forbids storage account access keys. The Search
    service identity must hold a blob data role on the storage account.
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

$endpoint     = (Get-RequiredEnv 'SEARCH_ENDPOINT').TrimEnd('/')
$storageResId = Get-RequiredEnv 'STORAGE_RESOURCE_ID'
$kbContainer  = Get-RequiredEnv 'KB_CONTAINER'
$ksContainer  = Get-RequiredEnv 'KS_CONTAINER'
$aiSubdomain  = (Get-RequiredEnv 'AISERVICES_SUBDOMAIN').TrimEnd('/')
$indexName    = Get-RequiredEnv 'INDEX_NAME'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI ('az') was not found on PATH. Install it from https://aka.ms/azcli."
}

# Acquire an Entra ID token for the Azure AI Search data plane (keys disabled).
$token = az account get-access-token --resource "https://search.azure.com" --query accessToken -o tsv 2>$null
if ([string]::IsNullOrWhiteSpace($token)) {
    throw "Failed to acquire an Entra ID access token. Run 'az login' first."
}

# Managed-identity connection string (no account key) for blob access.
$storageConn = "ResourceId=$storageResId;"

$apiVersion       = '2024-11-01-preview'
$dataSourceName   = "$indexName-ds"
$skillsetName     = "$indexName-ss"
$indexerName      = "$indexName-idxr"
$knowledgeStoreCt = $ksContainer

$headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type'  = 'application/json'
}

function Invoke-Search {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [object]$Body
    )
    $uri = "$endpoint/$Path"
    if ($uri -notmatch '\?') { $uri += "?api-version=$apiVersion" } else { $uri += "&api-version=$apiVersion" }

    $params = @{ Method = $Method; Uri = $uri; Headers = $headers; SkipHttpErrorCheck = $true }
    if ($PSBoundParameters.ContainsKey('Body') -and $null -ne $Body) {
        $params['Body'] = ($Body | ConvertTo-Json -Depth 20)
    }

    # Retry to absorb RBAC role-assignment propagation delay (401/403).
    for ($attempt = 1; $attempt -le 10; $attempt++) {
        $resp = Invoke-WebRequest @params
        if ($resp.StatusCode -lt 400) { return $resp }
        if ($resp.StatusCode -in 401, 403 -and $attempt -lt 10) {
            Write-Host "  $Method $Path got HTTP $($resp.StatusCode) (likely RBAC propagation); retrying in 20s..."
            Start-Sleep -Seconds 20
            continue
        }
        throw "$Method $Path failed (HTTP $($resp.StatusCode)): $($resp.Content)"
    }
}

# --- 1. Data source ----------------------------------------------------------
Write-Host "Creating data source '$dataSourceName'..."
# System-assigned managed identity is implied by the ResourceId= connection
# string; the 'identity' property is omitted (not valid for system MI here).
$dataSource = @{
    name        = $dataSourceName
    type        = 'azureblob'
    credentials = @{ connectionString = $storageConn }
    container   = @{ name = $kbContainer }
}
Invoke-Search -Method 'Put' -Path "datasources/$dataSourceName" -Body $dataSource | Out-Null

# --- 2. Skillset (AI enrichment + knowledge store) ---------------------------
Write-Host "Creating skillset '$skillsetName'..."
$skillset = @{
    name                = $skillsetName
    description         = 'AI-3008 knowledge mining enrichment pipeline.'
    cognitiveServices   = @{
        '@odata.type'  = '#Microsoft.Azure.Search.AIServicesByIdentity'
        description    = 'AI Services account that backs the billable built-in skills (managed identity).'
        subdomainUrl   = $aiSubdomain
        # identity = null => use the search service's system-assigned managed identity
        identity       = $null
    }
    skills              = @(
        @{
            '@odata.type' = '#Microsoft.Skills.Text.LanguageDetectionSkill'
            name          = 'detect-language'
            context       = '/document'
            inputs        = @(@{ name = 'text'; source = '/document/content' })
            outputs       = @(@{ name = 'languageCode'; targetName = 'languageCode' })
        },
        @{
            '@odata.type'  = '#Microsoft.Skills.Text.KeyPhraseExtractionSkill'
            name           = 'key-phrases'
            context        = '/document'
            inputs         = @(
                @{ name = 'text'; source = '/document/content' },
                @{ name = 'languageCode'; source = '/document/languageCode' }
            )
            outputs        = @(@{ name = 'keyPhrases'; targetName = 'keyPhrases' })
        },
        @{
            '@odata.type'   = '#Microsoft.Skills.Text.V3.EntityRecognitionSkill'
            name            = 'entities'
            context         = '/document'
            categories      = @('Organization', 'Location', 'Person')
            defaultLanguageCode = 'en'
            inputs          = @(
                @{ name = 'text'; source = '/document/content' },
                @{ name = 'languageCode'; source = '/document/languageCode' }
            )
            outputs         = @(
                @{ name = 'organizations'; targetName = 'organizations' },
                @{ name = 'locations'; targetName = 'locations' },
                @{ name = 'persons'; targetName = 'persons' }
            )
        }
    )
    knowledgeStore      = @{
        storageConnectionString = $storageConn
        projections             = @(
            @{
                objects = @(
                    @{
                        storageContainer = $knowledgeStoreCt
                        source           = '/document'
                    }
                )
                tables  = @()
                files   = @()
            }
        )
    }
}
Invoke-Search -Method 'Put' -Path "skillsets/$skillsetName" -Body $skillset | Out-Null

# --- 3. Index ----------------------------------------------------------------
Write-Host "Creating index '$indexName'..."
$index = @{
    name   = $indexName
    fields = @(
        @{ name = 'id'; type = 'Edm.String'; key = $true; searchable = $false; filterable = $true; sortable = $true; retrievable = $true }
        @{ name = 'content'; type = 'Edm.String'; searchable = $true; filterable = $false; sortable = $false; retrievable = $true }
        @{ name = 'fileName'; type = 'Edm.String'; searchable = $true; filterable = $true; sortable = $true; retrievable = $true }
        @{ name = 'language'; type = 'Edm.String'; searchable = $false; filterable = $true; sortable = $false; retrievable = $true; facetable = $true }
        @{ name = 'keyPhrases'; type = 'Collection(Edm.String)'; searchable = $true; filterable = $true; retrievable = $true; facetable = $true }
        @{ name = 'organizations'; type = 'Collection(Edm.String)'; searchable = $true; filterable = $true; retrievable = $true; facetable = $true }
        @{ name = 'locations'; type = 'Collection(Edm.String)'; searchable = $true; filterable = $true; retrievable = $true; facetable = $true }
        @{ name = 'persons'; type = 'Collection(Edm.String)'; searchable = $true; filterable = $true; retrievable = $true; facetable = $true }
    )
}
Invoke-Search -Method 'Put' -Path "indexes/$indexName" -Body $index | Out-Null

# --- 4. Indexer --------------------------------------------------------------
Write-Host "Creating indexer '$indexerName'..."
$indexer = @{
    name            = $indexerName
    dataSourceName  = $dataSourceName
    skillsetName    = $skillsetName
    targetIndexName = $indexName
    parameters      = @{
        configuration = @{
            dataToExtract = 'contentAndMetadata'
            parsingMode   = 'default'
        }
    }
    fieldMappings        = @(
        @{ sourceFieldName = 'metadata_storage_path'; targetFieldName = 'id'; mappingFunction = @{ name = 'base64Encode' } }
        @{ sourceFieldName = 'metadata_storage_name'; targetFieldName = 'fileName' }
    )
    outputFieldMappings  = @(
        @{ sourceFieldName = '/document/languageCode'; targetFieldName = 'language' }
        @{ sourceFieldName = '/document/keyPhrases'; targetFieldName = 'keyPhrases' }
        @{ sourceFieldName = '/document/organizations'; targetFieldName = 'organizations' }
        @{ sourceFieldName = '/document/locations'; targetFieldName = 'locations' }
        @{ sourceFieldName = '/document/persons'; targetFieldName = 'persons' }
    )
}
Invoke-Search -Method 'Put' -Path "indexers/$indexerName" -Body $indexer | Out-Null

# --- 5. Run the indexer ------------------------------------------------------
Write-Host "Running indexer '$indexerName'..."
Invoke-Search -Method 'Post' -Path "indexers/$indexerName/run" | Out-Null

# Poll indexer status until the run finishes.
# Terminal states: success -> done; persistentFailure / error / failed -> throw.
# transientFailure and inProgress mean "still working", so we keep polling until
# success or timeout (and a timeout is treated as a failure, not a warning).
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 5
    $status = (Invoke-Search -Method 'Get' -Path "indexers/$indexerName/status").Content | ConvertFrom-Json
    $last = $status.lastResult
    $state = if ($last -and $last.status) { "$($last.status)".ToLower() } else { 'pending' }
    Write-Host "  indexer status: $state"

    switch ($state) {
        'success' {
            Write-Host "Knowledge mining index '$indexName' is ready." -ForegroundColor Green
            exit 0
        }
        # Still working - keep polling (empty block; the for loop continues).
        { $_ -in 'transientfailure', 'inprogress', 'pending', 'reset' } { }
        # Anything else (persistentfailure, error, failed, ...) is terminal.
        default {
            $detail = if ($last) { $last | ConvertTo-Json -Depth 8 } else { $status | ConvertTo-Json -Depth 8 }
            throw "Indexer '$indexerName' run failed (state: $state): $detail"
        }
    }
}

throw "Timed out waiting for indexer '$indexerName' to finish. Check the Azure portal for the indexer execution history."
