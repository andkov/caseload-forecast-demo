#' ---
#' title: "Train Lane 4: Income Support Model Estimation"
#' author: "GoA Analytics Team"
#' date: "2026-02-23"
#' ---
#'
#' ============================================================================
#' TRAIN PATTERN: Estimate Model Tiers on Mint Artifacts
#' ============================================================================
#'
#' **Purpose**: Fit two model tiers on Mint-prepared time series data,
#'   evaluate backtest accuracy on the held-out 24-month test window,
#'   and persist fitted model objects for consumption by the Forecast lane.
#'
#' **Input** (all from ./data-private/derived/forge/):
#'   - ds_train.parquet       : Training slice (Apr 2005 – Sep 2023, 222 months)
#'   - ds_test.parquet        : Test slice     (Oct 2023 – Sep 2025,  24 months)
#'   - ds_full.parquet        : Full series    (Apr 2005 – Sep 2025, 246 months)
#'   - forge_manifest.yml     : Data contract (focal_date, transform flags, forge_hash)
#'   - config.yml             : Project configuration
#'
#' **Output** (all saved to ./data-private/derived/models/):
#'   - tier_1_snaive.rds      : Seasonal naive model fitted on full series
#'   - tier_2_arima.rds       : ARIMA model fitted on full series (auto-selected order)
#'   - model_registry.csv     : Metadata, metrics, and rds paths for all fitted tiers
#'
#' **Forbidden**: Reading Ellis output directly, generating forward forecasts
#'   (forward projection is Lane 5's responsibility), model refitting in Forecast lane
#'
#' **EDA Decision Traceability** (codified upstream in 3-mint-IS.R):
#'   [EDA-001] Log transform: TRUE — y = log(caseload); back-transform via exp()
#'             for human-interpretable metrics on original caseload scale
#'   [EDA-002] Differencing: d=1 expected — auto.arima() will confirm or override
#'   [EDA-003] Seasonal period: 12 — monthly data, fiscal year cycle
#'   [EDA-004] 24-month backtest window — test slice is Oct 2023 – Sep 2025
#'   [EDA-005] Wide prediction intervals expected — STL decomposition showed
#'             substantial residual variance
#'
#' **Model Tiers Implemented**:
#'   Tier 1 (Naive baseline): snaive() — seasonal naive; repeats last year's
#'             monthly pattern. Stronger benchmark than random-walk naive for
#'             monthly data with clear fiscal year seasonality.
#'   Tier 2 (ARIMA): auto.arima() on log-transformed series (y column). Auto-
#'             selects (p,d,q)(P,D,Q)[12] orders; EDA-002 expects d=1.
#'   Tier 3 (Subgroup disaggregation): Not implemented in this lane (deferred).
#'   Tier 4 (ARIMA + dynamic xreg): Not implemented — xreg_dynamic placeholder
#'             is 0-row in current Mint artifacts.
#'
#' **Forecast Lane Hand-off (5-forecast-IS.R)**:
#'   - Load model_registry.csv to discover available models
#'   - For each row: readRDS(rds_path) -> forecast(model, h = 24)
#'   - All .rds models are fitted on ts_full (Oct 2025 onward is genuine horizon)
#'   - forge_hash links every model back to exact Mint input for invalidation logic
#'
#' ============================================================================

#+ echo=F
# rmarkdown::render(input = "./manipulation/4-train-IS.R") # run to knit

# ---- setup -------------------------------------------------------------------
rm(list = ls(all.names = TRUE))
cat("\014")

script_start <- Sys.time()

# ---- load-packages -----------------------------------------------------------
library(magrittr)
library(dplyr)
library(lubridate)
library(forecast)   # snaive(), auto.arima(), forecast()
requireNamespace("arrow")
requireNamespace("checkmate")
requireNamespace("yaml")
requireNamespace("config")

# ---- load-sources ------------------------------------------------------------
base::source("./scripts/common-functions.R")

# ---- declare-globals ---------------------------------------------------------
config    <- config::get()

dir_forge  <- config$directories$forge
dir_models <- config$directories$models

random_seed      <- config$random_seed
forecast_horizon <- config$forecast_horizon
focal_date       <- as.Date(config$focal_date)

# Helper: reconstruct ts start from a data frame with a `date` column
ts_start_from <- function(df) {
  c(year(min(df$date)), month(min(df$date)))
}

