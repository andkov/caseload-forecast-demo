# Alberta Income Support: Caseload Forecast — Project Website

<!-- Generated from analysis/frontend-1/initial.prompt.md
     Edit the source document, then copy here to re-run the pipeline. -->

## Purpose

A project website documenting the Alberta Income Support caseload forecasting pipeline — from open data ingestion to 24-month forward projections. Audience: analytics team and internal stakeholders. The site functions as both a technical reference and a demonstration of reproducible research practice.

## Format

Quarto website

## Index

- ./README.md

## Navigation

### Project

- ./ai/project/mission.md
- ./ai/project/method.md
- ./ai/project/glossary.md

### Pipeline

- ./manipulation/pipeline.md (primary content; augment with ./manipulation/README.md philosophy section)
- ./manipulation/images/flow-skeleton.png (embed diagram on pipeline page)

### Analysis

- ./analysis/eda-2/ (use existing eda-2.html for embedding; include prints g1 through g7)
- ./analysis/report-1/ (use existing report-1.html for embedding; include all prints)

### Guides

- ./guides/getting-started.md
- ./guides/flow-usage.md

## Exclusions

- *.R
- *_cache/
- data-private/
- nonflow/
- data-local/
- README.md (inside subfolders)
- prompt-start.md
- analysis/eda-1/
- guides/mcp-setup/
- guides/command-reference.md
- guides/custom-data-guide.md
- guides/environment-management.md
- guides/silent-mini-eda-export-guide.md

## Theme

sketchy

## Repo URL

https://github.com/your-org/caseload-forecast-demo

## Footer

Alberta Strategic Data Analytics · Alberta Income Support Caseload Forecast · Built with Quarto

## Notes

- Apply full-width page layout (no sidebar TOC) when embedding HTML reports in the Analysis section.
- The Pipeline page should lead with the flow diagram before the prose.
- EDA-1 excluded — no rendered HTML available yet.
