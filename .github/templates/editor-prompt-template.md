# editor.prompt.md Template

This template defines the schema for `editor.prompt.md` — the contract file that captures **what the human wants to publish**. The Publishing PE uses this as the scaffold when bootstrapping a new frontend workspace.

---

## Schema

```markdown
# [Website Name]

## Purpose

[1-2 paragraphs describing the website's goal, intended audience, and context.
Example: "A project documentation site for the caseload forecasting pipeline, aimed at team members and stakeholders who need to understand the data, methodology, and results."]

## Format

Quarto website

## Index

[Source file for the landing/home page]
- ./README.md

## Navigation

[Each ### section defines one navbar entry. Files listed under each section become pages.
Single file = direct link. Multiple files = dropdown menu.]

### [Section Name]
- [path/to/file.md]
- [path/to/file.qmd]
- [All md files in ./some/directory/]
[Optional per-file notes in parentheses]

### [Section Name]
- [path/to/file.md]

## Exclusions

[Patterns and paths to exclude from content discovery]
- *.R
- *_cache/
- data-private/
- nonflow/
- README.md (inside subfolders)
- prompt-start.md

## Theme

[Quarto Bootswatch theme name]
cosmo

## Repo URL

[GitHub repository URL for site header/footer, or "none"]

## Footer

[Footer text, or "none"]

## Notes

[Any additional editorial instructions for the Editor agent.
Examples:
- "Use only figures g1 through g5 from EDA-1 prints/"
- "Combine pipeline.md and README.md into a single Data page"
- "Exclude the glossary — it's not ready yet"
- "For analysis/eda-2, use the rendered HTML rather than re-rendering the QMD"]
```

---

## Field Reference

| Field | Required | Producer | Description |
|-------|----------|----------|-------------|
| Website Name | Yes | PE | Display title for the site |
| Purpose | Yes | PE + Human | Goal and audience |
| Format | Yes | PE | Always "Quarto website" (for now) |
| Index | Yes | PE | Landing page source file |
| Navigation | Yes | PE + Human | Navbar sections with source file lists |
| Exclusions | Yes | PE | Patterns to skip during content discovery |
| Theme | No | PE + Human | Bootswatch theme (default: cosmo) |
| Repo URL | No | PE | GitHub URL for site links |
| Footer | No | PE + Human | Footer text |
| Notes | No | Human | Free-form editorial instructions |

---

## Conventions

- **Globs**: Use "All md files in ./path/" to indicate directory enumeration.
- **Explicit files**: Use relative paths from the repo root (e.g., `./guides/getting-started.md`).
- **Per-file notes**: Add notes in parentheses after a file path (e.g., `- ./analysis/eda-1/ (use HTML override)`).
- **Section ordering**: Sections appear in the navbar in the order listed.
- **Missing files**: The PE should validate that all explicit paths exist before finalizing. Missing files are flagged as warnings.
