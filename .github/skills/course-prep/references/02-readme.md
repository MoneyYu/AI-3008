# Phase 2 — Attendee-facing README

The `README.md` is the **attendee-facing** course reference page. It uses **HackMD-style** syntax
(the user publishes it on HackMD), which is *not* plain GitHub Markdown. Preserve these constructs:

- **YAML front-matter** (`image`, `tags`, Google Analytics `GA` id).
- **Admonition blocks**: `:::success`, `:::info`, `:::warning` … `:::`.
- An optional **mind map**: a ```` ```markmap ```` fenced block.

## Hard rule: attendee-only

Keep **trainer-private** content out of the README — no demo-environment details, no model-choice
rationale, no Terraform, no internal notes. Those live in `docs/` (Phase 6 and
`docs/demo-environment.md`). If you find such a section in an old README, **move** it to `docs/`.

## Required sections (adapt to the course)

1. **Front-matter + title + one-paragraph intro** — what the course teaches, in plain language.
2. **`## Course`** — `:::success` with the per-instance metadata: **Date** (`YYYYMMDD`),
   **Course ID** (the numeric ESI delivery id). `:::info` with the **Course Survey** link.
3. **`## Course Materials`** — the Microsoft Learn learning-path links (EN / `zh-cn` / `zh-tw`) and
   the Learn course page.
4. **`## Infos`** — LxP portal (`esi.microsoft.com`) and ESI support links.
5. **`## Lab`**
   - **Skillable**: ESI Labs link + `:::success` **Training key** + `:::info` redeem-once / valid
     6 months note.
   - **Instruction**: the lab exercise links (grouped per lab repo if there are several), plus each
     `main.zip`. Add a `:::warning` if labs aren't localized.
6. **`## Links`** — curated, **topic-grouped** authoritative Microsoft Learn links (per module /
   service). This is where you add comparisons surfaced by the slides (e.g. *ChatCompletions API vs
   Responses API*, *Default vs Custom deployment settings*) with a short explanation + links.
7. *(optional)* **mind map** — a ```` ```markmap ```` overview of the modules.

## Per-instance metadata to refresh every delivery

`Date`, `Course ID`, `Course Survey`, and the **Skillable Training key**. These change per class —
update them and nothing else when only re-running the same course.

## Quality bar

- **Verify every external link resolves (HTTP 200)** before adding it. Drop or fix dead links.
- Prefer canonical `learn.microsoft.com/...` URLs over blog/marketing pages.
- Keep wording concise and attendee-appropriate; technical depth goes in `docs/teaching-guide.md`.
- When the slides show two competing concepts, add a short **comparison** (a small table) to the
  relevant `## Links` subsection rather than burying a single link.
