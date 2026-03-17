---
description: "Rules for handling analysis/ folder content for website inclusion. Covers rendered outputs, figure selection, QMD rendering, and asset handling."
applyTo: "analysis/**"
---

# Publishing Analysis Instructions

Rules for including content from `analysis/` subfolders in the published website.

## Typical analysis/ Structure

```
analysis/
├── eda-1/
│   ├── eda-1.R           — computation script (exclude)
│   ├── eda-1.qmd         — Quarto report source
│   ├── eda-1.html        — rendered report (use for HTML embedding)
│   ├── prints/           — publication-ready figures (preferred)
│   └── figure-png-iso/   — Quarto render artifacts (avoid)
├── eda-2/
│   ├── eda-2.R
│   ├── eda-2.qmd
│   └── prints/
└── report-1/
    ├── report-1.R
    ├── report-1.qmd
    └── prompt-start.md   — authoring brief (exclude)
```

---

## Default Rendering Behavior

When `editor.prompt.md` references an analysis unit (e.g., `analysis/eda-1`):

1. **Default**: Use the `.qmd` source as canonical content. Copy it to `content/<section>/` and let Quarto render it during the Printer's build step.
2. **HTML override**: If `editor.prompt.md` explicitly says to use existing `.html`, embed the HTML body content inline in a `.qmd` wrapper (per `publishing-content.instructions.md` rules).

## Figure Selection

| Source | Priority | Use for |
|--------|----------|---------|
| `prints/` | **Preferred** | Publication-ready PNGs — use these for website visuals |
| `figure-png-iso/` | Avoid | Intermediate Quarto render artifacts |
| `*_cache/` | Exclude | Internal knitr/Quarto caches — never include |

When both `prints/` and `figure-png-iso/` contain equivalent figures, always use `prints/`.

## Files to Always Exclude

- `*.R` script files
- `README.md` inside analysis subfolders
- `prompt-start.md` (authoring briefs)
- `*_cache/` directories
- `data-local/` directories

## Self-Contained Assets

- Copy all required figures (especially `prints/*.png`) into `content/<section>/assets/` or `content/<section>/prints/`.
- Update image paths in page files to point to the copied assets.
- The rendered site must not depend on files outside `_frontend-N/_site/`.

## Theme Consistency

- All analysis pages must render with the same theme and style settings as the rest of the site.
- If an embedded HTML report visually diverges from the site theme, normalize via the page wrapper's format settings.

## Sync on Source Changes

- On every Editor run, re-scan referenced analysis folders.
- Replace copied pages/assets if sources changed.
- Add new matching files discovered since the last run.
