# CACHE Manifest: Income Support Caseload Analysis-Ready Data

**Source**: Alberta Open Data - Income Support Monthly Caseload Statistics  
**Processing Script**: [manipulation/2-ellis.R](../../manipulation/2-ellis.R)  
**Coverage**: April 2005 – September 2025 (246 months)  
**Last Updated**: 2026-02-18

---

## Purpose

This manifest documents the **analysis-ready datasets** produced by the Ellis pattern transformation of Alberta Income Support caseload data. These datasets are the **primary source of truth** for all downstream analytical work, including exploratory data analysis, time-series forecasting, and Azure ML model development.

After passing through the Ellis transformation, raw operational data has been cleaned, validated, and restructured into formats optimized for different analytical workflows. All data quality issues have been addressed, dates standardized, and categorical variables enriched with descriptive labels.

---

## Output Structure: Dual Format Strategy

The Ellis lane produces **two parallel outputs** to serve different analytical needs:

### 1. **Parquet Files** (Primary)
- **Location**: [data-private/derived/open-data-is-2-tables/](../../data-private/derived/open-data-is-2-tables/)
- **Format**: Apache Parquet (columnar storage)
- **Purpose**: Primary format for **statistical analysis, forecasting, and Azure ML**
- **Advantages**:
  - Columnar compression for efficient storage (~10x smaller than CSV)
  - Fast filtering and aggregation operations
  - Native integration with Azure ML TabularDataset
  - Schema preservation with proper data types
  - Cross-platform compatibility (R, Python, Spark)
- **Usage**: Load via `arrow::read_parquet()` (R) or `pd.read_parquet()` (Python)

### 2. **SQLite Database** (Secondary)
- **Location**: [data-private/derived/open-data-is-2.sqlite](../../data-private/derived/open-data-is-2.sqlite)
- **Format**: SQLite relational database
- **Purpose**: **SQL exploration, prototyping queries, ad-hoc investigation**
- **Advantages**:
  - Familiar SQL interface for data exploration
  - Easy JOIN operations across tables
  - Lightweight single-file portability
  - No server setup required
- **Usage**: Connect via DBI in R or sqlite3 in Python

**Why Both?** Parquet optimizes for analytical workflows (column-oriented operations, cloud integration), while SQLite enables rapid SQL-based exploration without requiring a database server. Use **Parquet for production analysis**, SQLite for quick investigation.

---

## Data Tables Overview

### Table Architecture: Wide vs Long Formats

Each dimension is available in **two formats**:

- **Wide format** (time-series analysis): One row per month, one column per category
  - Optimal for: Time-series forecasting, ARIMA models, visual inspection of trends
  - Example: `client_type_wide` has columns `etw_working`, `bfe`, etc.

- **Long format** (faceted analysis): One row per month × category combination
  - Optimal for: ggplot2 faceting, statistical modeling with category as predictor, Azure ML AutoML
  - Includes descriptive labels (e.g., `client_type_label = "ETW: Working"`)
  - Example: `client_type_long` has 648 rows (162 months × 4 categories)

This manifest **focuses on long-format tables** as the primary analytical interface, with wide formats available for specialized time-series workflows.

---

## Table Inventory (11 Total)

| Table Name                     | Format | Rows | Time Span        | Categories | Description                                      |
|--------------------------------|--------|------|------------------|------------|--------------------------------------------------|
| `total_caseload`               | Wide   | 246  | Apr 2005-Sep 2025| 1          | Unified total caseload across all time periods   |
| `client_type_long`             | Long   | 648  | Apr 2012-Sep 2025| 4          | Caseload by employment category                  |
| `family_composition_long`      | Long   | 648  | Apr 2012-Sep 2025| 4          | Caseload by family structure                     |
| `regions_long`                 | Long   | 720  | Apr 2018-Sep 2025| 8          | Caseload by ALSS administrative region           |
| `age_groups_long`              | Long   | 990  | Apr 2020-Sep 2025| 15         | Caseload by age bin                              |
| `gender_long`                  | Long   | 198  | Apr 2020-Sep 2025| 3          | Caseload by gender identity                      |
| `client_type_wide`             | Wide   | 162  | Apr 2012-Sep 2025| 4          | Same data, pivoted for time-series analysis      |
| `family_composition_wide`      | Wide   | 162  | Apr 2012-Sep 2025| 4          | Same data, pivoted for time-series analysis      |
| `regions_wide`                 | Wide   | 90   | Apr 2018-Sep 2025| 8          | Same data, pivoted for time-series analysis      |
| `age_groups_wide`              | Wide   | 66   | Apr 2020-Sep 2025| 15         | Same data, pivoted for time-series analysis      |
| `gender_wide`                  | Wide   | 66   | Apr 2020-Sep 2025| 3          | Same data, pivoted for time-series analysis      |

