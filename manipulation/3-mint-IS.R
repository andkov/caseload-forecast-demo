#' ---
#' title: "Mint Lane 3: Income Support Model-Ready Data Preparation"
#' author: "GoA Analytics Team"
#' date: "2026-02-20"
#' ---
#'
#' ============================================================================
#' MINT PATTERN: Transform Ellis Output into Model-Ready Artifacts
#' ============================================================================
#'
#' **Purpose**: Prepare unified set of time series objects and exogenous
#'   regressor matrices consumed by ALL model tiers in Train lane.
#'
#' **Input**:
#'   - ./data-private/derived/open-data-is-2-tables/total_caseload.parquet
#'   - ./data-private/derived/open-data-is-2-tables/client_type_wide.parquet
#'   - config.yml (focal_date, backtest_months, transform flags)
#'   - EDA-confirmed analytical decisions (see EDA Decision Log below)
#'
#' **Output** (all saved to ./data-private/derived/forge/):
#'   - ds_train.parquet          : Data frame slice, train  (Tiers 1-4 reconstruct ts from this)
#'   - ds_test.parquet           : Data frame slice, test   (date, year, month, ..., caseload, y)
#'   - ds_full.parquet           : Data frame slice, full   (for forward projection)
#'   - xreg_train.parquet        : Client-type proportions, train slice  (date + prop_* cols) (Tier 3 subgroup context)
#'   - xreg_test.parquet         : Client-type proportions, test slice   (Tier 3)
#'   - xreg_full.parquet         : Client-type proportions, full series  (Tier 3)
#'   - xreg_future.parquet       : Client-type proportions, forecast horizon (Tier 3)
#'   - xreg_dynamic_train.parquet: Tier 4 placeholder — 0-row schema
#'   - xreg_dynamic_test.parquet : Tier 4 placeholder — 0-row schema
#'   - xreg_dynamic_full.parquet : Tier 4 placeholder — 0-row schema
#'   - xreg_dynamic_future.parquet: Tier 4 placeholder — 0-row schema
#'   - forge_manifest.yml        : Data contract documenting all decisions (YAML)
#'
#' NOTE: ts objects (ts_train, ts_test, ts_full) are NOT persisted.
#'   Train lane reconstructs them from ds_*.parquet with:
#'     ts(ds_train$y, start=c(year(min(date)), month(min(date))), frequency=12)
#'
#' **Forbidden**: Model fitting, new data sourcing, re-running Ellis logic
#'
#' **EDA Decision Log** (codified from analysis/eda-2/):
#'   [EDA-001] Log transform: TRUE — confirmed by eda-2 g12 variance stabilization
#'   [EDA-002] Differencing: d=1 expected — confirmed by eda-2 g8 stationarity tests
#'   [EDA-003] Seasonal period: 12 — monthly data, fiscal year cycle
#'   [EDA-004] 24-month backtest window — confirmed by eda-2 g7 split visualization
#'   [EDA-005] Wide prediction intervals expected — eda-2 g11 decomposition
#'
#' **Model Tier Consumption** (Train lane loads from forge/ and reconstructs ts):
#'   Tier 1 (Naive):              ds_train, ds_test  → reconstruct ts_train, ts_test
#'   Tier 2 (ARIMA):              ds_train, ds_test, ds_full  → ts_train, ts_test, ts_full
#'   Tier 3 (Subgroup disaggr.):  per-client-type series from client_type_wide + xreg context
#'   Tier 4 (ARIMA + dynamic):    same + xreg_dynamic_* (0-row placeholder — skip if empty)
#'
#' ============================================================================

#+ echo=F
# rmarkdown::render(input = "./manipulation/3-mint-IS.R") # run to knit
# ---- setup -------------------------------------------------------------------
rm(list = ls(all.names = TRUE))
cat("\014")

script_start <- Sys.time()

# ---- load-packages -----------------------------------------------------------
library(magrittr)
library(dplyr)
library(lubridate)
requireNamespace("arrow")
requireNamespace("checkmate")
requireNamespace("yaml")
requireNamespace("digest")
requireNamespace("config")

# ---- load-sources ------------------------------------------------------------
base::source("./scripts/common-functions.R")