# Helper: back-transform log-scale values to original caseload scale
# [EDA-001] Mint applied y = log(caseload); reverse with exp()
back_transform <- function(y_hat) {
  exp(y_hat)
}

# Helper: compute regression-style accuracy metrics on original caseload scale
# Returns a named numeric vector: rmse, mae, mape
compute_metrics <- function(actual, predicted) {
  residuals <- actual - predicted
  rmse <- sqrt(mean(residuals^2, na.rm = TRUE))
  mae  <- mean(abs(residuals),     na.rm = TRUE)
  mape <- mean(abs(residuals / actual) * 100, na.rm = TRUE)
  c(rmse = round(rmse, 1), mae = round(mae, 1), mape = round(mape, 3))
}

cat("\n", strrep("=", 70), "\n")
cat("TRAIN LANE 4: Income Support Model Estimation\n")
cat(strrep("=", 70), "\n")
cat("  focal_date       :", format(focal_date), "\n")
cat("  forecast_horizon :", forecast_horizon, "months\n")
cat("  random_seed      :", random_seed, "\n")
cat("  forge dir        :", dir_forge, "\n")
cat("  models dir       :", dir_models, "\n")
cat("  Executed         :", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")

# ==============================================================================
# SECTION 1: LOAD FORGE ARTIFACTS
# ==============================================================================

# ---- load-data ---------------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 1: Load Forge Artifacts\n")
cat(strrep("=", 70), "\n")

checkmate::assert_directory_exists(dir_forge, .var.name = "forge directory")

ds_train <- arrow::read_parquet(file.path(dir_forge, "ds_train.parquet"))
ds_test  <- arrow::read_parquet(file.path(dir_forge, "ds_test.parquet"))
ds_full  <- arrow::read_parquet(file.path(dir_forge, "ds_full.parquet"))

manifest_path <- file.path(dir_forge, "forge_manifest.yml")
checkmate::assert_file_exists(manifest_path, .var.name = "forge_manifest.yml")
forge_manifest <- yaml::read_yaml(manifest_path)
forge_hash     <- forge_manifest$forge_hash

cat("\n  Loaded from forge:\n")
cat("    ds_train  :", nrow(ds_train), "rows |",
    format(min(ds_train$date)), "to", format(max(ds_train$date)), "\n")
cat("    ds_test   :", nrow(ds_test),  "rows |",
    format(min(ds_test$date)),  "to", format(max(ds_test$date)),  "\n")
cat("    ds_full   :", nrow(ds_full),  "rows |",
    format(min(ds_full$date)),  "to", format(max(ds_full$date)),  "\n")
cat("    forge_hash:", forge_hash, "\n")

# Create models directory if it does not yet exist
dir.create(dir_models, recursive = TRUE, showWarnings = FALSE)
cat("  Models dir ready:", dir_models, "\n")

# ==============================================================================
# SECTION 2: RECONSTRUCT TIME SERIES OBJECTS
# ==============================================================================

# ---- reconstruct-ts ----------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 2: Reconstruct ts Objects from Parquet Slices\n")
cat(strrep("=", 70), "\n")

# Train lane reconstructs ts objects in-memory from ds_*.parquet$y
# (Mint intentionally does NOT persist ts objects — parquet is the on-disk format)
ts_train <- ts(ds_train$y, start = ts_start_from(ds_train), frequency = 12)
ts_test  <- ts(ds_test$y,  start = ts_start_from(ds_test),  frequency = 12)
ts_full  <- ts(ds_full$y,  start = ts_start_from(ds_full),  frequency = 12)

cat("\n  ts_train: length =", length(ts_train),
    "| start =", paste(start(ts_train), collapse = ","),
    "| end =", paste(end(ts_train), collapse = ","), "\n")
cat("  ts_test:  length =", length(ts_test),
    "| start =", paste(start(ts_test), collapse = ","),
    "| end =", paste(end(ts_test), collapse = ","), "\n")
cat("  ts_full:  length =", length(ts_full),
    "| start =", paste(start(ts_full), collapse = ","),
    "| end =", paste(end(ts_full), collapse = ","), "\n")
cat("  Contiguity (train + test == full):",
    length(ts_train) + length(ts_test) == length(ts_full), "\n")
cat("  Back-transform check: exp(first y) =",
    round(exp(ts_train[1]), 0), "(expected ~27,969)\n")

# ==============================================================================
# SECTION 3: VALIDATE DATA CONTRACT
# ==============================================================================

# ---- validate-data -----------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 3: Validate Against Forge Manifest Contract\n")
cat(strrep("=", 70), "\n")

# Length assertions against manifest
checkmate::assert_true(
  length(ts_train) == forge_manifest$data_slices$train$n_months,
  .var.name = "ts_train length vs forge_manifest$data_slices$train$n_months"
)
checkmate::assert_true(
  length(ts_test) == forge_manifest$data_slices$test$n_months,
  .var.name = "ts_test length vs forge_manifest$data_slices$test$n_months"
)
checkmate::assert_true(
  length(ts_full) == forge_manifest$data_slices$full$n_months,
  .var.name = "ts_full length vs forge_manifest$data_slices$full$n_months"
)

# [EDA-001] Confirm log transform flag is TRUE before assuming y = log(caseload)
checkmate::assert_true(
  isTRUE(forge_manifest$transform_decisions$log_transform),
  .var.name = "forge_manifest log_transform flag"
)

# Verify y == log(caseload) integrity in both slices
checkmate::assert_true(
  all(abs(ds_train$y - log(ds_train$caseload)) < 1e-10),
  .var.name = "ds_train y == log(caseload)"
)
checkmate::assert_true(
  all(abs(ds_test$y - log(ds_test$caseload)) < 1e-10),
  .var.name = "ds_test y == log(caseload)"
)

cat("  All assertions passed.\n")
cat("  Transform confirmed: y = log(caseload) [EDA-001]\n")
cat("  Seasonal period from manifest:",
    forge_manifest$transform_decisions$seasonal_period, "[EDA-003]\n")

# ==============================================================================
# SECTION 4: TIER 1 — SEASONAL NAIVE BASELINE
# ==============================================================================

# ---- tier-1-snaive -----------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 4: Tier 1 — Seasonal Naive Baseline (snaive)\n")
cat(strrep("=", 70), "\n")

set.seed(random_seed)

# --- 4a. Backtest fit (train slice only) -------------------------------------
# Forecast over the held-out test window to evaluate accuracy
fit_snaive_backtest <- snaive(ts_train, h = length(ts_test))

fc_snaive_backtest <- as.numeric(fit_snaive_backtest$mean)
actual_test_orig   <- back_transform(as.numeric(ts_test))
fc_snaive_orig     <- back_transform(fc_snaive_backtest)

metrics_snaive <- compute_metrics(actual_test_orig, fc_snaive_orig)

cat("\n  Backtest Results (24-month hold-out, original caseload scale):\n")
cat("    RMSE :", metrics_snaive["rmse"], "\n")
cat("    MAE  :", metrics_snaive["mae"],  "\n")
cat("    MAPE :", metrics_snaive["mape"], "%\n")

# --- 4b. Full-series refit (for Forecast lane persistence) -------------------
# Refit on ts_full so Forecast lane projects from Oct 2025 onward
set.seed(random_seed)
fit_snaive_full <- snaive(ts_full, h = forecast_horizon)

cat("\n  Tier 1 (snaive) full-series fit:\n")
cat("    Model         : snaive (seasonal naive, period = 12)\n")
cat("    Training data :", length(ts_full), "months (Apr 2005 – Sep 2025)\n")
cat("    AIC/BIC       : N/A (non-parametric)\n")
cat("    Forecast lane : call forecast(readRDS(rds_path), h =", forecast_horizon, ")\n")

# ==============================================================================
# SECTION 5: TIER 2 — AUTO ARIMA
# ==============================================================================

# ---- tier-2-arima ------------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 5: Tier 2 — Auto ARIMA\n")
cat(strrep("=", 70), "\n")

cat("  Fitting auto.arima() on ts_train (", length(ts_train), "months)...\n")
cat("  [EDA-002] Expecting d=1 differencing for stationarity\n")
cat("  [EDA-003] Seasonal period = 12 (auto.arima will search seasonal orders)\n")
cat("  This may take a few seconds ...\n")

set.seed(random_seed)

# --- 5a. Backtest fit (train slice only) -------------------------------------
fit_arima_backtest <- auto.arima(
  ts_train,
  stepwise   = FALSE,  # exhaustive search for best model
  approximation = FALSE
)

fc_arima_backtest <- forecast(fit_arima_backtest, h = length(ts_test))
fc_arima_orig     <- back_transform(as.numeric(fc_arima_backtest$mean))
metrics_arima     <- compute_metrics(actual_test_orig, fc_arima_orig)

arima_order_str <- paste0(
  "(", paste(arimaorder(fit_arima_backtest)[1:3], collapse = ","), ")",
  "(", paste(arimaorder(fit_arima_backtest)[4:6], collapse = ","), ")",
  "[", frequency(ts_train), "]"
)

cat("\n  ARIMA Order Selected  :", arima_order_str, "\n")
cat("  AIC                   :", round(fit_arima_backtest$aic,  2), "\n")
cat("  AICc                  :", round(fit_arima_backtest$aicc, 2), "\n")
cat("  BIC                   :", round(fit_arima_backtest$bic,  2), "\n")

cat("\n  Backtest Results (24-month hold-out, original caseload scale):\n")
cat("    RMSE :", metrics_arima["rmse"], "\n")
cat("    MAE  :", metrics_arima["mae"],  "\n")
cat("    MAPE :", metrics_arima["mape"], "%\n")

# --- 5b. Full-series refit (for Forecast lane persistence) -------------------
cat("\n  Refitting auto.arima() on ts_full (", length(ts_full), "months)...\n")
set.seed(random_seed)
fit_arima_full <- auto.arima(
  ts_full,
  stepwise      = FALSE,
  approximation = FALSE
)

arima_full_order_str <- paste0(
  "(", paste(arimaorder(fit_arima_full)[1:3], collapse = ","), ")",
  "(", paste(arimaorder(fit_arima_full)[4:6], collapse = ","), ")",
  "[", frequency(ts_full), "]"
)

cat("  Full-series ARIMA order:", arima_full_order_str, "\n")
cat("  AIC  :", round(fit_arima_full$aic,  2), "\n")
cat("  AICc :", round(fit_arima_full$aicc, 2), "\n")
cat("  BIC  :", round(fit_arima_full$bic,  2), "\n")
cat("  Forecast lane: call forecast(readRDS(rds_path), h =", forecast_horizon, ")\n")

# ==============================================================================
# SECTION 6: PERSIST MODEL OBJECTS
# ==============================================================================

# ---- save-models -------------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 6: Persist Model Objects (.rds)\n")
cat(strrep("=", 70), "\n")

# Both models are fitted on ts_full so that Forecast lane forecasts genuinely
# forward from the end of observed data (Sep 2025 → Oct 2025 onward)
path_snaive <- file.path(dir_models, "tier_1_snaive.rds")
path_arima  <- file.path(dir_models, "tier_2_arima.rds")

saveRDS(fit_snaive_full, file = path_snaive)
saveRDS(fit_arima_full,  file = path_arima)

cat("\n  Saved:\n")
cat("    ", path_snaive, "\n")
cat("    ", path_arima,  "\n")

# Round-trip verification: reload and run a 1-step forecast to confirm .rds integrity
fit_snaive_rt <- readRDS(path_snaive)
fit_arima_rt  <- readRDS(path_arima)

checkmate::assert_true(
  !is.null(forecast(fit_snaive_rt, h = 1)$mean),
  .var.name = "snaive round-trip forecast"
)
checkmate::assert_true(
  !is.null(forecast(fit_arima_rt, h = 1)$mean),
  .var.name = "arima round-trip forecast"
)

cat("  Round-trip verification: both .rds reload and forecast successfully.\n")

# ==============================================================================
# SECTION 7: MODEL REGISTRY
# ==============================================================================

# ---- model-registry ----------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 7: Build and Write Model Registry CSV\n")
cat(strrep("=", 70), "\n")

trained_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

model_registry <- data.frame(
  model_id = c("tier_1_snaive", "tier_2_arima"),
  tier     = c(1L, 2L),
  tier_label = c("Naive Baseline", "ARIMA"),
  model_description = c(
    "Seasonal naive: repeats last year's monthly pattern (frequency=12)",
    paste0("Auto ARIMA ", arima_full_order_str,
           ": auto-selected on log-transformed full series")
  ),
  rds_filename = c(
    basename(path_snaive),
    basename(path_arima)
  ),
  rds_path = c(path_snaive, path_arima),
  arima_order = c(NA_character_, arima_full_order_str),
  aic  = c(NA_real_, round(fit_arima_full$aic,  2)),
  aicc = c(NA_real_, round(fit_arima_full$aicc, 2)),
  bic  = c(NA_real_, round(fit_arima_full$bic,  2)),
  backtest_rmse = c(metrics_snaive["rmse"], metrics_arima["rmse"]),
  backtest_mae  = c(metrics_snaive["mae"],  metrics_arima["mae"]),
  backtest_mape = c(metrics_snaive["mape"], metrics_arima["mape"]),
  n_train      = rep(length(ts_train), 2),
  n_test       = rep(length(ts_test),  2),
  n_full       = rep(length(ts_full),  2),
  focal_date   = rep(as.character(focal_date), 2),
  forge_hash   = rep(forge_hash, 2),
  trained_at   = rep(trained_at, 2),
  stringsAsFactors = FALSE
)

path_registry <- file.path(dir_models, "model_registry.csv")
write.csv(model_registry, file = path_registry, row.names = FALSE)

cat("\n  Model Registry:\n\n")
# Print a readable summary (not the full wide CSV)
for (i in seq_len(nrow(model_registry))) {
  cat("  [", model_registry$model_id[i], "]\n")
  cat("    tier        :", model_registry$tier[i], "-", model_registry$tier_label[i], "\n")
  cat("    description :", model_registry$model_description[i], "\n")
  cat("    rds file    :", model_registry$rds_filename[i], "\n")
  if (!is.na(model_registry$arima_order[i])) {
    cat("    order       :", model_registry$arima_order[i], "\n")
    cat("    AICc        :", model_registry$aicc[i], "\n")
  }
  cat("    RMSE        :", model_registry$backtest_rmse[i], "(original scale)\n")
  cat("    MAE         :", model_registry$backtest_mae[i],  "\n")
  cat("    MAPE        :", model_registry$backtest_mape[i], "%\n")
  cat("    forge_hash  :", model_registry$forge_hash[i], "\n")
  cat("\n")
}
cat("  Registry written to:", path_registry, "\n")
cat("  Rows:", nrow(model_registry), "\n")

# ==============================================================================
# SECTION 8: ARTIFACT SUMMARY & SESSION INFO
# ==============================================================================

# ---- session-info ------------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SESSION INFO\n")
cat(strrep("=", 70), "\n")

duration <- difftime(Sys.time(), script_start, units = "secs")

# List artifacts with sizes
model_files <- list.files(dir_models, full.names = TRUE)
file_info   <- file.info(model_files)
artifact_summary <- data.frame(
  file     = basename(model_files),
  size_kb  = round(file_info$size / 1024, 1),
  stringsAsFactors = FALSE
)

cat("\n  Train completed in", round(as.numeric(duration), 1), "seconds\n")
cat("  Executed:", trained_at, "\n")
cat("  forge_hash consumed:", forge_hash, "\n")
cat("\n  Artifacts saved to:", dir_models, "\n\n")
cat("  ", sprintf("%-28s %8s", "File", "Size (KB)"), "\n")
cat("  ", strrep("-", 38), "\n")
for (i in seq_len(nrow(artifact_summary))) {
  cat("  ", sprintf("%-28s %8.1f", artifact_summary$file[i],
                    artifact_summary$size_kb[i]), "\n")
}
cat("  ", strrep("-", 38), "\n")
cat("  ", sprintf("%-28s %8.1f", "TOTAL", sum(artifact_summary$size_kb)), "\n")

cat("\n  Tiers implemented:\n")
cat("    Tier 1: snaive()    — seasonal naive baseline\n")
cat("    Tier 2: auto.arima() —", arima_full_order_str, "\n\n")
cat("  Deferred tiers (available in forge, not yet implemented):\n")
cat("    Tier 3: subgroup disaggregation — per-client-type ARIMA, then sum\n")
cat("    Tier 4: auto.arima(xreg = xreg_dynamic) — placeholder, 0-row in forge\n")

cat("\n  Ready for Forecast lane (5-forecast-IS.R)\n")
cat("    -> Load model_registry.csv\n")
cat("    -> For each row: readRDS(rds_path) |> forecast(h = 24)\n")
cat("    -> Check forge_hash matches current forge_manifest.yml before forecasting\n")

sessionInfo()
