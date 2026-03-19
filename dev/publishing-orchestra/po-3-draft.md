# Publishing Orchestra v3 — Design Draft

**Status**: Working draft toward `.github/publishing-orchestra-3.md`
**Builds on**: `dev/publishing-orchestra/po-2-critique.md` (SWOT analysis + interview findings)
**Date**: 2026-03-18

---

## Design Philosophy

Publishing Orchestra v3 preserves the **Raw → Edited → Printed** lifecycle — the system's best idea — while cutting the machinery in half. The guiding principle:

> **Fewer files, fewer agents, same human control.**

V2 had 14 framework files and 4 agents to produce a 12-page website. V3 targets 7 files and 2 agents. The reduction comes from eliminating redundant specification layers (`printer.prompt.md`, `questions.prompt.md`), merging agents whose boundaries were artificial, and inlining schemas that served only one consumer.

---

## The Three States of Analytic Content

Unchanged from v2 — this is the conceptual foundation.

```
RAW  ──────────►  EDITED  ──────────►  PRINTED
(repo)            (edited_content/)     (_site/)
```

### Raw

The repository at a point in time. Contains everything: working drafts, analyses, pipelines, AI config, developer tooling. Honest but noisy. Not shaped for any audience, but to the convenience of the analyst who composed RAW.

### Edited
Content curated by a human (via `editor.prompt.md`) and assembled by the Builder agent into `_frontend-N/edited_content/`. Self-contained, normalized, ready for Quarto rendering. Every page is classified as one of four types (see Content Type Taxonomy below).

### Printed
The rendered static website in `_frontend-N/_site/`. Output of `quarto render` applied to the Edited state. Browseable, portable, self-contained. Can be opened via `file://` without a local server.

---

## Content Type Taxonomy

Every page in `edited_content/` is exactly one of four types. This taxonomy is the primary organizing concept for the instruction file and the Builder agent.

| Type | Definition | Source | Builder action |
|---|---|---|---|
| **VERBATIM** | Repo file displayed as-is | Existing `.md` / `.qmd` | Copy to `edited_content/`, add minimal YAML frontmatter if missing |
| **REDIRECTED** | Pointer to a self-contained HTML report | Existing `.html` | Create redirect stub (`.qmd` with `<meta http-equiv="refresh">`), copy `.html` to `_site/` via post-render hook |
| **COMPOSED** | New content that doesn't exist in the repo | Human's editorial brief in `editor.prompt.md` | Agent authors the page, guided by instruction rules and the brief's stated intent / goal / spirit |
| **TRANSFORMED** | Derived from a repo file with modifications applied | Existing file + transformation rules | Copy source, then apply changes: inject `{{< include >}}` shortcodes, strip developer content, rewrite links, add frontmatter, etc. |

### Examples from `_frontend-1`

| Page | Type | Source → Output |
|---|---|---|
| `project/mission.md` | VERBATIM | `ai/project/mission.md` → copied |
| `project/glossary.md` | VERBATIM | `ai/project/glossary.md` → copied |
| `pipeline/cache-manifest.md` | VERBATIM | `data-public/metadata/CACHE-manifest.md` → copied |
| `analysis/eda-2.qmd` | REDIRECTED | Stub redirecting to `analysis/eda-2/eda-2.html` |
| `analysis/report-1.qmd` | REDIRECTED | Stub redirecting to `analysis/report-1/report-1.html` |
| `index.qmd` | COMPOSED | Agent-authored landing page |
| `project/summary.md` | COMPOSED | Agent-authored project summary |
| `docs/site-map.md` | COMPOSED | Agent-authored site map |
| `docs/readme.qmd` | TRANSFORMED | `README.md` → links rewritten, mermaid diagram injected via `{{< include >}}`, images co-located |
| `pipeline/pipeline.qmd` | TRANSFORMED | `manipulation/pipeline.md` → mermaid block replaced with `{{< include >}}`, extension changed to `.qmd` |

---

## Agents

### Two agents, clear boundary

| Agent | Role | Human-facing? | Analogy |
|---|---|---|---|
| **Publishing Editor** | Planning + human conversation. Reads human intent, scans repo, classifies pages, produces `editor.prompt.md`. Entry point for the workflow. | Yes | Editorial planning meeting |
| **Publishing Builder** | Execution. Populates `edited_content/`, generates `_quarto.yml`, renders `_site/`. Guided by instruction files. Non-conversational — reports results. | No | The press room |

