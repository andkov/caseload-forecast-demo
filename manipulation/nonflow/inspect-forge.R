# Inspect forge artifacts produced by 3-mint-IS.R (parquet format)
# Run to validate artifacts are viable for Train lane
forge <- "./data-private/derived/forge"
library(lubridate)

# ---- data frames & ts objects ------------------------------------------------
cat("===== DATA FRAMES + RECONSTRUCTED TS OBJECTS =====\n")
ds_train <- arrow::read_parquet(file.path(forge, "ds_train.parquet"))
ds_test  <- arrow::read_parquet(file.path(forge, "ds_test.parquet"))
ds_full  <- arrow::read_parquet(file.path(forge, "ds_full.parquet"))

# Reconstruct ts objects (as Train lane will do)
ts_start_from <- function(df) c(year(min(df$date)), month(min(df$date)))
ts_train <- ts(ds_train$y, start = ts_start_from(ds_train), frequency = 12)
ts_test  <- ts(ds_test$y,  start = ts_start_from(ds_test),  frequency = 12)
ts_full  <- ts(ds_full$y,  start = ts_start_from(ds_full),  frequency = 12)

cat("\nts_train (reconstructed from ds_train.parquet):\n")
cat("  class:    ", class(ts_train), "\n")
cat("  length:   ", length(ts_train), "\n")
cat("  frequency:", frequency(ts_train), "\n")
cat("  start:    ", paste(start(ts_train), collapse = ","), "\n")
cat("  end:      ", paste(end(ts_train),   collapse = ","), "\n")
cat("  range:    [", round(min(ts_train), 4), ",", round(max(ts_train), 4), "]\n")
cat("  NAs:      ", sum(is.na(ts_train)), "\n")

cat("\nts_test:\n")
cat("  length:   ", length(ts_test), "\n")
cat("  start:    ", paste(start(ts_test), collapse = ","), "\n")
cat("  end:      ", paste(end(ts_test),   collapse = ","), "\n")
cat("  NAs:      ", sum(is.na(ts_test)), "\n")

cat("\nts_full:\n")
cat("  length:   ", length(ts_full), "\n")
cat("  start:    ", paste(start(ts_full), collapse = ","), "\n")
cat("  end:      ", paste(end(ts_full),   collapse = ","), "\n")
cat("  NAs:      ", sum(is.na(ts_full)), "\n")

cat("\nContiguity: train + test == full:", length(ts_train) + length(ts_test) == length(ts_full), "\n")
cat("Back-transform (first obs): exp(", round(ts_train[1], 4), ") =",
    round(exp(ts_train[1]), 0), "(expected ~27,969)\n")

cat("\nds_train:\n")
cat("  dim:     ", nrow(ds_train), "x", ncol(ds_train), "\n")
cat("  columns: ", paste(names(ds_train), collapse = ", "), "\n")
cat("  NAs in y:", sum(is.na(ds_train$y)), "\n")
cat("\n  First 3 rows (date / caseload / y):\n")
print(head(ds_train[, c("date", "caseload", "y")], 3))
cat("\n  Last 3 rows (date / caseload / y):\n")
print(tail(ds_train[, c("date", "caseload", "y")], 3))

cat("\nds_test (first 3 / last 3):\n")
print(head(ds_test[, c("date", "caseload", "y")], 3))
print(tail(ds_test[, c("date", "caseload", "y")], 3))

cat("\nTransform integrity - y == log(caseload):\n")
cat("  train: all match =", all(abs(ds_train$y - log(ds_train$caseload)) < 1e-10), "\n")
cat("  test:  all match =", all(abs(ds_test$y  - log(ds_test$caseload))  < 1e-10), "\n")

# ---- xreg tables -------------------------------------------------------------
cat("\n===== XREG TABLES (Tier 3) =====\n")
xreg_train_df  <- arrow::read_parquet(file.path(forge, "xreg_train.parquet"))
xreg_test_df   <- arrow::read_parquet(file.path(forge, "xreg_test.parquet"))
xreg_full_df   <- arrow::read_parquet(file.path(forge, "xreg_full.parquet"))
xreg_future_df <- arrow::read_parquet(file.path(forge, "xreg_future.parquet"))

# Extract matrix columns (as Train lane will do before passing to auto.arima)
xreg_cols  <- c("prop_etw_working", "prop_etw_available", "prop_etw_unavailable")
xreg_train <- as.matrix(xreg_train_df[, xreg_cols])
xreg_test  <- as.matrix(xreg_test_df[, xreg_cols])
xreg_full  <- as.matrix(xreg_full_df[, xreg_cols])
xreg_future <- as.matrix(xreg_future_df[, xreg_cols])

cat("\nxreg_train:\n")
cat("  class:    ", class(xreg_train_df), "\n")
cat("  dim:      ", nrow(xreg_train), "x", ncol(xreg_train), "\n")
cat("  colnames: ", paste(colnames(xreg_train), collapse = ", "), "\n")
cat("  date col: ", as.character(min(xreg_train_df$date)), "to",
    as.character(max(xreg_train_df$date)), "\n")