---

## Historical Phases: Dimension Availability

Alberta's Income Support reporting evolved over time, adding dimensions progressively:

| Phase | Period              | Months | Dimensions Available                                              |
|-------|---------------------|--------|-------------------------------------------------------------------|
| 1     | Apr 2005 - Mar 2012 | 84     | Total Caseload only                                               |
| 2     | Apr 2012 - Mar 2018 | 72     | + Client Type, Family Composition                                 |
| 3     | Apr 2018 - Mar 2020 | 24     | + ALSS Regions                                                    |
| 4     | Apr 2020 - Mar 2022 | 24     | + Average Age, Client Gender                                      |
| 5     | Apr 2022 - Sep 2025 | 42     | + Gender "Other" category (first non-suppressed: Aug 2022)        |

**Implication for Analysis**: When analyzing dimensional breakdowns (e.g., by region), you're limited to more recent time periods. For full historical context (2005-2025), use `total_caseload` only.

---

## Common Column Schema

All tables share these **temporal identifier columns**:

| Column         | Type   | Description                                                  | Example           |
|----------------|--------|--------------------------------------------------------------|-------------------|
| `date`         | Date   | First day of month (YYYY-MM-DD)                              | `2020-11-01`      |
| `year`         | Integer| Calendar year                                                | `2020`            |
| `month`        | Integer| Month number (1-12)                                          | `11`              |
| `fiscal_year`  | Char   | Alberta fiscal year (Apr-Mar): `FY YYYY-YY`                  | `FY 2020-21`      |
| `month_label`  | Char   | Readable month-year                                          | `Nov 2020`        |

**Long-format tables** additionally include:
- `{dimension}_category`: Machine-readable category name (e.g., `etw_working`, `age_18_19`)
- `{dimension}_label`: Human-readable category label (e.g., `"ETW: Working"`, `"Age 18-19"`)
- `count`: Numeric caseload value (NA for suppressed values)

---

## 1. Total Caseload Table

**Table**: `total_caseload`  
**Rows**: 246 (one per month, Apr 2005 - Sep 2025)  
**Format**: Wide (no categories to pivot)

### Purpose
Unified time-series of total Income Support caseload across all client types, regions, and demographics. This is the **only dimension available for the full 20-year historical period**.

### Columns
| Column       | Type    | Description                                    |
|--------------|---------|------------------------------------------------|
| `date`       | Date    | Month identifier (first day of month)          |
| `year`       | Integer | Calendar year                                  |
| `month`      | Integer | Month number (1-12)                            |
| `fiscal_year`| Char    | Alberta fiscal year (FY YYYY-YY)               |
| `month_label`| Char    | Human-readable month-year                      |
| `caseload`   | Numeric | Total active caseload count                    |

### Usage Notes
- **No missing values**: Complete coverage for all 246 months
- **Data quality**: Nov 2020 correction applied (duplicate row removed)
- **Trend analysis**: Use for long-term forecasting and policy impact assessment
- **Baseline**: Compare dimensional breakdowns against this total to verify completeness

---

## 2. Client Type Tables

**Long**: `client_type_long` (648 rows = 162 months × 4 categories)  
**Wide**: `client_type_wide` (162 rows, Apr 2012 - Sep 2025)

### Purpose
Distinguishes clients by **employment readiness and program type**, capturing shifts in Alberta's labor market attachment philosophy.

### Categories

#### Long Format Columns
| Column                | Type    | Description                                          |
|-----------------------|---------|------------------------------------------------------|
| `client_type_category`| Char    | Machine name: `etw_working`, `etw_available_for_work`, `etw_unavailable_for_work`, `bfe` |
| `client_type_label`   | Char    | Human label                                          |
| `count`               | Numeric | Caseload count (NA if suppressed)                    |

#### Wide Format Columns (Pivoted)
| Column                      | Type    | Caseload Count For...                               |
|-----------------------------|---------|-----------------------------------------------------|
| `etw_working`               | Numeric | Expected to Work: Currently employed                |
| `etw_available_for_work`    | Numeric | Expected to Work: Available and seeking work        |
| `etw_unavailable_for_work`  | Numeric | Expected to Work: Temporarily unable (illness, etc.)|
| `bfe`                       | Numeric | Barriers to Full Employment: Significant barriers       |

