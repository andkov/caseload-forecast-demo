# Glossary

Core terms for standardizing project communication.

---

## Data Pipeline Terminology

### Pattern
A reusable solution template for common data pipeline tasks. Patterns define the structure, philosophy, and constraints for a category of operations. The project uses six patterns: Ferry, Ellis, Mint, Train, Forecast, Report.

### Lane
A specific implementation instance of a pattern within a project. A lane may be implemented as a single script or a group of scripts operating within the same pattern. Lanes are numbered to indicate approximate execution order across the full pipeline. Examples: `1-ferry.R`, `2-ellis.R`, `3-mint-IS.R`, `4-train-arima.R`, `5-forecast-IS.R`, `6-report-IS.qmd`.

### Ferry Pattern
Data transport pattern that moves data between storage locations with minimal/zero semantic transformation. Like a "cargo ship" - carries data intact. 
- **Allowed**: SQL filtering, SQL aggregation, column selection
- **Forbidden**: Column renaming, factor recoding, business logic
- **Input**: External databases, APIs, flat files
- **Output**: CACHE database (staging schema), parquet backup

### Ellis Pattern
Data transformation pattern that creates clean, analysis-ready datasets. Named after Ellis Island - the immigration processing center where arrivals are inspected, documented, and standardized before entry.
- **Required**: Name standardization, factor recoding, data type verification, missing data handling, derived variables
- **Includes**: Minimal EDA for validation (not extensive exploration)
- **Input**: CACHE staging (ferry output), flat files, parquet
- **Output**: CACHE database (project schema), WAREHOUSE archive, parquet files
- **Documentation**: Generates CACHE-manifest.md

### Mint Pattern
Model-ready data preparation pattern that shapes Ellis output into standardized artifacts consumed by Train lanes. Named for coin minting — producing a standardized artifact of exact specification from refined material.
- **Applies**: Train/test split (keyed to `focal_date`), log transforms, xreg matrix construction, temporal subsetting
- **Codifies**: EDA-confirmed analytical decisions (e.g., log transform, seasonal period, differencing order)
- **Forbidden**: Model fitting, new data sourcing, re-running Ellis logic
- **Input**: Ellis parquet output + EDA-informed decisions
- **Output**: Serialized `.rds` artifacts (ts objects, xreg matrices) in `./data-private/derived/forge/` + `forge_manifest.yml`
- **Documentation**: Generates forge_manifest.yml

### Train Pattern
Model estimation pattern that fits statistical models and evaluates diagnostic quality. Each Train lane consumes Mint artifacts only — never Ellis output directly.
- **Process**: Estimate model parameters on training slice, evaluate fit diagnostics, backtest on held-out window
- **Input**: Mint artifacts (`ts_train.rds`, `xreg_*.rds`, `forge_manifest.yml`)
- **Output**: Fitted model `.rds` in `./data-private/derived/models/` + model registry entry
- **Versioning**: Each model links to its `forge_manifest.yml` via `forge_hash` in the model registry

### Forecast Pattern
Prediction generation pattern that produces forward-looking forecasts from Train model objects.
- **Process**: Apply fitted model to full series, generate point forecasts + prediction intervals for configured horizon
- **Input**: Train model `.rds` + Mint `ts_full.rds` for forward projection
- **Output**: CSV of point forecasts + intervals, Quarto report
- **Horizon**: Configured in `config.yml` (default: 24 months from `focal_date`)

### Report Pattern
Final deliverable assembly pattern that combines EDA, model performance, and forecasts into publication-ready output.
- **Input**: EDA reports, Train performance metrics, Forecast outputs
- **Output**: Static HTML report for stakeholder delivery
- **Delivery**: SharePoint/network drive (Phase 1); Azure Static Web App + AAD auth (Phase 2)

### EDA (Exploratory Data Analysis)
Exploratory analysis that operates on Ellis output. EDA is **not a numbered lane** in the pipeline — it is a lateral analytical activity that produces reports and insight, not data artifacts consumed by downstream scripts. EDA findings are codified as documented decisions in Mint scripts (e.g., `[EDA-001] Log transform: TRUE`).

---

## Mint-Train-Forecast Lineage

The Mint, Train, and Forecast patterns form a versioned chain where each stage's output is traceable to its input. All three stages are keyed by `focal_date`. Changing `focal_date` invalidates all Mint, Train, and Forecast artifacts. The `forge_manifest.yml` provides the hash that links a model registry entry back to its exact input data slice.

```
Ellis output → [EDA insight] → Mint → Train → Forecast
                                 │       │        │
                           forge_manifest │   forecast CSV
                                 │    model .rds   │
                                 └── forge_hash ────┘
                                   (versioning bond)
```

### Forge Manifest
YAML file (`forge_manifest.yml`) documenting the data contract between Mint and Train: `focal_date`, split date, transform decisions (log, seasonal period), row counts, and EDA decision references. Analogous to CACHE-manifest for Ellis, but for model-ready artifacts.

---

## Storage Layers

### CACHE
Intermediate database storage - the last stop before analysis. Contains multiple schemas:
- **Staging schema** (`{project}_staging` or `_TEST`): Ferry deposits raw data here
- **Project schema** (`P{YYYYMMDD}`): Ellis writes analysis-ready data here
- Both Ferry and Ellis write to CACHE, but to different schemas with different purposes.

### WAREHOUSE
Long-term archival database storage. Only Ellis writes here after data pipelines are stabilized and verified. Used for reproducibility and historical preservation.