### Why this split

- The **Editor** requires judgment: interpreting vague human intent, deciding what type each page is, writing COMPOSED page briefs. It's conversational.
- The **Builder** requires precision: copying files, authoring COMPOSED pages per instruction rules, resolving assets. It's procedural.
- `editor.prompt.md` is the clean handoff: human-readable intent on one side, mechanical execution on the other.
- If the Builder gets something wrong in `edited_content/`, you re-run *just the Builder* without redoing editorial planning.

### What happened to v2's agents

| v2 Agent | v3 Fate | Rationale |
|---|---|---|
| Publishing Orchestrator | Absorbed into **Editor** | The Editor is already the human-facing agent; state detection is a decision tree, not a separate entity |
| Publishing PE | Absorbed into **Editor** Phase 1 | Repo scanning and intent elicitation are the Editor's first act |
| Publishing Editor | Becomes **Editor** | Same core role, expanded to include orchestration |
| Publishing Printer | Becomes **Builder** | Same core role, expanded to include assembly |

---

## Procedural Map

### Phase 0 — Human Intent

The human writes their vision for the website in a prompt file:

```
./analysis/frontend-N/frontend-N-1.prompt.md
```

This is unadulterated human intent — what the site should achieve, who it's for, what it should feel like. The file is preserved as a permanent record.

**Iteration rounds** produce delta files:
- `frontend-N-2.prompt.md` — refinements after seeing first results
- `frontend-N-3.prompt.md` — further adjustments
- Each delta assumes prior prompts have been implemented. Deltas are additive, not replacements.
- Kept as separate files to preserve the trajectory of evolving human thinking.

### Phase 1 — Editorial Planning

**Agent**: Publishing Editor (human-facing, conversational)

**Inputs**:
- `analysis/frontend-N/frontend-N-*.prompt.md` — all rounds, read in order
- `.github/templates/editor-prompt-template.md` — schema reference
- Repo contents — scanned for publishable material

**Process**:
1. Read human intent prompts (merge deltas in sequence)
2. Scan the repo for publishable content
3. Evaluate each candidate against the template schema
4. Classify each page: VERBATIM / REDIRECTED / COMPOSED / TRANSFORMED
5. For COMPOSED pages, write a brief: intent, goal, spirit, desired effect
6. Produce `_frontend-N/editor.prompt.md`

**Output**: `_frontend-N/editor.prompt.md` containing:
- Website name, purpose, audience
- Navigation structure (sections → pages)
- Each page: type, source file (or brief for COMPOSED), notes
- Theme, footer, repo URL
- Exclusions

**Checkpoint**: Human reviews and confirms `editor.prompt.md`. May edit it directly before proceeding.

### Phase 2 — Assembly

**Agent**: Publishing Builder (non-conversational, instruction-guided)

**Inputs**:
- `_frontend-N/editor.prompt.md` (confirmed by human)
- `.github/instructions/publishing-rules.instructions.md`
- Repo source files (read-only)

**Process**: Populate `_frontend-N/edited_content/`:
- **VERBATIM** → copy from repo, add frontmatter if missing
- **REDIRECTED** → create redirect stubs
- **COMPOSED** → author new content per brief + instruction rules
- **TRANSFORMED** → copy source, apply modifications per rules

**Self-containment rule**: At the end of Phase 2, `edited_content/` is fully self-contained. All images, figures, and assets are co-located. No post-render fixups should be necessary for content resolution.

**Output**: `_frontend-N/edited_content/` — all pages and assets, organized by section.

**Inspection point** (optional): Human can browse `edited_content/` to verify content before rendering. Not a mandatory pause — Builder proceeds automatically.

### Phase 3 — Render

**Agent**: Publishing Builder (continued)

**Process**:
1. Generate `_frontend-N/_quarto.yml` from `editor.prompt.md`
   - Explicit render list (no wildcards)
   - Navbar structure matching `editor.prompt.md` sections
   - Pre/post-render hooks if needed (documented, first-class)
2. Run `quarto render` from `_frontend-N/`
3. Reconcile: verify every page in `editor.prompt.md` has a corresponding `.html` in `_site/`

