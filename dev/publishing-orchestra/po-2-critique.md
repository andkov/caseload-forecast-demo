# Critique of Publishing Orchestra 2

**Purpose**: Starting document for designing Publishing Orchestra v3.
**Scope**: Architecture review of `.github/publishing-orchestra-2.md` and its 13-file / 4-agent implementation, informed by the `_frontend-1` stable build (commit `7cc74d5`).

---

## Executive Summary

Publishing Orchestra v2 has an elegant conceptual model (Raw → Edited → Printed) but its implementation is over-engineered for its actual use case: generating 12-page static websites from existing repo content. The 13-file / 4-agent architecture imposes high cognitive overhead, heavy redundancy, and ceremony that doesn't prevent the real problems encountered during builds. V3 should preserve the lifecycle model while collapsing the agent count, eliminating redundant specification layers, and reducing the file count by ~60%.

---

## SWOT Analysis

### Strengths

1. **The Raw → Edited → Printed lifecycle metaphor is genuinely excellent.** It gives a clear mental anchor for what each transformation does and why. It answers "where am I in the process?" at a glance. Keep this in v3.

2. **Contract-file communication is the right pattern for stateless AI agents.** Agents in VS Code Copilot have no shared memory between invocations. File-mediated handoffs (`editor.prompt.md` → `content/` → `_site/`) are architecturally correct.

3. **Human checkpoints prevent runaway AI.** The mandatory pauses at each phase transition are a genuine safety mechanism. The Orchestrator cannot auto-build a website the human hasn't reviewed.

4. **Source file integrity is non-negotiable and well-enforced.** The rule that agents never modify original repo files is clearly stated in every agent definition and was never violated during the `_frontend-1` build.

5. **Multi-frontend support** — N independent sites from one repo — is a real, valuable feature.

6. **`editor.prompt.md` as "crystallization of human intent" is the system's best abstraction.** It captures what matters (sections, pages, audience, notes) without prescribing how. It's the one file a human actually needs to understand.

7. **Instruction files with `applyTo` patterns are a scalable rule system.** They allow content-type-specific normalization without burdening agent definitions with domain rules.

---

### Weaknesses

1. **Massive cognitive overhead.** To understand the system, a human must internalize 13 files across 4 layers plus the design document (a 14th file). The system description is ~5× longer than the actual website it produced. A new team member needs significant onboarding before making a simple page change.

2. **Heavy redundancy — the same workflow is described 4+ times.** The pipeline is documented in:
   - `publishing-orchestra-2.md` (design doc, ~350 lines)
   - `publishing-orchestrator.agent.md` (state machine + phase execution, ~200 lines)
   - `publishing-orchestra-SKILL.md` (skill file, ~110 lines)
   - Individual agent files (PE, Editor, Printer — each ~200 lines)
   - `_frontend-1/content/docs/publishing-orchestra.md` (site page)

   When one description changes, the others go stale. This already happened: the Printer workflow says "Step 4: Place content files" — but in practice content files stay in `content/` and are rendered in-place via `project.render`.

3. **`printer.prompt.md` is a leaky abstraction.** It claims to be "the deterministic build spec" but the actual `_quarto.yml` diverges from it on every row:

   | In spec (`printer.prompt.md`) | In reality (`_quarto.yml`) |
   |---|---|
   | `content/index.md` | `content/index.qmd` |
   | `content/docs/readme.md` | `content/docs/readme.qmd` |
   | `content/pipeline/pipeline.md` | `content/pipeline/pipeline.qmd` (pre-render generated) |
   | iframe embeds | meta-refresh redirects |
   | No pre/post-render scripts | 2 R scripts registered in hooks |
   | 11 pages in render list | 12 pages (extras added later) |
   | `stories/stories-1.qmd` | dropped entirely |

   The spec became a historical artifact before `_site/` was first rendered. The real source of truth is `_quarto.yml` + `content/`. The intermediate layer adds confusion without adding control.

