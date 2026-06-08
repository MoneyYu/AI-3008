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

## Authentication: Entra ID only (no keys)

This stack is designed for tenants where **company policy forbids account/access keys** (the
common `disableLocalAuth` / "Key based authentication is not permitted" enterprise posture). Every
service uses **Microsoft Entra ID (AAD)** auth:

- Storage uses `shared_access_key_enabled = false`; the provider sets `storage_use_azuread = true`.
- The Foundry/AI Services account and Document Intelligence set `local_auth_enabled = false`.
- Azure AI Search sets `local_authentication_enabled = false` (RBAC-only).
- The data-plane scripts acquire AAD bearer tokens (`az account get-access-token`) instead of keys,
  and the AI Search indexer/knowledge-store/AI-Services skill bindings use **managed identity**.
- Terraform creates the required **role assignments** automatically (for the running principal and
  the Search managed identity). Because fresh role assignments take time to propagate, the scripts
  retry on `401/403`.

> This was validated end-to-end (deploy + data plane + destroy) on a policy-restricted subscription.

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

- Permission to **create role assignments** (Owner or User Access Administrator) - the stack assigns
  blob / Cognitive Services / Search data-plane roles because keys are disabled.
- Quota for `gpt-5.4`, `gpt-image-2` (or your `image_model_name`), `text-embedding-3-large`, and
  `gpt-5.2` in your region. Check in the Foundry portal under **Operate > Quota** before applying.
  If `gpt-image-2` has no quota, override `image_model_name`/`image_model_version` (for example to
  `gpt-image-1.5` / `2025-12-16`).
- AI Search capacity in the chosen region. If the main region (eastus2) is out of Search capacity,
  set `search_location` to another region (for example `eastus`).

## Usage

```powershell
cd TERRAFORM
terraform init
terraform plan  -out main.tfplan -var "group_postfix=01"
terraform apply main.tfplan
```

Retrieve connection details for the demos (auth is Entra ID; there are no key outputs):

```powershell
terraform output                          # non-sensitive values
terraform output -raw foundry_endpoint
terraform output -raw search_endpoint
terraform output -raw storage_account_name
```

### Variables

| Variable | Default | Description |
| --- | --- | --- |
| `group_postfix` | *(required)* | Unique suffix per class/instance (`^[a-z0-9]{1,10}$`) |
| `chat_capacity` | `50` | Capacity (k TPM) for `gpt-5.4` |
| `image_capacity` | `1` | Capacity for the image model |
| `image_model_name` | `gpt-image-2` | Image model to deploy; override to one you have quota for (e.g. `gpt-image-1.5`) |
| `image_model_version` | `2026-04-21` | Version for `image_model_name` (e.g. `2025-12-16` for `gpt-image-1.5`) |
| `embedding_capacity` | `50` | Capacity for `text-embedding-3-large` |
| `cu_completion_capacity` | `50` | Capacity for the `gpt-5.2` CU completion model |
| `search_location` | *(main location)* | Region for AI Search; override if the default region is out of capacity |
| `enable_data_plane` | `true` | Run the data-plane scripts after apply |
| `user_name` / `user_password` | `demouser` / `Azuredemo2020` | Reserved for lab user scenarios |

> Set `enable_data_plane=false` to provision resources only (no sample data, analyzer, or index).

### Example: deploy in a quota/capacity-constrained subscription

```powershell
terraform apply -auto-approve `
  -var "group_postfix=0608" `
  -var "image_model_name=gpt-image-1.5" `
  -var "image_model_version=2025-12-16" `
  -var "search_location=eastus"
```

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

If you used non-default vars (image model / search region), pass the same `-var` flags to `destroy`.

## Notes & known limitations

- Model **versions** and the **retirement schedule** change over time - re-verify before each delivery.
- `terraform apply` may fail if the subscription lacks **quota** for the selected models, or if the
  chosen region is out of **AI Search capacity** - use `image_model_name`/`image_model_version` and
  `search_location` to adapt (see the example above).
- The data-plane scripts authenticate with **Entra ID** (`az login` required) and use the
  Content Understanding GA REST API (`2025-11-01`) and the AI Search REST API (`2024-11-01-preview`,
  needed for the managed-identity `AIServicesByIdentity` skill binding). Update these if the API
  versions change.
- All three scripts run with `pwsh -NoProfile` so a user's PowerShell profile can't interfere.
