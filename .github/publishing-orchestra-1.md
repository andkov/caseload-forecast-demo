# Frontend-1: Publishing Orchestrator Map

**Purpose of this document**: A standing orientation guide for the human editor working on `frontend-1`. Read this before touching any file in this directory or in `_frontend-1/`. Consult it whenever you lose your bearings.

---

## What this system does

The Publishing Orchestra converts a reproducible analytics repository into a static Quarto website — not automatically, but deliberately, with you as the curator. It is not a deployment tool. It is an editorial instrument.

The system does three things well:

1. **Discovers** what is publishable in the repository (code outputs, analysis reports, documentation, pipeline diagrams).
2. **Receives your editorial intent** — which content, for whom, in what order, with what framing.
3. **Executes mechanically** — normalizing sources, scaffolding a Quarto project, and rendering `_site/`.

The creative act — deciding what story the website tells and what evidence it marshals — belongs entirely to you. The agents carry out that intent faithfully. They do not exercise judgment about what matters.

---

## The editorial frame

Before touching any tool, form the narrative:

> *Who is the audience? What do they need to walk away knowing? What is the through-line from the landing page to the final analysis?*

A project website is not an index. It is a curated argument. In this case, the argument is something like:

> *"Here is an open, reproducible pipeline that takes publicly available data and produces defensible 24-month caseload projections. You can understand every decision, reproduce every result, and trust the forecast."*

Every file selection, every nav label, every footnote annotation in `initial.prompt.md` is a micro-choice that either reinforces that argument or dilutes it. The Publishing Orchestra gives you a structured place to make those choices explicitly.

---

## System map: the 13 files

The system lives in `.github/`. It comprises four layers.

### Layer 1 — Agents (4 files)

These are VS Code agent definitions. Each appears in the agent picker (`@name`) when you open a Copilot Chat session.

```
.github/agents/
  publishing-orchestrator.agent.md    ← the only agent you talk to directly
  publishing-pe.agent.md              ← Prompt Engineer: bootstraps editor.prompt.md
  publishing-editor.agent.md          ← Content curator: assembles content/ folder
  publishing-publisher.agent.md       ← Builder: renders the _site/
```

| Agent | What it does in plain language | When to invoke it |
|---|---|---|
| **Orchestrator** | Detects pipeline state, dispatches subagents, pauses at every human checkpoint, routes build errors | Always start here: `@publishing-orchestrator` |
| **Prompt Engineer** | Scans the repo, produces a sensible first draft of `editor.prompt.md`, interviews you to refine it | When starting a new frontend from scratch |
| **Editor** | Reads your `editor.prompt.md`, resolves each file path, normalizes content into `content/`, writes `publisher.prompt.md` | After you approve `editor.prompt.md` |
| **Publisher** | Reads `publisher.prompt.md` + `content/`, scaffolds `_quarto.yml`, runs `quarto render`, writes `questions.prompt.md` if stuck | After you approve `publisher.prompt.md` |

The Orchestrator runs each specialist agent as a subagent. You never need to invoke PE, Editor, or Publisher directly — but you can if you want to re-run a single stage without resetting the entire pipeline.

---

### Layer 2 — Instruction files (4 files)

These are VS Code instruction files. They auto-apply to matching file contexts and guide agent behavior when working within those folders.

```
.github/instructions/
  publishing-content.instructions.md      applyTo: _frontend-*/**
  publishing-analysis.instructions.md     applyTo: analysis/**
  publishing-manipulation.instructions.md applyTo: manipulation/**
  publishing-index.instructions.md        applyTo: _frontend-*/**
```

You do not invoke these directly. They are standing rules that shape how the Editor normalizes content:

