# frontend-1: Publishing Orchestra v2 — First Stable Site

**Date**: 2026-03-18
**Commit**: `7cc74d5770b231139669c1318a5d12950ed43e58`
**Message**: `frontend-1 stable made with publishing-orchestrator-2`
**Archive**: `M:\SPQ\PQA\R&A\_Research and Open Data\GitHub Data\caseload-forecaste-demo\2026-03-18-frontend-1-po-2`
**Scope**: `_frontend-1/`, `.github/instructions/publishing-content.instructions.md`, `.github/publishing-orchestra-2.md`

---

## Summary

Built and stabilized the first static website for the `caseload-forecast-demo` project using
the Publishing Orchestra v2 multi-agent system. The site documents the full arc of the Alberta
Income Support caseload forecasting pipeline — from data ingestion to 24-month projections —
for the analytics team and internal stakeholders.

The build exercised the full PE → Editor → Printer pipeline and surfaced several design
decisions that were resolved, codified, and fed back into the orchestra's instruction files.

---

## Site Structure

| Section | Pages | Theme |
|---------|-------|-------|
| Index (landing) | 1 | COMPOSED |
| Project | 4 (Summary, Mission, Method, Glossary) | 3 VERBATIM + 1 COMPOSED |
| Pipeline | 2 (Pipeline Guide, CACHE Manifest) | 1 GENERATED + 1 VERBATIM |
| Analysis | 2 (EDA, Forecast Report) | REDIRECT |
| Docs | 3 (README, Publishing Orchestra, Site Map) | 1 VERBATIM + 2 COMPOSED |

**Theme**: `journal` (changed from `sketchy` at human request — professional/scholarly)
**Total pages rendered**: 12
**Quarto render exit code**: 0 (clean)

---

## Key Technical Decisions

### 1. `file://` Portability is Mandatory

**Problem**: iframes fail silently in Chrome/Edge/Firefox when opened via `file://` (security
restriction). The original transit pages for Analysis used `<iframe>` embeds.

**Decision**: `_site/` must be fully portable — copyable to any location and browseable
without a local server. This is a **mandatory constraint** for this class of publishing
orchestra (static HTML sites for personal computers). A separate class (e.g., RShiny apps)
will handle cases where a server is required.

**Fix**: Replaced iframe embeds with `<meta http-equiv="refresh">` redirects + fallback link.
Redirect targets (`eda-2.html`, `report-1.html`) are copied into `_site/analysis/*/` by the
post-render script so the relative paths resolve correctly.

### 2. Verbatim-Copied Files Must Carry Their Assets

**Problem**: `README.md` (root) references images in `libs/images/README-main/` relative to
the repo root. When copied verbatim to `content/docs/readme.qmd`, those paths resolve to
`_site/content/docs/libs/images/README-main/` — which didn't exist in `_site/`.

**Fix**: Post-render script `copy-analysis-html.R` now mirrors all `libs/images/README-main/`
PNGs into `_site/content/docs/libs/images/README-main/`.

**System rule codified**: `publishing-content.instructions.md` §5 now has a mandatory
**Asset Resolution Algorithm** for verbatim-copied files:
- Scan for all local asset references (markdown `![]()`, HTML `<img>`, `<script>`, `<link>`, Quarto `{{< include >}}`)
- Resolve each relative to the source file's original directory
- Mirror into `content/<section>/` preserving relative path structure (no path rewriting needed)
- Recurse into included files

### 3. Canonical Mermaid Diagram via `{{< include >}}`

**Problem**: The same pipeline architecture diagram needed to appear on three pages (Index,
Pipeline Guide, Docs/README). Duplicating it meant three divergence points.

**Fix**: Single canonical file `content/_pipeline-diagram.qmd` containing one `{mermaid}`
block with `%%{init: {'theme':'neutral'}}%%`. All three pages use `{{< include >}}`.

**White background fix**: Quarto's default mermaid theme inherited the dark Bootswatch subgraph
background. Adding `%%{init: {'theme':'neutral'}}%%` forces white subgraph fills while
preserving the coloured node styles.

### 4. `.qmd` Extension Required for `{{< include >}}`

**Problem**: `pipeline.md` and `readme.md` use `{{< include >}}` shortcodes (Quarto executable
syntax). Quarto requires `.qmd` extension for any file with executable content. Files with
`.md` extension are rendered as plain markdown — shortcodes are ignored and raw text is shown.

**Fix for pipeline**: Pre-render script `scripts/prep-pipeline-qmd.R` generates
`content/pipeline/pipeline.qmd` from `manipulation/pipeline.md` on every render. The
source-of-truth remains the raw file; the `.qmd` is a build artifact.

