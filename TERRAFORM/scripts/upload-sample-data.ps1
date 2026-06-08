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
      SAMPLE_DATA_PATH  - path to the sample-data folder

    Authentication: Entra ID (AAD) via `--auth-mode login`. Company policy
    forbids storage account access keys, so the running principal must hold a
    blob data role (e.g. Storage Blob Data Contributor) on the account. Because
    a freshly created role assignment can take a minute or two to propagate,
    the uploads are retried.
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

    # Retry to absorb RBAC role-assignment propagation delay.
    $maxAttempts = 10
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        az storage blob upload-batch `
            --account-name $storageAccount `
            --auth-mode login `
            --destination $container `
            --source $source `
            --overwrite true `
            --no-progress `
            --only-show-errors 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) { break }

        if ($attempt -eq $maxAttempts) {
            throw "Upload to container '$container' failed after $maxAttempts attempts (az exit code $LASTEXITCODE). If this is an authorization error, confirm the running principal has 'Storage Blob Data Contributor' on '$storageAccount'."
        }
        Write-Host "  attempt $attempt failed (likely RBAC propagation); retrying in 20s..."
        Start-Sleep -Seconds 20
    }
}

Write-Host "Sample data upload complete." -ForegroundColor Green