4. **The PE agent is ceremonial for experienced users.** In practice, the human wrote `editor.prompt.md` directly (via `initial.prompt.md` in the design workspace). The PE's scanning logic duplicates what any competent user already knows about their own repo. The "one question at a time" interview protocol adds latency without proportional value.

5. **The Editor conflates curation with creation.** `editor.prompt.md` contains `<!-- TBD: FILE DOES NOT EXIST -->` markers asking the Editor to *create* content (index page, 400-word project summary, RevealJS slideshow). But the Editor's constraints say "never make editorial decisions" and "deterministic — same input → same output." Creating a project summary is inherently editorial and non-deterministic. This is a design contradiction papered over by letting the Editor do it anyway.

6. **File format confusion caused most real bugs.** Of the 6 issues logged in the stable build, 3 were `.md` vs `.qmd` extension problems. The rules exist in instruction files but are complex enough that agents still got them wrong.

7. **`questions.prompt.md` was never used.** The entire question-routing mechanism (template, lifecycle, Orchestrator routing) was designed but all problems in the `_frontend-1` build were resolved through direct human–AI conversation.

8. **The Orchestrator can't reliably orchestrate.** The agent definition includes a fallback "manual guidance mode" because VS Code Copilot doesn't reliably support calling custom agents as subagents. The "orchestra" became a human manually invoking each instrument.

9. **Design workspace vs execution workspace is confusing.** Both `analysis/frontend-1/initial.prompt.md` and `_frontend-1/editor.prompt.md` exist for the same site — two competing "sources of truth" with a manual copy step between them.

10. **Templates add a layer without adding value.** The 3 template files are schemas each referenced by exactly one agent, exactly once. They could be inlined without losing anything — they're not reusable across projects and were not being used for validation.

---

### Opportunities

1. **Collapse from 4 agents to 2.** An Orchestrator (state detection + human conversation) and a Builder (PE scanning + Editor normalization + Printer rendering in one pass) would cover 95% of the use case. The Builder pauses for human approval between Discover → Assemble → Render phases.

2. **Eliminate `printer.prompt.md`.** The Builder could produce `_quarto.yml` directly. The intermediate spec demonstrably doesn't hold — the Printer always has to adjust anyway. Let the build tool be its own spec.

3. **Merge instruction files.** The 4 instruction files share a common pattern: "for content of type X, do Y." A single `publishing-rules.instructions.md` with sections per content type would be easier to maintain and cross-reference.

4. **Kill templates as standalone files.** Inline the `editor.prompt.md` schema into the Builder agent definition. The Printer and questions schemas never provided independent value.

5. **Resolve the creation vs curation contradiction.** Either: (a) accept that the Builder creates content (summaries, index pages) and drop the "deterministic" fiction, or (b) require all pages to exist before invoking the Builder. Option (b) is cleaner — separate authoring from assembling. Document "Builder-authored content" as an explicitly named category.

6. **Simplify asset resolution.** Adopt a simpler rule: "At the end of Phase 2 (Assemble), `content/` must  be fully self-contained. No post-render fixups." If assets can't be pre-resolved, document the exception as a named R-script hook — a first-class pattern, not a workaround.

7. **Single source of truth for the design.** One document (the v3 design doc) is the only place the workflow is described. Agent definitions reference it rather than re-describing it.

8. **Drop the design workspace pattern.** `analysis/frontend-1/initial.prompt.md` with inline HTML comments that get "stripped to become `editor.prompt.md`" is unnecessary ceremony. Let `editor.prompt.md` itself carry HTML comments for human reasoning.

---

### Threats

1. **Context window limits.** Even a reduced v3 file set competes for AI context with the project's copilot-instructions.md (~16K tokens). If the Publishing Orchestra consumes too much context, agent quality degrades.

2. **VS Code agent platform instability.** Multi-agent orchestration relies on features (subagent invocation, tool restrictions, `applyTo` patterns) that are still evolving in VS Code Copilot. Platform changes could silently break the system.

