---
description: "Rules for handling manipulation/ folder content for website inclusion. Covers pipeline documentation, diagrams, and file exclusions."
applyTo: "manipulation/**"
---

# Publishing Manipulation Instructions

Rules for including content from the `manipulation/` folder in the published website.

## Typical manipulation/ Structure

```
manipulation/
├── pipeline.md            — authoritative technical pipeline guide
├── README.md              — pipeline philosophy and naming conventions
├── 1-ferry.R              — lane scripts (exclude from website)
├── 2-ellis.R
├── 3-mint-IS.R
├── 4-train-IS.R
├── 5-forecast-IS.R
├── example/               — educational demos (exclude)
├── images/                — pipeline diagrams (use in website)
│   ├── flow-skeleton.png
│   ├── flow-skeleton-01.png
│   ├── flow-skeleton-02.png
│   └── flow-skeleton-car.png
└── nonflow/               — ad-hoc tools (exclude)
```

---

## Primary Content Sources

When `editor.prompt.md` references `manipulation/`:

- **`pipeline.md`** is the primary page content — the authoritative technical description of the pipeline.
- If `editor.prompt.md` says to augment with `README.md`, incorporate the pipeline philosophy as a preamble or companion section.
- Use meaningful titles and headings — never expose raw source path strings as visible page text.

## Pipeline Diagrams

- Use images from `manipulation/images/` for visual pipeline explanations.
- Preferred order: `flow-skeleton.png` → `flow-skeleton-01.png` → `flow-skeleton-02.png`.
- Copy images to `content/<section>/images/` and update paths in page files.

## Files to Always Exclude

- **All `*.R` script files** — computation code, not documentation.
- **`nonflow/` directory** and all its contents.
- **`example/` directory** — educational demos, not for publication (unless explicitly requested).
- **`data-private/` references** — never expose sensitive data paths.

## Data Path Handling

The `.R` scripts write outputs to `data-private/derived/` — this is sensitive. When describing pipeline outputs in website content, refer to output types generically (e.g., "Parquet files", "SQLite database") without exposing absolute or relative file system paths.

## Visual Pipeline Summary (for reference)

```
1. Ferry   → staging data
2. Ellis   → analysis-ready tables (Parquet + SQLite)
3. Mint    → model-ready slices
4. Train   → fitted models
5. Forecast → forward predictions
6. Report  → publication-ready HTML
```

This summary can be used as a text-based fallback when pipeline diagrams are not available.