### Category Definitions

- **ETW: Working** – Clients employed but earnings insufficient for self-sufficiency (income supplementation)
- **ETW: Available for Work** – Clients actively seeking employment, job-ready
- **ETW: Unavailable for Work** – Clients temporarily unable to work (caregiving, short-term illness, training)
- **Barriers to Full Employment** – Clients with significant barriers to employment (disabilities, chronic health conditions, complex life circumstances requiring longer-term support)

### Usage Notes
- **Policy context**: "Expected to Work" (ETW) classification introduced April 2012 as part of Alberta Works reform
- **Forecasting strategy**: Model each category separately due to different policy drivers and economic sensitivities
- **Missing values**: 6 suppressed cells (small counts) converted to NA
- **Total validation**: Sum of 4 categories should approximate `total_caseload` for overlapping periods (minor discrepancies due to suppression)

---

## 3. Family Composition Tables

**Long**: `family_composition_long` (648 rows = 162 months × 4 categories)  
**Wide**: `family_composition_wide` (162 rows, Apr 2012 - Sep 2025)

### Purpose
Classifies clients by **household structure**, enabling analysis of support needs by family type and dependency ratios.

### Categories

#### Long Format Columns
| Column                 | Type    | Description                                          |
|------------------------|---------|------------------------------------------------------|
| `family_type_category` | Char    | Machine name: `single`, `single_parent`, `couples_with_children`, `childless_couples` |
| `family_type_label`    | Char    | Human label                                          |
| `count`                | Numeric | Caseload count (NA if suppressed)                    |

#### Wide Format Columns (Pivoted)
| Column                   | Type    | Caseload Count For...                           |
|--------------------------|---------|------------------------------------------------|
| `single`                 | Numeric | Single individuals without dependents          |
| `single_parent`          | Numeric | Single-parent households with children         |
| `couples_with_children`  | Numeric | Two-parent households with children            |
| `childless_couples`      | Numeric | Couples without dependent children             |

### Category Definitions

- **Single** – Individuals living alone or in non-dependent adult households
- **Single Parent** – One adult with dependent children (primary caregiver)
- **Couples with Children** – Two adults (married/common-law) with dependent children
- **Childless Couples** – Two adults without dependent children

### Usage Notes
- **Data quality note**: Nov 2020 had duplicate row (48,850 vs 44,850) – **correction row (44,850) retained**
- **Policy implications**: Single parents may have different work requirements and support levels
- **Child dependency**: "Children" defined as dependent minors (typically under 18 or in full-time education)
- **Forecasting**: Single category typically largest (~50-60% of caseload historically)

---

## 4. ALSS Regions Tables

**Long**: `regions_long` (720 rows = 90 months × 8 regions)  
**Wide**: `regions_wide` (90 rows, Apr 2018 - Sep 2025)

### Purpose
Geographic distribution of caseload by **Alberta Learning and Social Services (ALSS) administrative regions**, enabling regional planning and resource allocation.

### Categories

#### Long Format Columns
| Column            | Type    | Description                                                   |
|-------------------|---------|---------------------------------------------------------------|
| `region_category` | Char    | Machine name: `calgary`, `central`, `edmonton`, `north_central`, `north_east`, `north_west`, `south`, `unknown` |
| `region_label`    | Char    | Human label (capitalized)                                     |
| `count`           | Numeric | Caseload count (NA if suppressed)                             |

#### Wide Format Columns (Pivoted)
| Column          | Type    | Geographic Coverage                                      |
|-----------------|---------|----------------------------------------------------------|
| `calgary`       | Numeric | Calgary metropolitan area                                |
| `central`       | Numeric | Red Deer and surrounding area                            |
| `edmonton`      | Numeric | Edmonton metropolitan area                               |
| `north_central` | Numeric | Grande Prairie area (renamed "Unknown" Jan 2022)         |
| `north_east`    | Numeric | Fort McMurray, Cold Lake area                            |
| `north_west`    | Numeric | Peace River, High Prairie area                           |
| `south`         | Numeric | Lethbridge, Medicine Hat area                            |
| `unknown`       | Numeric | Unspecified region (appears Jan 2022, replaces North Central) |

### Region Definitions