3. **Quarto version coupling.** The system is tightly bound to current Quarto behavior: `project.render` semantics, pre/post-render hooks, `.qmd` vs `.md` extension handling, mermaid theme initialization. Quarto updates could silently break builds.

4. **Diminishing returns.** The infrastructure-to-output ratio is already high (13 config files + 2 R scripts to produce 12 HTML pages). Adding more framework doesn't produce better websites.

---

## Structural Critique

### The Ceremony Problem

The v2 system has **14 framework files** to produce a **12-page website**:

| Layer | Files | Lines (approx.) | Purpose |
|---|---|---|---|
| Design doc | 1 | ~350 | Explain the system |
| Agent definitions | 4 | ~800 | Tell AI agents how to behave |
| Instruction files | 4 | ~300 | Content-type rules |
| Templates | 3 | ~250 | Schema references |
| Entry points | 2 | ~170 | VS Code integration |
| **Total** | **14** | **~1,870** | |

The `_frontend-1` output: 12 rendered HTML pages, 2 R helper scripts, 1 `_quarto.yml`. Framework-to-output ratio: ~1,870 lines of instructions → 12 pages.

### The Redundancy Problem

The PE → Editor → Printer pipeline is described at least 5 times, each with slightly different terminology and level of detail. They inevitably drift. When they drift, agents follow conflicting instructions.

### The Agent Boundary Problem

The 4-agent split mirrors a human publishing house (editor-in-chief, copy editor, typesetter, press operator) but doesn't map well to how AI agents actually work:

- **PE and Editor share a boundary that's hard to enforce.** Both read the repo, both make judgments about what's publishable. Why scan twice?
- **Editor and Printer share a boundary that's artificial.** The Editor produces `printer.prompt.md`; the Printer translates it into `_quarto.yml`. This is a format conversion, not a meaningful transformation. The Editor could produce `_quarto.yml` directly.
- **The Orchestrator is mostly a router.** It detects state and tells the human which agent to invoke next. This could be a decision tree in a single agent rather than a separate entity — but the human-facing role is worth preserving.

---

## Recommendations for v3

### Principle: Preserve the Model, Simplify the Machinery

The Raw → Edited → Printed lifecycle is the system's best idea. V3 keeps it front and center while dramatically reducing the machinery needed to execute it.

### Proposed Architecture

**2 agents** instead of 4:
1. **Publishing Orchestrator** — Human-facing coordinator. Detects state, manages checkpoints, handles errors.
2. **Publishing Builder** — Combined PE + Editor + Printer in one agent. Three internal phases (Discover → Assemble → Render) with human checkpoints between them.

**1 contract file** instead of 3:
- `editor.prompt.md` remains as the human intent document.
- `printer.prompt.md` eliminated — Builder produces `_quarto.yml` directly.
- `questions.prompt.md` eliminated — Builder asks the human directly (same conversation).

**2 instruction files** instead of 4:
- `publishing-rules.instructions.md` — merged content / analysis / manipulation rules.
- `publishing-index.instructions.md` — kept separate (conceptually distinct).

**0 template files** instead of 3:
- Schemas documented in the design doc or inlined in agent definitions.

**Total: ~6 files** instead of 14.

### Proposed Workflow

```
1. Human invokes @publishing-orchestrator
2. Orchestrator detects state, routes to Builder
3. Builder Phase 1 — DISCOVER: scan repo, show content inventory
   ⏸ Human checkpoint
4. Builder Phase 2 — ASSEMBLE: normalize content/ from editor.prompt.md
   ⏸ Human checkpoint
5. Builder Phase 3 — RENDER: build _quarto.yml + quarto render
   ⏸ Human checkpoint: site ready at _site/
```

Three phases, three checkpoints, two agents, one conversation.

### File Disposition Table

