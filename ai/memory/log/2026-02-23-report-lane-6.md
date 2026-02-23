# Report Lane 6: Implementation and Artifact Contract

**Date**: 2026-02-23  
**Scope**: `analysis/report-1/report-1.R`, `analysis/report-1/report-1.qmd`, `flow.R`  
**Trigger**: Human request to implement Lane 6 (Report) consuming Lane 3–5 artifacts,
  structured as an inverted pyramid with policy implication framing

---

## Summary

Implemented `analysis/report-1/` as a dual-file Quarto report (`.R` development layer +
`.qmd` publication layer) that integrates all Mint, Train, and Forecast artifacts into a
single self-contained HTML. The report uses an **inverted pyramid** narrative: forecast
answer first, model comparison second, backtest diagnostics third, specifications and
provenance last. Report renders in ~10 seconds via `quarto render analysis/report-1/report-1.qmd`.

---

## Report Structure

| Section | Purpose | Chunks |
|---------|---------|--------|
| The Forecast | Lead with 24-month ARIMA projection (hero graph) + key numbers callout | `g1`, `t1` |
| Model Comparison | How the two forecasts differ; tabular performance summary | `g2`, `g21`, `t2` |
| Backtest Evidence | Do the models track reality? Residual diagnostics | `g3`, `g31`, `g32` |
| Policy Implications | Plain-language narrative on evidence for prediction strategy | (prose) |
| Model Specifications | ARIMA orders, AIC, train/test row counts | `t3` |
| Data Lineage & Provenance | forge_manifest + forecast_manifest summary tables | `t4`, `t5` |

---

## Files Created

```
analysis/report-1/
├── report-1.R          # Development layer: all chunk definitions, ggsave() calls
├── report-1.qmd        # Publication layer: read_chunk() + narrative prose
├── report-1.html       # Rendered self-contained HTML output
├── prints/             # PNG exports (g1 through g32, 300 DPI, 10×6 in)
└── data-local/         # Reserved for intermediate data outputs
```

**flow.R registration** (Phase 6):
```r
"run_qmd", "analysis/report-1/report-1.qmd",  # IS caseload forecast report (Lanes 3-5 → HTML)
```

---

## Artifacts Consumed

### Lane 3 (Mint)
| Artifact | Path | Purpose in Report |
|----------|------|-------------------|
| `forge_manifest.yml` | `data-private/derived/forge/` | Lineage provenance table `t4`; lineage integrity check |
| `ds_full.parquet` | `data-private/derived/forge/` | Historical series for hero graph `g1` |

### Lane 4 (Train)
| Artifact | Path | Purpose in Report |
|----------|------|-------------------|
| `model_registry.csv` | `data-private/derived/models/` | Model specs table `t3`; `forge_hash` lineage validation |

### Lane 5 (Forecast)
| Artifact | Path | Purpose in Report |
|----------|------|-------------------|
| `forecast_long.csv` | `data-private/derived/forecast/` | All graphs and `t1` key numbers |
| `backtest_comparison.csv` | `data-private/derived/forecast/` | Backtest diagnostic graphs `g3`, `g31`, `g32` |
| `model_performance.csv` | `data-private/derived/forecast/` | Performance table `t2`; best-model highlight |
| `forecast_manifest.yml` | `data-private/derived/forecast/` | Provenance summary table `t5`; lineage integrity check |

---

## Graph Inventory

| Chunk | Type | Description |
|-------|------|-------------|
| `g1` | Line + ribbon | Hero: 20-year history + 24-month ARIMA forecast with 80%/95% PI ribbons |
| `g2` | Faceted line | Side-by-side comparison: Naive vs ARIMA forecast panels, both with PIs |
| `g21` | Overlaid line | Both model forecasts on one axis; easier direct visual comparison |
| `g3` | Scatter + line | Actual vs fitted (in-sample backtest, both models) |
| `g31` | Line | Residuals over time; detect bias/drift patterns |
| `g32` | Line | Percentage error over time; scale-free view of accuracy |