**Output**:
- `_frontend-N/_quarto.yml` — Quarto config (the real and only build spec)
- `_frontend-N/_site/` — rendered static website

**Checkpoint**: Human reviews `_site/`.

### Iteration Loops

After reviewing `_site/`, the human can re-enter at multiple points:

| Loop | Entry point | Re-runs from | When to use |
|---|---|---|---|
| **A — Re-plan** | Write `frontend-N-K.prompt.md` (delta) | Phase 1 | Structural changes: add sections, change audience, rethink navigation |
| **B — Re-assemble** | Edit `editor.prompt.md` | Phase 2 | Content changes: swap a page type, adjust a brief, add/remove pages |
| **C — Micro-edit** | Edit files in `edited_content/` directly | Phase 3 (render only) | Fine-tuning: fix a typo, adjust wording, tweak CSS |
| **D — Conversational** | Talk to Editor agent in chat | Agent determines appropriate loop | Most common in practice |

---

## Contract Files

V3 eliminates two of v2's three contract files:

| File | v2 | v3 | Rationale |
|---|---|---|---|
| `editor.prompt.md` | Human intent → Editor input | **Kept** — the system's best abstraction | Single contract between human and Builder |
| `printer.prompt.md` | Editor output → Printer input | **Eliminated** | Builder writes `_quarto.yml` directly; the intermediate spec was always stale |
| `questions.prompt.md` | Printer blockers → Orchestrator | **Eliminated** | Builder makes its best attempt, flags issues at the `edited_content/` inspection point. Major blockers are resolved conversationally via the Editor agent. |

### `editor.prompt.md` in v3

The format evolves from v2. Key changes:

1. **Explicit content types**: Every page is tagged VERBATIM / REDIRECTED / COMPOSED / TRANSFORMED.
2. **COMPOSED briefs**: For pages that don't exist in the repo, the Editor writes a brief describing intent, goal, spirit, and desired effect (not a detailed recipe).
3. **Human comments welcome**: HTML comments (`<!-- ... -->`) are preserved as human reasoning — no need for a separate `initial.prompt.md`.

Example structure:

```markdown
# [Website Name]

## Purpose
[1-2 paragraphs: goal, audience, context]

## Navigation

### [Section Name]

#### [Page Title]
- **Type**: VERBATIM
- **Source**: ./ai/project/mission.md

#### [Page Title]
- **Type**: COMPOSED
- **Intent**: Orient the visitor. Establish credibility. Invite exploration.
- **Goal**: Landing page — first thing a visitor sees.
- **Spirit**: Professional but approachable. Visuals lead, prose follows.
- **Inputs**: Mermaid diagram from manipulation/pipeline.md,
  forecast image from analysis/report-1/prints/g1_forecast_report.png

#### [Page Title]
- **Type**: REDIRECTED
- **Source**: ./analysis/eda-2/eda-2.html

#### [Page Title]
- **Type**: TRANSFORMED
- **Source**: ./README.md
- **Transforms**: Inject mermaid diagram via include, rewrite links for site context,
  strip developer build instructions, co-locate images

## Exclusions
[Patterns to skip]

## Theme
[Bootswatch theme name]

## Footer
[Footer text]
```

---

## Instruction Files

### Merged into one: `publishing-rules.instructions.md`

Contains exhaustive rules for how to produce each page type in `edited_content/`. Organized by content type:

```markdown
# Publishing Rules

## 1. General Principles
- Self-containment: all assets co-located in edited_content/
- Source file integrity: never modify repo originals
- Explicit render list: no wildcards in _quarto.yml

## 2. VERBATIM Pages
- Copy source to edited_content/<section>/
- Add YAML frontmatter if missing (title from first heading or filename)
- Do not modify content
- Co-locate any referenced images

## 3. REDIRECTED Pages
- Create .qmd stub with <meta http-equiv="refresh"> pointing to the HTML
- Use page-layout: full, toc: false
- Register post-render hook to copy the target .html into _site/

## 4. COMPOSED Pages
- Author content per the brief in editor.prompt.md
- Follow the stated intent, goal, spirit
- Consult instruction sub-sections for specific page types:
  ### 4a. Index Page
  [Rules for landing pages: visual anchors first, orientation text,
   link alignment with navbar, no developer jargon, ...]
  ### 4b. Site Map
  [Rules for auto-generating site map from editor.prompt.md structure]
  ### 4c. Project Summary
  [Rules for synthesizing from mission/method/README]

## 5. TRANSFORMED Pages
- Copy source, then apply documented modifications
- Common transforms:
  ### 5a. Mermaid diagram injection
  [Replace ```mermaid fences with {{< include _partial.qmd >}}]
  ### 5b. Link rewriting
  [Adjust relative paths for site context]
  ### 5c. Developer content stripping
  [Remove build instructions, CLI commands, contributor guides]
  ### 5d. Extension promotion
  [.md → .qmd when file contains executable content like {{< include >}}]

