# nolint start
# AI agents must consult ./analysis/eda-1/eda-style-guide.md before making changes to this file.
rm(list = ls(all.names = TRUE)) # Clear memory from previous run. Not called by knitr (above first chunk).
cat("\014") # Clear the console
cat("Working directory: ", getwd()) # Must be set to Project Directory

# ---- load-packages -----------------------------------------------------------
library(magrittr)
library(ggplot2)     # graphs
library(forcats)     # factors
library(stringr)     # strings
library(lubridate)   # dates
library(dplyr)       # data wrangling
library(tidyr)       # data wrangling
library(scales)      # axis formatting
library(arrow)       # parquet files
library(yaml)        # read YAML manifests
library(knitr)       # kable tables
library(kableExtra)  # table styling
library(forecast)    # forecast objects (for class checks / plot methods)
library(fs)          # file system

# ---- httpgd (VS Code interactive plots) -------------------------------------
if (requireNamespace("httpgd", quietly = TRUE)) {
  tryCatch({
    if (is.function(httpgd::hgd)) {
      httpgd::hgd()
    } else if (is.function(httpgd::httpgd)) {
      httpgd::httpgd()
    } else {
      httpgd::hgd()
    }
    message("httpgd started.")
  }, error = function(e) {
    message("httpgd detected but failed to start: ", conditionMessage(e))
  })
} else {
  message("httpgd not installed. Using default graphics device.")
}

# ---- load-sources ------------------------------------------------------------
base::source("./scripts/common-functions.R")
base::source("./scripts/operational-functions.R")

# ---- declare-globals ---------------------------------------------------------

local_root   <- "./analysis/report-1/"
local_data   <- paste0(local_root, "data-local/")
prints_folder <- paste0(local_root, "prints/")

if (!fs::dir_exists(local_data))    fs::dir_create(local_data)
if (!fs::dir_exists(prints_folder)) fs::dir_create(prints_folder)

# Artifact paths from upstream lanes
dir_forge    <- "./data-private/derived/forge/"
dir_models   <- "./data-private/derived/models/"
dir_forecast <- "./data-private/derived/forecast/"

# Read config for key parameters
config <- config::get()
focal_date       <- as.Date(config$focal_date)           # 2025-09-01
forecast_horizon <- config$forecast_horizon              # 24
backtest_months  <- config$backtest_months               # 24

forecast_start   <- focal_date + months(1)               # 2025-10-01
forecast_end     <- focal_date + months(forecast_horizon) # 2027-09-01
test_start       <- focal_date - months(backtest_months)  # 2023-09-01 (split date)
test_end         <- focal_date                           # 2025-09-01

message("Focal date: ", focal_date)
message("Forecast window: ", forecast_start, " to ", forecast_end)
message("Backtest window: ", test_start, " to ", test_end)

# Colour constants (match EDA-2 conventions)
col_historical <- "steelblue"
col_arima      <- "#2166ac"   # Tier 2 - ARIMA (cool blue)
col_naive      <- "#d6604d"   # Tier 1 - Seasonal Naive (warm coral)
col_split_line <- "gray50"

tier_colours <- c(
  "Tier 1: Naive Baseline" = col_naive,
  "Tier 2: ARIMA"          = col_arima
)

# ---- declare-functions -------------------------------------------------------

# Consistent fiscal year label: "FY 2025-26"
format_fiscal_year_label <- function(date_vec) {
  year  <- lubridate::year(date_vec)
  month <- lubridate::month(date_vec)
  fy_start <- ifelse(month >= 4, year, year - 1)
  paste0("FY ", fy_start, "-", sprintf("%02d", (fy_start + 1L) %% 100L))
}

# Clean percentage: "13.4 %"
fmt_pct <- function(x, digits = 1) paste0(round(x, digits), " %")

# Clean comma number: "45,123"
fmt_num <- function(x, digits = 0) scales::comma(round(x, digits))

# Build consistent display label from tier number + short tier_label
make_tier_label <- function(tier, tier_label) {
  paste0("Tier ", tier, ": ", tier_label)
}

