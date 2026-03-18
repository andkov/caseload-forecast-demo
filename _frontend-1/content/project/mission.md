---
title: "Project Mission"
---

# Project Mission

This repository provides a **cloud-migration learning sandbox** for monthly caseload forecasting. It uses publicly available Alberta Income Support data to create a complete, self-contained forecasting workflow that analysts can run on-premises, then migrate to cloud ML platforms (Azure ML, Snowflake ML, or others) with guidance from cloud platform partners.

The repo prioritizes **simplicity over realism**: model complexity is deliberately constrained to three tiers (naive baseline, ARIMA, augmented ARIMA) to focus learning on cloud orchestration, not statistical nuance. Once the cloud pipeline is stable, it will be re-grafted onto real, operationally complex production data.

## Objectives

- **Establish end-to-end on-prem pipeline**: Ferry → Ellis → Mint → Train → Forecast → Report (EDA informs Mint but is not a sequential gate; monthly refresh cadence)
- **Demonstrate cloud ML migration path**: Understand compute provisioning, model registry, experiment tracking (MLflow), endpoint serving, and orchestration for government analytics use cases
- **Enable analyst fluency**: Analysts with solid R/stats backgrounds gain hands-on experience with cloud ML concepts and terminology
- **Inform cloud adoption strategy**: Clarify where cloud compute is indispensable (e.g., large-scale estimation) vs. where on-prem suffices
- **Prototype report serving & security**: Explore delivery mechanisms (static HTML → SharePoint, cloud-hosted web apps, Power BI) with identity-provider-based access control (e.g., Microsoft Entra ID)

## Success Metrics

- **Pipeline completeness**: Ferry, Ellis, Mint, Train, Forecast, Report scripts all execute without manual intervention
- **Reproducibility**: Re-running the pipeline with same data produces identical forecasts (deterministic seeds, versioned dependencies)
- **Cloud readiness**: Project structure and code patterns align with cloud ML pipeline requirements (tested against Azure ML; adaptable to Snowflake ML and other providers)
- **Report delivery**: Static HTML renders successfully, displays 24-month horizon forecasts with model performance diagnostics

## Non-Goals

- **Model sophistication**: This is not a production forecasting system. Model accuracy is secondary to workflow clarity.
- **Real-time inference**: Monthly batch forecasting only; no streaming data or live endpoints (yet).
- **Automated deployment**: Cloud migration is Phase 2. Phase 1 establishes local workflow and confirms cloud platform requirements.
- **Multi-program disaggregation**: Initial scope is total caseload only. Program-level forecasts deferred to re-graft phase.

## Cloud Strategy

This repo is the **cloud-agnostic on-prem core** — a self-contained forecasting pipeline designed as a point of departure for multiple cloud implementations. Architecture decisions (Apache Parquet artifacts, modular pipeline stages, MLflow experiment tracking) are deliberately chosen for cross-platform portability.

**Current migration targets:**

- **Azure ML** (primary): Full ML lifecycle — compute instances, model registry, pipeline orchestration, endpoint serving. Provider-specific fork: `caseload-forecast-demo-azure`.
- **Snowflake ML** (secondary): Data warehousing, Snowpark for feature engineering, Snowflake Model Registry, Streamlit for report delivery. Provider-specific fork: `caseload-forecast-demo-snowflake`.

Provider-specific adaptations live in separate fork repositories derived from this cloud-agnostic core. The workspace also includes `azure-aml-demo` as a read-only reference — a prototypical Azure ML project providing Azure-specific examples. This repo remains provider-neutral so that the same pipeline patterns can be adapted to any cloud ML platform.

## Stakeholders

- **Lead Analyst**: Primary user; builds pipeline, learns cloud ML platforms, documents learnings
- **Analytics Team**: Secondary audience for static HTML reports; validates workflow patterns for reusability
- **Infrastructure Lead**: Infrastructure and product ownership guidance for cloud platform setup
- **Data Strategy Lead**: Strategic advisor on cloud adoption patterns and organizational needs
- **Cloud Platform Partners**: Cloud ML specialists providing migration guidance (Azure, Snowflake)