| v2 Component | v3 Status | Rationale |
|---|---|---|
| `publishing-orchestra-2.md` | **Replace** with `publishing-orchestra-3.md` | Single source of truth |
| `publishing-orchestrator.agent.md` | **Keep** (simplified) | State detection + routing |
| `publishing-pe.agent.md` | **Merge** into Builder | Scanning = Builder Phase 1 |
| `publishing-editor.agent.md` | **Merge** into Builder | Assembly = Builder Phase 2 |
| `publishing-printer.agent.md` | **Merge** into Builder | Rendering = Builder Phase 3 |
| `publishing-content.instructions.md` | **Merge** into `publishing-rules.instructions.md` | |
| `publishing-analysis.instructions.md` | **Merge** into `publishing-rules.instructions.md` | |
| `publishing-manipulation.instructions.md` | **Merge** into `publishing-rules.instructions.md` | |
| `publishing-index.instructions.md` | **Keep** (trim if possible) | |
| `editor-prompt-template.md` | **Delete** — inline schema into design doc | Never independently reused |
| `printer-prompt-template.md` | **Delete** — no longer needed | |
| `questions-prompt-template.md` | **Delete** — feature was never used | |
| `publishing-orchestra-SKILL.md` | **Keep** (simplified) | VS Code discoverability |
| `publishing-new.prompt.md` | **Keep** | Convenient bootstrap |

### Contradictions to Resolve

1. **Creation vs. curation**: Explicitly define "Builder-authored content" as a named category. Accept that the Builder creates index pages and summaries. Drop the "deterministic" claim for these pages. Make them reviewable at the Assemble checkpoint.

2. **Pre/post-render R scripts**: Give them first-class status as a "hooks pattern" in the design doc. Not workarounds — they are the correct mechanism for cross-boundary asset resolution.

3. **Design workspace**: Drop `analysis/frontend-N/`. Let `editor.prompt.md` carry inline HTML comments for human reasoning. One file, one source of truth for editorial intent.

---

## Open Questions for the Next Round

1. Should the Orchestrator and Builder be merged into a single agent? Two keeps routing separate from file manipulation; one is simpler but mixes concerns.
2. Should the framework be made portable across repos (removing project-specific paths like `analysis/`, `manipulation/`, `ai/`)? Or stay project-specific and document portability as a future goal?
3. How should the v3 design handle cases where a page genuinely doesn't exist yet? Require it as a precondition, or retain TBD markers with explicit "Builder will author this" semantics?
4. Should `_quarto.yml` be the sole spec, or should there be a thin human-readable summary of the built site (replacing `printer.prompt.md` at a higher level of abstraction)?

---
---

# Part 2 — Interview Findings and V3 Procedural Map

**Source**: Human–AI interview conducted 2026-03-18 (Q1–Q13).

---

## Interview Summary: Resolved Design Decisions

| # | Question | Resolution |
|---|----------|------------|
| Q1 | Who authors COMPOSED pages? | Agent, guided by instruction files. Human reviews in `edited_content/`. |
| Q2 | What happens in Phase 2? | A separate agent ensures all elements are present in `edited_content/` per `editor.prompt.md`. |
| Q3 | Where does iteration feedback re-enter? | Multiple entry points: edit `editor.prompt.md` (re-run Phase 2), edit `edited_content/` directly (re-render), or new `frontend-N-K.prompt.md` delta (re-run from Phase 1). |
| Q4 | Multiple prompt files? | Yes. `frontend-N-2.prompt.md`, `-3`, etc. are **deltas** — they assume prior prompts have been implemented and add specific refinements. Kept as separate files to preserve the human's evolving intent. |
| Q5 | What goes into `editor.prompt.md`? | Human intent — what `edited_content/` SHOULD contain. Not a manifest; describes purpose, audience, desired pages and their types. Some pages may not exist yet. |
| Q6 | One agent or two for planning vs assembly? | **Two agents**: Editor (plans, converses with human, produces `editor.prompt.md`) and Builder (executes mechanically, populates `edited_content/`, renders `_site/`). |
| Q7 | What transformations for TRANSFORMED pages? | Whatever is necessary: `{{< include >}}` injection, stripping dev content, link rewriting, YAML frontmatter, etc. |
| Q8 | Iteration prompt format? | Delta — assumes prior implementation, adds refinements. Separate files per round. |
| Q9 | COMPOSED page brief format in `editor.prompt.md`? | Intent, goal, spirit, desired effect. Not a detailed recipe — just enough for the Builder to understand what the human wants. |
| Q10 | Where does `editor-prompt-template.md` live? | Same place: `.github/templates/editor-prompt-template.md`. Stays a standalone file. |
| Q11 | Is `edited_content/` checkpoint mandatory? | Optional inspection point — "there if you want to look." Builder proceeds to render. Not a mandatory pause. |
| Q12 | COMPOSED page brief detail level? | Less prescriptive than v2's `<!-- TBD -->` markers. Intent + goal + spirit + desired effect. |
| Q13 | Instruction files: merged or per-page? | **Merged** into one `publishing-rules.instructions.md` with exhaustive detail on how to produce each page type. Can be split later if needed. |