# Canonical ordered levels for tier_label_display factor
tier_display_levels <- c(
  "Tier 1: Naive Baseline",
  "Tier 2: ARIMA"
)

# ---- load-data ---------------------------------------------------------------

message("\n--- Loading forecast artifacts ---")

# Lane 5 outputs
ds_forecast_long <- read.csv(paste0(dir_forecast, "forecast_long.csv"),
                              stringsAsFactors = FALSE) %>%
  mutate(date = as.Date(date))

ds_forecast_wide <- read.csv(paste0(dir_forecast, "forecast_wide.csv"),
                              stringsAsFactors = FALSE) %>%
  mutate(date = as.Date(date))

ds_backtest      <- read.csv(paste0(dir_forecast, "backtest_comparison.csv"),
                              stringsAsFactors = FALSE) %>%
  mutate(date = as.Date(date))

ds_model_perf    <- read.csv(paste0(dir_forecast, "model_performance.csv"),
                              stringsAsFactors = FALSE)

forecast_manifest <- yaml::read_yaml(paste0(dir_forecast, "forecast_manifest.yml"))

# Lane 3 outputs
forge_manifest <- yaml::read_yaml(paste0(dir_forge, "forge_manifest.yml"))
ds_full        <- arrow::read_parquet(paste0(dir_forge, "ds_full.parquet")) %>%
  mutate(date = as.Date(date))

# Lane 4 outputs
model_registry <- read.csv(paste0(dir_models, "model_registry.csv"),
                            stringsAsFactors = FALSE) %>%
  mutate(focal_date = as.Date(focal_date))

message("  forecast_long.csv  : ", nrow(ds_forecast_long), " rows")
message("  backtest_comparison: ", nrow(ds_backtest), " rows")
message("  model_performance  : ", nrow(ds_model_perf), " rows")
message("  model_registry     : ", nrow(model_registry), " rows")
message("  ds_full (parquet)  : ", nrow(ds_full), " months")

# ---- tweak-data-1 ------------------------------------------------------------
# forecast_long & backtest have tier + tier_label but NOT model_description.
# model_performance & model_registry have model_description.
# Use make_tier_label(tier, tier_label) consistently for all four datasets.

ds_forecast_long <- ds_forecast_long %>%
  mutate(
    date               = as.Date(date),
    tier_label_display = factor(make_tier_label(tier, tier_label),
                                levels = tier_display_levels)
  )

ds_backtest <- ds_backtest %>%
  mutate(
    date               = as.Date(date),
    tier_label_display = factor(make_tier_label(tier, tier_label),
                                levels = tier_display_levels),
    residual           = actual_caseload - fitted_caseload,
    pct_error          = residual / actual_caseload * 100,
    over_predict       = residual < 0
  )

ds_model_perf <- ds_model_perf %>%
  mutate(
    tier_label_display = factor(make_tier_label(tier, tier_label),
                                levels = tier_display_levels)
  )

model_registry <- model_registry %>%
  mutate(
    focal_date         = as.Date(as.character(focal_date)),
    tier_label_display = factor(make_tier_label(tier, tier_label),
                                levels = tier_display_levels),
    arima_order_clean  = ifelse(is.na(arima_order), "N/A (rule-based)", arima_order)
  )

# ---- inspect-data-0 ----------------------------------------------------------

cat("\n=== REPORT PROVENANCE DASHBOARD ===\n\n")

# Forge manifest summary
cat("--- Lane 3 (Mint) | forge_manifest.yml ---\n")
cat("  Focal date    :", forge_manifest$mint_execution$focal_date, "\n")
cat("  Split date    :", forge_manifest$mint_execution$split_date, "\n")
cat("  Backtest months:", forge_manifest$mint_execution$backtest_months, "\n")
cat("  Log transform :", forge_manifest$transform_decisions$log_transform, "\n")
cat("  Seasonal period:", forge_manifest$transform_decisions$seasonal_period, "\n")
cat("  Train         :", forge_manifest$data_slices$train$start_date,
    "→", forge_manifest$data_slices$train$end_date,
    "(", forge_manifest$data_slices$train$n_months, "months)\n")
