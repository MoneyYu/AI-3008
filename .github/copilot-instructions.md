# Copilot instructions for AI-3008

This repository is a **Microsoft training-course reference repo** for the course
**AI-3008 – "Extract insights from visual data on Azure"** (a vision / multimodal Azure AI course).
It is *not* an application codebase. It contains:

- `README.md` – the attendee-facing course reference page (links, lab info, mind map). Keep
  trainer-private / demo-environment details **out** of this file.
- `TERRAFORM/` – a trainer-private "demo-ready backup" Azure environment the trainer can stand up if
  the live, from-scratch demo fails. It must reach a *completed* state (resources **and** data-plane).
- `docs/` – trainer-only documentation (e.g. `docs/demo-environment.md` describing the demo stack and
  model choices). Not attendee-facing.

## Validate changes

There is no app build/test suite. The checks that matter are:

```powershell
# Terraform (run from the TERRAFORM/ folder)
terraform fmt -recursive          # format; use -check in CI
terraform init -backend=false     # first time / after provider changes
terraform validate                # must pass before committing

# PowerShell scripts – syntax/parse check (no test runner exists)
Get-ChildItem TERRAFORM/scripts/*.ps1 | ForEach-Object {
  $e=$null; [System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$null,[ref]$e)
  if ($e.Count) { "FAIL: $($_.Name)"; $e } else { "OK: $($_.Name)" }
}
```

`terraform apply` requires `az login`, a target subscription, and **model quota in East US 2**;
do not assume it can run in CI. Do not commit `.terraform/`, `*.tfstate`, or `.terraform.lock.hcl`
(already git-ignored).

## Terraform architecture & conventions

The stack deliberately mirrors the sibling course repos (`MoneyYu/AI-3016`, `AI-3003`, `AI-102`):

- **File split:** `MAIN.tf` = providers + variables + locals + resource groups; `MOD.tf` = all
  resources + the data-plane wiring; `OUTPUT.tf` = endpoints/keys/names. Keep new resources in
  `MOD.tf`, not `MAIN.tf`.
- **Naming:** everything is derived from `var.group_postfix` via `locals` (`group_name =
  "AI3008-<postfix>"`, `group_name_lower`, fixed `random_str`). `group_postfix` is validated to
  `^[a-z0-9]{1,10}$` because the storage-account name uses it directly (storage names: ≤24 chars,
  lowercase alphanumeric only). Reuse the locals for any new name; don't interpolate `group_postfix`
  raw into a storage name.
- **Region is `eastus2`** (a local, not a variable) — chosen for Content Understanding GA + Foundry
  + the selected models. Don't change it casually.
- **Foundry pattern (azurerm ~>4.x, not azapi):** `azurerm_cognitive_account` kind `AIServices`
  with `project_management_enabled = true` + `custom_subdomain_name`, then
  `azurerm_cognitive_account_project`, then `azurerm_cognitive_deployment` per model.
- **Model deployments are chained with `depends_on`** (one after another) on purpose — the Cognitive
  Services control plane rejects parallel deployment writes.
- **Data-plane automation:** three `terraform_data` resources run the `scripts/*.ps1` files via
  `local-exec` (`interpreter = ["pwsh","-File"]`), passing endpoints/keys through the `environment`
  map. Env-var names in those maps must exactly match each script's `Get-RequiredEnv` calls.
  Gated by `var.enable_data_plane`.

## Model selection rule (important, time-sensitive)

Models **must** be validated against the
[Foundry model retirement schedule](https://learn.microsoft.com/azure/ai-foundry/concepts/model-lifecycle-retirement)
before use. Never deploy a retired or soon-to-be-retired model; prefer the latest GA. Re-check before
each course delivery and bump versions. Note the constraint that **Azure Content Understanding only
supports a fixed set of completion models** (currently `gpt-4.1` / `gpt-5.2`), so CU has its own
`gpt-5.2` deployment separate from the `gpt-5.4` chat/vision deployment. `sora-2`, `FLUX`, and
`Phi-4` are deployed manually in the portal (documented in `TERRAFORM/README.md`), not via Terraform.

## Data-plane scripts (`TERRAFORM/scripts/`)

PowerShell 7 (`pwsh -NoProfile`) + Azure CLI. The whole stack is **Entra ID (AAD) only** - company
policy forbids account/access keys, so storage uses `shared_access_key_enabled = false`, the Foundry
and Document Intelligence accounts set `local_auth_enabled = false`, and AI Search sets
`local_authentication_enabled = false`. Scripts acquire AAD bearer tokens via
`az account get-access-token` (so they need `az login`) and the AI Search data source / knowledge
store / AI-Services skill bindings use **managed identity**. Terraform creates the required role
assignments, and the scripts retry on `401/403` to absorb RBAC propagation. REST API versions:
Content Understanding GA `2025-11-01` (PUT analyzer + poll `Operation-Location`, `allowReplace=true`;
note CU requires `PATCH /contentunderstanding/defaults` before creating an analyzer) and Azure AI
Search `2024-11-01-preview` (needed for `AIServicesByIdentity`). Polling loops must **throw on
terminal failure and on timeout** (don't silently exit 0).

## Sample data (`TERRAFORM/sample-data/`)

Realistic, fictional **"Northwind Traders"** assets (images, documents, knowledge-base corpus) — the
repo is private/not open-sourced, so there is no licensing concern, but data should *look* genuinely
real. Assets are generated one-time with Python (Pillow / reportlab / matplotlib) in a **virtual
environment** (per user preference); only the resulting binary assets are committed, not the
generator. Mark new binary asset types as `binary` in `.gitattributes` (the global `* text=auto`
will otherwise corrupt PDFs/PNGs via line-ending normalization).

## README conventions

`README.md` uses **HackMD-style** syntax that is not plain GitHub Markdown: YAML front-matter, `:::success` /
`:::info` / `:::warning` admonition blocks, and a ` ```markmap ` mind-map block. Preserve these when
editing. Keep the per-course instance metadata (Date, Course ID, survey link, Skillable training key).
Microsoft Learn links should be verified to resolve (HTTP 200) before adding.

## Git & GitHub workflow

- **Conventional Commits** are required (see `.github/skills/git-commit/SKILL.md`):
  `<type>(<scope>): <description>` with a body and footers. Append the trailer
  `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` to commits.
- **Issues:** the `.github/skills/github-issues/SKILL.md` skill defines the workflow — create/update
  issues with `gh api` (the MCP server is read-only for writes), prefer the org **issue types**
  (`Task`/`Bug`/`Feature`) over equivalent labels. House convention: the **issue body holds the scope /
  things-to-do**, and progress/decisions/notes are appended as **comments**, not edited into the body.