---

## V3 Procedural Map

### Content Type Taxonomy

Every page in `edited_content/` is one of four types:

| Type | Definition | Source | Agent action |
|---|---|---|---|
| **VERBATIM** | Repo file displayed as-is | Existing `.md`/`.qmd` | Copy to `edited_content/`, add minimal frontmatter if missing |
| **REDIRECTED** | Pointer to a self-contained HTML report | Existing `.html` | Create redirect stub (`.qmd` with meta-refresh), copy `.html` to `_site/` via post-render hook |
| **COMPOSED** | New content that doesn't exist in the repo | Human's editorial brief in `editor.prompt.md` | Agent authors the page, guided by instruction rules and the brief's stated intent/goal/spirit |
| **TRANSFORMED** | Derived from a repo file with modifications | Existing file + transformation rules | Copy source, then apply changes: inject includes, strip dev content, rewrite links, add frontmatter |

### Lifecycle: Raw → Edited → Printed

```
┌──────────────────────────────────────────────────────────────────────────┐
│ PHASE 0 — HUMAN INTENT                                                  │
│                                                                          │
│ Human writes:  ./analysis/frontend-N/frontend-N-1.prompt.md              │
│   (what the site should achieve, who it's for, what it should feel like) │
│                                                                          │
│ Subsequent rounds (if needed):                                           │
│   frontend-N-2.prompt.md  (delta — refinements, not full replacement)    │
│   frontend-N-3.prompt.md  (delta — further refinements)                  │
│   ...                                                                    │
│ These files are preserved as a record of evolving human intent.          │
└────────────────────────────────┬─────────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ PHASE 1 — EDITORIAL PLANNING  [Editor agent + human]                     │
│                                                                          │
│ Inputs:                                                                  │
│   - frontend-N-*.prompt.md files (all rounds, read in order)             │
│   - .github/templates/editor-prompt-template.md (schema reference)       │
│   - Repo scan (what content exists in the RAW state)                     │
│                                                                          │
│ The Editor agent:                                                        │
│   1. Reads human intent prompts (merging deltas in order)                │
│   2. Scans the repo for publishable content                              │
│   3. Evaluates each candidate against the template schema                │
│   4. Classifies each page: VERBATIM / REDIRECTED / COMPOSED / TRANSFORMED│
│   5. For COMPOSED pages, writes a brief: intent, goal, spirit, effect    │
│   6. Produces _frontend-N/editor.prompt.md                               │
│                                                                          │
│ Output:                                                                  │
│   _frontend-N/editor.prompt.md                                           │
│     - Website name, purpose, audience                                    │
│     - Navigation structure (sections → pages)                            │
│     - Each page: type, source file (or brief for COMPOSED), notes        │
│     - Theme, footer, repo URL                                            │
│     - Exclusions                                                         │
│                                                                          │
│ ⏸ CHECKPOINT: Human reviews and confirms editor.prompt.md                │
│   (human may edit it directly before proceeding)                         │
└────────────────────────────────┬─────────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ PHASE 2 — ASSEMBLY  [Builder agent]                                      │
│                                                                          │
│ Inputs:                                                                  │
│   - _frontend-N/editor.prompt.md (confirmed)                             │
│   - .github/instructions/publishing-rules.instructions.md                │
│   - Repo source files (read-only)                                        │
│                                                                          │
│ The Builder agent populates _frontend-N/edited_content/:                 │
│                                                                          │
│   VERBATIM pages    → copy from repo, add frontmatter if missing         │
│   REDIRECTED pages  → create redirect stubs (.qmd with meta-refresh)     │
│   COMPOSED pages    → author new content per brief + instruction rules   │
│   TRANSFORMED pages → copy source, apply modifications per rules         │
│                                                                          │
│ Self-containment rule:                                                   │
│   At the end of Phase 2, edited_content/ is fully self-contained.        │
│   All images, figures, and assets are co-located.                        │
│   No post-render fixups should be necessary for content resolution.      │
│                                                                          │
│ Output:                                                                  │
│   _frontend-N/edited_content/     (all pages + assets, organized by      │
│                                    section, ready for Quarto)            │
│                                                                          │
│ 👁 INSPECTION POINT (optional): Human can browse edited_content/          │
│   to verify content before rendering. Not a mandatory pause.             │
└────────────────────────────────┬─────────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ PHASE 3 — RENDER  [Builder agent, continued]                             │
│                                                                          │
│ The Builder agent:                                                       │
│   1. Generates _frontend-N/_quarto.yml from editor.prompt.md             │
│      - Explicit render list (no wildcards)                               │
│      - Navbar structure matching editor.prompt.md sections               │
│      - Pre/post-render hooks if needed (documented, not workarounds)     │
│   2. Runs: quarto render (from _frontend-N/)                             │
│   3. Reconciles: verifies every page in editor.prompt.md has a           │
│      corresponding .html in _site/                                       │
│                                                                          │
│ Output:                                                                  │
│   _frontend-N/_quarto.yml        (Quarto config — the real build spec)   │
│   _frontend-N/_site/             (rendered static website)               │
│                                                                          │
│ ⏸ CHECKPOINT: Human reviews _site/                                       │
└────────────────────────────────┬─────────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ ITERATION LOOPS                                                          │
│                                                                          │
│ After reviewing _site/, the human can re-enter at multiple points:       │
│                                                                          │
│ Loop A — Re-plan (structural changes)                                    │
│   Write frontend-N-K.prompt.md (delta with new instructions)             │
│   Re-run from Phase 1                                                    │
│                                                                          │
│ Loop B — Re-assemble (content changes)                                   │
│   Edit editor.prompt.md (adjust pages, types, briefs)                    │
│   Re-run from Phase 2                                                    │
│                                                                          │
│ Loop C — Micro-edit (fine-tuning)                                        │
│   Edit files directly in edited_content/                                 │
│   Re-render only (quarto render from _frontend-N/)                       │
│                                                                          │
│ Loop D — Conversational (most common)                                    │
│   Talk to the Editor agent in chat                                       │
│   Agent determines which loop applies and acts accordingly               │
└──────────────────────────────────────────────────────────────────────────┘
```

