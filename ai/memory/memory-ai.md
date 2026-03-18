# AI Memory

AI system status and technical briefings.

---

# 2026-03-18

## frontend-1: Publishing Orchestra v2 — First Stable Site

Built and stabilized the first static website for the caseload-forecast-demo project using the Publishing Orchestra v2 multi-agent system (`@publishing-editor` → `@publishing-printer`). Site renders 12 pages under the `journal` Quarto theme. **Key architecture decisions made during build**: (1) `file://` portability is mandatory — iframe embeds replaced with meta-refresh redirects for Analysis pages; (2) images referenced by verbatim-copied files must be co-located in `content/` — rule codified in `publishing-content.instructions.md` §5 (Mandatory Asset Resolution Algorithm); (3) pipeline diagram shared across Index, Pipeline Guide, and Docs/README via a canonical `_pipeline-diagram.qmd` partial using `{{< include >}}`; (4) files needing `{{< include >}}` shortcodes must have `.qmd` extension — pre-render script `scripts/prep-pipeline-qmd.R` generates `pipeline.qmd` from raw `manipulation/pipeline.md` on every build; (5) README needs `.qmd` promotion (permanent `readme.qmd` in `content/docs/`) for same reason. Post-render script `scripts/copy-analysis-html.R` copies redirect targets and README image assets into `_site/`. Read-only snapshot archived at `M:\SPQ\PQA\R&A\_Research and Open Data\GitHub Data\caseload-forecaste-demo\2026-03-18-frontend-1-po-2` (commit `7cc74d5`). Detailed log: `ai/memory/log/2026-03-18-frontend-1-publishing-orchestra-2.md`.

---

# 2026-02-23


## report-1: Report Lane 6

Implemented `analysis/report-1/` as a dual-file Quarto report (`.R` dev layer + `.qmd` pub layer) producing a self-contained HTML. Report is structured as an inverted pyramid: lead with 24-month ARIMA forecast hero graph (`g1`), key numbers callout (`t1`), model comparison (`g2`, `g21`, `t2`), backtest diagnostics (`g3`, `g31`, `g32`), policy implications prose, then model specs (`t3`) and provenance tables (`t4` forge manifest, `t5` forecast manifest). **Critical schema facts**: `forecast_long.csv` and `backtest_comparison.csv` have **no `model_description` column** — use `tier_label` (`"Naive Baseline"` / `"ARIMA"`) for display; `model_performance.csv` does have `model_description`. `forecast_manifest.yml`'s `models_forecasted` is a list of objects — iterate with `sapply(..., function(m) m$model_id)`, do not call `paste()` directly on it; `forecast_parameters` keys are `focal_date`, `first_forecast_month`, `last_forecast_month`, `forecast_horizon_months`, `random_seed`, `transform` (no `script`, `executed_at`). Lineage validation at load time: two `forge_hash` cross-checks (Train ↔ Mint, Forecast ↔ Mint). Colour system: `col_historical = "steelblue"`, `col_arima = "#2166ac"`, `col_naive = "#d6604d"`; `tier_display_levels = c("Tier 1: Naive Baseline", "Tier 2: ARIMA")` drives all factor ordering — add new tier label here when Tier 3+ arrives. Registered in `flow.R` Phase 6. Renders in ~10s; output: `analysis/report-1/report-1.html`. Detailed log: `ai/memory/log/2026-02-23-report-lane-6.md`.

---

## 5-forecast-IS.R: Forecast Lane 5

