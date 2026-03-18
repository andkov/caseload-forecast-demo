---
toc: true
---

# Publishing Orchestra — Design v2

**Status**: Current design reference (March 2026). Supersedes `publishing-orchestra-1.md`.

A multi-agent system that transforms a reproducible analytics repository into a static Quarto website — with human editorial control at every stage.

---

## Three States of Analytic Content

The central model of the Publishing Orchestra is a **three-state content lifecycle**:

```
RAW  ──────────► EDITED  ──────────► PRINTED
(repo)          (content/)           (_site/)
```

### Raw

The repository at a point in time — typically identified by a commit hash. It contains everything: working drafts, experimental analyses, internal reports, data pipelines, AI configuration, developer tooling, and partially complete work. Raw content is honest but noisy. It is not shaped for any particular audience.

> Raw = the full GitHub repo. You cannot publish Raw content directly — it requires human judgment about what belongs on a website and what doesn't.

### Edited

Content that has been curated by a human (via `editor.prompt.md`) and normalized by the Publishing Editor into `_frontend-N/content/`. The Edited state is:

- **Localized**: all edited files live in `_frontend-N/content/`, never in the repo source tree
- **Self-contained**: all referenced images, figures, and media are copied alongside page files
- **Normalized**: source formats (`.md`, `.qmd`, `.html`) are converted into website-ready Quarto pages
- **Approved**: the human has reviewed and accepted the content plan before this state is produced

> Edited = curated raw materials, ready for printing, but not yet a website.

### Printed

The rendered static website in `_frontend-N/_site/`. It is the output of `quarto render` applied to the Edited state, following the deterministic specification in `printer.prompt.md`. The Printed state is:

- **Browseable**: a self-contained `_site/` folder that can be opened in a browser or deployed to any static host
- **Reproducible**: given the same Edited state and `printer.prompt.md`, the Printer always produces the same `_site/`
- **Separable**: `_site/` does not depend on files outside itself

> Printed = the public face of the analysis. This is what an audience sees.

---

## Pipeline: How Content Moves Through the Three States

**Human checkpoints** (①②③) are mandatory pauses. The Orchestrator never auto-proceeds past a checkpoint.

---

## Agents

### Publishing Orchestrator

**The only agent you interact with directly.**

| | |
|---|---|
| **Invocation** | `@publishing-orchestrator` |
| **Input** | Your instructions, `_frontend-N/` workspace state |
| **Output** | Dispatches to subagents, pauses at checkpoints, routes errors |

The Orchestrator detects the current pipeline state by inspecting which files exist in `_frontend-N/`:

| State | Condition | Action |
|-------|-----------|--------|
| `INIT` | Workspace empty or missing | Run Prompt Engineer |
| `PE_READY` | `editor.prompt.md` exists | Show to human → run Editor |
| `EDITOR_READY` | `editor.prompt.md` + `content/` + `printer.prompt.md` exist | Show to human → run Printer |
| `PRINTER_READY` | All above + `_site/` | Show site to human → done |
| `BLOCKED` | `questions.prompt.md` exists | Route blockers to human → resolve → re-run Printer |

---

### Publishing PE (Prompt Engineer)

**Helps the human articulate what to publish.**

Scans the repository for publishable content and bootstraps `editor.prompt.md`. Interviews the human to refine which pages appear, the target audience, and content classification (verbatim vs editorialized).

---

### Publishing Editor

**Performs the Raw → Edited transformation.**

| | |
|---|---|
| **Input** | `_frontend-N/editor.prompt.md` + repository source files (read-only) |
| **Output** | `_frontend-N/content/` (normalized pages + assets) + `_frontend-N/printer.prompt.md` |

**Critical localization rule**: everything the Editor creates goes into `_frontend-N/content/`. The Editor **never modifies original source files**.

---

### Publishing Printer

**Performs the Edited → Printed transformation.**

| | |
|---|---|
| **Input** | `_frontend-N/printer.prompt.md` + `_frontend-N/content/` (read-only) |
| **Output** | `_frontend-N/_quarto.yml` + `_frontend-N/_site/` |

The Printer is non-editorial. It does not make content decisions and never reads original source files — only `content/`.

---

## Contract Files

```
_frontend-N/
├── editor.prompt.md       ← WHAT to publish (human intent; PE produces, human refines)
├── printer.prompt.md      ← HOW to build (Editor produces; Printer reads)
├── content/               ← EDITED state (all normalized page files + assets)
├── _quarto.yml            ← Quarto config (Printer produces)
├── _site/                 ← PRINTED state (Printer produces)
└── questions.prompt.md    ← BLOCKERS (Printer writes; Orchestrator routes; deleted after resolution)
```

---

## Quick Reference

| Task | What to do |
|------|------------|
| Start the publishing pipeline | `@publishing-orchestrator` |
| Change what pages appear on the website | Edit `_frontend-N/editor.prompt.md` |
| Re-run only the Print step | `@publishing-printer` |
| Add a second website for a different audience | Create `_frontend-2/` with a new `editor.prompt.md` |
| Change how `.html` files are embedded | Edit `publishing-content.instructions.md` |
| Change which analysis figures are selected | Edit `publishing-analysis.instructions.md` |
