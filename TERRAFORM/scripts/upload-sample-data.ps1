#requires -Version 7.0
<#
.SYNOPSIS
    Uploads the AI-3008 sample data to Azure Blob Storage.

.DESCRIPTION
    Part of the AI-3008 demo backup environment. Uploads the contents of the
    sample-data folder into the matching blob containers so the Content
    Understanding and AI Search demos have realistic content to work with.

    Invoked by Terraform (terraform_data.upload_sample_data) via local-exec.
    Reads its configuration from environment variables and uses the Azure CLI
    (`az storage blob upload-batch`) with the storage account key, so it does
    NOT require an interactive `az login`.

.NOTES
    Environment variables:
      STORAGE_ACCOUNT   - storage account name
      STORAGE_KEY       - storage account key
      SAMPLE_DATA_PATH  - path to the sample-data folder
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

$storageAccount = Get-RequiredEnv 'STORAGE_ACCOUNT'
$storageKey     = Get-RequiredEnv 'STORAGE_KEY'
$sampleDataPath = Get-RequiredEnv 'SAMPLE_DATA_PATH'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI ('az') was not found on PATH. Install it from https://aka.ms/azcli."
}

# container name -> sub-folder of sample-data
$map = [ordered]@{
    'sample-images'    = 'images'
    'sample-documents' = 'documents'
    'knowledge-base'   = 'knowledge-base'
}

foreach ($container in $map.Keys) {
    $source = Join-Path $sampleDataPath $map[$container]

    if (-not (Test-Path $source)) {
        Write-Warning "Source folder '$source' not found; skipping container '$container'."
        continue
    }

    $fileCount = (Get-ChildItem -Path $source -File -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($fileCount -eq 0) {
        Write-Warning "No files in '$source'; skipping container '$container'."
        continue
    }

    Write-Host "Uploading $fileCount file(s) from '$source' -> container '$container'..."

    az storage blob upload-batch `
        --account-name $storageAccount `
        --account-key $storageKey `
        --destination $container `
        --source $source `
        --overwrite true `
        --no-progress `
        --only-show-errors | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "Upload to container '$container' failed (az exit code $LASTEXITCODE)."
    }
}

Write-Host "Sample data upload complete." -ForegroundColor Green
