# AI-3008 Demo Environment (Terraform)

This Terraform stack provisions a **fully deployed, demo-ready backup environment** for the
course **AI-3008 - Extract insights from visual data on Azure**. In class the trainer builds
everything live from scratch; this stack is the fallback so every demo can still be shown
working if the live build fails.

## What it deploys

| Resource | Purpose | Module(s) |
| --- | --- | --- |
| Resource group `AI3008-<postfix>` | Holds the backup environment | all |
| Resource group `Demo<postfix>` | Empty RG for the live from-scratch build | - |
| Microsoft Foundry account (`AIServices`) + project | Hosts Azure OpenAI + Content Understanding | 1-6 |
| `gpt-5.4` deployment | Chat / vision model | 1, 4 |
| `gpt-image-2` deployment | Image generation | 2 |
| `gpt-5.2` deployment | Content Understanding completion model | 4-6 |
| `text-embedding-3-large` deployment | Embeddings for AI Search | 8 |
| Azure AI Search (standard) | Knowledge mining | 8 |
| Storage account + containers | Sample data + knowledge store | 4-8 |
| Azure Document Intelligence (`FormRecognizer`) | Document extraction | 7 |

After the resources are created, three PowerShell scripts bring the environment to a
**completed end state** (controlled by `enable_data_plane`):

1. `scripts/upload-sample-data.ps1` - uploads the realistic `sample-data/` assets to blob storage.
2. `scripts/create-cu-analyzer.ps1` - creates a custom Content Understanding **invoice analyzer**.
3. `scripts/build-search-index.ps1` - builds and runs the AI Search **knowledge-mining** pipeline
   (data source -> skillset with AI enrichment + knowledge store -> index -> indexer).

## Models & lifecycle

Models are validated against the
[Foundry model retirement schedule](https://learn.microsoft.com/azure/ai-foundry/concepts/model-lifecycle-retirement)
to avoid retired or soon-to-be-retired models (verified 2026-06-08). **Re-check before each
delivery** and bump versions as needed.

| Role | Model | Version | Lifecycle | Retires |
| --- | --- | --- | --- | --- |
| Chat / vision | `gpt-5.4` | 2026-03-05 | GA | 2027-03-05 |
| Image generation | `gpt-image-2` | 2026-04-21 | GA | 2027-04-21 |
| Embeddings | `text-embedding-3-large` | 1 | GA | 2027-04-15 |
| Content Understanding completion | `gpt-5.2` | 2025-12-11 | GA | 2026-12-12 |

> The course labs use `gpt-4.1` (retires 2026-10-14); `gpt-5.4` is the forward-looking,
> vision-enabled GA replacement.
>
> **Content Understanding** only supports a fixed set of completion models (as of 2026-06-08:
> `gpt-4.1` and `gpt-5.2`). `gpt-5.4` is **not** supported by CU yet, so CU uses its own `gpt-5.2`
> deployment. Re-check the
> [CU supported models](https://learn.microsoft.com/azure/ai-services/content-understanding/concepts/models-deployments)
> and bump when newer models are added.

### Deployed manually (not in Terraform)

These are preview / quota-constrained and are deployed in the **Foundry portal**:

- **`sora-2` (version `2025-12-08`)** - video generation (module 3). The `2025-10-06` version
  retires 2026-07-15, so always pick `2025-12-08`.
- **`FLUX.2-pro`** - alternative image model (Black Forest Labs), GA.
- **`Phi-4-multimodal-instruct`** - shown in the ChatCompletions example, GA.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Azure CLI](https://aka.ms/azcli) (`az`) and [PowerShell 7+](https://aka.ms/powershell) (`pwsh`)
  for the data-plane scripts
- An authenticated Azure session and a target subscription:

  ```powershell
  az login
  $env:ARM_SUBSCRIPTION_ID = "<your-subscription-id>"
  ```

- Quota in **East US 2** for `gpt-5.4`, `gpt-image-2`, `text-embedding-3-large`, and `gpt-5.2`.
  Check in the Foundry portal under **Operate > Quota** before applying.

## Usage

```powershell
cd TERRAFORM
terraform init
terraform plan  -out main.tfplan -var "group_postfix=01"
terraform apply main.tfplan
```

Retrieve connection details for the demos:

```powershell
terraform output                         # non-sensitive values
terraform output -raw foundry_endpoint
terraform output -raw foundry_key        # sensitive
terraform output -raw search_admin_key   # sensitive
```

### Variables

| Variable | Default | Description |
| --- | --- | --- |
| `group_postfix` | *(required)* | Unique suffix per class/instance |
| `chat_capacity` | `50` | Capacity (k TPM) for `gpt-5.4` |
| `image_capacity` | `1` | Capacity for `gpt-image-2` |
| `embedding_capacity` | `50` | Capacity for `text-embedding-3-large` |
| `enable_data_plane` | `true` | Run the data-plane scripts after apply |
| `user_name` / `user_password` | `demouser` / `Azuredemo2020` | Reserved for lab user scenarios |

> Set `enable_data_plane=false` to provision resources only (no sample data, analyzer, or index).

## Sample data

`sample-data/` contains realistic, fictional **"Northwind Traders"** assets (no real data, not
open-sourced):

- `images/` - café menu, store receipt, product poster, business card, revenue chart
- `documents/` - invoices (PDF + image), purchase order, service agreement
- `knowledge-base/` - a 12-document corpus (about pages, policies, FAQs, press releases) used by
  the knowledge-mining indexer

## Clean up

```powershell
terraform destroy -var "group_postfix=01"
```

## Notes & known limitations

- Model **versions** and the **retirement schedule** change over time - re-verify before each delivery.
- `terraform apply` may fail if the subscription lacks **quota** for the selected models in East US 2.
- The Content Understanding analyzer and AI Search scripts use the **GA REST APIs**
  (`2025-11-01` and `2024-07-01`). If those API versions change, update the scripts.
- The data-plane scripts authenticate with **resource keys** (retrieved by Terraform), so they do
  not require `az login`; only `upload-sample-data.ps1` uses the `az` CLI (with the storage key).
