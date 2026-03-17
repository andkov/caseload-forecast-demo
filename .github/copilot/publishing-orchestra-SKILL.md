---
name: publishing-orchestra
description: "**WORKFLOW SKILL** — Publish a reproducible analytics repository as a static Quarto website using a multi-agent pipeline (Orchestrator → Prompt Engineer → Editor → Printer). USE FOR: building project websites from repo content; creating new frontend workspaces; understanding the publishing workflow; resolving printer build errors. DO NOT USE FOR: modifying analysis code; running data pipelines; general R/Python coding. INVOKES: Publishing Orchestrator agent as entry point, which dispatches PE, Editor, and Printer subagents."
---

# Publishing Orchestra

A multi-agent system for publishing reproducible analytics repositories as static Quarto websites with human editorial control at every stage.

---

## Architecture

```
Human ↔ Publishing Orchestrator
              │
              ├── Publishing PE        →  editor.prompt.md
              ├── Publishing Editor    →  content/ + printer.prompt.md
              └── Publishing Printer   →  _quarto.yml + _site/
```

### Agents

| Agent | Role | Human-facing? | Invocation |
|-------|------|---------------|------------|
| **Publishing Orchestrator** | Pipeline coordinator, state manager, error router | Yes | `@publishing-orchestrator` |
| **Publishing PE** | Content discovery, intent refinement, prompt authoring | Via Orchestrator | `@publishing-pe` |
| **Publishing Editor** | Source resolution, content normalization, spec generation | No | `@publishing-editor` |
| **Publishing Printer** | Quarto scaffolding, rendering, reconciliation | No | `@publishing-printer` |

### Contract Files

All handoffs between agents use files in `_frontend-N/`:

| File | Producer | Consumer | Purpose |
|------|----------|----------|---------|
| `editor.prompt.md` | PE | Editor | What to publish (human intent) |
| `printer.prompt.md` | Editor | Printer | How to build (deterministic spec) |
| `content/` | Editor | Printer | Normalized source materials |
| `questions.prompt.md` | Printer | Orchestrator | Build blockers requiring human input |
| `_site/` | Printer | Human | Final rendered website |

---

## Workflow

1. **Human invokes** `@publishing-orchestrator` (or uses `/publishing-new` to bootstrap).
2. **Orchestrator determines state** by inspecting `_frontend-N/` contents.
3. **PE phase**: Scans repo, bootstraps `editor.prompt.md` with sensible defaults, interviews human to refine. **Human checkpoint.**
4. **Editor phase**: Reads `editor.prompt.md`, resolves files, assembles `content/`, produces `printer.prompt.md`. **Human checkpoint.**
5. **Printer phase**: Reads spec + content, scaffolds Quarto project, renders `_site/`. **Human checkpoint.**
6. **Error loop**: If Printer writes `questions.prompt.md`, Orchestrator routes questions to human, resolves, and re-runs Printer.

---

## File Locations

### Agent Definitions
- `.github/agents/publishing-orchestrator.agent.md`
- `.github/agents/publishing-pe.agent.md`
- `.github/agents/publishing-editor.agent.md`
- `.github/agents/publishing-printer.agent.md`

### Instruction Files
- `.github/instructions/publishing-content.instructions.md` — Content normalization rules
- `.github/instructions/publishing-analysis.instructions.md` — Analysis folder handling
- `.github/instructions/publishing-manipulation.instructions.md` — Manipulation folder handling
- `.github/instructions/publishing-index.instructions.md` — Index page generation

### Templates
- `.github/templates/editor-prompt-template.md` — Schema for `editor.prompt.md`
- `.github/templates/printer-prompt-template.md` — Schema for `printer.prompt.md`
- `.github/templates/questions-prompt-template.md` — Schema for `questions.prompt.md`

### Prompts
- `.github/prompts/publishing-new.prompt.md` — Bootstrap a new frontend workspace

### Frontend Workspaces
- `_frontend-1/`, `_frontend-2/`, etc. — Independent website workspaces (created at runtime)

---

## Key Design Principles

1. **Human control at every stage** — Orchestrator pauses for approval at every phase transition.
2. **Contract-first handoffs** — Agents communicate through files, not shared memory or conversation state.
3. **Pattern-portable** — Agent prompts do not hard-code project-specific terms. Domain context comes from the repo's own documentation and `editor.prompt.md`.
4. **Multiple frontends** — Each `_frontend-N/` is independent, supporting different purposes and audiences.
5. **Quarto-only printer** — The architecture supports future format printers, but only Quarto is implemented.
6. **Deterministic Printer** — Given the same `printer.prompt.md` and `content/`, always produces the same `_site/`.
