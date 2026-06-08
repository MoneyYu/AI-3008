---
image: https://learn.microsoft.com/training/achievements/generic-badge.svg
tags: AI-3008, Reference
GA: G-DXYJBX6BH8
---

# AI-3008 Reference

> **Course AI-3008-A: Extract insights from visual data on Azure**
> Build intelligent applications that can *see, interpret, and reason over* images and
> documents using multimodal models, Azure Content Understanding, Document Intelligence, and
> Azure AI Search.

## Course
:::success
Date: 20260609
Course ID: 100423
:::

:::info
Course Survey: [https://aka.ms/ai3008survey](https://aka.ms/ai3008survey)
:::

## Course Materials
[Course AI-3008 English version](https://learn.microsoft.com/en-us/training/paths/insight-visual-data/)
[Course AI-3008 简体中文版本](https://learn.microsoft.com/zh-cn/training/paths/insight-visual-data/)
[Course AI-3008 正體中文版本](https://learn.microsoft.com/zh-tw/training/paths/insight-visual-data/)

[Microsoft Learn course page (AI-3008-A)](https://learn.microsoft.com/en-us/training/courses/ai-3008)

## Infos
[LxP Portal](https://esi.microsoft.com/)

[ESI Support](https://aka.ms/esisupport)

## Lab
### Skillable lab system
[ESI Labs](https://aka.ms/esilab)
:::success
Training key: 992D3E5ACD74FEC6
:::

:::info
Only need to redeem once
Valid for 6 months
:::

### Instruction
The labs for this course are spread across two Microsoft Learning repositories.

#### Vision (modules 1-4)
[AI-3008 Labs EN - Azure AI Vision](https://microsoftlearning.github.io/mslearn-ai-vision/)

- [01 - Develop a vision-enabled generative AI app](https://microsoftlearning.github.io/mslearn-ai-vision/Instructions/Exercises/01-gen-ai-vision.html)
- [02 - Generate images with AI](https://microsoftlearning.github.io/mslearn-ai-vision/Instructions/Exercises/02-generate-image.html)
- [03 - Generate videos with Microsoft Foundry](https://microsoftlearning.github.io/mslearn-ai-vision/Instructions/Exercises/03-generate-video.html)
- [04 - Analyze images with Content Understanding](https://microsoftlearning.github.io/mslearn-ai-vision/Instructions/Exercises/04-content-understanding.html)

[Vision lab files (main.zip)](https://github.com/MicrosoftLearning/mslearn-ai-vision/archive/refs/heads/main.zip)

#### Information Extraction (modules 5-8)
[AI-3008 Labs EN - Information Extraction](https://microsoftlearning.github.io/mslearn-ai-information-extraction/)

- [01 - Extract information from multimodal content (Content Understanding)](https://microsoftlearning.github.io/mslearn-ai-information-extraction/Instructions/Exercises/01-content-understanding.html)
- [02 - Develop a Content Understanding client application](https://microsoftlearning.github.io/mslearn-ai-information-extraction/Instructions/Exercises/02-content-understanding-api.html)
- [03 - Extract data with Azure Document Intelligence](https://microsoftlearning.github.io/mslearn-ai-information-extraction/Instructions/Exercises/03-document-intelligence.html)
- [04 - Create a knowledge mining solution with Azure AI Search](https://microsoftlearning.github.io/mslearn-ai-information-extraction/Instructions/Exercises/04-knowledge-mining.html)
- [05 - Build a RAG pipeline](https://microsoftlearning.github.io/mslearn-ai-information-extraction/Instructions/Exercises/05-rag-pipeline.html)

[Information Extraction lab files (main.zip)](https://github.com/MicrosoftLearning/mslearn-ai-information-extraction/archive/refs/heads/main.zip)

:::warning
At time of writing there are **no localized (zh-cn / zh-tw) lab repositories** for the new vision
course — only the English instructions above are available.
:::

## Demo Environment (Terraform)
A Terraform stack in [`TERRAFORM/`](./TERRAFORM) provisions a **fully deployed, demo-ready** backup
environment (region: `East US 2`) so every demo can be shown working even if the from-scratch live
build fails. It deploys a Microsoft Foundry account + project, model deployments, Azure AI Search,
Storage, and Azure Document Intelligence, and runs data-plane scripts that upload sample data, create
a Content Understanding analyzer, and build an AI Search index. See [`TERRAFORM/README.md`](./TERRAFORM/README.md).

### Models used
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

### Deploying a model: Default vs Custom settings
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

## Links
### Microsoft Foundry
[What is Microsoft Foundry?](https://learn.microsoft.com/azure/foundry/what-is-foundry)

[Create and configure all the resources for Microsoft Foundry Models](https://learn.microsoft.com/azure/foundry/foundry-models/how-to/quickstart-create-resources)

[How to use Foundry Tools in the Microsoft Foundry portal](https://learn.microsoft.com/azure/ai-services/connect-services-foundry-portal)

[Microsoft Foundry Playgrounds](https://learn.microsoft.com/azure/foundry/concepts/concept-playgrounds)

[Microsoft Foundry feature availability across cloud regions](https://learn.microsoft.com/azure/foundry/reference/region-support)

[Foundry Models sold by Azure (models & regions)](https://learn.microsoft.com/azure/foundry/foundry-models/concepts/models-sold-directly-by-azure)

[Foundry Models lifecycle and retirement schedule](https://learn.microsoft.com/azure/ai-foundry/concepts/model-lifecycle-retirement)

[Deploy Foundry Models - Default vs Custom settings](https://learn.microsoft.com/azure/foundry/foundry-models/how-to/deploy-foundry-models)

[Deployment types for Foundry Models](https://learn.microsoft.com/azure/foundry/foundry-models/concepts/deployment-types)

### Responsible AI
[Configure content filters in Azure AI Foundry](https://learn.microsoft.com/azure/ai-foundry/openai/how-to/content-filters)

[Content filter configurability](https://learn.microsoft.com/azure/ai-foundry/openai/concepts/content-filter-configurability)

[Use Risks & Safety monitoring in Azure AI Foundry](https://learn.microsoft.com/azure/ai-foundry/openai/how-to/risks-safety-monitor)

[Responsible AI for Azure Content Understanding](https://learn.microsoft.com/azure/ai-services/content-understanding/overview#responsible-ai)

### 1. Develop a vision-enabled generative AI application
[Module - Develop a vision-enabled generative AI application](https://learn.microsoft.com/training/modules/develop-generative-ai-vision-apps/)

[Use vision-enabled chat models](https://learn.microsoft.com/azure/ai-foundry/openai/how-to/gpt-with-vision)

[Vision-enabled chat model concepts](https://learn.microsoft.com/azure/ai-foundry/openai/concepts/gpt-with-vision)

[Azure OpenAI Responses API](https://learn.microsoft.com/azure/ai-foundry/openai/how-to/responses)

### 2. Generate images with AI
[Image generation how-to (GPT-Image)](https://learn.microsoft.com/azure/foundry/openai/how-to/dall-e)

[Quickstart: Generate images with Azure OpenAI](https://learn.microsoft.com/azure/ai-foundry/openai/dall-e-quickstart)

### 3. Generate videos with Microsoft Foundry
[Module - Generate videos with Microsoft Foundry](https://learn.microsoft.com/training/modules/generate-video-with-foundry/)

[Video generation with Sora 2 (preview)](https://learn.microsoft.com/azure/foundry/openai/concepts/video-generation)

[Quickstart: Generate a video with Sora (preview)](https://learn.microsoft.com/azure/ai-foundry/openai/video-generation-quickstart)

### 4-6. Azure Content Understanding
[What is Azure Content Understanding?](https://learn.microsoft.com/azure/ai-services/content-understanding/overview)

[What is a Content Understanding analyzer?](https://learn.microsoft.com/azure/ai-services/content-understanding/concepts/analyzer-reference)

[Prebuilt analyzers](https://learn.microsoft.com/azure/ai-services/content-understanding/concepts/prebuilt-analyzers)

[Tutorial: Create a custom analyzer](https://learn.microsoft.com/azure/ai-services/content-understanding/tutorial/create-custom-analyzer)

[Create a Microsoft Foundry (multi-service) resource](https://learn.microsoft.com/azure/ai-services/content-understanding/how-to/create-multi-service-resource)

[Quickstart: Use the Content Understanding REST API](https://learn.microsoft.com/azure/ai-services/content-understanding/quickstart/use-rest-api)

[Region and language support](https://learn.microsoft.com/azure/ai-services/content-understanding/language-region-support)

### 7. Azure Document Intelligence
[What is Azure Document Intelligence?](https://learn.microsoft.com/azure/ai-services/document-intelligence/overview?view=doc-intel-4.0.0)

[Document processing models](https://learn.microsoft.com/azure/ai-services/document-intelligence/model-overview?view=doc-intel-4.0.0)

[Document Intelligence Studio](https://learn.microsoft.com/azure/ai-services/document-intelligence/studio-overview?view=doc-intel-4.0.0)

[Document Intelligence custom models](https://learn.microsoft.com/azure/ai-services/document-intelligence/train/custom-model?view=doc-intel-4.0.0)

[Quickstart: Get started with Document Intelligence](https://learn.microsoft.com/azure/ai-services/document-intelligence/quickstarts/get-started-sdks-rest-api?view=doc-intel-4.0.0)

### 8. Knowledge mining with Azure AI Search
[Module - Create a knowledge mining solution with Azure AI Search](https://learn.microsoft.com/training/modules/ai-knowldge-mining/)

[AI enrichment in Azure AI Search](https://learn.microsoft.com/azure/search/cognitive-search-concept-intro)

[Skillset concepts in Azure AI Search](https://learn.microsoft.com/azure/search/cognitive-search-working-with-skillsets)

[Knowledge store in Azure AI Search](https://learn.microsoft.com/azure/search/knowledge-store-concept-intro)

[Integrated vectorization in Azure AI Search](https://learn.microsoft.com/azure/search/vector-search-integrated-vectorization)

[Multimodal search in Azure AI Search](https://learn.microsoft.com/azure/search/multimodal-search-overview)

[Azure Content Understanding skill (for AI Search)](https://learn.microsoft.com/azure/search/cognitive-search-skill-content-understanding)

## Mind Map
```markmap
# Extract insights from visual data on Azure

## Generative AI + Vision
### Vision-enabled apps
- [Use vision-enabled chat models](https://learn.microsoft.com/azure/ai-foundry/openai/how-to/gpt-with-vision)
- Multimodal prompts (text + image)
- ChatCompletions API vs Responses API
### Generate images
- [Image generation (GPT-Image)](https://learn.microsoft.com/azure/foundry/openai/how-to/dall-e)
- OpenAI Image API
### Generate video
- [Sora 2 (preview)](https://learn.microsoft.com/azure/foundry/openai/concepts/video-generation)
- Text-to-video, asynchronous jobs

## Azure Content Understanding
### Multimodal analysis
- Images
- Documents and forms
- Audio
- Video
### Building blocks
- [Analyzers](https://learn.microsoft.com/azure/ai-services/content-understanding/concepts/analyzer-reference)
- [Prebuilt analyzers](https://learn.microsoft.com/azure/ai-services/content-understanding/concepts/prebuilt-analyzers)
- Schema (extract / generate fields)
- [REST API](https://learn.microsoft.com/azure/ai-services/content-understanding/quickstart/use-rest-api)

## Azure Document Intelligence
- [Prebuilt models](https://learn.microsoft.com/azure/ai-services/document-intelligence/model-overview?view=doc-intel-4.0.0)
- Custom models
- Layout / read / OCR
- Key-value pairs, tables, structured data

## Azure AI Search (Knowledge Mining)
### Indexing pipeline
- Data source
- Indexer (document cracking)
- Skillset (AI enrichment)
- Index
### AI enrichment skills
- Language detection
- Key phrase extraction
- Entity recognition
- OCR / image captions
- [Content Understanding skill](https://learn.microsoft.com/azure/search/cognitive-search-skill-content-understanding)
- [Integrated vectorization](https://learn.microsoft.com/azure/search/vector-search-integrated-vectorization)
### Outputs
- Searchable index
- [Knowledge store](https://learn.microsoft.com/azure/search/knowledge-store-concept-intro)
```

## Credentials
[AI-3008: Extract insights from visual data on Azure](https://learn.microsoft.com/en-us/training/paths/insight-visual-data/)

## Contact
- Money Yu
    - Mail: [Money.Yu@microsoft.com](mailto:Money.Yu@microsoft.com)
    - LinkedIn: [@abc12207](https://www.linkedin.com/in/abc12207/)