**Fix for readme**: `content/docs/readme.qmd` is a permanent promoted copy. It does not
regenerate on each render (Quarto resolves the render list before pre-render scripts run,
so dynamically generated files aren't reliably picked up as render targets).

### 5. `project.render` Must List `.qmd` Not `.md`

When a pre-render script produces a `.qmd` from a `.md`, `_quarto.yml`'s `project.render`
must list the `.qmd` path. Similarly, navbar `href` values must also point to `.qmd`.

---

## File Artifacts in `_frontend-1/`

```
_frontend-1/
├── editor.prompt.md                   ← Editorial intent (journal theme, 5 sections)
├── printer.prompt.md                  ← Build spec (auto-generated by Editor)
├── _quarto.yml                        ← Quarto config (Printer-generated)
├── scripts/
│   ├── prep-pipeline-qmd.R            ← Pre-render: pipeline.md → pipeline.qmd (with mermaid include)
│   └── copy-analysis-html.R           ← Post-render: copies HTML redirects + README images
├── content/
│   ├── _pipeline-diagram.qmd          ← Canonical mermaid diagram partial
│   ├── index.qmd                      ← Landing page (COMPOSED)
│   ├── images/
│   │   └── g1_forecast_report.png     ← Forecast hero image for index
│   ├── project/                       ← summary.md (COMPOSED), mission/method/glossary.md (VERBATIM)
│   ├── pipeline/
│   │   ├── pipeline.md                ← Source (with {{< include >}} replacing mermaid block)
│   │   └── cache-manifest.md          ← VERBATIM copy
│   ├── analysis/
│   │   ├── eda-2.qmd                  ← REDIRECT → analysis/eda-2/eda-2.html
│   │   └── report-1.qmd               ← REDIRECT → analysis/report-1/report-1.html
│   └── docs/
│       ├── readme.qmd                 ← VERBATIM copy of README.md (permanent .qmd)
│       ├── publishing-orchestra.md    ← COMPOSED condensed summary
│       └── site-map.md                ← COMPOSED site map with type legend
└── _site/                             ← Portable static website (12 HTML pages)
```

---

## Issues Encountered and Resolved

| # | Issue | Root Cause | Resolution |
|---|-------|------------|------------|
| 1 | Blank iframe (Analysis pages) | Chrome blocks `file://` iframes | Replaced with meta-refresh redirects |
| 2 | Redirect target not found | Post-render copy script not yet run | Added `copy-analysis-html.R` as post-render hook |
| 3 | Pipeline diagram shows as raw text, not rendered | `pipeline.md` has `.md` extension | Pre-render script generates `pipeline.qmd` |
| 4 | `readme.qmd` silently skipped in render | Quarto resolves render list before pre-render runs | Made `readme.qmd` a permanent file |
| 5 | README images broken (broken image icon) | Verbatim copy didn't carry `libs/images/README-main/` assets | Post-render script mirrors image folder into `_site/` |
| 6 | Dark subgraph backgrounds in mermaid | Default Quarto mermaid theme inherits dark Bootstrap styling | Added `%%{init: {'theme':'neutral'}}%%` to diagram partial |
| 7 | `_frontend-1/_frontend-1/` ghost directory | `quarto render` run from repo root instead of `_frontend-1/` | Deleted artifact; documented correct working directory |
| 8 | Forecast image in `_frontend-1/analysis/` | Editor placed image relative to `content/` using `../analysis/` path | Moved to `content/images/` and updated reference |

---

## System Files Updated

| File | Change |
|------|--------|
| `.github/instructions/publishing-content.instructions.md` | §5 rewritten with mandatory Asset Resolution Algorithm |
| `.github/publishing-orchestra-2.md` | Printer section: added note re pre/post-render scripts; Instruction Files table: updated `publishing-content` description to match current rule |
| `_frontend-1/content/docs/site-map.md` | Added GENERATED content type; corrected Pipeline Guide type; added build scripts table; corrected Publishing Orchestra type to COMPOSED |

---

## Lessons for Future Publishing Orchestra Runs

1. **Check `file://` compatibility first** — any embed technique must work without a server.
2. **Asset resolution is non-optional** — every verbatim copy must be audited for local references.
3. **Diagram partials > inline diagrams** — shared diagrams belong in `_pipeline-diagram.qmd`.
4. **`.md` files with shortcodes need pre-render promotion to `.qmd`** — budget for this step when planning pipeline docs pages.
5. **Run `quarto render` from inside `_frontend-N/`** — running from repo root produces doubled paths.
6. **`_site/` alone travels** — `.quarto/` is a build cache; only `_site/` is needed for distribution.