- **`publishing-content`** — General normalization rules: `.md` files become Quarto transit pages; `.html` files are embedded inline; assets are copied with correct paths.
- **`publishing-analysis`** — Rules for `analysis/` content: prefer `.qmd` source; use `.html` embed if available and specified; choose figures from `prints/` over `figure-png-iso/`; exclude `*.R`, `*_cache/`, `README.md`.
- **`publishing-manipulation`** — Rules for `manipulation/` content: use `pipeline.md` as primary; include `manipulation/images/`; exclude `.R` scripts and `nonflow/`.
- **`publishing-index`** — Rules for the landing page: adapt root `README.md` for web audiences; strip dev-setup commands; rewrite internal links; align with the site map.

If you want to change how the Editor behaves for a class of files, these are the files to edit.

---

### Layer 3 — Template files (3 files)

These are schema reference documents that agents use as structural scaffolding when producing contract files.

```
.github/templates/
  editor-prompt-template.md      ← schema PE uses to draft editor.prompt.md
  publisher-prompt-template.md   ← schema Editor uses to draft publisher.prompt.md
  questions-prompt-template.md   ← schema Publisher uses to write blockers
```

You do not edit these during normal operation. They define the field names, conventions, and syntax that keep the pipeline's contract files parseable across agents. If you find yourself wanting to add a new kind of annotation to `editor.prompt.md` (e.g., a `priority` field on nav sections), the right place to document that convention is here.

---

### Layer 4 — Entry points (2 files)

These are the on-ramps into the system.

```
.github/copilot/publishing-orchestra-SKILL.md    ← makes the system discoverable
.github/prompts/publishing-new.prompt.md         ← /publishing-new bootstrap command
```

- **`publishing-orchestra-SKILL.md`** is registered as a VS Code skill. When you ask Copilot anything related to publishing a website from this repo, VS Code will surface this skill and load it. It contains the architecture summary and workflow overview.
- **`publishing-new.prompt.md`** is the `/publishing-new` slash command. Running it bootstraps a new `_frontend-N/` workspace: it finds the next available N, scans the repo for publishable content, and generates a default `editor.prompt.md` ready for review.

---

## How the contract files flow

The pipeline communicates through files in `_frontend-1/`. No agent holds shared state. Every handoff is a file.

```
                          YOU (human)
                             │
                     review & edit
                             │
  [PE scans repo]  ──────►  editor.prompt.md       ← your editorial intent
                             │
                     you approve
                             │
  [Editor reads] ──────────► content/               ← normalized source materials
                          publisher.prompt.md        ← deterministic build spec
                             │
                     you approve
                             │
  [Publisher reads] ───────► _quarto.yml            ← scaffolded Quarto project
                          _site/                     ← rendered website
                             │
                     you review
                             │
  [If stuck] ──────────────► questions.prompt.md    ← blockers → you resolve → re-run
```

**`editor.prompt.md`** is the most important file. It is the crystallization of your editorial intent. Everything downstream follows from it mechanically. Write it carefully.

**`publisher.prompt.md`** is a machine-readable expansion of `editor.prompt.md`. You do not edit it; you approve or reject it.

**`content/`** is a normalized staging area. All source files are copied and adapted here. The Publisher never reads original source files — only `content/`.

**`questions.prompt.md`** only appears when the Publisher is stuck. It lists blockers — ambiguous file paths, missing assets, conflicting instructions — with options for resolution. The Orchestrator routes these to you.

---

## This workspace: frontend-1

Two files exist in this directory as the starting point for this frontend:

```
analysis/frontend-1/
  README.md          ← this file
  initial.prompt.md  ← the human editorial document
```

```
_frontend-1/
  editor.prompt.md   ← the pipeline-ready contract (mirrors initial.prompt.md)
```

### `initial.prompt.md` — your editorial document

This is where you work. It is structured identically to `editor.prompt.md` but contains inline `<!-- comments -->` at every decision point explaining the rationale behind each choice. When you want to change the website:

1. Open `initial.prompt.md`.
2. Edit the selections, framing, and notes.
3. Copy the result (without the comments) to `_frontend-1/editor.prompt.md`.
4. Invoke `@publishing-orchestrator` pointing at `_frontend-1/`.

