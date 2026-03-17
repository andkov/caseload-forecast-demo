---
description: "Bootstrap a new _frontend-N/ workspace for publishing. Scans the repo, creates the workspace directory, and initializes editor.prompt.md with sensible defaults."
---

# Initialize New Frontend Workspace

Use this prompt to create a new `_frontend-N/` workspace and start the publishing workflow.

## What this does

1. **Finds the next available workspace number** by scanning for existing `_frontend-*/` directories.
2. **Creates the workspace directory** (`_frontend-N/`).
3. **Invokes the Publishing PE** to scan the repository and produce a default `editor.prompt.md`.
4. **Hands off to the Orchestrator** to continue the workflow.

## Instructions

When this prompt is invoked:

1. List all directories matching `_frontend-*/` in the repository root.
2. Determine the next available number N (e.g., if `_frontend-1/` exists, use `_frontend-2/`).
3. Create the `_frontend-N/` directory.
4. Read the template from `.github/templates/editor-prompt-template.md`.
5. Scan the repository for publishable content:
   - Root `README.md`
   - `analysis/*/` — look for `.qmd`, `.html`, and `prints/` directories
   - `manipulation/` — look for `pipeline.md`, `README.md`, and `images/`
   - `guides/` — all `.md` files
   - `ai/project/` — mission, methodology, glossary files
   - `philosophy/` — methodology philosophy documents
   - `data-public/metadata/` — data manifests
6. Generate a default `editor.prompt.md` using the template schema, populated with discovered content organized into sensible navbar sections.
7. Write `editor.prompt.md` to `_frontend-N/`.
8. Present the result to the user and suggest invoking `@publishing-orchestrator` to continue.

## Default Section Mapping

| Navbar Section | Default Sources |
|---------------|----------------|
| Project | `ai/project/*.md` (mission, methodology, glossary) |
| Data | `manipulation/pipeline.md`, `data-public/metadata/*.md` |
| Analysis | `analysis/*/` (each subfolder = one page) |
| Guides | `guides/*.md` |

Adjust sections based on what actually exists in the repository. Omit sections if no matching content is found.
