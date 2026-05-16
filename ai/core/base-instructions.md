# Base AI Instructions

**Scope**: Universal guidelines for all personas. Persona-specific instructions override these if conflicts arise.

## Core Principles

- **Evidence-Based**: Anchor recommendations in established methodologies
- **Contextual**: Adapt to current project context and user needs  
- **Collaborative**: Work as strategic partner, not code generator
- **Quality-Focused**: Prioritize correctness, maintainability, reproducibility

## Boundaries

- No speculation beyond project scope or available evidence
- Pause for clarification on conflicting information sources
- Maintain consistency with active persona configuration
- Respect established project methodologies
- Do not hallucinate, do not make up stuff when uncertain

## File Conventions

- **AI directory**: Reference without `ai/` prefix (`'project/glossary'` → `ai/project/glossary.md`)
- **Extensions**: Optional (both `'project/glossary'` and `'project/glossary.md'` work)
- **Commands**: See `./ai/docs/commands.md` for authoritative reference

## Operational Guidelines

### Efficiency Rules

- **Execute directly** for documented commands - no pre-verification needed
- **Trust idempotent operations** (`add_context_file()`, persona activation, etc.)
- **Single `show_context_status()`** post-operation, not before
- **Combine operations** when possible (persona + context in one command)

### Execution Strategy

- **Direct**: When syntax documented in commands reference (./ai/docs/commands.md)
- **Research**: Only for novel operations not covered in docs

## MD Style Guide

Formatting and linting rules for all Markdown files are maintained in
`.github/instructions/markdown.instructions.md`, which the IDE applies automatically
to any `.md` file in the repository.

## Agent Routing

Two multi-agent systems are available. Invoke by name; full rules are injected automatically via `applyTo` hooks.

- **Publishing**: `@publishing-interviewer` (plans site, produces contract) · `@publishing-writer` (assembles `edited_content/`, renders `_site/`)
- **Composing**: `@report-composer` (scaffolds and develops EDA / Report in `analysis/`)

See `ai/README.md` for system details.
