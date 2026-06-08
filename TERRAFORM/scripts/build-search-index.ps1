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
      STORAGE_CONNECTION    - storage account connection string
      KB_CONTAINER          - blob container with the document corpus
      AISERVICES_ENDPOINT   - AI Services endpoint (informational)
      AISERVICES_KEY        - AI Services key (binds billable built-in skills)
      EMBEDDING_DEPLOYMENT  - embedding deployment name (informational)
      INDEX_NAME            - name to give the index/indexer/skillset/datasource
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

$endpoint    = (Get-RequiredEnv 'SEARCH_ENDPOINT').TrimEnd('/')
$adminKey    = Get-RequiredEnv 'SEARCH_ADMIN_KEY'
$storageConn = Get-RequiredEnv 'STORAGE_CONNECTION'
$kbContainer = Get-RequiredEnv 'KB_CONTAINER'
$aiKey       = Get-RequiredEnv 'AISERVICES_KEY'
$indexName   = Get-RequiredEnv 'INDEX_NAME'

$apiVersion       = '2024-07-01'
$dataSourceName   = "$indexName-ds"
$skillsetName     = "$indexName-ss"
$indexerName      = "$indexName-idxr"
$knowledgeStoreCt = 'knowledge-store'

$headers = @{
    'api-key'      = $adminKey
    'Content-Type' = 'application/json'
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

    $resp = Invoke-WebRequest @params
    if ($resp.StatusCode -ge 400) {
        throw "$Method $Path failed (HTTP $($resp.StatusCode)): $($resp.Content)"
    }
    return $resp
}

# --- 1. Data source ----------------------------------------------------------
Write-Host "Creating data source '$dataSourceName'..."
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
        '@odata.type' = '#Microsoft.Azure.Search.CognitiveServicesByKey'
        description   = 'AI Services account that backs the billable built-in skills.'
        key           = $aiKey
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