- **Calgary** – Urban metropolitan region (largest population center)
- **Edmonton** – Urban metropolitan region (provincial capital)
- **Central** – Central Alberta, anchored by Red Deer
- **North East** – Oil sands region, resource economy-dependent
- **North West** – Peace Country, agricultural and resource-based
- **South** – Southern Alberta, agricultural focus
- **North Central** → **Unknown** – Taxonomy change in January 2022, reason unclear

### Usage Notes
- **Coverage limitation**: Regional data only available Apr 2018 onward (7.5 years)
- **Economic heterogeneity**: Calgary/Edmonton urban markets vs rural/resource regions have different economic drivers
- **Resource sensitivity**: North East region highly correlated with oil price fluctuations
- **Data quality**: "North Central" → "Unknown" transition in Jan 2022 may indicate reporting change or regional boundary redefinition
- **Forecasting strategy**: Consider regional economic indicators (oil prices for North East, housing starts for Calgary/Edmonton)

---

## 5. Age Groups Tables

**Long**: `age_groups_long` (990 rows = 66 months × 15 age bins)  
**Wide**: `age_groups_wide` (66 rows, Apr 2020 - Sep 2025)

### Purpose
Age distribution of caseload, enabling cohort analysis, lifecycle stage profiling, and age-specific policy design.

### Categories (15 Age Bins)

#### Long Format Columns
| Column         | Type    | Description                                                                  |
|----------------|---------|------------------------------------------------------------------------------|
| `age_category` | Char    | Machine name: `age_18_19`, `age_20_24`, ..., `age_65`                        |
| `age_label`    | Char    | Human label: `"Age 18-19"`, `"Age 20-24"`, ..., `"Age 65+"`                  |
| `count`        | Numeric | Caseload count (NA if suppressed)                                            |

#### Wide Format Columns (15 Bins)
| Column       | Type    | Age Range        | Life Stage Context                              |
|--------------|---------|------------------|-------------------------------------------------|
| `age_18_19`  | Numeric | 18-19            | Youth transitioning to adulthood, post-secondary entry |
| `age_20_24`  | Numeric | 20-24            | Early career establishment, education completion |
| `age_25_29`  | Numeric | 25-29            | Career building, family formation               |
| `age_30_34`  | Numeric | 30-34            | Mid-career, young families                      |
| `age_35_39`  | Numeric | 35-39            | Established families, peak parenting demands    |
| `age_40_44`  | Numeric | 40-44            | Mid-life career, adolescent children possible   |
| `age_45_49`  | Numeric | 45-49            | Late career, older children more independent    |
| `age_50_54`  | Numeric | 50-54            | Pre-retirement planning, potential caregiving   |
| `age_55_59`  | Numeric | 55-59            | Early retirement considerations, empty nest     |
| `age_60`     | Numeric | 60 (single year) | Early retiree, pre-pension eligibility          |
| `age_61`     | Numeric | 61 (single year) | Transition to pension eligibility               |
| `age_62`     | Numeric | 62 (single year) | Pension-eligible                                |
| `age_63`     | Numeric | 63 (single year) | Pension-eligible                                |
| `age_64`     | Numeric | 64 (single year) | Pension-eligible                                |
| `age_65`     | Numeric | 65+ (open-ended) | Pension age and beyond                          |

### Usage Notes
- **Coverage limitation**: Age data only available Apr 2020 onward (5.5 years) – limited for long-term forecasting
- **Bin heterogeneity**: 5-year bins for ages 18-59, then single-year bins 60-64, then open-ended 65+
- **Policy context**: Age 60-64 granularity reflects transition to federal pension programs (CPP at 60, OAS at 65)
- **Data quality**: Nov 2020 has data quality flag – **Average Age total doesn't align with category totals** (use category sums, not reported total)
- **Forecasting**: Consider demographic trends (aging Baby Boomers) and policy eligibility transitions
- **Life-stage analysis**: Group into young adults (18-29), prime working age (30-54), pre-retirees (55-64), seniors (65+)

---

## 6. Gender Tables

**Long**: `gender_long` (198 rows = 66 months × 3 categories)  
**Wide**: `gender_wide` (66 rows, Apr 2020 - Sep 2025)

### Purpose
Gender distribution of caseload, supporting equity analysis and gender-responsive policy design.

### Categories