# ---- declare-globals ---------------------------------------------------------
config <- config::get()

# Forecasting parameters
focal_date       <- as.Date(config$focal_date)
backtest_months  <- config$backtest_months
use_log          <- config$use_log_transform
seasonal_period  <- config$seasonal_period
forecast_horizon <- config$forecast_horizon
random_seed      <- config$random_seed

# Reproducibility
set.seed(random_seed)

# Paths - Input (Ellis output)
path_total    <- "./data-private/derived/open-data-is-2-tables/total_caseload.parquet"
path_client   <- "./data-private/derived/open-data-is-2-tables/client_type_wide.parquet"

# Paths - Output (Forge directory)
dir_forge <- config$directories$forge
if (!dir.exists(dir_forge)) dir.create(dir_forge, recursive = TRUE, showWarnings = FALSE)

# Derived temporal boundaries
split_date <- focal_date %m-% months(backtest_months) # lubridate arithmetic
cat("\n", strrep("=", 70), "\n")
cat("MINT LANE 3: MODEL-READY DATA PREPARATION\n")
cat(strrep("=", 70), "\n")
cat("  focal_date:      ", as.character(focal_date), "\n")
cat("  backtest_months: ", backtest_months, "\n")
cat("  split_date:      ", as.character(split_date), "\n")
cat("  log_transform:   ", use_log, "\n")
cat("  seasonal_period: ", seasonal_period, "\n")
cat("  forecast_horizon:", forecast_horizon, "\n")
cat("  random_seed:     ", random_seed, "\n")
cat("  output_dir:      ", dir_forge, "\n")
cat(strrep("=", 70), "\n")

# ==============================================================================
# SECTION 1: IMPORT & VALIDATE ELLIS OUTPUT
# ==============================================================================

# ---- load-data ---------------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 1: IMPORT & VALIDATE ELLIS OUTPUT\n")
cat(strrep("=", 70), "\n")

# -- 1a. Total caseload (primary target series) --
checkmate::assert_file_exists(path_total, extension = "parquet")
ds_total <- arrow::read_parquet(path_total)
cat("\n  Total caseload loaded:", nrow(ds_total), "rows,", ncol(ds_total), "columns\n")

# -- 1b. Client type wide (for Tier 3 subgroup disaggregation) --
checkmate::assert_file_exists(path_client, extension = "parquet")
ds_client <- arrow::read_parquet(path_client)
cat("  Client type loaded:  ", nrow(ds_client), "rows,", ncol(ds_client), "columns\n")

# ---- validate-data -----------------------------------------------------------
cat("\n  Validating total_caseload...\n")

# Structure assertions
checkmate::assert_data_frame(ds_total, min.rows = 200, max.rows = 300)
checkmate::assert_names(names(ds_total),
                        must.include = c("date", "year", "month", "fiscal_year",
                                         "month_label", "caseload"))
# Type assertions
checkmate::assert_date(ds_total$date, any.missing = FALSE)
checkmate::assert_integer(as.integer(ds_total$year), lower = 2005, upper = 2030)
checkmate::assert_integer(as.integer(ds_total$month), lower = 1, upper = 12)
checkmate::assert_numeric(ds_total$caseload, lower = 0, any.missing = FALSE)

# Temporal completeness: no gaps in monthly sequence
expected_dates <- seq.Date(min(ds_total$date), max(ds_total$date), by = "month")
missing_dates  <- setdiff(as.character(expected_dates), as.character(ds_total$date))
if (length(missing_dates) > 0) {
  stop("Temporal gaps detected in total_caseload: ", paste(missing_dates, collapse = ", "))
}

# Confirm focal_date is within data range
checkmate::assert_true(focal_date <= max(ds_total$date),
                       .var.name = "focal_date within data range")
checkmate::assert_true(focal_date >= min(ds_total$date),
                       .var.name = "focal_date after data start")

cat("    date:         valid Date, no missing, range",
    as.character(min(ds_total$date)), "to", as.character(max(ds_total$date)), "\n")
cat("    caseload:     numeric, positive, no missing\n")
cat("    temporal:     no gaps in monthly sequence\n")
cat("    focal_date:   within data range\n")
cat("  Validating client_type_wide...\n")

