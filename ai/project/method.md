# Methodology

This project follows a **ferry-ellis-mint-train-forecast-report** pipeline adapted from [RAnalysisSkeleton](https://github.com/wibeasley/RAnalysisSkeleton) patterns, optimized for monthly time series forecasting with cloud migration as Phase 2 objective.

## Data Source

**Alberta Income Support Aggregated Caseload Data**  

- **Public URL**: [Open Alberta - Income Support](https://open.alberta.ca/dataset/e1ec585f-3f52-40f2-a022-5a38ea3397e5/resource/4f97a3ae-1b3a-48e9-a96f-f65c58526e07/download/is-aggregated-data-april-2005-sep-2025.csv)  
- **Temporal coverage**: April 2005 to present (updated monthly by GoA)  
- **Structure**: Monthly aggregates by geography, measure type (caseload, intakes, exits), and demographics  
- **Forecast target**: Total active caseload count, 24-month horizon, monthly intervals  

## Pipeline Stages

| # | Pattern      | Alias       | Key Input                      | Key Output                              | Forbidden                          |
|---|--------------|-------------|------------------------------- |-----------------------------------------|------------------------------------|
| 1 | **Ferry**    | Ingestion   | Open Alberta CSV / local file  | Staging parquet / SQLite                | Semantic transforms, renaming      |
| 2 | **Ellis**    | Transform   | Ferry staging output           | Analysis-ready parquet + CACHE-manifest | Model fitting, new data sourcing |
| — | *(EDA)*      | *(Advisory)*| Ellis parquet                  | Reports & insight only                  | Producing consumed data artifacts  |
| 3 | **Mint**     | Prep        | Ellis parquet + EDA decisions  | `forge/` parquet slices + `forge_manifest.yml` | Model fitting, re-running Ellis |
| 4 | **Train**    | Estimation  | Mint artifacts only            | Model `.rds` + model registry CSV       | Reading Ellis output directly      |
| 5 | **Forecast** | Prediction  | Train `.rds` + Mint full slice | Forecast CSV + Quarto report            | Refitting models                   |
| 6 | **Report**   | Delivery    | EDA + Train metrics + Forecast | Static HTML                             | New data transformations           |

### 1. Ferry Pattern (Data Ingestion)

- **Input**: CSV from Open Alberta URL or local cache (`./data-private/raw/`)
- **Process**: Download if missing, validate schema, minimal SQL-like filtering (no semantic transforms)
- **Output**: Staging data in `./data-raw/derived/` (parquet + CACHE DB if using DuckDB)
- **Validation**: Row counts, date range checks, missing value inventory

### 2. Ellis Pattern (Data Transformation)

- **Input**: Ferry output (raw monthly aggregates)
- **Process**:
  - Standardize column names (`janitor::clean_names`)
  - Parse dates (YY-Mon format → proper Date objects)
  - Clean numeric values (remove commas, handle suppressed cells)
  - Create derived temporal features: fiscal year, month labels, lag features
  - Filter to analysis-ready subset (e.g., Alberta total, caseload measure only)
- **Output**: Analysis-ready dataset in `./data-raw/derived/` + CACHE-manifest.md
- **Quality checks**: No missing dates in series, monotonic time index, documented factor levels

### EDA (Exploratory Data Analysis) — Advisory, Not a Numbered Lane

EDA operates on Ellis output and produces analytical insight (reports, visualizations, stationarity tests) — not data artifacts consumed by downstream scripts. EDA findings are codified as documented decisions in Mint scripts.

- **Objectives**: Visualize trends, seasonality, structural breaks; diagnose stationarity
- **Key outputs**:
  - Time series plot (2010-present for context, fiscal year overlays)
  - ACF/PACF plots for AR/MA order selection
  - Seasonal decomposition (STL or classical)
  - Summary statistics table (mean, SD, growth rates by fiscal year)
- **Format**: Quarto report (`analysis/eda-2/eda-2.qmd`) rendering to HTML
- **Relationship to Mint**: EDA decisions are logged and referenced in Mint scripts (e.g., `[EDA-001] Log transform: TRUE — confirmed by eda-2 g12`)

### 3. Mint Pattern (Model-Ready Preparation)

- **Input**: Ellis parquet output + EDA-confirmed analytical decisions
- **Process**:
  - Apply train/test split keyed to `focal_date` and `backtest_months` from `config.yml`
  - Apply log transform (if EDA-confirmed)
  - Construct `ts` objects for train, test, and full series
  - Build xreg matrices for model tiers requiring exogenous regressors
- **Output**: Apache Parquet data artifacts in `./data-private/derived/forge/` + `forge_manifest.yml`
  - `ds_train/test/full.parquet` — data frame slices (Train lane reconstructs `ts` objects from these)
  - `xreg_train/test/full/future.parquet` — exogenous regressors with `date` column (cross-language)
  - `xreg_dynamic_*.parquet` — 0-row schema placeholder for Tier 4
- **Validation**: Contract assertions (row counts, date boundaries, transform flags)
- **Forbidden**: Model fitting, new data sourcing, re-running Ellis logic

### 4. Train Pattern (Model Estimation)

- **Input**: Mint artifacts only (`ds_*.parquet`, `xreg_*.parquet`, `forge_manifest.yml`) — never Ellis output directly
  - Reconstruct `ts` objects: `ts(ds_train$y, start=c(year(min(date)), month(min(date))), frequency=12)`
- **Train/test split**: Defined by Mint; uses all data through `focal_date - 24 months` for training; holds out last 24 months for backtesting
- **Model tiers** (increasing complexity):
  1. **Naive baseline**: Last observed value propagated forward (benchmark)
  2. **ARIMA**: Auto-selected orders via `forecast::auto.arima()` on log-transformed series
  3. **ARIMA + static predictor**: Include client type as exogenous regressor (slowly-varying in demo data)
  4. **ARIMA + time-varying predictor**: Placeholder for economic indicator (e.g., oil price, unemployment rate) — structure only, real covariate TBD
- **Model storage**: Save fitted model objects as `.rds` in `./data-private/derived/models/` (R-native format; model objects cannot be stored as parquet); register metadata in model registry CSV with `forge_hash` linking back to `forge_manifest.yml`
- **Performance metrics**: RMSE, MAE, MAPE on held-out 24-month backtesting window

### 5. Forecast Pattern Pattern (Prediction)

- **Input**: Train model `.rds` + Mint `ds_full.parquet` for forward projection (reconstruct `ts_full` on load)
- **Horizon**: 24 months ahead from `focal_date`
- **Outputs**:
  - Point forecasts + 80%/95% prediction intervals for each model tier
  - Comparison table: all models side-by-side with performance diagnostics
- **Format**: CSV + Quarto report (`analysis/forecast-1/forecast-1.qmd`)

### 6. Report Pattern (Deliverables)

- **Deliverable**: Static HTML combining EDA + model performance + 24-month forecast visualization
- **Interactivity**: Optional Plotly/htmlwidgets for hover details (keep simple; avoid heavy JS dependencies)
- **Delivery**: Manual publish to SharePoint/network drive (Phase 1); Azure Static Web App + AAD auth (Phase 2)

## Reproducibility Standards

- **Version control**: Git tracks all code, config, and documentation; data files in `.gitignore` (too large, privacy)
- **Dependency management**: `renv.lock` for R packages; `conda`/`mamba` for Python (if Azure migration requires)
- **Random seeds**: Set `set.seed(42)` before any stochastic operation; document in script headers
- **Configuration**: `config.yml` stores `focal_date`, file paths, model hyperparameters (no hardcoded magic numbers)
- **Execution order**: `flow.R` orchestrates full pipeline; each stage sources common functions from `./scripts/`
- **Determinism**: Forecasts are deterministic given fixed seed and package versions (no model randomness beyond seed)

## Azure ML Migration Strategy (Phase 2)

- **R vs. Python**: Keep data wrangling in R (ferry/ellis patterns stable); consider Python for model training if Azure ML integration is smoother
- **Compute allocation**: Use cheap CPU instances for ferry/ellis; evaluate GPU necessity for complex models (unlikely for ARIMA)
- **Model registry**: Transition from local model `.rds` files to Azure ML model registry with MLflow tracking; data artifacts already in Parquet align natively with Azure ML `TabularDataset`
- **Endpoint serving**: Deploy best-performing model as REST API endpoint for programmatic access (e.g., Power BI integration)
- **Pipeline orchestration**: Refactor `flow.R` into Azure ML pipeline with parameterized components (one pipeline step = one pattern/lane)
- **Scheduling**: Monthly refresh via Azure ML scheduled pipeline runs (replaces manual `Rscript flow.R` execution)

## Mint-Train-Forecast Lineage

The Mint, Train, and Forecast patterns form a versioned chain keyed by `focal_date`:

- **Mint** produces `forge_manifest.yml` with split boundaries, transform flags, and row counts
- **Train** records `forge_hash` in the model registry CSV, linking each fitted model to its exact input data slice
- **Forecast** inherits lineage through the model object it consumes
- Changing `focal_date` in `config.yml` invalidates all Mint, Train, and Forecast artifacts
- This is the minimum viable versioning strategy for Phase 1; Phase 2 transitions to Azure ML model registry with MLflow tracking

## Quality Assurance

- **Unit tests**: `testthat` for data validation functions (`scripts/tests/`)
- **Integration test**: `flow.R` must execute without errors on sample data
- **Peer review**: Code changes reviewed by SDA team before merge to `main` branch
- **Documentation**: All functions have roxygen-style headers; non-obvious logic has inline comments