### Agents in V3

| Agent | Role | Human-facing? | Inputs | Outputs |
|---|---|---|---|---|
| **Editor** | Planning + human conversation. Reads human intent prompts, scans repo, classifies pages, produces `editor.prompt.md`. Also serves as the entry point (absorbs v2 Orchestrator role). | Yes | `frontend-N-*.prompt.md`, `editor-prompt-template.md`, repo scan | `editor.prompt.md` |
| **Builder** | Execution. Populates `edited_content/`, generates `_quarto.yml`, renders `_site/`. Guided by instruction files. Non-conversational. | No (reports via Editor) | `editor.prompt.md`, `publishing-rules.instructions.md`, repo source files | `edited_content/`, `_quarto.yml`, `_site/` |

### File Inventory (v3 target)

```
.github/
├── publishing-orchestra-3.md                    ← Design doc (single source of truth)
├── agents/
│   ├── publishing-editor.agent.md               ← Editor (planning + human conversation)
│   └── publishing-builder.agent.md              ← Builder (assembly + rendering)
├── instructions/
│   └── publishing-rules.instructions.md         ← Merged rules: VERBATIM, REDIRECTED,
│                                                   COMPOSED, TRANSFORMED handling;
│                                                   plus analysis/, manipulation/, index rules
├── templates/
│   └── editor-prompt-template.md                ← Schema for editor.prompt.md (kept)
├── copilot/
│   └── publishing-orchestra-SKILL.md            ← VS Code discoverability (simplified)
└── prompts/
    └── publishing-new.prompt.md                 ← Bootstrap new frontend workspace

Total: 7 files  (down from 14)
```