---

## Table Inventory

| Chunk | Type | Description |
|-------|------|-------------|
| `t1` | `kable` | Key forecast numbers: current caseload, 12-month / 24-month ARIMA point forecasts |
| `t2` | `kableExtra` | Model performance comparison: RMSE, MAE, MAPE; best row highlighted |
| `t3` | `kable` | Model specifications: ARIMA order, AIC/AICc/BIC, n_train, n_test |
| `t4` | `kable` | Forge manifest provenance: focal_date, split boundaries, transform decisions, forge_hash |
| `t5` | `kable` | Forecast manifest provenance: forecast window, models forecasted, forecast_hash |

---

## Colour System

```r
col_historical  <- "steelblue"
col_arima       <- "#2166ac"
col_naive       <- "#d6604d"
col_split_line  <- "gray50"

tier_display_levels <- c("Tier 1: Naive Baseline", "Tier 2: ARIMA")

tier_colours <- c(
  "Tier 1: Naive Baseline" = col_naive,
  "Tier 2: ARIMA"          = col_arima
)
```

Colour choices follow EDA-2 conventions and extend them: steelblue for historical
continuity, blue/red divergence for model discrimination. The `tier_display_levels`
vector provides the canonical factor ordering for all ggplot `scale_*` calls — this
prevents alphabetical reordering and ensures consistent colour–model mapping.

---

## Key Schema Facts (for future agents)

**`forecast_long.csv` columns** (48 rows: 2 models × 24 months):
```
date, year, month, fiscal_year, month_label, model_id, tier, tier_label,
point_forecast, lo_80, hi_80, lo_95, hi_95
```
- `tier_label` values: `"Naive Baseline"` (tier=1), `"ARIMA"` (tier=2)
- **No `model_description` column** — use `tier_label` for display, `tier` for filtering

**`backtest_comparison.csv` columns** (48 rows: 2 models × 24 months):
```
date, actual_caseload, model_id, tier, tier_label, fitted_caseload, residual, pct_error
```
- Contains `fitted()` values (in-sample visual diagnostics), **not true hold-out metrics**
- True accuracy numbers (RMSE/MAE/MAPE) live in `model_performance.csv`

**`model_performance.csv` columns** (2 rows):
```
model_id, tier, tier_label, model_description, backtest_rmse, backtest_mae, backtest_mape,
n_train, n_test, focal_date
```
- **Has `model_description`** — use for t2 table only

**`forecast_manifest.yml` structure** (confirmed from actual file):
```yaml
forecast_hash: fa43528f49351759fe7b2742c44444ef
forge_hash_consumed: 3ef1c81a04b78581f3df84e0a68f1504
forecast_parameters:
  focal_date: '2025-09-01'
  first_forecast_month: '2025-10-01'
  last_forecast_month: '2027-09-01'
  forecast_horizon_months: 24
  random_seed: 42
  transform: "log (EDA-001); back-transformed via exp()"
models_forecasted:  # list of objects, NOT simple strings
  - model_id: tier_1_snaive
    tier: 1
    tier_label: Naive Baseline
    rds_file: tier_1_snaive.rds
    backtest_rmse: 10300.2
    backtest_mape: 16.36
  - model_id: tier_2_arima
    ...
artifacts:  # nested dict; keys = artifact names
  forecast_long: ...
  forecast_wide: ...
  ...
```
**Critical**: `models_forecasted` is a list of objects — use
`sapply(forecast_manifest$models_forecasted, function(m) m$model_id)` to extract IDs.
Do NOT use `paste(forecast_manifest$models_forecasted, ...)`.

---

## Lineage Validation

The report validates two lineage links at load time (in `load-data` chunk):

1. **Train ↔ Mint**: `model_registry$forge_hash[1] == forge_manifest$forge_hash`
2. **Forecast ↔ Mint**: `forecast_manifest$forge_hash_consumed == forge_manifest$forge_hash`

