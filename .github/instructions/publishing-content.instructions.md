---
description: "Rules for normalizing source files (.md, .qmd, .html) into Quarto-compatible website pages. Applied by the Publishing Editor when assembling content/."
applyTo: "_frontend-*/**"
---

# Publishing Content Normalization

Rules for transforming repository source files into website-ready pages for the `content/` folder.

## When to Apply

Apply these rules whenever the Publishing Editor processes a source file for inclusion in a `_frontend-N/content/` directory.

---

## 1. Page Semantics

- Each source file resolved from `editor.prompt.md` becomes one website page.
- Never expose raw file paths (e.g., `./philosophy/FIDES-example.md`) as visible page text, headings, or navigation labels.
- Derive display labels from: (1) YAML frontmatter `title`, (2) first markdown heading, (3) humanized filename stem — in that priority order.

## 2. Markdown Files (.md)

### Preferred: Transit QMD Wrapper

Create a `.qmd` transit page in `content/<section>/` that includes the original markdown content:

```qmd
---
title: "<derived from source>"
---

{{< include <source-filename>.md >}}
```

- Copy the original `.md` alongside the `.qmd` so the include path resolves.
- Preserve all original content exactly as authored — no editorial rewriting.
- The transit `.qmd` is a thin wrapper; the `.md` remains the source of truth.

### Frontmatter

Ensure each transit page has at minimum:

```yaml
---
title: "<derived from filename or first heading>"
---
```

Remove execution-only fields (`execute`, `knitr`, `jupyter`) that are irrelevant to static rendering.

## 3. QMD Files (.qmd)

- Copy the `.qmd` to `content/<section>/` without modification to its content.
- Strip or comment out R/Python code chunks that cannot execute in the static site context, unless the site is configured for live computation.
- Retain YAML frontmatter (`title`, `author`, `date`, `description`).

## 4. HTML Files (.html)

### Preferred: Inline Body Embed

If a source has an existing rendered `.html` (e.g., `eda-1.html`), embed the body content directly into a `.qmd` wrapper:

```qmd
---
title: "Report Title"
format:
  html:
    page-layout: full
    toc: false
---

```{=html}
<!-- body content from source HTML -->
<div class="report-content">
  ... (extracted <body> content) ...
</div>
```
```

**Never use iframes**. Iframes cause HTML-inside-HTML rendering issues.

**Never use "open in new tab" links**. Do not add `target="_blank"` attributes.

### Fallback: Direct Link

If the HTML is too large or its JS/CSS conflicts with the site theme, create a regular in-page link:

```markdown
[View the report](report.html)
```

Copy the `.html` file alongside the page so the link resolves.

## 5. Figure and Asset References

### Mandatory: Asset Resolution for Verbatim-Copied Files

When a source file is copied verbatim into `content/`, its relative image and asset references still point to paths relative to its **original location** in the repo. Those paths will break when the file is rendered from `content/`. The Editor **must** resolve all assets.

**Algorithm — apply to every verbatim-copied `.md`, `.qmd`, or `.html`:**

1. **Scan** the source file for all local asset references:
   - Markdown images: `![...](path)`
   - HTML images: `<img src="path">`
   - HTML/CSS resources: `<link href="path">`, `<script src="path">`
   - Quarto includes: `{{< include path >}}`
   - Exclude absolute URLs (`http://`, `https://`, `data:`).

2. **Resolve** each relative path against the source file's original directory in the repo.

3. **Copy** the resolved file to a mirrored path under `content/<section>/`:
   - Preserve the relative path structure so the reference in the copied file still resolves correctly.
   - Example: source at `README.md` references `libs/images/foo.png` → copy to `content/docs/libs/images/foo.png`.
   - Example: source at `analysis/report-1/report-1.qmd` references `prints/fig.png` → copy to `content/analysis/prints/fig.png`.

4. **Do not rewrite** the file's internal references. Preserving the relative paths means the copy resolves automatically from its new location — no path surgery needed.

5. **Recurse**: if a copied asset is itself a file that references further assets (e.g., an included `.md`), apply the same algorithm to it.

### Additional asset rules

- Prefer `prints/` sources when both `prints/` and `figure-png-iso/` exist for the same figure.
- Ensure the `content/` folder is fully self-contained — no asset may reference a path outside `content/`.
- Document every asset copy in `printer.prompt.md` under the **Assets** section.

## 6. Sync Behavior

- Re-resolve all file references on every Editor run.
- If source files changed since the last run, update the corresponding files in `content/`.
- If new matching files appear, add them during the same run.

## 7. Source File Integrity

- **Never edit original source files** in their repository locations.
- All transformations happen on copies placed inside `content/`.
- The original files remain the source of truth.