cat("  NAs:      ", sum(is.na(xreg_train)), "\n")
cat("  First row:", round(xreg_train[1, ], 4), "\n")
cat("  Last row: ", round(xreg_train[nrow(xreg_train), ], 4), "\n")

cat("\nxreg_test:\n")
cat("  First row:", round(xreg_test[1, ], 4), "\n")
cat("  Last row: ", round(xreg_test[nrow(xreg_test), ], 4), "\n")
cat("  NAs:      ", sum(is.na(xreg_test)), "\n")

cat("\nxreg_future (all 24 rows - static assumption):\n")
print(round(xreg_future, 4))

cat("\nDimension alignment:\n")
cat("  xreg_train nrow == ts_train length:", nrow(xreg_train) == length(ts_train), "\n")
cat("  xreg_test  nrow == ts_test  length:", nrow(xreg_test)  == length(ts_test), "\n")
cat("  xreg_full  nrow == ts_full  length:", nrow(xreg_full)  == length(ts_full), "\n")
cat("  xreg_future nrow == forecast_horizon (24):", nrow(xreg_future) == 24, "\n")

cat("\nProportion validity (each row sum < 1.0 - BFE excluded):\n")
cat("  train row sum range: [", round(min(rowSums(xreg_train)), 4), ",",
    round(max(rowSums(xreg_train)), 4), "] all < 1:",
    all(rowSums(xreg_train) < 1.0), "\n")
cat("  test  row sum range: [", round(min(rowSums(xreg_test)), 4), ",",
    round(max(rowSums(xreg_test)), 4), "] all < 1:",
    all(rowSums(xreg_test) < 1.0), "\n")

# xreg_dynamic placeholders (0-row parquet schema)
xreg_dyn_train <- arrow::read_parquet(file.path(forge, "xreg_dynamic_train.parquet"))
xreg_dyn_test  <- arrow::read_parquet(file.path(forge, "xreg_dynamic_test.parquet"))
cat("\nxreg_dynamic_train is 0-row placeholder:", nrow(xreg_dyn_train) == 0, "\n")
cat("xreg_dynamic_test  is 0-row placeholder:", nrow(xreg_dyn_test) == 0, "\n")
cat("xreg_dynamic_train schema:", paste(names(xreg_dyn_train), collapse = ", "), "\n")

# ---- xreg volatility check ---------------------------------------------------
cat("\n===== XREG TEMPORAL VARIATION CHECK =====\n")
cat("  (Do proportions actually vary? Static only at back-filled portion)\n\n")
cat("  Train proportion trends (start vs end):\n")
cat("    prop_etw_working:    ", round(xreg_train[1, 1], 4), "->",
    round(xreg_train[nrow(xreg_train), 1], 4), "\n")
cat("    prop_etw_available:  ", round(xreg_train[1, 2], 4), "->",
    round(xreg_train[nrow(xreg_train), 2], 4), "\n")
cat("    prop_etw_unavailable:", round(xreg_train[1, 3], 4), "->",
    round(xreg_train[nrow(xreg_train), 3], 4), "\n")

# ---- forge manifest ----------------------------------------------------------
cat("\n===== FORGE MANIFEST =====\n")
manifest <- yaml::read_yaml(file.path(forge, "forge_manifest.yml"))
cat("Top-level keys:", paste(names(manifest), collapse = ", "), "\n\n")
cat("mint_execution:\n")
for (k in names(manifest$mint_execution)) {
  cat("  ", k, ":", manifest$mint_execution[[k]], "\n")
}
cat("\ntransform_decisions:\n")
for (k in names(manifest$transform_decisions)) {
  cat("  ", k, ":", manifest$transform_decisions[[k]], "\n")
}
cat("\ndata_slices:\n")
cat("  train:", manifest$data_slices$train$start_date, "to",
    manifest$data_slices$train$end_date, "(", manifest$data_slices$train$n_months, "months)\n")
cat("  test: ", manifest$data_slices$test$start_date,  "to",
    manifest$data_slices$test$end_date,  "(", manifest$data_slices$test$n_months,  "months)\n")
cat("  full: ", manifest$data_slices$full$start_date,  "to",
    manifest$data_slices$full$end_date,  "(", manifest$data_slices$full$n_months,  "months)\n")

cat("\nxreg_static:\n")
cat("  columns:  ", paste(unlist(manifest$xreg_static$columns), collapse = ", "), "\n")
cat("  backfill: ", manifest$xreg_static$backfill_method, "\n")
cat("  future:   ", manifest$xreg_static$future_method, "\n")
cat("  n_backfilled:", manifest$xreg_static$n_backfilled_months, "\n")

cat("\nxreg_dynamic status:", manifest$xreg_dynamic$status, "\n")

cat("\nEDA decisions:\n")
for (d in manifest$eda_decisions) {
  cat("  [", d$id, "]", d$decision, "—", d$rationale, "\n")
}
cat("\nforge_hash:", manifest$forge_hash, "\n")
cat("artifacts :", length(manifest$artifacts), "listed\n")

cat("\n✅ All artifact checks complete — forge is Train-lane ready.\n")
cat("   Format: Apache Parquet (cross-language: R/Python/Azure ML)\n")
cat("   ts objects: reconstructed from ds_*.parquet in Train lane\n")
