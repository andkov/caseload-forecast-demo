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
- 6 time series visualizations exploring different analytical perspectives
- Growth rate analysis identifying volatility patterns
- Period-based summary statistics for forecasting context

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
- **Insights**: Barrier-Free Employment forms stable base, ETW: Available most volatile
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

### For Forecasting Model Development

1. **High economic sensitivity** - unemployment rate, oil prices, wage growth should be included as predictors

2. **Client type heterogeneity** - model each category separately rather than aggregating

3. **Structural breaks** - 2012 policy reform, COVID-19 federal programs require dummy variables or regime-specific models

4. **Modest seasonality** - include seasonal adjustment but not dominant signal

5. **High baseline volatility** - use wide prediction intervals, consider ensemble approaches

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

- **EDA-3**: Analyze family composition and regional breakdowns
- **EDA-4**: External economic predictors (unemployment, oil prices, demographics)
- **Model Development**: ARIMA baseline → multivariate models → Azure ML AutoML
- **Forecast Validation**: Backtesting framework using historical test set

---

For questions or issues, consult:
- [CACHE-manifest.md](../../data-public/metadata/CACHE-manifest.md) - Data dictionary
- [2-ellis.R](../../manipulation/2-ellis.R) - Data transformation logic
- [Project Glossary](../../ai/project/glossary.md) - Term definitions
