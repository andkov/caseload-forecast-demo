# Alberta Income Support: Caseload Forecast — Project Website

Let's create front-end-1.

## Purpose

A project website for the Alberta Income Support caseload forecasting pipeline. The site documents the full arc from open data ingestion to 24-month forward projections — the methodology, the evidence, and the results. Intended for the analytics team and internal stakeholders who want to understand the approach, inspect the analysis, and run the pipeline themselves.

## Format

Quarto website

## Index

- ./index.md   <!-- TBD: FILE DOES NOT EXIST — create a brief overview of the project to give the onboarding human analyst options to explore. -->

## Navigation

### Project

- ./ai/project/summary.md         <!-- TBD: FILE DOES NOT EXIST — create a brief high-level summary of the project: what it is, why it was built, what it produces. ~300-500 words. -->
- ./ai/project/mission.md
- ./ai/project/method.md
- ./ai/project/glossary.md

### Pipeline

- ./manipulation/pipeline.md
- ./data-public/metadata/CACHE-manifest.md

### Analysis

- ./analysis/eda-2/                (use existing eda-2.html verbatim — embed full HTML)
- ./analysis/report-1/             (use existing report-1.html verbatim — embed full HTML)

### Stories

- ./analysis/stories/stories-1.qmd <!-- TBD: FILE DOES NOT EXIST — create a single Quarto RevealJS slideshow summarizing the project narrative. Format: revealjs. Suggested path: analysis/stories/stories-1.qmd. -->

### Docs

- ./README.md                      (verbatim — present as a full documentation page)

## Exclusions

- *.R
- *_cache/
- data-private/
- nonflow/
- example/
- README.md (inside subfolders)
- prompt-start.md
- analysis/eda-1/
- guides/
- ai/core/
- ai/scripts/
- ai/templates/
- ai/vscode/

## Theme

sketchy

## Repo URL

https://github.com/your-org/caseload-forecast-demo

## Footer

Alberta Strategic Data Analytics · Alberta Income Support Caseload Forecast · Built with Quarto

## Notes

- Two files are marked TBD and must be created before the Publisher can complete the build:
  1. `ai/project/summary.md` — high-level project summary for the Project dropdown landing page.
  2. `analysis/stories/stories-1.qmd` — RevealJS slideshow. Use `format: revealjs` in YAML frontmatter.
- Analysis pages (EDA-2, Report-1) should embed the existing rendered HTML verbatim. Apply full-width layout (no sidebar TOC) on those pages.
- The Docs > README page is intentionally separate from the Index landing page — same source file, exposed as a complete documentation reference in the navbar.
- The Pipeline section should present pipeline.md first, then the CACHE manifest as a data reference.
