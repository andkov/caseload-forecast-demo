---
title: "Site Map"
---

# Site Map

This page documents the full structure of the site — what pages are included,
where each page's content comes from, and how it was prepared.

## Content Types

| Type | Meaning |
|------|----------|
| **VERBATIM** | Exact copy of a source file from the repository |
| **COMPOSED** | Synthesized or written by the Publishing Editor |
| **GENERATED** | Produced by a pre-render script from a verbatim source, with transformations applied (e.g. mermaid diagram injection) |
| **REDIRECT** | Transit page that forwards the browser to a standalone rendered HTML file |

## Navigation Structure

```
Alberta Income Support: Caseload Forecast
│
├── 🏠  Index                      COMPOSED  ← forecast image + orientation + pipeline diagram
│
├── Project
│   ├── Summary                    COMPOSED  ← synthesized from mission.md, method.md, README.md
│   ├── Mission                    VERBATIM  ← ai/project/mission.md
│   ├── Method                     VERBATIM  ← ai/project/method.md
│   └── Glossary                   VERBATIM  ← ai/project/glossary.md
│
├── Pipeline
│   ├── Pipeline Guide             GENERATED ← manipulation/pipeline.md (pre-render: mermaid diagram injected)
│   └── CACHE Manifest             VERBATIM  ← data-public/metadata/CACHE-manifest.md
│
├── Analysis
│   ├── EDA                        REDIRECT  → analysis/eda-2/eda-2.html
│   └── Forecast Report            REDIRECT  → analysis/report-1/report-1.html
│
└── Docs
    ├── README                     VERBATIM  ← README.md (root, with mermaid diagram injected)
    ├── Publishing Orchestra       COMPOSED  ← .github/publishing-orchestra-2.md (condensed)
    └── Site Map                   COMPOSED  ← this page
```

## Source File Provenance

| Section | Page | Source File | Type |
|---------|------|-------------|------|
| — | Index | *(Editor-composed)* | COMPOSED |
| Project | Summary | `ai/project/summary.md` | COMPOSED |
| Project | Mission | `ai/project/mission.md` | VERBATIM |
| Project | Method | `ai/project/method.md` | VERBATIM |
| Project | Glossary | `ai/project/glossary.md` | VERBATIM |
| Pipeline | Pipeline Guide | `manipulation/pipeline.md` | GENERATED |
| Pipeline | CACHE Manifest | `data-public/metadata/CACHE-manifest.md` | VERBATIM |
| Analysis | EDA | `analysis/eda-2/eda-2.html` | REDIRECT |
| Analysis | Forecast Report | `analysis/report-1/report-1.html` | REDIRECT |
| Docs | README | `README.md` | VERBATIM |
| Docs | Publishing Orchestra | `.github/publishing-orchestra-2.md` | COMPOSED |
| Docs | Site Map | *(Editor-composed)* | COMPOSED |

## Build System

The site is produced by the **Publishing Orchestra** — a multi-agent workflow with three
transformation stages:

```
RAW  ──────────► EDITED  ──────────► PRINTED
(repo)          (content/)           (_site/)
```

- **Raw** — the GitHub repository at a point in time
- **Edited** — curated and normalized content in `_frontend-1/content/`
- **Printed** — the rendered static website in `_frontend-1/_site/`

The Quarto build is augmented by two R scripts registered in `_quarto.yml`:

| Script | Hook | Purpose |
|--------|------|---------|
| `scripts/prep-pipeline-qmd.R` | `pre-render` | Generates `pipeline.qmd` from `manipulation/pipeline.md`, injecting the canonical mermaid diagram partial |
| `scripts/copy-analysis-html.R` | `post-render` | Copies `eda-2.html` and `report-1.html` into `_site/analysis/*/`; copies README image assets into `_site/content/docs/libs/` |

All files in `_site/` are self-contained and portable: the folder can be copied to any
location and opened with a standard browser using `file://` URLs without a local server.
