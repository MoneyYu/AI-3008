---
tags: AI-3008, Trainer, Demo
---

# AI-3008 Demo Environment (Trainer-only)

> This document is for the **trainer** preparing the AI-3008 demos. It is intentionally kept out of
> the attendee-facing [`README.md`](../README.md). For the full Terraform usage, variables, and
> prerequisites, see [`TERRAFORM/README.md`](../TERRAFORM/README.md).

## Overview

A Terraform stack in [`TERRAFORM/`](../TERRAFORM) provisions a **fully deployed, demo-ready** backup
environment (region: `East US 2`) so every demo can be shown working even if the from-scratch live
build fails. It deploys a Microsoft Foundry account + project, model deployments, Azure AI Search,
Storage, and Azure Document Intelligence, and runs data-plane scripts that upload sample data, create
a Content Understanding analyzer, and build an AI Search index.

The environment uses **Microsoft Entra ID (AAD) auth only** (no access keys), matching enterprise
policy. See [`TERRAFORM/README.md`](../TERRAFORM/README.md) for deploy/destroy instructions and the
variables that let you adapt to model quota and regional capacity.

## Models used

All models are validated against the [Foundry model retirement schedule](https://learn.microsoft.com/azure/ai-foundry/concepts/model-lifecycle-retirement)
to avoid retired or soon-to-be-retired models.

| Role | Model | Lifecycle | Notes |
| --- | --- | --- | --- |
| Chat / vision | `gpt-5.4` | GA | Vision-enabled, Responses API. (Course labs use `gpt-4.1`, which retires 2026-10-14.) |
| Image generation | `gpt-image-2` | GA | Latest GA OpenAI image model (matches current lab). |
| Embeddings | `text-embedding-3-large` | GA | Used for AI Search vectorization. |
| Content Understanding completion | `gpt-5.2` | GA | CU only supports `gpt-4.1` / `gpt-5.2` today; `gpt-5.2` is the CU-recommended model. |
| Video | `sora-2` (2025-12-08) | Preview | Only video model; deploy manually. |
| Multimodal (optional) | `Phi-4-multimodal-instruct` | GA | Shown in the ChatCompletions example. |

## Deploying a model: Default vs Custom settings

When you deploy a model in Microsoft Foundry, the **Deploy** button offers two options:

| | **Default settings** | **Custom settings** |
| --- | --- | --- |
| What it sets | Global Standard deployment type + default quota | You choose SKU, quota, PTU, spillover, and guardrails |
| Deployment type / SKU | **Global Standard** (pay-as-you-go, token-based, routed globally) | Any supported type: Global/DataZone **Standard**, or **Provisioned (PTU)**, etc. |
| Capacity / throughput | Default quota (TPM) for the model in the region | Set your own quota (TPM) or reserve dedicated **PTU** capacity |
| Spillover | Not configured | Optionally overflow provisioned traffic to a standard deployment |
| Guardrails (content filters) | Default content filter | Choose / configure a custom guardrails policy |
| Best for | Quick start, demos, dev/test (fastest path) | Production: data residency, predictable latency, cost control, governance |

> For this course's demos, **Default settings** (Global Standard) is the quickest path. The Terraform
> stack deploys the equivalent of "Default settings" by using the `GlobalStandard`/`Standard` SKU with
> a default capacity. Use **Custom settings** when you need provisioned throughput, data-zone residency,
> spillover, or a custom content-filter policy.

- [Deploy Microsoft Foundry Models in the Foundry portal (Default vs Custom settings)](https://learn.microsoft.com/azure/foundry/foundry-models/how-to/deploy-foundry-models)
- [Deployment types for Microsoft Foundry Models (Global/Data Zone Standard vs Provisioned)](https://learn.microsoft.com/azure/foundry/foundry-models/concepts/deployment-types)
- [Quotas and limits](https://learn.microsoft.com/azure/ai-foundry/openai/quotas-limits)
- [What is provisioned throughput (PTU)?](https://learn.microsoft.com/azure/foundry/openai/concepts/provisioned-throughput)
- [Determine PTU sizing for a workload](https://learn.microsoft.com/azure/foundry/openai/how-to/provisioned-throughput-sizing)
- [Manage traffic with spillover for provisioned deployments](https://learn.microsoft.com/azure/foundry/openai/how-to/spillover-traffic-management)
- [Guardrails and controls overview](https://learn.microsoft.com/azure/foundry/guardrails/guardrails-overview)
- [How to configure guardrails and controls](https://learn.microsoft.com/azure/foundry/guardrails/how-to-create-guardrails)