#### Long Format Columns
| Column            | Type    | Description                                        |
|-------------------|---------|----------------------------------------------------|
| `gender_category` | Char    | Machine name: `female`, `male`, `other`            |
| `gender_label`    | Char    | Human label: `"Female"`, `"Male"`, `"Other"`       |
| `count`           | Numeric | Caseload count (NA if suppressed)                  |

#### Wide Format Columns (Pivoted)
| Column   | Type    | Description                                            |
|----------|---------|--------------------------------------------------------|
| `female` | Numeric | Clients identifying as female                          |
| `male`   | Numeric | Clients identifying as male                            |
| `other`  | Numeric | Clients identifying outside binary (available Apr 2022+)|

### Category Definitions

- **Female** – Clients identifying as female (includes cisgender and transgender women)
- **Male** – Clients identifying as male (includes cisgender and transgender men)
- **Other** – Non-binary, two-spirit, or other gender identities (column present from April 2020 as NA; first non-suppressed value August 2022)

### Usage Notes
- **Coverage limitation**: Gender data available Apr 2020 onward (5.5 years)
- **Taxonomy evolution**: "Other" category column exists in data from April 2020 (all values NA/suppressed), with first **reportable (non-NA) value in August 2022** due to small-count suppression in earlier months
- **Historical analysis**: When analyzing 2020 through July 2022, only Female/Male have non-NA values; Other = NA for Apr 2020 through Jul 2022
- **Equity analysis**: Female clients historically represent majority (~52-55%) of Income Support caseload
- **Intersectionality**: Cross-reference with family_composition (e.g., single mothers vs single fathers) for nuanced insights

---

## Data Quality Notes

### Applied Corrections

1. **Nov 2020 Duplicate (Family Composition)**:
   - **Issue**: Two rows existed for Nov 2020, one with incorrect total (48,850), one with correction (44,850)
   - **Resolution**: Correction row retained, duplicate removed
   - **Affected table**: `family_composition_long`, `family_composition_wide`

2. **Nov 2020 Age Groups Total Mismatch**:
   - **Issue**: Reported "Average Age" total (16,280) doesn't match sum of age category components (23,480)
   - **Resolution**: `data_quality_flag` column added to raw data, category sums used as truth
   - **Affected table**: `age_groups_long`, `age_groups_wide`

3. **Suppressed Values**:
   - **Pattern**: Small counts masked as `" -   "` in source data for privacy protection
   - **Resolution**: Converted to `NA` for statistical analysis
   - **Affected tables**: All dimensional tables (6 cells total across all categories)
   - **Implication**: Totals may not sum perfectly due to suppressed cells

### Validation Rules Applied

All tables passed the following checks (see [manipulation/2-ellis.R](../../manipulation/2-ellis.R) Section 3):
- ✅ Date columns are valid Date type within 2005-2025 range
- ✅ Year/month are valid integers
- ✅ Geography field is consistently "Alberta"
- ✅ Fiscal year follows `FY YYYY-YY` format
- ✅ Counts are non-negative numeric (NA allowed for suppression)
- ✅ Composite keys (date × category) are unique within each table

---

## Usage Guide for Analysts

### Recommended Workflows

#### 1. **Exploratory Data Analysis**
```r
# Load long-format table for ggplot2 faceting
library(arrow)
client_type <- read_parquet("data-private/derived/open-data-is-2-tables/client_type_long.parquet")

# Faceted time-series plot
library(ggplot2)
ggplot(client_type, aes(x = date, y = count, color = client_type_label)) +
  geom_line() +
  facet_wrap(~client_type_label, scales = "free_y") +
  theme_minimal()
```

#### 2. **Time-Series Forecasting (ARIMA/ETS)**
```r
# Load wide-format table for direct ts() conversion
library(arrow)
client_type <- read_parquet("data-private/derived/open-data-is-2-tables/client_type_wide.parquet")

# Convert single column to time series
library(forecast)
ts_etw_working <- ts(client_type$etw_working, start = c(2012, 4), frequency = 12)
model <- auto.arima(ts_etw_working)
forecast(model, h = 24)
```

#### 3. **Azure ML Integration**
```python
# Load into Azure ML workspace
from azureml.core import Workspace, Dataset
ws = Workspace.from_config()

# Register Parquet files as TabularDataset
datastore = ws.get_default_datastore()
dataset = Dataset.Tabular.from_parquet_files(
    path=[(datastore, 'open-data-is-2-tables/*.parquet')]
)
dataset.register(ws, name='income_support_caseload', create_new_version=True)
```

