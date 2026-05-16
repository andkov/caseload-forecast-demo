---
description: >
  Formatting and style rules for all Markdown files (.md) in the repository.
  Covers linting compliance, heading conventions, inline markup hierarchy,
  code fence tagging, table structure, callout patterns, and instruction file
  frontmatter.
applyTo: "**/*.md"
---

# Markdown Style Rules

## Linting Rules

These rules map to markdownlint checks. All must be satisfied before committing.

- **MD025 / single-h1**: Every file has exactly one `#` (H1) heading — the document title. Use `##` and below for all sections, including date entries in log/memory files.
- **MD022 / blanks-around-headings**: Always add a blank line before and after every heading (`#`, `##`, `###`, etc.).
- **MD032 / blanks-around-lists**: Always add a blank line before and after every list block (bulleted or numbered).
- **MD031 / blanks-around-fences**: Always add a blank line before and after fenced code blocks (` ``` `).
- **MD012 / no-multiple-blanks**: Never use more than one consecutive blank line.
- **MD009 / no-trailing-spaces**: No trailing whitespace at the end of lines.
- **MD010 / no-hard-tabs**: Use spaces, not tab characters, for indentation.
- **MD041 / first-line-heading**: The first line of every file must be a `#` H1 heading.

## Heading Style

- Use **Title Case** for all headings (`## Core Principles`, not `## core principles`).
- Use `---` horizontal rules only for major structural breaks between top-level sections, not between every subsection.
- Never skip heading levels (do not jump from `##` directly to `####`).

## Inline Markup

Use backticks for:

- File paths and names: `manipulation/1-ferry.R`, `.Rprofile`
- Package and function names: `haven::zap_labels()`, `callr::r_session$new()`
- Variable and column names: `days_absent_total`, `wts_m_pooled`
- R options and environment variables: `renv.config.startup.quiet`, `RENV_CONFIG_STARTUP_QUIET`
- Chunk names and labels: `load-packages`, `g2-data-prep`
- CLI flags and arguments: `--no-save`, `--timeout`

Use bold for:

- Key terms introduced for the first time in a document
- Label prefixes in callouts: `**Note:**`, `**Warning:**`
- Emphasis within list items where a term is the subject of the point

Do not nest backtick and bold markup on the same token (`**\`code\`**` is forbidden).

## Code Fences

Always include a language identifier after the opening fence.

Common identifiers used in this repository:

| Language | Tag |
|----------|-----|
| R | `r` |
| YAML | `yaml` |
| JSON | `json` |
| SQL | `sql` |
| PowerShell | `powershell` |
| Markdown (example blocks) | `markdown` |
| Plain text / console output | `text` |

## Tables

- Use pipe tables exclusively. No HTML tables.
- Every table must include a header row and a separator row of dashes.
- Do not use colon-alignment in separator rows unless column alignment is semantically meaningful.

## Callouts and Notes

Use the blockquote + bold label pattern for asides and warnings:

```markdown
> **Note:** This variable is absent from the PUMF for confidentiality reasons.
```

Do not use HTML `<div>` or Quarto callout blocks (`::: {.callout-note}`) in plain `.md` files; those belong in `.qmd` documents only.

## Instruction File Frontmatter

Every `.instructions.md` file must open with a YAML frontmatter block:

```yaml
---
description: >
  One-paragraph summary of what this file governs.
  Second sentence if needed.
applyTo: "glob/pattern/**"
---
```

- `description`: plain-English summary used by the IDE to decide when to surface the file.
- `applyTo`: glob pattern matching the file paths this instruction governs.
- File naming convention: `{topic}.instructions.md`, all lowercase, hyphen-separated.