## 6. Asset Resolution
- All images, figures, media copied into edited_content/ at assembly time
- Relative paths must resolve within edited_content/
- For assets that cannot be pre-resolved (e.g., redirect targets),
  use documented pre/post-render hooks

## 7. Pre/Post-Render Hooks
- First-class pattern, not workarounds
- Registered in _quarto.yml by the Builder
- Used for: copying redirect target HTMLs, mirroring external images
- Each hook is an R script in _frontend-N/scripts/
```

### `editor-prompt-template.md` — Kept

Stays at `.github/templates/editor-prompt-template.md`. Updated to reflect the v3 `editor.prompt.md` schema (content types, COMPOSED briefs). Consulted by the Editor agent when producing `editor.prompt.md` from human intent prompts.

---

## Pre/Post-Render Hooks

V2 discovered hooks organically and treated them as workarounds. V3 gives them first-class status.

**When hooks are needed**: When the self-containment rule has a legitimate exception — typically REDIRECTED pages whose HTML targets live outside `edited_content/`.

**How they work**:
- Builder creates R scripts in `_frontend-N/scripts/`
- Builder registers them in `_quarto.yml` under `project.pre-render` / `project.post-render`
- Each script is documented with a comment explaining what it does and why

**Current hooks from `_frontend-1`** (carry forward to v3):

| Script | Hook | Purpose |
|---|---|---|
| `prep-pipeline-qmd.R` | pre-render | Generates `pipeline.qmd` from `manipulation/pipeline.md`, injecting mermaid include |
| `copy-analysis-html.R` | post-render | Copies redirect target HTMLs into `_site/`, mirrors README images |

---

## File Inventory

### Framework files (7)

```
.github/
├── publishing-orchestra-3.md                    ← Design doc (single source of truth)
├── agents/
│   ├── publishing-editor.agent.md               ← Editor (planning + conversation)
│   └── publishing-builder.agent.md              ← Builder (assembly + rendering)
├── instructions/
│   └── publishing-rules.instructions.md         ← Merged rules for all 4 content types
├── templates/
│   └── editor-prompt-template.md                ← Schema for editor.prompt.md
├── copilot/
│   └── publishing-orchestra-SKILL.md            ← VS Code discoverability
└── prompts/
    └── publishing-new.prompt.md                 ← Bootstrap new frontend workspace
```

### Per-frontend workspace

```
analysis/frontend-N/
├── frontend-N-1.prompt.md       ← Round 1 human intent (preserved)
├── frontend-N-2.prompt.md       ← Round 2 delta (preserved)
└── ...

