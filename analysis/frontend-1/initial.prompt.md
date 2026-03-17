# Alberta Income Support: Caseload Forecast — Project Website

<!-- ============================================================
  HUMAN INSPECTION POINT
  
  This file is the editorial starting point for frontend-1.
  Review every section. Edit freely. This is where you exercise
  editorial judgment before the pipeline runs.
  
  When satisfied, the Publishing Orchestrator (or you manually)
  copies this to _frontend-1/editor.prompt.md to begin the build.
  
  YOU ARE RESPONSIBLE for the selection, framing, and language
  captured here. The agents will follow your instructions faithfully.
  ============================================================ -->

## Purpose

A project website documenting the Alberta Income Support caseload forecasting pipeline — from open data ingestion to 24-month forward projections. The audience is the analytics team and internal stakeholders who want to understand the methodology, inspect the analysis, and use the pipeline themselves. The site should function as both a technical reference and a demonstration of reproducible research practice.

## Format

Quarto website

## Index

- ./README.md

<!-- The root README introduces the project well. The publisher
     will adapt it for website context (strip dev-setup commands,
     adjust links). If you prefer a custom introduction, replace
     the path with a new .md file of your own. -->

## Navigation

<!-- Each ### section becomes one navbar entry.
     - Single file  → direct nav link
     - Multiple files → dropdown menu
     
     Add, remove, or reorder sections freely.
     Add notes in parentheses after any file path. -->

### Project

- ./ai/project/mission.md
- ./ai/project/method.md
- ./ai/project/glossary.md

<!-- Covers: why this project exists, the 6-stage pipeline
     methodology, and the full domain/Azure glossary.
     Consider: keep all three as a dropdown, or merge into one page. -->

### Pipeline

- ./manipulation/pipeline.md (primary content; augment with ./manipulation/README.md philosophy section)
- ./manipulation/images/flow-skeleton.png (diagram — embed in the pipeline page)

<!-- The pipeline.md is the authoritative technical reference.
     The manipulation/README.md contains the naming philosophy.
     Consider: present as a single unified "How it works" page. -->

### Analysis

- ./analysis/eda-2/ (use existing eda-2.html for embedding; include prints g1 through g7)
- ./analysis/report-1/ (use existing report-1.html for embedding; include all prints)

<!-- EDA-2 covers time-series exploration: trends, seasonality,
     ACF/PACF, log transform decision. 11 figures in prints/.
     
     Report-1 is the final forecast report: 24-month ARIMA projections
     with prediction intervals. 6 figures in prints/.
     
     EDA-1 is excluded below — no rendered HTML yet.
     Add it back when eda-1.html exists, or change to QMD rendering. -->

### Guides

- ./guides/getting-started.md
- ./guides/flow-usage.md

<!-- Getting Started covers first-time environment setup.
     Flow Usage covers running the pipeline day-to-day.
     
     Consider: add more guides if the audience needs them.
     Other available guides:
       - guides/command-guide.md
       - guides/command-reference.md
       - guides/custom-data-guide.md
       - guides/environment-management.md
       - guides/silent-mini-eda-export-guide.md -->

## Exclusions

- *.R
- *_cache/
- data-private/
- nonflow/
- data-local/
- README.md (inside subfolders — use only root README.md for index)
- prompt-start.md
- analysis/eda-1/ (no rendered output yet)
- guides/mcp-setup/
- guides/command-reference.md
- guides/custom-data-guide.md
- guides/environment-management.md
- guides/silent-mini-eda-export-guide.md

## Theme

sketchy

<!-- Bootswatch theme options: cosmo, flatly, litera, lumen, lux,
     materia, minty, morph, pulse, quartz, sandstone, simplex,
     sketchy, slate, solar, spacelab, superhero, united, vapor,
     yeti, zephyr -->

## Repo URL

https://github.com/your-org/caseload-forecast-demo

<!-- Replace with actual GitHub URL. Used for "View source" links
     in the site header. Set to "none" to omit. -->

## Footer

Alberta Strategic Data Analytics · Alberta Income Support Caseload Forecast · Built with Quarto

## Notes

<!-- Free-form editorial instructions for the Editor agent.
     Add anything that doesn't fit the structured sections above. -->

- For the Analysis section, apply full-width page layout (no sidebar TOC) when embedding the HTML reports.
- The Pipeline page should lead with the flow diagram (flow-skeleton.png) before the prose, not after.
- Do not include the technical glossary (ai/project/glossary.md) if the audience is primarily analysts rather than engineers — reconsider this section.
- Prefer the sketchy Bootswatch theme to signal that this is a demo/sandbox project, not a production reporting system.
- EDA-1 has only a .qmd source and no rendered output. Leave it out of the site for now. Revisit after eda-1 is rendered.