### Workspace Structure (v3)

```
caseload-forecast-demo/
├── analysis/
│   └── frontend-N/
│       ├── frontend-N-1.prompt.md   ← Round 1 human intent (preserved)
│       ├── frontend-N-2.prompt.md   ← Round 2 delta (preserved)
│       └── ...
├── _frontend-N/
│   ├── editor.prompt.md             ← Confirmed editorial plan
│   ├── edited_content/              ← All pages + assets (self-contained)
│   │   ├── index.qmd               ← COMPOSED
│   │   ├── project/
│   │   │   ├── summary.md          ← COMPOSED
│   │   │   ├── mission.md          ← VERBATIM
│   │   │   └── ...
│   │   ├── pipeline/
│   │   │   ├── pipeline.qmd        ← TRANSFORMED
│   │   │   └── cache-manifest.md   ← VERBATIM
│   │   ├── analysis/
│   │   │   ├── eda-2.qmd           ← REDIRECTED
│   │   │   └── report-1.qmd        ← REDIRECTED
│   │   └── docs/
│   │       ├── readme.qmd          ← TRANSFORMED
│   │       └── site-map.md         ← COMPOSED
│   ├── _quarto.yml                  ← Generated by Builder (the real build spec)
│   ├── scripts/                     ← Pre/post-render hooks (first-class, documented)
│   └── _site/                       ← Rendered website
└── .github/
    └── ...                          ← Framework files (7 total)
```

### Key Differences from V2

| Aspect | V2 | V3 |
|---|---|---|
| Agents | 4 (Orchestrator, PE, Editor, Printer) | 2 (Editor, Builder) |
| Framework files | 14 | 7 |
| Contract files per frontend | 3 (`editor.prompt.md`, `printer.prompt.md`, `questions.prompt.md`) | 1 (`editor.prompt.md`) |
| Intermediate spec | `printer.prompt.md` (leaky, diverged from reality) | None — `_quarto.yml` is the build spec |
| Content folder | `content/` | `edited_content/` (distinct from `_site/content/`) |
| Content types | Implicit (VERBATIM emerged organically) | 4 explicit types: VERBATIM, REDIRECTED, COMPOSED, TRANSFORMED |
| Human intent preservation | `analysis/frontend-N/initial.prompt.md` (single file) | `analysis/frontend-N/frontend-N-*.prompt.md` (versioned deltas) |
| Instruction files | 4 separate | 1 merged |
| COMPOSED page briefs | `<!-- TBD -->` comments in `editor.prompt.md` | Structured briefs: intent, goal, spirit, desired effect |
| `edited_content/` self-containment | Not enforced (needed post-render fixups) | Mandatory rule: fully self-contained at end of Phase 2 |
| Pre/post-render hooks | Discovered organically, treated as workarounds | First-class pattern, documented in design doc |

---

## Remaining Open Questions

1. **Framework portability**: Should v3 remove project-specific paths (`analysis/`, `manipulation/`, `ai/`) from instruction files, or stay project-specific and document portability as a future goal?
2. **Hook formalization**: Should pre/post-render R scripts have their own section in `publishing-rules.instructions.md`, or a separate `publishing-hooks.instructions.md`?
3. **Builder error handling**: When the Builder encounters an ambiguous COMPOSED brief, does it stop and ask the Editor (who relays to human), or make its best attempt and flag it for review at the `edited_content/` inspection point?