# Client type structure
checkmate::assert_data_frame(ds_client, min.rows = 100)
checkmate::assert_names(names(ds_client),
                        must.include = c("date", "etw_working", "etw_available_for_work",
                                         "etw_unavailable_for_work", "bfe"))
cat("    columns:      date + 4 ETW/BFE categories present\n")

cat("\n  All validation checks passed\n")

# ==============================================================================
# SECTION 2: TRAIN / TEST / FULL SPLIT
# ==============================================================================

# ---- split-data --------------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 2: TRAIN / TEST / FULL SPLIT\n")
cat(strrep("=", 70), "\n")

# Total caseload splits
# Train: all data up to and including split_date
# Test:  data after split_date through focal_date
# Full:  all data through focal_date (for forward projection after training)
ds_train <- ds_total %>% filter(date <= split_date)
ds_test  <- ds_total %>% filter(date > split_date & date <= focal_date)
ds_full  <- ds_total %>% filter(date <= focal_date)

# Validate splits
n_train <- nrow(ds_train)
n_test  <- nrow(ds_test)
n_full  <- nrow(ds_full)

checkmate::assert_true(n_train + n_test == n_full,
                       .var.name = "train + test == full")
checkmate::assert_true(n_test == backtest_months,
                       .var.name = paste0("test set == ", backtest_months, " months"))
checkmate::assert_true(max(ds_train$date) == split_date,
                       .var.name = "train ends at split_date")
checkmate::assert_true(min(ds_test$date) == split_date %m+% months(1),
                       .var.name = "test starts month after split_date")

cat("\n  Training set: ", n_train, " months (",
    as.character(min(ds_train$date)), " to ", as.character(max(ds_train$date)), ")\n", sep = "")
cat("  Test set:     ", n_test, " months (",
    as.character(min(ds_test$date)), " to ", as.character(max(ds_test$date)), ")\n", sep = "")
cat("  Full set:     ", n_full, " months (",
    as.character(min(ds_full$date)), " to ", as.character(max(ds_full$date)), ")\n", sep = "")

# ==============================================================================
# SECTION 3: VARIANCE STABILIZATION
# ==============================================================================

# ---- transform-data ----------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 3: VARIANCE STABILIZATION\n")
cat(strrep("=", 70), "\n")

# [EDA-001] Log transform: confirmed by eda-2 g12 variance stabilization
# Log transformation stabilizes variance across the 20-year series where
# caseload levels have changed substantially (high-variance periods: 2005-2010
# vs lower-variance recent years).

if (use_log) {
  # Safety: verify all values are strictly positive before log transform
  checkmate::assert_numeric(ds_train$caseload, lower = 0.1,
                            .var.name = "caseload positive for log transform")
  checkmate::assert_numeric(ds_test$caseload, lower = 0.1,
                            .var.name = "caseload positive for log transform")

  ds_train <- ds_train %>% mutate(y = log(caseload))
  ds_test  <- ds_test  %>% mutate(y = log(caseload))
  ds_full  <- ds_full  %>% mutate(y = log(caseload))

  transform_label <- "log"
  cat("\n  Applied log transformation (EDA-001)\n")
  cat("  Train y range: [", round(min(ds_train$y), 4), ",",
      round(max(ds_train$y), 4), "]\n")
  cat("  Test  y range: [", round(min(ds_test$y), 4), ",",
      round(max(ds_test$y), 4), "]\n")
} else {
  ds_train <- ds_train %>% mutate(y = caseload)
  ds_test  <- ds_test  %>% mutate(y = caseload)
  ds_full  <- ds_full  %>% mutate(y = caseload)

  transform_label <- "identity"
  cat("\n  No transformation applied (identity)\n")
}

# ==============================================================================
# SECTION 4: CONSTRUCT TIME SERIES OBJECTS (Tiers 1-4)
# ==============================================================================

# ---- build-ts ----------------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 4: CONSTRUCT TIME SERIES OBJECTS\n")
cat(strrep("=", 70), "\n")

# [EDA-003] Seasonal period = 12 (monthly data, annual cycle)
# These ts objects are the core artifacts consumed by ALL model tiers.

