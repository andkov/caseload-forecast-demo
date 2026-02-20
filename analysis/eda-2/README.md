# EDA-2: Alberta Income Support Caseload Time Series Analysis

## Overview

This exploratory data analysis focuses on **time series patterns** in Alberta Income Support caseload data, providing foundational understanding for forecasting model development.

**Analytical Focus:**
- Total caseload trends (April 2005 - September 2025, 246 months)
- Client type composition evolution (April 2012 - September 2025, 162 months)
- Seasonal patterns and year-over-year growth rates
- Historical period comparison (crisis vs stable periods)

**Data Sources:**
- **Total Caseload**: `total_caseload.parquet` → ds0_total → ds1_total
- **Client Types**: `client_type_long.parquet` → ds0_client_type → ds1_client_type

**Naming Convention:**
- ds0_* = loaded state from parquet files
- ds1_* = after tweak-data-1 transformations (date formatting)

**Key Outputs:**
- 12 visualizations exploring different analytical perspectives
- Stationarity tests (ADF, KPSS) informing differencing requirements
- ACF/PACF plots for ARIMA order selection
- Seasonal decomposition guiding model complexity decisions
- Train/test split visualization showing 24-month backtest window

---

## Files in This Directory

### Core Analysis Files
- **[eda-2.R](eda-2.R)** - R script with all data loading, transformation, and visualization code
- **[eda-2.qmd](eda-2.qmd)** - Quarto report document that calls chunks from the R script
- **README.md** (this file) - Analysis overview and usage instructions

### Generated Outputs
- **`prints/`** - PNG exports of all visualizations (created automatically)
- **`data-local/`** - Temporary derived datasets for analysis (created automatically)
- **`figure-png-iso/`** - Quarto-generated figure files during rendering

---

## Quick Start

### Interactive Exploration (Recommended for Development)

```r
# Open eda-2.R in VS Code or RStudio
# Run chunks interactively to explore data

# Optional: Enable interactive plotting in VS Code
library(httpgd)
httpgd::hgd()
```

### Render Full Report

```bash
# From project root directory
quarto render analysis/eda-2/eda-2.qmd
```

Or use the VS Code task:
- Press `Ctrl+Shift+P` → "Tasks: Run Task" → "Render EDA-2 Quarto Report"

**Output:** Self-contained HTML report with embedded visualizations

---

## Visualizations Generated

### g1: Total Caseload Time Series (2005-2025)
- **Purpose**: Show complete 20-year historical trajectory
- **Insights**: Major economic shocks visible (2008 crisis, oil collapse, COVID-19)
- **Format**: Line + point chart with year breaks on x-axis

### g2: Average Caseload by Historical Period
- **Purpose**: Compare aggregate levels across policy/economic phases
- **Insights**: COVID-19 pandemic period had highest average, pre-2008 lowest
- **Format**: Bar chart with 7 distinct periods

### g3: Client Type Stacked Area Chart
- **Purpose**: Show composition evolution since 2012 Alberta Works reform
- **Insights**: Barriers to Full Employment forms stable base, ETW: Available most volatile
- **Format**: Stacked area with 4 client categories

### g4: Client Type Faceted Time Series
- **Purpose**: Individual trajectory analysis for each client type
- **Insights**: Each category has distinct patterns - justifies separate modeling
- **Format**: 4-panel facet with independent y-axes

### g5: Year-over-Year Comparison (2020-2025)
- **Purpose**: Identify seasonal patterns and recent year dynamics
- **Insights**: Modest seasonality (spring increases, summer dips)
- **Format**: Multi-line overlay by year

### g6: Year-over-Year Growth Rate
- **Purpose**: Quantify volatility and identify structural break periods
- **Insights**: ±40-50% YoY swings during crises, baseline volatility ±5-10%
- **Format**: Line chart with color-coded increase/decrease points

### g7: Train/Test Split Visualization
- **Purpose**: Show temporal boundaries for model training vs backtesting
- **Insights**: Training through Sep 2023, test = last 24 months (Oct 2023 - Sep 2025)
- **Format**: Line chart with vertical split demarcation

### g8: Stationarity Tests (ADF & KPSS)
- **Purpose**: Determine differencing requirement for ARIMA models
- **Insights**: Test results guide d parameter selection (likely d=1 based on trends)
- **Format**: Text output table with test statistics and interpretations

### g9: Autocorrelation Function (ACF)
- **Purpose**: Identify MA (moving average) order for ARIMA modeling
- **Insights**: Lag structure informs q parameter in ARIMA(p,d,q)
- **Format**: Correlogram with significance bounds

### g10: Partial Autocorrelation Function (PACF)
- **Purpose**: Identify AR (autoregressive) order for ARIMA modeling
- **Insights**: Lag structure informs p parameter in ARIMA(p,d,q)
- **Format**: Partial correlogram with significance bounds

### g11: Seasonal Decomposition (STL)
- **Purpose**: Separate trend, seasonal, and irregular components
- **Insights**: Modest seasonality suggests SARIMA optional; large remainder = wide intervals needed
- **Format**: 4-panel faceted time series (observed, trend, seasonal, remainder)

### g12: Log Transformation Comparison
- **Purpose**: Assess variance stabilization benefits of log transformation
- **Insights**: Log scale reduces heteroscedasticity; use for all ARIMA models per method.md
- **Format**: 2-panel comparison (original vs log scale)

---

## Data Preparation Pipeline