Both checks emit `[OK] Lineage intact` or `[WARNING]` to the console. A warning does not
halt the report (render proceeds with stale-artifact caution noted) but signals the analyst
to re-run upstream lanes.

---

## Narrative Architecture (Inverted Pyramid)

The `.qmd` section ordering was deliberately chosen so a reader skimming for 30 seconds
gets the forecast number; a reader spending 5 minutes gets the model comparison; a reader
spending 15 minutes gets the full diagnostic and lineage account:

```
1. Mission Statement           ← anchors policy context
2. Definition of Terms         ← glossary for non-analyst readers
3. Environment                 ← reproducibility audit trail (prose, no code output)
4. Data                        ← what was observed (invisible chunk group)
5. The Forecast (LEAD)         ← g1 hero graph + t1 numbers callout
6. Model Comparison            ← g2, g21, t2
7. Backtest Evidence           ← g3, g31, g32
8. Policy Implications         ← plain-language narrative prose
9. Model Specifications        ← t3 (audience: technical)
10. Data Lineage & Provenance  ← t4 forge manifest, t5 forecast manifest
11. Session Info               ← R package versions
```

---

## QMD Configuration

```yaml
title: "Alberta Income Support: Caseload Forecast Report"
subtitle: "24-Month Forward Projections — October 2025 to September 2027"
author: "Strategic Data Analytics Team"
format:
  html:
    theme: yeti
    page-layout: full
    toc: true
    toc-location: right
    code-fold: show
    self-contained: true
    embed-resources: true
```

`root.dir` is set to workspace root (`../../`) in the `set_options` chunk so all relative
paths in `report-1.R` resolve correctly from the project root.

---

## Bugs Encountered and Fixed

| Error | Root Cause | Fix Applied |
|-------|-----------|-------------|
| `object 'model_description' not found` in `tweak-data-1` | `forecast_long.csv` and `backtest_comparison.csv` have no `model_description` column | Changed `make_tier_label(tier, model_description)` → `make_tier_label(tier, tier_label)` throughout |
| `arguments imply differing number of rows: 9, 5` in `t5` | `t5_data` data.frame used non-existent manifest keys (`script`, `executed_at`, `forecast_start`, `forecast_end`) and called `paste(models_forecasted, ...)` on a list of objects | Rewrote `t5_data` to use actual manifest keys; used `sapply(..., function(m) m$model_id)` |
| `inspect-data-0` printed NULL for forecast parameters | Same manifest key mismatch as above | Corrected all `forecast_manifest$forecast_parameters$*` references to actual keys |
| `{{< var forecast_hi >}}` undefined variables | QMD used shortcode variables that were never declared | Replaced with inline computed prose |
| Duplicate chunk labels | Setup chunks (`load-packages`, etc.) appeared twice — once in exec section, once in Environment section | Replaced Environment section chunk refs with plain prose |

---

## Extending This Report (for future agents)

**Adding a new model tier** (e.g., Tier 3 ARIMA+xreg):
1. Run `4-train-IS.R` (adds row to `model_registry.csv`, new `.rds` in `models/`)
2. Run `5-forecast-IS.R` (adds rows to `forecast_long.csv`, `backtest_comparison.csv`, `model_performance.csv`)
3. In `report-1.R`: add the new tier label to `tier_display_levels` and `tier_colours`
4. No other structural changes needed — all graphs and tables use `tier_display_levels`
   as the factor ordering, so a new tier will automatically appear

**Changing the fiscal year overlay** or adding annotations: modify the `g1` chunk in
`report-1.R`; the `.qmd` chunk reference picks up changes automatically on next render.

**Scheduled refresh**: `flow.R` with updated `focal_date` in `config.yml` re-runs all
lanes and re-renders this report. The `forge_hash` lineage checks at load time will
confirm artifacts are in sync.
