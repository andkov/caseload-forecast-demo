# Methodology

This project follows a **ferry-ellis-forecast** pipeline adapted from [RAnalysisSkeleton](https://github.com/wibeasley/RAnalysisSkeleton) patterns, optimized for monthly time series forecasting with cloud migration as Phase 2 objective.

## Data Source

**Alberta Income Support Aggregated Caseload Data**  
- **Public URL**: [Open Alberta - Income Support](https://open.alberta.ca/dataset/e1ec585f-3f52-40f2-a022-5a38ea3397e5/resource/4f97a3ae-1b3a-48e9-a96f-f65c58526e07/download/is-aggregated-data-april-2005-sep-2025.csv)  
- **Temporal coverage**: April 2005 to present (updated monthly by GoA)  
- **Structure**: Monthly aggregates by geography, measure type (caseload, intakes, exits), and demographics  
- **Forecast target**: Total active caseload count, 24-month horizon, monthly intervals  

## Pipeline Stages

### 1. Ferry Pattern (Data Ingestion)
- **Input**: CSV from Open Alberta URL or local cache (`./data-private/raw/`)
- **Process**: Download if missing, validate schema, minimal SQL-like filtering (no semantic transforms)
- **Output**: Staging data in `./data-public/derived/` (parquet + CACHE DB if using DuckDB)
- **Validation**: Row counts, date range checks, missing value inventory

### 2. Ellis Pattern (Data Transformation)
- **Input**: Ferry output (raw monthly aggregates)
- **Process**:
  - Standardize column names (`janitor::clean_names`)
  - Parse dates (YY-Mon format → proper Date objects)
  - Clean numeric values (remove commas, handle suppressed cells)
  - Create derived temporal features: fiscal year, month labels, lag features
  - Filter to analysis-ready subset (e.g., Alberta total, caseload measure only)
- **Output**: Analysis-ready dataset in `./data-public/derived/` + CACHE-manifest.md
- **Quality checks**: No missing dates in series, monotonic time index, documented factor levels

### 3. EDA (Exploratory Data Analysis)
- **Objectives**: Visualize trends, seasonality, structural breaks; diagnose stationarity
- **Key outputs**:
  - Time series plot (2010-present for context, fiscal year overlays)
  - ACF/PACF plots for AR/MA order selection
  - Seasonal decomposition (STL or classical)
  - Summary statistics table (mean, SD, growth rates by fiscal year)
- **Format**: Quarto report (`analysis/eda-2/eda-2.qmd`) rendering to HTML

### 4. Train (Model Estimation)
- **Train/test split**: Use all data through `focal_date - 24 months` for training; hold out last 24 months for backtesting
- **Model tiers** (increasing complexity):
  1. **Naive baseline**: Last observed value propagated forward (benchmark)
  2. **ARIMA**: Auto-selected orders via `forecast::auto.arima()` on log-transformed series
  3. **ARIMA + static predictor**: Include gender composition as exogenous regressor (time-invariant in demo data)
  4. **ARIMA + time-varying predictor**: Placeholder for economic indicator (e.g., oil price, unemployment rate) — structure only, real covariate TBD
- **Model storage**: Save fitted model objects as `.rds` in `./data-private/derived/models/`; register metadata in model registry CSV
- **Performance metrics**: RMSE, MAE, MAPE on held-out 24-month backtesting window

### 5. Forecast (Prediction)
- **Horizon**: 24 months ahead from `focal_date`
- **Outputs**:
  - Point forecasts + 80%/95% prediction intervals for each model tier
  - Comparison table: all models side-by-side with performance diagnostics
- **Format**: CSV + Quarto report (`analysis/forecast-1/forecast-1.qmd`)

### 6. Reporting
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
- **Model registry**: Transition from local `.rds` files to Azure ML model registry with MLflow tracking
- **Endpoint serving**: Deploy best-performing model as REST API endpoint for programmatic access (e.g., Power BI integration)
- **Pipeline orchestration**: Refactor `flow.R` into Azure ML pipeline with parameterized components (one pipeline step = one script)
- **Scheduling**: Monthly refresh via Azure ML scheduled pipeline runs (replaces manual `Rscript flow.R` execution)

## Quality Assurance

- **Unit tests**: `testthat` for data validation functions (`scripts/tests/`)
- **Integration test**: `flow.R` must execute without errors on sample data
- **Peer review**: Code changes reviewed by SDA team before merge to `main` branch
- **Documentation**: All functions have roxygen-style headers; non-obvious logic has inline comments