cat("  Test          :", forge_manifest$data_slices$test$start_date,
    "→", forge_manifest$data_slices$test$end_date,
    "(", forge_manifest$data_slices$test$n_months, "months)\n")
cat("  forge_hash    :", forge_manifest$forge_hash, "\n\n")

# EDA decisions
cat("  EDA Decisions codified in Mint:\n")
for (d in forge_manifest$eda_decisions) {
  cat("    [", d$id, "] ", d$decision, "\n", sep = "")
}
cat("\n")

# Forecast manifest summary
cat("--- Lane 5 (Forecast) | forecast_manifest.yml ---\n")
cat("  Focal date    :", forecast_manifest$forecast_parameters$focal_date, "\n")
cat("  Forecast start:", forecast_manifest$forecast_parameters$first_forecast_month, "\n")
cat("  Forecast end  :", forecast_manifest$forecast_parameters$last_forecast_month, "\n")
cat("  Horizon months:", forecast_manifest$forecast_parameters$forecast_horizon_months, "\n")
cat("  Transform     :", forecast_manifest$forecast_parameters$transform, "\n")
cat("  Models        :", paste(sapply(forecast_manifest$models_forecasted, function(m) m$model_id), collapse = ", "), "\n")
cat("  forge_hash    :", forecast_manifest$forge_hash_consumed, "\n")
cat("  forecast_hash :", forecast_manifest$forecast_hash, "\n\n")

# Verify lineage integrity
if (!is.null(forecast_manifest$forge_hash_consumed) &&
    forecast_manifest$forge_hash_consumed == forge_manifest$forge_hash) {
  cat("  [OK] Lineage intact: forge_hash matches across manifests.\n\n")
} else {
  cat("  [WARNING] forge_hash mismatch — forecast may be stale relative to Mint.\n\n")
}

# Model performance snapshot
cat("--- Lane 4 (Train) | model_registry.csv ---\n")
model_registry %>%
  select(model_id, tier, model_description, arima_order_clean,
         backtest_rmse, backtest_mape) %>%
  print()

# ---- g1-data-prep ------------------------------------------------------------
# Hero graph data: full historical series + ARIMA forward forecast
# One continuous timeline; region marked by source (Historical / Forecast)

# Historical portion – use actual caseload from full series
g1_historical <- ds_full %>%
  select(date, caseload) %>%
  mutate(
    series    = "Historical",
    point_val = caseload,
    lo_80     = NA_real_,
    hi_80     = NA_real_,
    lo_95     = NA_real_,
    hi_95     = NA_real_
  )

# Forecast portion – ARIMA only (Tier 2, higher numbered = better)
g1_forecast_arima <- ds_forecast_long %>%
  filter(tier == 2) %>%
  select(date, point_forecast, lo_80, hi_80, lo_95, hi_95) %>%
  mutate(
    series    = "24-Month Forecast (ARIMA)",
    point_val = point_forecast
  ) %>%
  select(date, series, point_val, lo_80, hi_80, lo_95, hi_95)

g1_data <- bind_rows(g1_historical, g1_forecast_arima)

# ---- g1 ----------------------------------------------------------------------
# Hero graph: 20-year history + 2-year forward ARIMA projection
# Inverted pyramid lead — this is what the reader needs to take away first.