# Helper: extract ts start from a data frame with date column
ts_start <- function(df) {
  c(year(min(df$date)), month(min(df$date)))
}

ts_train <- ts(ds_train$y, start = ts_start(ds_train), frequency = seasonal_period)
ts_test  <- ts(ds_test$y,  start = ts_start(ds_test),  frequency = seasonal_period)
ts_full  <- ts(ds_full$y,  start = ts_start(ds_full),  frequency = seasonal_period)

# Validate ts objects (in-memory only — NOT persisted to disk)
# Train lane reconstructs from ds_*.parquet using:
#   ts(ds_train$y, start=c(year(min(date)), month(min(date))), frequency=12)
checkmate::assert_class(ts_train, "ts")
checkmate::assert_class(ts_test,  "ts")
checkmate::assert_class(ts_full,  "ts")
checkmate::assert_true(frequency(ts_train) == seasonal_period)
checkmate::assert_true(length(ts_train) == n_train)
checkmate::assert_true(length(ts_test)  == n_test)
checkmate::assert_true(length(ts_full)  == n_full)

cat("\n  ts_train: ", length(ts_train), " obs, frequency ",
    frequency(ts_train), ", start (", paste(start(ts_train), collapse = ", "),
    "), end (", paste(end(ts_train), collapse = ", "), ")\n", sep = "")
cat("  ts_test:  ", length(ts_test), " obs, frequency ",
    frequency(ts_test), ", start (", paste(start(ts_test), collapse = ", "),
    "), end (", paste(end(ts_test), collapse = ", "), ")\n", sep = "")
cat("  ts_full:  ", length(ts_full), " obs, frequency ",
    frequency(ts_full), ", start (", paste(start(ts_full), collapse = ", "),
    "), end (", paste(end(ts_full), collapse = ", "), ")\n", sep = "")
cat("  (ts objects are in-memory validation only — persisted as ds_*.parquet)\n")

# ==============================================================================
# SECTION 5: BUILD CLIENT-TYPE PROPORTION MATRICES (Tier 3 subgroup context)
# ==============================================================================

# ---- build-xreg-static ------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 5: CLIENT-TYPE PROPORTION MATRICES (Tier 3 subgroup context)\n")
cat(strrep("=", 70), "\n")

# Tier 3: Subgroup disaggregation
# Client-type proportions provide context for per-subgroup forecasting.
# Client type data available Apr 2012 onward (162 months); for months before
# Apr 2012, we carry back the earliest available proportions.

# Calculate proportions from wide-format client type table
ds_client_prop <- ds_client %>%
  filter(date <= focal_date) %>%
  mutate(
    total = etw_working + etw_available_for_work +
            etw_unavailable_for_work + bfe,
    # Proportions (handle NA from suppression gracefully)
    prop_etw_working     = etw_working / total,
    prop_etw_available   = etw_available_for_work / total,
    prop_etw_unavailable = etw_unavailable_for_work / total
    # Note: prop_bfe is the complement (1 - sum of others), excluded to avoid
    # collinearity in regression. Train lane can add intercept if needed.
  ) %>%
  select(date, prop_etw_working, prop_etw_available, prop_etw_unavailable)

# Earliest available proportions for back-fill (Phase 1 months: Apr 2005 - Mar 2012)
earliest_props <- ds_client_prop %>%
  filter(date == min(date)) %>%
  select(-date)

cat("\n  Client type proportions computed from", nrow(ds_client_prop), "months\n")
cat("  Earliest proportions (for back-fill):\n")
cat("    prop_etw_working:    ", round(earliest_props$prop_etw_working, 4), "\n")
cat("    prop_etw_available:  ", round(earliest_props$prop_etw_available, 4), "\n")
cat("    prop_etw_unavailable:", round(earliest_props$prop_etw_unavailable, 4), "\n")

# Build full-length regressor table aligned with ds_full
xreg_df <- ds_full %>%
  select(date) %>%
  left_join(ds_client_prop, by = "date")