This two-file convention — annotated editorial document here, clean contract there — keeps your thinking visible and revisable without cluttering the pipeline input.

### Current narrative structure (frontend-1)

The four navbar sections encode a deliberate argument structure:

| Section | Content | What it establishes |
|---|---|---|
| **Project** | mission, method, glossary | Why this exists; the 6-stage pipeline; shared vocabulary |
| **Pipeline** | pipeline.md + flow diagram | How the data moves from raw ingestion to forecast |
| **Analysis** | EDA-2 (embedded HTML) + Report-1 (embedded HTML) | The evidence: exploratory findings, then the forecast |
| **Guides** | Getting Started + Flow Usage | How to use it yourself |

This is a logical arc: *purpose → method → evidence → invitation*. If you want to change the argument, change the section order and content in `initial.prompt.md`. The arc will change accordingly.

**What is currently excluded and why:**

- `analysis/eda-1/` — no rendered HTML yet; `.qmd` source only. Add it back when `eda-1.html` exists.
- `guides/mcp-setup/` — developer infrastructure; not relevant to stakeholder audience.
- Several guides (`command-reference.md`, `custom-data-guide.md`, etc.) — operational detail that serves pipeline users, not the intended website audience.
- `ai/` content (except `project/`) — internal AI configuration; not audience-facing.

---

## Workflow: building or updating

### First build (from scratch)

```
1. Review analysis/frontend-1/initial.prompt.md
   └── Adjust selections, change theme, confirm repo URL
2. Copy (clean) to _frontend-1/editor.prompt.md
3. Invoke @publishing-orchestrator
   └── Tell it: "The editor.prompt.md already exists in _frontend-1/"
   └── It will run Editor → Publisher → present _site/ for review
```

### Updating after new analysis is added

```
1. Open analysis/frontend-1/initial.prompt.md
2. Add the new file path to the appropriate nav section
3. Add a comment explaining the editorial rationale
4. Copy the updated content to _frontend-1/editor.prompt.md
5. Invoke @publishing-orchestrator
   └── It detects that editor.prompt.md changed, re-runs Editor and Publisher
```

### Adding a second frontend (different audience)

```
1. Run /publishing-new
   └── It creates _frontend-2/ and analysis/frontend-2/initial.prompt.md
2. Edit initial.prompt.md for the new audience
3. Invoke @publishing-orchestrator pointing at _frontend-2/
```

Each `_frontend-N/` is fully independent. You can have a stakeholder-facing site, a technical reference site, and an internal team site running from the same repository, each with different page selections and themes.

---

## Quick reference

| Task | What to do |
|---|---|
| Change what pages appear on the website | Edit `analysis/frontend-1/initial.prompt.md`, then copy to `_frontend-1/editor.prompt.md` |
| Change the visual theme | Edit `Theme:` in `initial.prompt.md` (Bootswatch themes: cosmo, sketchy, flatly, etc.) |
| Add a custom landing page | Replace `./README.md` in `Index:` with a path to your own `.md` file |
| Start the pipeline | `@publishing-orchestrator` |
| Re-run only the build step | `@publishing-publisher` (assumes `content/` is current) |
| Change how `.html` files are embedded | Edit `.github/instructions/publishing-content.instructions.md` |
| Change which analysis figures are selected | Edit `.github/instructions/publishing-analysis.instructions.md` |
| Change the agent interview questions | Edit `.github/agents/publishing-pe.agent.md` |
| Add a new frontend for a different audience | `/publishing-new` |

---

## Files in this directory

| File | Purpose |
|---|---|
| `README.md` | This orientation document |
| `initial.prompt.md` | Human editorial document — annotated, revisable, source of truth for editorial intent |

The clean pipeline input (`editor.prompt.md`) lives in `_frontend-1/`, not here. This directory is the thinking space. `_frontend-1/` is the execution space.