This analysis consumes **analysis-ready data** from the Ellis pattern:

```
Raw Alberta Open Data 
  ↓
Ferry Lane 1 (1-ferry.R) - Transport to CACHE database
  ↓
Ellis Lane 2 (2-ellis.R) - Clean, validate, transform
  ↓
Parquet files in ./data-private/derived/open-data-is-2-tables/
  ↓
EDA-2 Analysis: Load as ds0_total, ds0_client_type
  ↓
Transform to ds1_total, ds1_client_type (tweak-data-1)
  ↓
All visualizations use ds1_* datasets
```

**Data Quality:** All Ellis validation checks passed. See [CACHE-manifest.md](../../data-public/metadata/CACHE-manifest.md) for complete documentation.

---

## Key Analytical Insights

### For Forecasting Model Development (train-1/model-1.R)

1. **Train/test split confirmed** - 222 months training (Apr 2005 - Sep 2023), 24 months test (Oct 2023 - Sep 2025)

2. **Log transformation required** - Variance increases with caseload level; log scale stabilizes volatility for ARIMA

3. **Differencing likely needed** - Stationarity tests indicate d=1 in ARIMA(p,d,q) will be necessary

4. **Seasonal component modest** - STL decomposition shows seasonality present but small relative to trend/irregular; SARIMA optional

5. **Wide prediction intervals essential** - Large irregular component in decomposition reflects economic shocks and structural breaks

6. **ACF/PACF patterns** - Inform initial ARIMA order selection; validate against `auto.arima()` recommendations

7. **Client type heterogeneity** - Model each category separately rather than aggregating (distinct volatility patterns persist)

8. **Structural breaks evident** - 2008 crisis, 2014 oil collapse, COVID-19 create regime changes requiring careful model specification

### Historical Context

- **Pre-2008**: Stable, low caseload (~25,000-30,000)
- **2008-09 Crisis**: First major shock (+40% increase)
- **2012 Alberta Works**: Policy reform introduced ETW framework
- **2014-16 Oil Collapse**: Sustained increase reflecting resource economy dependence
- **2020-21 COVID-19**: Largest spike (~60,000 peak) but rapid recovery as federal programs deployed
- **2022-25**: Return to pre-pandemic baseline (~50,000)

---

## Dependencies

### R Packages Required
- **Data wrangling**: dplyr, tidyr, lubridate
- **Visualization**: ggplot2, scales
- **File I/O**: arrow (parquet), fs
- **Utilities**: magrittr, janitor, testit

### Optional (for interactive plotting)
- **httpgd** - VS Code interactive plot device

Install all dependencies:
```r
install.packages(c("dplyr", "tidyr", "ggplot2", "lubridate", 
                   "scales", "arrow", "fs", "janitor", "magrittr"))
```

---

## Troubleshooting

### Parquet Files Not Found
**Error:** Cannot open file './data-private/derived/open-data-is-2-tables/total_caseload.parquet'

**Solution:** Run the Ellis lane to generate analysis-ready data:
```r
source("manipulation/2-ellis.R")
# Or run complete pipeline:
source("flow.R")
```

### Quarto Rendering Fails
**Error:** Chunk 'g1' not found in R script

**Solution:** Ensure chunk labels in `eda-2.R` match exactly with those referenced in `eda-2.qmd`

### httpgd Won't Start
**Error:** Compilation failed on Windows

**Solution:** Install binary version from CRAN:
```r
install.packages("httpgd", repos = "https://cran.rstudio.com", type = "win.binary")
```

---

## Next Steps

**Immediate: Mint Lane Implementation (`3-mint-IS.R`)**

This EDA provides the diagnostic foundation for the Mint pattern (method.md §3), which codifies these analytical decisions into reproducible model-ready data slices:

1. **EDA decisions to codify in Mint**:
   - `[EDA-001]` Use log transformation (g12 confirms variance stabilization)
   - `[EDA-002]` Expect d=1 differencing (g8 stationarity tests)
   - `[EDA-003]` Seasonal period = 12 (monthly, fiscal year cycle)
   - `[EDA-004]` 24-month backtest window (g7 split visualization)
   - `[EDA-005]` Wide prediction intervals expected (g11 decomposition shows large irregular component)

2. **Mint outputs** (consumed by Train lanes):
   - `ts_train.rds`, `ts_test.rds`, `ts_full.rds` — time series objects
   - `xreg_static_train.rds`, `xreg_static_test.rds` — regressor matrices
   - `forge_manifest.yml` — data contract documenting split dates, transforms, row counts

3. **Train lanes** (consume Mint artifacts, never Ellis output directly):
   - Tier 1: Naive baseline (benchmark)
   - Tier 2: ARIMA on log-transformed series (auto-selected orders)
   - Tier 3: ARIMA + static predictor (client type)
   - Tier 4: ARIMA + time-varying predictor (structure only)

4. **Performance metrics**: RMSE, MAE, MAPE on 24-month test period

**Longer-Term**:
- **Client type-specific models**: Separate ARIMA per category
- **External economic predictors**: Unemployment, oil prices
- **Azure ML Migration**: Refactor for cloud execution with MLflow tracking

---

For questions or issues, consult:
- [CACHE-manifest.md](../../data-public/metadata/CACHE-manifest.md) - Data dictionary
- [2-ellis.R](../../manipulation/2-ellis.R) - Data transformation logic
- [Project Glossary](../../ai/project/glossary.md) - Term definitions