g1_forecast_report <- ggplot() +
  # 95% prediction interval ribbon
  geom_ribbon(
    data = g1_data %>% filter(series != "Historical") ,
    aes(x = date, ymin = lo_95, ymax = hi_95),
    fill = col_arima, alpha = 0.13
  ) +
  # 80% prediction interval ribbon
  geom_ribbon(
    data = g1_data %>% filter(series != "Historical"),
    aes(x = date, ymin = lo_80, ymax = hi_80),
    fill = col_arima, alpha = 0.25
  ) +
  # Historical line
  geom_line(
    data = g1_data %>% filter(series == "Historical"),
    aes(x = date, y = point_val),
    color = col_historical, linewidth = 0.8
  ) +
  # Forecast line
  geom_line(
    data = g1_data %>% filter(series != "Historical"),
    aes(x = date, y = point_val),
    color = col_arima, linewidth = 1, linetype = "solid"
  ) +
  # Focal date marker
  geom_vline(xintercept = focal_date, linetype = "dashed",
             color = col_split_line, linewidth = 0.6) +
  annotate("text",
           x = focal_date + days(60), y = max(ds_full$caseload, na.rm = TRUE) * 0.97,
           label = paste0("Latest data\n", format(focal_date, "%b %Y")),
           hjust = 0, size = 3, color = col_split_line) +
  scale_x_date(
    date_breaks = "2 years", date_labels = "%Y",
    expand = expansion(mult = c(0.01, 0.02))
  ) +
  scale_y_continuous(
    labels = scales::comma_format(),
    expand = expansion(mult = c(0, 0.06))
  ) +
  labs(
    title    = "Alberta Income Support: 24-Month Caseload Forecast",
    subtitle = paste0(
      "Historical series (Apr 2005 – Sep 2025) with ARIMA forward projection ",
      "(Oct 2025 – Sep 2027). Shaded bands: 80% and 95% prediction intervals."
    ),
    x       = NULL,
    y       = "Total Caseload",
    caption = paste0(
      "Source: Alberta Open Data (Income Support). ",
      "Model: ARIMA (3,1,1)(1,0,0)[12] estimated on log-transformed series (", nrow(ds_full), " months). ",
      "forecast_hash: ", substr(forecast_manifest$forecast_hash, 1, 8), "..."
    )
  ) +
  theme_minimal() +
  theme(
    plot.title    = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    plot.caption  = element_text(size = 8, color = "gray60"),
    axis.text.x   = element_text(angle = 45, hjust = 1),
    panel.grid.minor = element_blank()
  )

ggsave(paste0(prints_folder, "g1_forecast_report.png"),
       g1_forecast_report, width = 10, height = 6, dpi = 300)
print(g1_forecast_report)

# ---- t1 ----------------------------------------------------------------------
# Key numbers table: snapshot point forecasts at +6, +12, +18, +24 months

# Current (focal) caseload
current_caseload <- ds_full %>%
  filter(date == focal_date) %>%
  pull(caseload)

# ARIMA forecasts at key horizons
t1_data <- ds_forecast_long %>%
  filter(tier == 2) %>%
  arrange(date) %>%
  mutate(horizon = row_number()) %>%
  filter(horizon %in% c(6L, 12L, 18L, 24L)) %>%
  mutate(
    month_label    = format(as.Date(date), "%B %Y"),
    fiscal_yr      = format_fiscal_year_label(as.Date(date)),
    point_fmt      = fmt_num(point_forecast),
    lo_95_fmt      = fmt_num(lo_95),
    hi_95_fmt      = fmt_num(hi_95),
    change_abs_fmt = fmt_num(point_forecast - current_caseload),
    change_pct_fmt = fmt_pct((point_forecast - current_caseload) /
                               current_caseload * 100)
  ) %>%
  select(
    `Horizon (+months)` = horizon,
    `Month`             = month_label,
    `Fiscal Year`       = fiscal_yr,
    `Point Forecast`    = point_fmt,
    `95% PI Low`        = lo_95_fmt,
    `95% PI High`       = hi_95_fmt,
    `Change vs Now`     = change_abs_fmt,
    `Change (%)`        = change_pct_fmt
  )

cat("\nKey forecast numbers (ARIMA, Tier 2):\n")
print(t1_data)

# ---- g2-data-prep ------------------------------------------------------------
# Both model tiers for comparison plots

g2_data <- ds_forecast_long %>%
  mutate(
    tier_label_display = factor(
      tier_label_display,
      levels = levels(ds_forecast_long$tier_label_display)
    )
  )