_frontend-N/
├── editor.prompt.md             ← Confirmed editorial plan (the one contract file)
├── edited_content/              ← All pages + assets (self-contained)
│   ├── index.qmd               ← COMPOSED
│   ├── _pipeline-diagram.qmd   ← Shared partial (mermaid diagram)
│   ├── project/
│   │   ├── summary.md          ← COMPOSED
│   │   ├── mission.md          ← VERBATIM
│   │   ├── method.md           ← VERBATIM
│   │   └── glossary.md         ← VERBATIM
│   ├── pipeline/
│   │   ├── pipeline.qmd        ← TRANSFORMED
│   │   └── cache-manifest.md   ← VERBATIM
│   ├── analysis/
│   │   ├── eda-2.qmd           ← REDIRECTED
│   │   └── report-1.qmd        ← REDIRECTED
│   └── docs/
│       ├── readme.qmd          ← TRANSFORMED
│       └── site-map.md         ← COMPOSED
├── scripts/                     ← Pre/post-render hooks
│   ├── prep-pipeline-qmd.R
│   └── copy-analysis-html.R
├── _quarto.yml                  ← Generated by Builder
└── _site/                       ← Rendered website
```

---

## Comparison: V2 → V3

| Aspect | V2 | V3 |
|---|---|---|
| Agents | 4 (Orchestrator, PE, Editor, Printer) | 2 (Editor, Builder) |
| Framework files | 14 | 7 |
| Contract files per frontend | 3 | 1 (`editor.prompt.md`) |
| Intermediate build spec | `printer.prompt.md` (leaked, diverged) | None — `_quarto.yml` is the spec |
| Content folder name | `content/` | `edited_content/` |
| Content type taxonomy | Implicit (emerged organically) | 4 explicit types: VERBATIM, REDIRECTED, COMPOSED, TRANSFORMED |
| COMPOSED page guidance | `<!-- TBD -->` comments | Structured briefs: intent, goal, spirit |
| Human intent preservation | Single `initial.prompt.md` | Versioned deltas: `frontend-N-1.prompt.md`, `-2`, `-3`... |
| Instruction files | 4 separate | 1 merged (`publishing-rules.instructions.md`) |
| Pre/post-render hooks | Workarounds | First-class documented pattern |
| Self-containment | Not enforced (needed post-render fixups) | Mandatory rule for `edited_content/` |
| Workflow descriptions | Duplicated 5+ times across files | Single source of truth in design doc |

---

## Migration Path: V2 → V3

### Files to create
1. `.github/publishing-orchestra-3.md` — from this draft
2. `.github/agents/publishing-builder.agent.md` — new agent
3. `.github/instructions/publishing-rules.instructions.md` — merged from 4 instruction files

### Files to update
4. `.github/agents/publishing-editor.agent.md` — expanded role (absorbs Orchestrator + PE)
5. `.github/copilot/publishing-orchestra-SKILL.md` — simplified
6. `.github/templates/editor-prompt-template.md` — add content type fields, COMPOSED brief schema
7. `.github/prompts/publishing-new.prompt.md` — minor updates

### Files to archive (move to `.github/archive/v2/` or delete)
8. `.github/publishing-orchestra-2.md` → archive
9. `.github/publishing-orchestra-1.md` → archive
10. `.github/agents/publishing-orchestrator.agent.md` → archive (absorbed into Editor)
11. `.github/agents/publishing-pe.agent.md` → archive (absorbed into Editor)
12. `.github/agents/publishing-printer.agent.md` → archive (becomes Builder)
13. `.github/instructions/publishing-content.instructions.md` → archive (merged)
14. `.github/instructions/publishing-analysis.instructions.md` → archive (merged)
15. `.github/instructions/publishing-manipulation.instructions.md` → archive (merged)
16. `.github/instructions/publishing-index.instructions.md` → archive (merged)
17. `.github/templates/printer-prompt-template.md` → delete
18. `.github/templates/questions-prompt-template.md` → delete

---

## Open Design Questions

1. **Framework portability**: Should v3 remove project-specific paths (`analysis/`, `manipulation/`, `ai/`) from the instruction file? Or stay project-specific and document portability as a future goal? **Recommendation**: Stay project-specific. This is a learning sandbox, not a framework distribution.

2. **Hook formalization**: Should hooks have their own section in `publishing-rules.instructions.md` (proposed above), or a separate file? **Recommendation**: Section within the merged file. Separate only if rules grow beyond ~50 lines.

3. **Builder error handling**: When the Builder encounters an ambiguous COMPOSED brief, does it stop and ask the Editor (who relays to human), or make its best attempt and flag it? **Recommendation**: Best attempt, flagged at the `edited_content/` inspection point. Stopping breaks the flow for edge cases.

4. **`edited_content/` vs `content/`**: The rename to `edited_content/` distinguishes it from `_site/content/`. Is this worth the extra characters? **Recommendation**: Yes — clarity over brevity, especially when both folders are discussed in the same conversation.

5. **Should `_quarto.yml` generation be part of Phase 2 or Phase 3?** Currently proposed as Phase 3. But `_quarto.yml` is tightly coupled to `edited_content/` structure — generating them together might be more natural. **Recommendation**: Phase 3 is fine. Assembly (content) and rendering (config + build) are conceptually distinct even if executed by the same agent in sequence.
