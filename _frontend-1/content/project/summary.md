---
title: "Project Summary"
description: "High-level overview of the Alberta Income Support caseload forecasting project."
---

# Project Summary

## What the Project Is

The Alberta Income Support Caseload Forecast is a complete, end-to-end forecasting pipeline
built on publicly available Government of Alberta data. It ingests monthly Income Support
caseload statistics (April 2005 – September 2025, approximately 50,000 rows), transforms
them through six reproducible pipeline stages, and produces a static HTML report containing
24-month ARIMA forecasts with 80% and 95% prediction intervals. The entire workflow runs
on-premises with a single command — `Rscript flow.R` — and is designed as the cloud-agnostic
core for subsequent migration to Azure ML and Snowflake.

## Why It Was Built

The project serves a dual purpose. First, it provides a **functional forecasting system**
for Alberta's Income Support program — a monthly social assistance benefit that supports
Albertans facing financial hardship. Reliable short-horizon projections inform program
planning, staffing, and budget allocation. Second, it is a **cloud-migration learning
sandbox**: model complexity is deliberately constrained (Seasonal Naïve baseline, ARIMA,
and an augmented ARIMA tier) so that analysts can focus on understanding cloud orchestration
patterns rather than statistical nuance. Once the cloud pipeline is stable, it will be
re-grafted onto operationally complex production data.

## What It Produces

The pipeline delivers three categories of output:

- **Analysis-ready datasets** — The Ellis transformation produces 11 clean, structured
  tables in Apache Parquet format (primary) and SQLite (secondary), documented in the
  CACHE Manifest. These datasets cover total caseload, client type, family composition,
  ALSS regions, age groups, and gender — spanning April 2005 to September 2025.
- **EDA diagnostic report** — An advisory Quarto HTML report (`eda-2.qmd`) diagnosing
  time-series properties: 20-year trends, seasonality, stationarity (ADF/KPSS tests),
  ACF/PACF profiles, STL decomposition, and log-transform assessment. EDA findings are
  codified as documented decisions in the Mint pipeline stage.
- **Forecast report** — The final deliverable (`report-1.html`) combines model performance
  diagnostics, a backtest against a held-out 24-month window, and a 24-month forward
  projection. The primary model is ARIMA(3,1,1)(1,0,0)[12] fitted on the log-transformed
  total caseload series; the Seasonal Naïve model serves as the benchmark.

## Who It Is For

- **Lead Analyst** — Primary user who builds and runs the pipeline, learns cloud ML
  platforms, and documents findings.
- **Analytics Team** — Secondary audience for the static HTML reports; validates workflow
  patterns for reuse across other programs.
- **Infrastructure and Data Strategy Leads** — Advisors evaluating cloud compute options,
  model registry design, and organizational adoption strategy.
- **Cloud Platform Partners** — Azure and Snowflake specialists who will guide the
  Phase 2 migration using this on-prem pipeline as the reference implementation.

The project is intentionally transparent: every modeling decision is documented, every
pipeline stage is auditable, and the full workflow is reproducible from a single command.