Implemented `manipulation/5-forecast-IS.R` — generates 24-month forward projections (Oct 2025 – Sep 2027) by loading Train `.rds` model objects and calling `forecast(readRDS(rds_path), h = 24)`. No model refitting. All forecast outputs `exp()` back-transformed per [EDA-001]. **Critical design**: Section 3 validates `forge_hash` from `model_registry.csv` against current `forge_manifest.yml` before loading any model; mismatch triggers a hard stop with instructions to re-run lanes 3–4. **Backtest diagnostics note**: `backtest_comparison.csv` contains in-sample `fitted()` values from full-series models (visual use only); true accuracy numbers (RMSE/MAE/MAPE) are in `model_performance.csv` (sourced from Train's hold-out evaluation). Produces 5 artifacts in `./data-private/derived/forecast/`: `forecast_long.csv` (48 rows: 2 models × 24 months, primary ggplot target), `forecast_wide.csv` (24 rows, kable table target), `backtest_comparison.csv` (48 rows), `model_performance.csv` (2 rows: snaive RMSE 10,300 / MAPE 16.4%; ARIMA RMSE 8,639 / MAPE 13.3%), `forecast_manifest.yml` (lineage YAML: `forecast_hash: fa43528f49351759fe7b2742c44444ef` → `forge_hash: 3ef1c81a04b78581f3df84e0a68f1504`). Added `directories.forecast` to `config.yml`; activated in `flow.R` Phase 5. Detailed log: `ai/memory/log/2026-02-23-forecast-lane-5.md`.

---

## 4-train-IS.R: Train Lane 4

Implemented `manipulation/4-train-IS.R` — estimates two model tiers on Mint forge artifacts and persists fitted objects for the Forecast lane. **Tier 1**: `snaive()` (seasonal naive, repeats last year's pattern). **Tier 2**: `auto.arima()` with `stepwise = FALSE, approximation = FALSE` (exhaustive search). Both models are fitted twice: once on `ts_train` for backtest evaluation, once on `ts_full` for Forecast lane persistence. All metrics (RMSE, MAE, MAPE) computed on original caseload scale after `exp()` back-transform per [EDA-001]. **Backtest results** (24-month hold-out): snaive RMSE 10,300 / MAPE 16.4%; ARIMA `(4,1,1)(1,0,0)[12]` RMSE 8,639 / MAPE 13.3% (ARIMA confirmed EDA-002's expected d=1). **Full-series ARIMA** order: `(3,1,1)(1,0,0)[12]`. Produces 3 artifacts in `./data-private/derived/models/`: `tier_1_snaive.rds`, `tier_2_arima.rds`, `model_registry.csv` (2-row hand-off contract for Lane 5). `forge_hash: 3ef1c81a04b78581f3df84e0a68f1504` stamped in registry for Mint–Train lineage. Activated in `flow.R`. Detailed log: `ai/memory/log/2026-02-23-train-lane-4.md`.

---

# 2026-02-20

## 6-pattern pipeline architecture

Restructured the project pipeline from an informal Ferry → Ellis → EDA → Train → Forecast → Report sequence into a formal **6-pattern architecture**: Ferry (1) → Ellis (2) → Mint (3) → Train (4) → Forecast (5) → Report (6). Key changes: introduced **Mint pattern** as the model-ready data preparation stage between Ellis and Train; redefined **EDA as advisory** (not a numbered lane — informs Mint but produces no artifacts consumed by downstream scripts); established **Mint-Train-Forecast lineage** as a versioned chain keyed by `focal_date`. Updated 10 files: glossary.md, method.md, mission.md, flow.R, config.yml, manipulation/README.md, manipulation/pipeline.md, analysis/eda-2/README.md, ai/personas/data-engineer.md, .vscode/tasks.json. Added `focal_date`, `backtest_months`, `forge`/`models` paths to config.yml. The `.github/copilot-instructions.md` auto-regenerates on next persona activation.

## 3-mint-IS.R: Mint Lane 3

Implemented `manipulation/3-mint-IS.R` — the single unified Mint lane producing all model-ready artifacts for all four Train tiers. Architecture decision: one-mint-serves-all (prevents artifact drift, single `forge_hash`). All data artifacts stored as **Apache Parquet** (cross-language: R/Python/Azure ML); fitted model objects remain `.rds` in Train lane. `ts` objects are built in-memory for validation but not persisted — Train lane reconstructs them from `ds_*.parquet`. Produces 12 forge artifacts: `ds_train/test/full.parquet`, `xreg_train/test/full/future.parquet`, `xreg_dynamic_*.parquet` (0-row placeholder for Tier 4), `forge_manifest.yml`. Activated in `flow.R`. Validated via `manipulation/nonflow/inspect-forge.R`. forge_hash: `ce3566ba5bd711426c9a4519f000d601` (focal_date 2025-09-01). Updated docs: method.md, glossary.md, analysis/eda-2/README.md.

---

# 2026-02-18


## test-ellis-cache

Created `manipulation/nonflow/test-ellis-cache.R` — a three-way alignment test verifying that the Ellis script (`2-ellis.R`), the artifacts it produces (Parquet + SQLite), and the CACHE-manifest (`data-public/metadata/CACHE-manifest.md`) all agree. Contains 229 assertions across 13 sections: artifact existence, SQLite↔Parquet parity, row counts, column schemas, temporal coverage, historical phase boundaries, wide↔long equivalence, data quality claims, manifest self-consistency, and script↔manifest agreement. Uses a custom `run_test(name, expr)` helper that tracks pass/fail/skip counts and exits with code 1 on any failure. Run via VS Code task "Test Ellis ↔ CACHE-Manifest Alignment" or `Rscript manipulation/nonflow/test-ellis-cache.R`. **When to use**: after modifying `2-ellis.R`, updating `CACHE-manifest.md`, or before any analysis that depends on the Ellis cache — ensures the manifest analysts rely on describes reality.

## eda-2

Created `analysis/eda-2/` directory with time series analysis of Alberta Income Support caseload data. Includes `eda-2.R` (analysis script with 6 visualizations), `eda-2.qmd` (Quarto report), and `README.md`. **Data genealogy**: loads parquet files as ds0_total (total caseload 2005-2025) and ds0_client_type (client type breakdowns 2012-2025), transforms to ds1_total and ds1_client_type in tweak-data-1 chunk with date formatting. **Visualizations**: g1 (20-year time series), g2 (historical period comparison), g3 (stacked area by client type), g4 (faceted client type trends), g5 (year-over-year overlay 2020-2025), g6 (YoY growth rate). Follows eda-1 template pattern: chunk-based Quarto integration, httpgd support, automatic prints folder creation, data transformation tracking (ds0 → ds1 naming convention). **Key insight**: Each client type exhibits distinct volatility patterns justifying separate forecasting models. Render with VS Code task "Render EDA-2 Quarto Report" or `quarto render analysis/eda-2/eda-2.qmd`.

## 2-ellis



## 1-ferry 

Created manipulation/1-ferry.R implementing multi-source ferry pattern: validates data can be loaded identically from 4 sources (URL, CSV, SQLite, SQL Server) and writes to staging database. Added to flow.R as first pipeline script. Created manipulation/pipeline.md documenting distinction between Non-Flow Scripts (one-time setup like create-data-assets.R) and Flow Scripts (reproducible pipeline steps). Configured logging to data-private/logs/YYYY/YYYY-MM/ following RAnalysisSkeleton pattern. Created VS Code task "Run Pipeline (flow.R)" using Rscript for consistent execution. Fixed flow.R config handling to provide fallback when path_log_flow undefined in config.yml.

---

# 2025-11-08

System successfully updated to use config-driven memory paths 

---

# 2025-11-08

Removed all hardcoded paths - memory system now fully configuration-driven using config.yml and ai-support-config.yml with intelligent fallbacks 

---

# 2025-11-08

Created comprehensive AI configuration system: ai-config-utils.R provides unified config reading for all AI scripts. Supports config.yml, ai-support-config.yml, and intelligent fallbacks. All hardcoded paths now configurable. 

---

# 2025-11-08

Refactored ai-memory-functions.R: Removed redundant inline config reader, removed unused export_memory_logic() and context_refresh() functions, improved quick_intent_scan() with directory exclusions (.git, node_modules, data-private) and file size limits, standardized error handling patterns across all functions, removed all emojis from R script output (keeping ASCII-only for cross-platform compatibility), updated initialization message. Script now cleaner, more efficient, and follows project standards. 

---

# 2025-11-11

Major refactoring complete: Split monolithic ai_memory_check() into focused single-purpose functions (check_memory_system, show_memory_help). Simplified detect_memory_system() by removing unused return values. Streamlined memory_status() removing redundant calls and persona checking. Removed system_type parameter from initialize_memory_system(). Result: 377 lines reduced to 312 lines (17% reduction), cleaner architecture, better separation of concerns. 