#### 4. **SQL Exploration**
```r
# Quick SQL investigation without loading full tables
library(DBI)
conn <- dbConnect(RSQLite::SQLite(), "data-private/derived/open-data-is-2.sqlite")

# Check regional trends
dbGetQuery(conn, "
  SELECT region_label, AVG(count) as avg_caseload
  FROM regions_long
  WHERE date >= '2023-01-01'
  GROUP BY region_label
  ORDER BY avg_caseload DESC
")
```

### Common Analysis Patterns

| Analysis Goal                     | Recommended Table(s)            | Format | Key Considerations                                |
|-----------------------------------|---------------------------------|--------|---------------------------------------------------|
| Long-term trend forecasting       | `total_caseload`                | Wide   | Full 20-year history, no dimensional breakdowns   |
| Multi-category forecasting        | `*_long` tables                 | Long   | Model each category separately with shared calendar effects |
| Regional resource allocation      | `regions_long`                  | Long   | Only 7.5 years of data, limited for long forecasts|
| Age cohort lifecycle analysis     | `age_groups_long`               | Long   | Only 5.5 years, consider demographic projections  |
| Gender equity dashboards          | `gender_long`                   | Long   | Handle "Other" category availability (2022+)      |
| Family policy impact              | `family_composition_long`       | Long   | Nov 2020 correction applied, verify totals        |
| Cross-dimensional profiling       | Join multiple `*_long` tables   | Long   | Use `date` as key, beware of phase availability  |
| Automated ML feature engineering  | All `*_long` tables             | Long   | Azure AutoML expects long format with category columns |

### Phase-Aware Analysis Tips

When analyzing dimensional data, respect historical availability:

```r
# Safe approach: Filter to Phase 5 for complete dimensional analysis
analysis_df <- regions_long %>%
  filter(date >= as.Date("2022-04-01")) %>%  # Phase 5 start
  left_join(age_groups_long, by = c("date", "year", "month", "fiscal_year", "month_label")) %>%
  left_join(gender_long, by = c("date", "year", "month", "fiscal_year", "month_label"))

# Result: 42 months with complete region × age × gender breakdowns
```

---

## Integration with Project Workflow

### Upstream Dependencies
- **Input**: [data-private/derived/open-data-is-1.sqlite](../../data-private/derived/open-data-is-1.sqlite) (Ferry output, see [INPUT-manifest.md](INPUT-manifest.md))
- **Source Script**: [manipulation/2-ellis.R](../../manipulation/2-ellis.R)
- **Raw Data Provenance**: Alberta Open Data Portal (see INPUT-manifest for source URL)

### Downstream Usage
- **EDA Scripts**: [analysis/eda-1/](../../analysis/eda-1/) – Exploratory data analysis using these tables as starting point
- **Forecasting Scripts**: TBD – Time-series modeling scripts will reference these tables
- **Azure ML Pipelines**: TBD – Cloud model training will consume Parquet files
- **Dashboards**: TBD – Interactive visualization tools will query long-format tables

### Reproducibility
To regenerate this dataset from raw data:
```r
# Full pipeline (includes ferry lane)
source("flow.R")

# Ellis lane only (assumes ferry output exists)
source("manipulation/2-ellis.R")
```

---

## Metadata

**Schema Version**: 1.0  
**Ellis Script Execution Time**: ~4.6 seconds  
**Total Storage**:
- Parquet: ~98 KB (11 files, compressed)
- SQLite: ~185 KB (single file with indexes)

**Checksums**: See [manipulation/2-ellis.R](../../manipulation/2-ellis.R) session info for R package versions and environment details.

**Data Lineage**:
1. Alberta Open Data Portal (raw CSV)
2. Ferry Lane ([manipulation/1-ferry.R](../../manipulation/1-ferry.R)) → SQLite staging
3. Ellis Lane ([manipulation/2-ellis.R](../../manipulation/2-ellis.R)) → Analysis-ready Parquet + SQLite
4. This CACHE-manifest documents Step 3 outputs

---

## Contact & Questions

For questions about:
- **Data content**: Consult Alberta Open Data metadata or Income Support program documentation
- **Processing decisions**: Review [manipulation/2-ellis.R](../../manipulation/2-ellis.R) comments and transformation logs
- **Analysis guidance**: See [analysis/eda-1/eda-style-guide.md](../../analysis/eda-1/eda-style-guide.md) for visualization standards

**Last Updated**: 2026-02-18  
**Document Maintainer**: Data Engineer (Persona)