# Back-fill pre-April-2012 months with earliest proportions
xreg_df <- xreg_df %>%
  mutate(
    prop_etw_working     = ifelse(is.na(prop_etw_working),
                                  earliest_props$prop_etw_working, prop_etw_working),
    prop_etw_available   = ifelse(is.na(prop_etw_available),
                                  earliest_props$prop_etw_available, prop_etw_available),
    prop_etw_unavailable = ifelse(is.na(prop_etw_unavailable),
                                  earliest_props$prop_etw_unavailable, prop_etw_unavailable)
  )

n_backfilled <- sum(is.na(ds_full$date %in% ds_client_prop$date))
cat("  Back-filled", sum(!(ds_full$date %in% ds_client_prop$date)),
    "months with earliest available proportions\n")

# Verify no NA remains after back-fill
checkmate::assert_numeric(xreg_df$prop_etw_working,     any.missing = FALSE)
checkmate::assert_numeric(xreg_df$prop_etw_available,    any.missing = FALSE)
checkmate::assert_numeric(xreg_df$prop_etw_unavailable,  any.missing = FALSE)

# Convert to matrices aligned with ts objects
xreg_cols <- c("prop_etw_working", "prop_etw_available", "prop_etw_unavailable")

# Split xreg to match train/test/full boundaries
xreg_full_df  <- xreg_df
xreg_train_df <- xreg_df %>% filter(date <= split_date)
xreg_test_df  <- xreg_df %>% filter(date > split_date & date <= focal_date)

xreg_train <- as.matrix(xreg_train_df[, xreg_cols])
xreg_test  <- as.matrix(xreg_test_df[, xreg_cols])
xreg_full  <- as.matrix(xreg_full_df[, xreg_cols])

# Validate dimensions match ts objects
checkmate::assert_true(nrow(xreg_train) == length(ts_train),
                       .var.name = "xreg_train rows == ts_train length")
checkmate::assert_true(nrow(xreg_test)  == length(ts_test),
                       .var.name = "xreg_test rows == ts_test length")
checkmate::assert_true(nrow(xreg_full)  == length(ts_full),
                       .var.name = "xreg_full rows == ts_full length")

cat("  xreg_train:", nrow(xreg_train), "x", ncol(xreg_train), "\n")
cat("  xreg_test: ", nrow(xreg_test),  "x", ncol(xreg_test), "\n")
cat("  xreg_full: ", nrow(xreg_full),  "x", ncol(xreg_full), "\n")

# ---- build-xreg-future ------------------------------------------------------
# For forecast horizon: carry forward the last known proportions
# (subgroup assumption: proportions held constant during forecast window)
last_props <- xreg_full_df %>%
  filter(date == max(date)) %>%
  select(all_of(xreg_cols))

xreg_future <- matrix(
  rep(as.numeric(last_props), each = forecast_horizon),
  nrow = forecast_horizon,
  ncol = length(xreg_cols)
)
colnames(xreg_future) <- xreg_cols

cat("  xreg_future:", nrow(xreg_future), "x", ncol(xreg_future),
    "(last proportions carried forward)\n")

# ==============================================================================
# SECTION 6: TIER 4 PLACEHOLDER (Dynamic Predictor)
# ==============================================================================

# ---- build-xreg-dynamic -----------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 6: TIER 4 PLACEHOLDER (Dynamic Predictor)\n")
cat(strrep("=", 70), "\n")

# Tier 4: ARIMA + time-varying predictor (economic indicator)
# Structure placeholder only — real covariate TBD in re-graft phase.
#
# When implemented, this section would:
# 1. Load external time series (e.g., Alberta unemployment rate from StatsCanada,
#    WTI oil prices from EIA/FRED API)
# 2. Align dates with ds_train/ds_test/ds_full using left_join on date
# 3. Handle missing values via interpolation (na.approx or seasonal fill)
# 4. Normalize/scale if needed for numerical stability
# 5. For forecast horizon: use external forecasts or carry-forward assumption
#
# For now, xreg_dynamic is NULL. Train lane Tier 4 checks for this and
# skips if NULL, logging that the placeholder was encountered.

xreg_dynamic_train  <- NULL
xreg_dynamic_test   <- NULL
xreg_dynamic_full   <- NULL
xreg_dynamic_future <- NULL

cat("\n  Tier 4 xreg_dynamic: NULL (placeholder — awaiting external economic data)\n")
cat("  Future candidates: Alberta unemployment rate, WTI oil price, housing starts\n")