---

## Schema Naming Conventions

### `_TEST`
Reserved for pattern demonstrations and ad-hoc testing. Not for production project data.

### `P{YYYYMMDD}`
Project schema naming convention. Date represents project launch or data snapshot date.
Example: `P20250120` for a project launched January 20, 2025.

### `P{YYYYMMDD}_staging`
Optional staging schema within a project namespace for Ferry outputs before Ellis processing.

---

## General Terms

### Artifact
Any generated output (report, model, dataset) subject to version control.

### Seed
Fixed value used to initialize pseudo-random processes for reproducibility.

### Persona
A role-specific instruction set shaping AI assistant behavior.

### Memory Entry
A logged observation or decision stored in project memory files.

### CACHE-manifest
Documentation file (`./data-public/metadata/CACHE-manifest.md`) describing analysis-ready datasets produced by Ellis pattern. Includes data structure, transformations applied, factor taxonomies, and usage notes.

### INPUT-manifest
Documentation file (`./data-public/metadata/INPUT-manifest.md`) describing raw input data before Ferry/Ellis processing.

### Forge Manifest
YAML file (`./data-private/derived/forge/forge_manifest.yml`) documenting model-ready data slices produced by Mint pattern. Includes `focal_date`, split boundaries, transform decisions, row counts, and EDA decision log.

---

## Forecasting Terminology

### Forecast Horizon
The number of time steps ahead for which predictions are generated. This project uses a **24-month horizon** (2 years forward from `focal_date`).

### Focal Date
The reference date representing the "present" for analysis purposes. Typically the last month with observed data. Configured in `config.yml` as `focal_date`.

### Train/Test Split
Division of historical data into:
- **Training set**: Used to estimate model parameters (all data up to `focal_date - 24 months`)
- **Test set**: Held-out data for backtesting model performance (last 24 months before `focal_date`)

### Backtesting
Retrospective evaluation of forecast accuracy by pretending past data points are "future" and comparing predictions to actuals.

### Model Tier
Classification of forecasting models by complexity:
1. **Naive baseline**: Simple benchmark (last value carried forward)
2. **ARIMA**: Autoregressive integrated moving average (univariate time series model)
3. **ARIMA + static predictor**: Includes time-invariant exogenous variable (e.g., client type)
4. **ARIMA + time-varying predictor**: Includes dynamic covariate (e.g., economic indicator)

### Prediction Interval
Range around point forecast representing uncertainty. Commonly 80% and 95% intervals (wider = more conservative).

### Point Forecast
Single "best guess" predicted value (typically the mean or median of the forecast distribution).

### Stationarity
A time series property where statistical properties (mean, variance, autocorrelation) are constant over time. ARIMA models require stationarity, often achieved via differencing.

### Seasonality
Regular, predictable patterns that repeat over fixed periods (e.g., monthly cycles, fiscal year effects).

---

## Azure ML Terminology (from transcript)

### Azure Machine Learning (AML)
Microsoft's cloud service for end-to-end machine learning workflows: data prep, model training, deployment, and MLOps.

### Compute Instance
Managed cloud VM for development work (Jupyter notebooks, VS Code remote). Billed per hour when running. Example: `Standard_DS3_v2` (4 cores, general-purpose CPU).

### Compute Cluster
Scalable pool of VMs for distributed training or batch inference. Auto-scales from 0 to N nodes based on workload.

### Workspace
Top-level Azure ML resource that groups models, datasets, compute, and experiments. Allows resource isolation and access control across teams/projects.

### Model Registry
Centralized catalog of trained models with versioning, metadata, and lineage tracking. Enables A/B testing and rollback.

### MLflow
Open-source framework for tracking experiments, packaging models, and ensuring portability across platforms (not locked into Azure).

### Endpoint
Deployed model as a REST API for real-time or batch inference. Can route traffic across multiple model versions (blue-green deployment).

### Blue-Green Deployment
Strategy for testing new model versions in production by gradually shifting traffic from old (blue) to new (green) and monitoring performance before full cutover.

### Pipeline (Azure ML)
Directed acyclic graph (DAG) of processing steps (data prep → training → evaluation → deployment). Parameterized and schedulable.

### Auto ML
Azure ML feature that automatically tries multiple algorithms and hyperparameters to find the best model for a given dataset and metric.

---

## SDA Domain Terms

### Caseload
Number of active clients receiving services at a given point in time. For Income Support: count of individuals/families with open cases in a specific month.

### Intake
New clients entering the program in a given period (e.g., monthly new applications approved).

### Exit
Clients leaving the program in a given period (case closures, eligibility expiry).

### Fiscal Year (Alberta)
April 1 to March 31. Example: **FY 2025-26** runs from April 1, 2025 to March 31, 2026.

### Income Support (IS)
Alberta government program providing financial assistance to Albertans in need. Part of Social Development portfolio.

### Strategic Data Analytics (SDA)
Government of Alberta team responsible for analytics, forecasting, and reporting for social programs. Led by Dony Alex.

### GoA (Government of Alberta)
Provincial government; context for data security, AAD authentication, and report distribution policies.

### AAD (Azure Active Directory)
Microsoft's cloud-based identity service. Used for single sign-on and access control to GoA Azure resources. Now called **Microsoft Entra ID**.

---
*This glossary is a living document. Update as project scope evolves or new Azure features are adopted.*