# Colour vector aligned to tier_display_levels
g2_colours <- setNames(
  c(col_naive, col_arima),
  tier_display_levels
)

# ---- g2 ----------------------------------------------------------------------
# Faceted forecast: one panel per model tier (honest side-by-side)
# Shared y-axis lets reader see absolute divergence between models.

g2_faceted_forecast <- ggplot(g2_data,
                               aes(x = date, y = point_forecast,
                                   color = tier_label_display,
                                   fill  = tier_label_display)) +
  geom_ribbon(aes(ymin = lo_95, ymax = hi_95), alpha = 0.13, colour = NA) +
  geom_ribbon(aes(ymin = lo_80, ymax = hi_80), alpha = 0.25, colour = NA) +
  geom_line(linewidth = 1) +
  facet_wrap(~tier_label_display, ncol = 1, scales = "fixed") +
  scale_colour_manual(values = g2_colours, guide = "none") +
  scale_fill_manual(  values = g2_colours, guide = "none") +
  scale_x_date(
    date_breaks = "3 months", date_labels = "%b %Y",
    expand = expansion(mult = c(0.02, 0.02))
  ) +
  scale_y_continuous(
    labels = scales::comma_format(),
    expand = expansion(mult = c(0.02, 0.06))
  ) +
  labs(
    title    = "24-Month Forecast by Model Tier",
    subtitle = paste0(
      "Oct 2025 – Sep 2027. Each panel shows point forecast with ",
      "80% (darker) and 95% (lighter) prediction intervals."
    ),
    x       = NULL,
    y       = "Forecasted Caseload",
    caption = "Shared y-axis enables direct comparison of forecast levels and uncertainty widths."
  ) +
  theme_minimal() +
  theme(
    plot.title    = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    plot.caption  = element_text(size = 8,  color = "gray60"),
    axis.text.x   = element_text(angle = 45, hjust = 1),
    strip.text    = element_text(face = "bold", size = 11),
    panel.grid.minor = element_blank()
  )

ggsave(paste0(prints_folder, "g2_faceted_forecast.png"),
       g2_faceted_forecast, width = 10, height = 8, dpi = 300)
print(g2_faceted_forecast)

# ---- g21 ---------------------------------------------------------------------
# Overlaid forecast: both models on one panel to reveal divergence over the horizon.