# ==============================================================================
# SECTION 7: GENERATE FORGE MANIFEST
# ==============================================================================

# ---- forge-manifest ----------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 7: FORGE MANIFEST\n")
cat(strrep("=", 70), "\n")

forge_manifest <- list(
  mint_execution = list(
    script         = "manipulation/3-mint-IS.R",
    executed_at    = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    r_version      = paste(R.version$major, R.version$minor, sep = "."),
    focal_date     = as.character(focal_date),
    split_date     = as.character(split_date),
    backtest_months = backtest_months,
    forecast_horizon = forecast_horizon,
    random_seed    = random_seed
  ),

  transform_decisions = list(
    log_transform       = use_log,
    transform_label     = transform_label,
    seasonal_period     = seasonal_period,
    expected_differencing = 1L   # [EDA-002] confirmed by eda-2 g8
  ),

  data_slices = list(
    train = list(
      start_date = as.character(min(ds_train$date)),
      end_date   = as.character(max(ds_train$date)),
      n_months   = n_train
    ),
    test = list(
      start_date = as.character(min(ds_test$date)),
      end_date   = as.character(max(ds_test$date)),
      n_months   = n_test
    ),
    full = list(
      start_date = as.character(min(ds_full$date)),
      end_date   = as.character(max(ds_full$date)),
      n_months   = n_full
    )
  ),

  xreg_static = list(
    columns         = xreg_cols,
    source_table    = "client_type_wide.parquet",
    backfill_method = "earliest available proportions carried backward",
    future_method   = "last known proportions carried forward",
    n_backfilled_months = sum(!(ds_full$date %in% ds_client_prop$date))
  ),

  xreg_dynamic = list(
    status    = "placeholder",
    columns   = NULL,
    rationale = "Awaiting external economic data (unemployment, oil price)"
  ),

  artifacts = list(
    "ds_train.parquet",
    "ds_test.parquet",
    "ds_full.parquet",
    "xreg_train.parquet",
    "xreg_test.parquet",
    "xreg_full.parquet",
    "xreg_future.parquet",
    "xreg_dynamic_train.parquet",
    "xreg_dynamic_test.parquet",
    "xreg_dynamic_full.parquet",
    "xreg_dynamic_future.parquet",
    "forge_manifest.yml"
  ),

  eda_decisions = list(
    list(id = "EDA-001", decision = "Use log transformation",
         rationale = "eda-2 g12 confirms variance stabilization"),
    list(id = "EDA-002", decision = "Expect d=1 differencing",
         rationale = "eda-2 g8 stationarity tests"),
    list(id = "EDA-003", decision = "Seasonal period = 12",
         rationale = "Monthly data, fiscal year cycle"),
    list(id = "EDA-004", decision = "24-month backtest window",
         rationale = "eda-2 g7 split visualization"),
    list(id = "EDA-005", decision = "Wide prediction intervals expected",
         rationale = "eda-2 g11 decomposition shows large irregular component")
  )
)

# Compute forge hash from manifest content (used by Train for lineage)
forge_hash <- digest::digest(forge_manifest, algo = "md5")
forge_manifest$forge_hash <- forge_hash

cat("\n  forge_hash:", forge_hash, "\n")

# ==============================================================================
# SECTION 8: SAVE ARTIFACTS
# ==============================================================================

# ---- save-artifacts ----------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 8: SAVE ARTIFACTS\n")
cat(strrep("=", 70), "\n")

# Strategy: All forge data artifacts saved as Apache Parquet for cross-language
# compatibility (R, Python, Azure ML). Only forge_manifest.yml stays YAML.
# ts objects are NOT persisted — Train lane reconstructs from ds_*.parquet.

# Data frame slices (primary source — Train lane reconstructs ts from these)
# Each parquet contains: date, year, month, fiscal_year, month_label, caseload, y
arrow::write_parquet(ds_train, file.path(dir_forge, "ds_train.parquet"))
arrow::write_parquet(ds_test,  file.path(dir_forge, "ds_test.parquet"))
arrow::write_parquet(ds_full,  file.path(dir_forge, "ds_full.parquet"))

# Client-type proportion tables (Tier 3 — subgroup disaggregation context)
# Include date column for alignment verification; Train lane strips it before fitting
arrow::write_parquet(
  xreg_train_df[, c("date", xreg_cols)],
  file.path(dir_forge, "xreg_train.parquet")
)
arrow::write_parquet(
  xreg_test_df[, c("date", xreg_cols)],
  file.path(dir_forge, "xreg_test.parquet")
)
arrow::write_parquet(
  xreg_full_df[, c("date", xreg_cols)],
  file.path(dir_forge, "xreg_full.parquet")
)

# xreg_future: create date column for forecast horizon months after focal_date
future_dates   <- seq(focal_date %m+% months(1), by = "month", length.out = forecast_horizon)
xreg_future_df <- dplyr::bind_cols(
  data.frame(date = future_dates),
  as.data.frame(xreg_future)
)
arrow::write_parquet(xreg_future_df, file.path(dir_forge, "xreg_future.parquet"))

# Dynamic regressor placeholders (Tier 4) — 0-row parquet with schema
# Train lane: if nrow(xreg_dynamic_train) == 0 → skip Tier 4 with logged message
xreg_dynamic_schema <- data.frame(
  date              = as.Date(character(0)),
  dynamic_predictor = numeric(0)
)
arrow::write_parquet(xreg_dynamic_schema, file.path(dir_forge, "xreg_dynamic_train.parquet"))
arrow::write_parquet(xreg_dynamic_schema, file.path(dir_forge, "xreg_dynamic_test.parquet"))
arrow::write_parquet(xreg_dynamic_schema, file.path(dir_forge, "xreg_dynamic_full.parquet"))
arrow::write_parquet(xreg_dynamic_schema, file.path(dir_forge, "xreg_dynamic_future.parquet"))

# Forge manifest (YAML — data contract for Train lane, not a data artifact)
yaml::write_yaml(forge_manifest, file.path(dir_forge, "forge_manifest.yml"))

# ---- verify-artifacts --------------------------------------------------------
# Quick round-trip: re-load ds_train.parquet and verify y column integrity
ds_train_check <- arrow::read_parquet(file.path(dir_forge, "ds_train.parquet"))
checkmate::assert_true(
  all(abs(ds_train_check$y - ds_train$y) < 1e-10),
  .var.name = "ds_train parquet round-trip integrity"
)

# List all saved files with sizes
forge_files <- list.files(dir_forge, full.names = TRUE)
file_info <- file.info(forge_files)
artifact_summary <- data.frame(
  file = basename(forge_files),
  size_kb = round(file_info$size / 1024, 1),
  stringsAsFactors = FALSE
)

cat("\n  Artifacts saved to:", dir_forge, "\n\n")
cat("  ", sprintf("%-30s %8s", "File", "Size (KB)"), "\n")
cat("  ", strrep("-", 40), "\n")
for (i in seq_len(nrow(artifact_summary))) {
  cat("  ", sprintf("%-30s %8.1f", artifact_summary$file[i],
                    artifact_summary$size_kb[i]), "\n")
}
cat("  ", strrep("-", 40), "\n")
cat("  ", sprintf("%-30s %8.1f", "TOTAL",
                  sum(artifact_summary$size_kb)), "\n")

# ==============================================================================
# SECTION 9: SESSION INFO
# ==============================================================================

# ---- session-info ------------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SESSION INFO\n")
cat(strrep("=", 70), "\n")

duration <- difftime(Sys.time(), script_start, units = "secs")
cat("\n  Mint completed in", round(as.numeric(duration), 1), "seconds\n")
cat("  Executed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("  User:", Sys.info()["user"], "\n")
cat("  Artifact Summary (all parquet except manifest):\n")
cat("    data frames:     3 parquet (ds_train/test/full — ts reconstructed from these)\n")
cat("    xreg static:     4 parquet (xreg_train/test/full/future — date + prop_* cols)\n")
cat("    xreg dynamic:    4 parquet (0-row placeholder schema for Tier 4)\n")
cat("    manifest:        1 YAML   (forge_manifest.yml)\n")
cat("    forge_hash:     ", forge_hash, "\n")
cat("\n  Ready for Train lane (4-train-IS.R)\n")

sessionInfo()