g21_overlaid_forecast <- ggplot(g2_data,
                                 aes(x = date, y = point_forecast,
                                     color = tier_label_display,
                                     fill  = tier_label_display)) +
  geom_ribbon(aes(ymin = lo_95, ymax = hi_95), alpha = 0.10, colour = NA) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.8, alpha = 0.7) +
  scale_colour_manual(
    values = g2_colours,
    name   = "Model Tier"
  ) +
  scale_fill_manual(
    values = g2_colours,
    guide  = "none"
  ) +
  scale_x_date(
    date_breaks = "3 months", date_labels = "%b %Y",
    expand = expansion(mult = c(0.02, 0.02))
  ) +
  scale_y_continuous(
    labels = scales::comma_format(),
    expand = expansion(mult = c(0.02, 0.06))
  ) +
  labs(
    title    = "Forecast Divergence: ARIMA vs Seasonal Naive",
    subtitle = paste0(
      "ARIMA (blue) captures trend dynamics; Seasonal Naive (coral) repeats last year's ",
      "monthly pattern. Gap widens as the horizon extends."
    ),
    x       = NULL,
    y       = "Forecasted Caseload",
    caption = paste0(
      "95% prediction intervals shown (ribbons). ",
      "ARIMA interval narrows relative to Naive because log-transformation ",
      "stabilises forecast variance."
    )
  ) +
  theme_minimal() +
  theme(
    plot.title    = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    plot.caption  = element_text(size = 8,  color = "gray60"),
    axis.text.x   = element_text(angle = 45, hjust = 1),
    legend.position  = "bottom",
    legend.title     = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

ggsave(paste0(prints_folder, "g21_overlaid_forecast.png"),
       g21_overlaid_forecast, width = 10, height = 6, dpi = 300)
print(g21_overlaid_forecast)

# ---- t2 ----------------------------------------------------------------------
# Performance metrics table: RMSE, MAE, MAPE side-by-side for all model tiers

t2_data <- ds_model_perf %>%
  arrange(tier) %>%
  select(
    `Model`           = tier_label_display,
    `ARIMA Order`     = arima_order,
    `AICc`            = aicc,
    `RMSE`            = backtest_rmse,
    `MAE`             = backtest_mae,
    `MAPE`            = backtest_mape,
    `Train Months`    = n_train,
    `Backtest Months` = n_test
  ) %>%
  mutate(
    `AICc`       = ifelse(is.na(`AICc`),        "—", as.character(round(`AICc`, 1))),
    `ARIMA Order`= ifelse(is.na(`ARIMA Order`), "—", as.character(`ARIMA Order`)),
    `RMSE`       = fmt_num(as.numeric(`RMSE`)),
    `MAE`        = fmt_num(as.numeric(`MAE`)),
    `MAPE`       = fmt_pct(as.numeric(`MAPE`))
  )

cat("\nModel performance metrics (24-month backtest):\n")
print(t2_data)

# ---- g3-data-prep ------------------------------------------------------------
# Backtest diagnostics data; window = test period (Oct 2023 – Sep 2025)

g3_data <- ds_backtest %>%
  arrange(tier, date)

# ---- g3 ----------------------------------------------------------------------
# Actual vs fitted over the 24-month backtest window (faceted by tier)

g3_actual_vs_fitted <- ggplot(g3_data) +
  geom_line(
    aes(x = date, y = actual_caseload),
    color = "black", linewidth = 0.9, linetype = "solid"
  ) +
  geom_line(
    aes(x = date, y = fitted_caseload, color = tier_label_display),
    linewidth = 0.9, linetype = "dashed"
  ) +
  geom_point(
    aes(x = date, y = actual_caseload),
    color = "black", size = 1.8, alpha = 0.7
  ) +
  facet_wrap(~tier_label_display, ncol = 1, scales = "fixed") +
  scale_colour_manual(values = g2_colours, guide = "none") +
  scale_x_date(
    date_breaks = "3 months", date_labels = "%b %Y",
    expand = expansion(mult = c(0.02, 0.02))
  ) +
  scale_y_continuous(
    labels = scales::comma_format(),
    expand = expansion(mult = c(0.02, 0.06))
  ) +
  labs(
    title    = "Backtest: Actual vs Model-Fitted Caseload",
    subtitle = paste0(
      "24-month held-out window: October 2023 – September 2025. ",
      "Black solid = actual; coloured dashed = model fitted."
    ),
    x       = NULL,
    y       = "Caseload",
    caption = paste0(
      "NOTE: Fitted values are one-step in-sample predictions from full-series models, ",
      "not true multi-step hold-out forecasts. ",
      "True backtest metrics (RMSE/MAE/MAPE) are from 4-train-IS.R."
    )
  ) +
  theme_minimal() +
  theme(
    plot.title    = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    plot.caption  = element_text(size = 8,  color = "gray60"),
    axis.text.x   = element_text(angle = 45, hjust = 1),
    strip.text    = element_text(face = "bold", size = 11),
    panel.grid.minor = element_blank()
  )

ggsave(paste0(prints_folder, "g3_actual_vs_fitted.png"),
       g3_actual_vs_fitted, width = 10, height = 8, dpi = 300)
print(g3_actual_vs_fitted)

# ---- g31 ---------------------------------------------------------------------
# Residual time series: reveals *when* and *in which direction* models err.
# Positive residual = model under-predicted (actual > fitted); 
# negative = model over-predicted.

g31_residuals <- ggplot(g3_data,
                         aes(x = date, y = residual, fill = over_predict)) +
  geom_col(width = 25, alpha = 0.8) +
  geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
  facet_wrap(~tier_label_display, ncol = 1, scales = "free_y") +
  scale_fill_manual(
    values = c(`TRUE` = col_naive, `FALSE` = col_arima),
    labels = c(`TRUE` = "Over-predicted (actual < fitted)",
               `FALSE` = "Under-predicted (actual > fitted)"),
    name   = NULL
  ) +
  scale_x_date(
    date_breaks = "3 months", date_labels = "%b %Y",
    expand = expansion(mult = c(0.02, 0.02))
  ) +
  scale_y_continuous(
    labels = scales::comma_format(),
    expand = expansion(mult = c(0.05, 0.05))
  ) +
  labs(
    title    = "Residuals Over the Backtest Window",
    subtitle = paste0(
      "Residual = actual – fitted. Positive (blue) = model under-predicted; ",
      "negative (coral) = model over-predicted."
    ),
    x       = NULL,
    y       = "Residual (cases)",
    caption = paste0(
      "Systematic upward or downward bias suggests a structural shift not captured by the model. ",
      "Random scatter is expected for a well-specified model."
    )
  ) +
  theme_minimal() +
  theme(
    plot.title    = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    plot.caption  = element_text(size = 8,  color = "gray60"),
    axis.text.x   = element_text(angle = 45, hjust = 1),
    strip.text    = element_text(face = "bold", size = 11),
    legend.position  = "bottom",
    panel.grid.minor = element_blank()
  )

ggsave(paste0(prints_folder, "g31_residuals.png"),
       g31_residuals, width = 10, height = 8, dpi = 300)
print(g31_residuals)

# ---- g32 ---------------------------------------------------------------------
# Absolute percentage error by month: how large is the miss as % of actual?
# Reference horizontal line at each model's MAPE from model_performance.csv.

mape_lines <- ds_model_perf %>%
  select(tier_label_display, backtest_mape) %>%
  mutate(backtest_mape = as.numeric(as.character(backtest_mape)))

g32_pct_error <- g3_data %>%
  mutate(abs_pct_error = abs(pct_error)) %>%
  ggplot(aes(x = date, y = abs_pct_error, color = tier_label_display)) +
  geom_line(linewidth = 0.8, alpha = 0.8) +
  geom_point(size = 2, alpha = 0.7) +
  geom_hline(
    data = mape_lines,
    aes(yintercept = backtest_mape, color = tier_label_display),
    linetype = "dashed", linewidth = 0.7
  ) +
  facet_wrap(~tier_label_display, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = g2_colours, guide = "none") +
  scale_x_date(
    date_breaks = "3 months", date_labels = "%b %Y",
    expand = expansion(mult = c(0.02, 0.02))
  ) +
  scale_y_continuous(
    labels = scales::percent_format(scale = 1, accuracy = 0.1),
    expand = expansion(mult = c(0, 0.10))
  ) +
  labs(
    title    = "Absolute Percentage Error by Month",
    subtitle = paste0(
      "Dashed horizontal line = MAPE (mean absolute percentage error). ",
      "Points above the line are worse-than-average months."
    ),
    x       = NULL,
    y       = "Absolute % Error",
    caption = paste0(
      "MAPE - Tier 1 (Naive Baseline): ",
      fmt_pct(mape_lines$backtest_mape[mape_lines$tier_label_display == tier_display_levels[1]]),
      "  |  Tier 2 (ARIMA): ",
      fmt_pct(mape_lines$backtest_mape[mape_lines$tier_label_display == tier_display_levels[2]])
    )
  ) +
  theme_minimal() +
  theme(
    plot.title    = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    plot.caption  = element_text(size = 8,  color = "gray60"),
    axis.text.x   = element_text(angle = 45, hjust = 1),
    strip.text    = element_text(face = "bold", size = 11),
    panel.grid.minor = element_blank()
  )

ggsave(paste0(prints_folder, "g32_pct_error.png"),
       g32_pct_error, width = 10, height = 8, dpi = 300)
print(g32_pct_error)

# ---- t3 ----------------------------------------------------------------------
# Model specification table: technical details for analysts

t3_data <- model_registry %>%
  arrange(tier) %>%
  select(
    `Tier`            = tier,
    `Model`           = tier_label_display,
    `ARIMA Order`     = arima_order_clean,
    `AIC`             = aic,
    `AICc`            = aicc,
    `BIC`             = bic,
    `Train N`         = n_train,
    `Test N`          = n_test,
    `Full N`          = n_full,
    `Focal Date`      = focal_date,
    `Forge Hash`      = forge_hash
  ) %>%
  mutate(
    `AIC`  = ifelse(is.na(`AIC`),  "—", round(`AIC`,  1)),
    `AICc` = ifelse(is.na(`AICc`), "—", round(`AICc`, 1)),
    `BIC`  = ifelse(is.na(`BIC`),  "—", round(`BIC`,  1)),
    `Forge Hash` = substr(`Forge Hash`, 1, 8)
  )

cat("\nModel specification registry:\n")
print(t3_data)

# ---- t4 ----------------------------------------------------------------------
# Data lineage table: forge manifest summarised in tabular form

t4_data <- data.frame(
  Field = c(
    "Script", "Executed At", "Focal Date", "Split Date",
    "Backtest Months", "Forecast Horizon",
    "Log Transform", "Seasonal Period", "Expected Differencing",
    "Train: Start", "Train: End", "Train: N Months",
    "Test: Start",  "Test: End",  "Test: N Months",
    "xreg Static Columns",
    "forge_hash"
  ),
  Value = c(
    forge_manifest$mint_execution$script,
    forge_manifest$mint_execution$executed_at,
    forge_manifest$mint_execution$focal_date,
    forge_manifest$mint_execution$split_date,
    forge_manifest$mint_execution$backtest_months,
    forge_manifest$mint_execution$forecast_horizon,
    forge_manifest$transform_decisions$log_transform,
    forge_manifest$transform_decisions$seasonal_period,
    forge_manifest$transform_decisions$expected_differencing,
    forge_manifest$data_slices$train$start_date,
    forge_manifest$data_slices$train$end_date,
    forge_manifest$data_slices$train$n_months,
    forge_manifest$data_slices$test$start_date,
    forge_manifest$data_slices$test$end_date,
    forge_manifest$data_slices$test$n_months,
    paste(forge_manifest$xreg_static$columns, collapse = ", "),
    forge_manifest$forge_hash
  ),
  stringsAsFactors = FALSE
)

cat("\nForge manifest (Lane 3 data contract):\n")
print(t4_data)

# ---- t5 ----------------------------------------------------------------------
# Forecast manifest summary: provenance snapshot for report header

t5_data <- data.frame(
  Field = c(
    "forecast_hash",
    "forge_hash Consumed",
    "Focal Date",
    "First Forecast Month",
    "Last Forecast Month",
    "Forecast Horizon (months)",
    "Transform Applied",
    "Random Seed",
    "Models Forecasted",
    "Artifact Files"
  ),
  Value = c(
    forecast_manifest$forecast_hash,
    forecast_manifest$forge_hash_consumed,
    forecast_manifest$forecast_parameters$focal_date,
    forecast_manifest$forecast_parameters$first_forecast_month,
    forecast_manifest$forecast_parameters$last_forecast_month,
    forecast_manifest$forecast_parameters$forecast_horizon_months,
    forecast_manifest$forecast_parameters$transform,
    forecast_manifest$forecast_parameters$random_seed,
    paste(sapply(forecast_manifest$models_forecasted,
                 function(m) m$model_id), collapse = ", "),
    paste(names(forecast_manifest$artifacts), collapse = ", ")
  ),
  stringsAsFactors = FALSE
)

cat("\nForecast manifest (Lane 5 provenance):\n")
print(t5_data)

# ---- session-info ------------------------------------------------------------
cat("\nReport completed at:", as.character(Sys.time()), "\n")
sessionInfo()
# nolint end
