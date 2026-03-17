# nolint start
# Technical appendix for note-1-briefing.qmd
# Chunks read by note-1-appendix.qmd via read_chunk("analysis/note-1/note-1-appendix.R")
rm(list = ls(all.names = TRUE))
cat("\014")
cat("Working directory: ", getwd())

# ---- load-packages -----------------------------------------------------------
library(magrittr)
library(ggplot2)
library(forcats)
library(stringr)
library(lubridate)
library(dplyr)
library(tidyr)
library(scales)
library(arrow)
library(yaml)
library(knitr)
library(kableExtra)
library(forecast)
library(fs)

if (requireNamespace("httpgd", quietly = TRUE)) {
  tryCatch({
    if (is.function(httpgd::hgd)) httpgd::hgd() else httpgd::httpgd()
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

local_root    <- "./analysis/note-1/"
local_data    <- paste0(local_root, "data-local/")
prints_folder <- paste0(local_root, "prints/")

if (!fs::dir_exists(local_data))    fs::dir_create(local_data)
if (!fs::dir_exists(prints_folder)) fs::dir_create(prints_folder)

dir_forge    <- "./data-private/derived/forge/"
dir_models   <- "./data-private/derived/models/"
dir_forecast <- "./data-private/derived/forecast/"

config           <- config::get()
focal_date       <- as.Date(config$focal_date)
forecast_horizon <- config$forecast_horizon
backtest_months  <- config$backtest_months

forecast_start <- focal_date + months(1)
forecast_end   <- focal_date + months(forecast_horizon)
test_start     <- focal_date - months(backtest_months)
test_end       <- focal_date

message("Focal date: ", focal_date)
message("Forecast window: ", forecast_start, " to ", forecast_end)
message("Backtest window: ", test_start, " to ", test_end)

# GoA corporate colours (Edition 27) from graph-presets.R
# sky_mid = #0077cd  / sky = #00b6ed  / goateal = #00AAD2
col_historical <- "#0077cd"   # sky_mid — historical series
col_arima      <- "#00AAD2"   # goateal — ARIMA forecast line
col_naive      <- "#ed8c00"   # sunset  — Naive baseline
col_interval   <- "#9ad7f9"   # sky_light — prediction interval fill
col_split_line <- "#aca4a3"   # stone — focal date marker
col_positive   <- "#0077cd"   # sky_mid — positive residuals
col_negative   <- "#ed8c00"   # sunset  — negative residuals (over-prediction)

tier_display_levels <- c(
  "Tier 1: Naive Baseline",
  "Tier 2: ARIMA"
)

tier_colours <- c(
  "Tier 1: Naive Baseline" = col_naive,
  "Tier 2: ARIMA"          = col_arima
)

g2_colours <- setNames(c(col_naive, col_arima), tier_display_levels)

# ---- declare-functions -------------------------------------------------------

format_fiscal_year_label <- function(date_vec) {
  year  <- lubridate::year(date_vec)
  month <- lubridate::month(date_vec)
  fy_start <- ifelse(month >= 4, year, year - 1)
  paste0("FY ", fy_start, "-", sprintf("%02d", (fy_start + 1L) %% 100L))
}

fmt_pct <- function(x, digits = 1) paste0(round(x, digits), " %")
fmt_num <- function(x, digits = 0) scales::comma(round(x, digits))

make_tier_label <- function(tier, tier_label) {
  paste0("Tier ", tier, ": ", tier_label)
}

# ---- load-data ---------------------------------------------------------------

message("\n--- Loading forecast artifacts ---")

ds_forecast_long <- read.csv(paste0(dir_forecast, "forecast_long.csv"),
                              stringsAsFactors = FALSE) %>%
  mutate(date = as.Date(date))

ds_forecast_wide <- read.csv(paste0(dir_forecast, "forecast_wide.csv"),
                              stringsAsFactors = FALSE) %>%
  mutate(date = as.Date(date))

ds_backtest <- read.csv(paste0(dir_forecast, "backtest_comparison.csv"),
                         stringsAsFactors = FALSE) %>%
  mutate(date = as.Date(date))

ds_model_perf <- read.csv(paste0(dir_forecast, "model_performance.csv"),
                           stringsAsFactors = FALSE)

forecast_manifest <- yaml::read_yaml(paste0(dir_forecast, "forecast_manifest.yml"))
forge_manifest    <- yaml::read_yaml(paste0(dir_forge,    "forge_manifest.yml"))

ds_full <- arrow::read_parquet(paste0(dir_forge, "ds_full.parquet")) %>%
  mutate(date = as.Date(date))

model_registry <- read.csv(paste0(dir_models, "model_registry.csv"),
                            stringsAsFactors = FALSE) %>%
  mutate(focal_date = as.Date(focal_date))

message("  forecast_long.csv  : ", nrow(ds_forecast_long), " rows")
message("  backtest_comparison: ", nrow(ds_backtest), " rows")
message("  model_performance  : ", nrow(ds_model_perf), " rows")
message("  model_registry     : ", nrow(model_registry), " rows")
message("  ds_full (parquet)  : ", nrow(ds_full), " months")

# ---- tweak-data-1 ------------------------------------------------------------

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

current_caseload <- ds_full %>%
  filter(date == focal_date) %>%
  pull(caseload)

# ---- provenance-dashboard ----------------------------------------------------

cat("\n=== DATA PROVENANCE DASHBOARD ===\n\n")

cat("--- Lane 3 (Mint) | forge_manifest.yml ---\n")
cat("  Focal date     :", forge_manifest$mint_execution$focal_date, "\n")
cat("  Split date     :", forge_manifest$mint_execution$split_date, "\n")
cat("  Backtest months:", forge_manifest$mint_execution$backtest_months, "\n")
cat("  Log transform  :", forge_manifest$transform_decisions$log_transform, "\n")
cat("  Seasonal period:", forge_manifest$transform_decisions$seasonal_period, "\n")
cat("  Train          :", forge_manifest$data_slices$train$start_date,
    "->", forge_manifest$data_slices$train$end_date,
    "(", forge_manifest$data_slices$train$n_months, "months)\n")
cat("  Test           :", forge_manifest$data_slices$test$start_date,
    "->", forge_manifest$data_slices$test$end_date,
    "(", forge_manifest$data_slices$test$n_months, "months)\n")
cat("  forge_hash     :", forge_manifest$forge_hash, "\n\n")

cat("--- Lane 5 (Forecast) | forecast_manifest.yml ---\n")
cat("  Focal date     :", forecast_manifest$forecast_parameters$focal_date, "\n")
cat("  Forecast start :", forecast_manifest$forecast_parameters$first_forecast_month, "\n")
cat("  Forecast end   :", forecast_manifest$forecast_parameters$last_forecast_month, "\n")
cat("  Horizon months :", forecast_manifest$forecast_parameters$forecast_horizon_months, "\n")
cat("  Transform      :", forecast_manifest$forecast_parameters$transform, "\n")
cat("  forge_hash     :", forecast_manifest$forge_hash_consumed, "\n")
cat("  forecast_hash  :", forecast_manifest$forecast_hash, "\n\n")

if (!is.null(forecast_manifest$forge_hash_consumed) &&
    forecast_manifest$forge_hash_consumed == forge_manifest$forge_hash) {
  cat("  [OK] Lineage intact: forge_hash matches across manifests.\n\n")
} else {
  cat("  [WARNING] forge_hash mismatch — forecast may be stale relative to Mint.\n\n")
}

# ---- g1 ----------------------------------------------------------------------
# Build combined data (historical + ARIMA forecast)

g1_historical <- ds_full %>%
  select(date, caseload) %>%
  mutate(
    series    = "Historical",
    point_val = caseload,
    lo_80 = NA_real_, hi_80 = NA_real_,
    lo_95 = NA_real_, hi_95 = NA_real_
  )

g1_forecast_arima <- ds_forecast_long %>%
  filter(tier == 2) %>%
  select(date, point_forecast, lo_80, hi_80, lo_95, hi_95) %>%
  mutate(
    series    = "24-Month Forecast (ARIMA)",
    point_val = point_forecast
  ) %>%
  select(date, series, point_val, lo_80, hi_80, lo_95, hi_95)

g1_data <- bind_rows(g1_historical, g1_forecast_arima)

g1 <- ggplot() +
  geom_ribbon(
    data = g1_data %>% filter(series != "Historical"),
    aes(x = date, ymin = lo_95, ymax = hi_95),
    fill = col_interval, alpha = 0.35
  ) +
  geom_ribbon(
    data = g1_data %>% filter(series != "Historical"),
    aes(x = date, ymin = lo_80, ymax = hi_80),
    fill = col_interval, alpha = 0.55
  ) +
  geom_line(
    data = g1_data %>% filter(series == "Historical"),
    aes(x = date, y = point_val),
    color = col_historical, linewidth = 0.8
  ) +
  geom_line(
    data = g1_data %>% filter(series != "Historical"),
    aes(x = date, y = point_val),
    color = col_arima, linewidth = 1.1, linetype = "solid"
  ) +
  geom_vline(xintercept = focal_date, linetype = "dashed",
             color = col_split_line, linewidth = 0.6) +
  annotate("text",
           x = focal_date + days(50), y = max(ds_full$caseload, na.rm = TRUE) * 0.97,
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
      "Model: ARIMA", forecast_manifest$models_forecasted[[2]]$arima_order %||% "(3,1,1)(1,0,0)[12]",
      " estimated on log-transformed series (", nrow(ds_full), " months). ",
      "forecast_hash: ", substr(forecast_manifest$forecast_hash, 1, 8), "..."
    )
  ) +
  theme(
    plot.title       = element_text(face = "bold", size = 14),
    plot.subtitle    = element_text(size = 11, color = "gray40"),
    plot.caption     = element_text(size = 8,  color = "gray60"),
    axis.text.x      = element_text(angle = 45, hjust = 1),
    panel.grid.minor = element_blank()
  )

ggsave(paste0(prints_folder, "g1_forecast.png"), g1, width = 10, height = 6, dpi = 300)
print(g1)

# ---- t1 ----------------------------------------------------------------------
# Key numbers table: ARIMA point forecast at +6, +12, +18, +24 months

t1_data <- ds_forecast_long %>%
  filter(tier == 2) %>%
  arrange(date) %>%
  mutate(horizon = row_number()) %>%
  filter(horizon %in% c(6L, 12L, 18L, 24L)) %>%
  mutate(
    month_label      = format(as.Date(date), "%B %Y"),
    fiscal_yr        = format_fiscal_year_label(as.Date(date)),
    point_fmt        = fmt_num(point_forecast),
    pi_95_range      = paste0(fmt_num(lo_95), " – ", fmt_num(hi_95)),
    pi_width         = fmt_num(hi_95 - lo_95),
    change_abs_fmt   = paste0(ifelse(point_forecast - current_caseload >= 0, "+", ""),
                              fmt_num(point_forecast - current_caseload)),
    change_pct_fmt   = paste0(ifelse(point_forecast - current_caseload >= 0, "+", ""),
                              fmt_pct((point_forecast - current_caseload) /
                                        current_caseload * 100))
  ) %>%
  select(
    `Horizon` = horizon,
    `Month`   = month_label,
    `Fiscal Year` = fiscal_yr,
    `Point Forecast` = point_fmt,
    `95% Prediction Interval` = pi_95_range,
    `PI Width` = pi_width,
    `Change vs Sep 2025` = change_abs_fmt,
    `Change (%)` = change_pct_fmt
  )

cat("\nKey forecast numbers (ARIMA, Tier 2):\n")
print(t1_data)

# ---- t2 ----------------------------------------------------------------------
# Model performance metrics table

t2_data <- ds_model_perf %>%
  arrange(tier) %>%
  mutate(
    arima_order = ifelse(is.na(arima_order), "N/A (rule-based)", arima_order),
    backtest_rmse = round(backtest_rmse, 1),
    backtest_mae  = round(backtest_mae,  1),
    backtest_mape = round(backtest_mape, 2)
  ) %>%
  select(
    `Model`       = tier_label_display,
    `Specification` = arima_order,
    `RMSE`        = backtest_rmse,
    `MAE`         = backtest_mae,
    `MAPE (%)`    = backtest_mape
  )

cat("\nModel performance (24-month backtest):\n")
print(t2_data)

# ---- g2 ----------------------------------------------------------------------
# Faceted forecast: one panel per model tier

g2 <- ggplot(ds_forecast_long,
             aes(x = date, y = point_forecast,
                 color = tier_label_display, fill = tier_label_display)) +
  geom_ribbon(aes(ymin = lo_95, ymax = hi_95), alpha = 0.13, colour = NA) +
  geom_ribbon(aes(ymin = lo_80, ymax = hi_80), alpha = 0.25, colour = NA) +
  geom_line(linewidth = 1) +
  facet_wrap(~tier_label_display, ncol = 1, scales = "fixed") +
  scale_colour_manual(values = g2_colours, guide = "none") +
  scale_fill_manual(  values = g2_colours, guide = "none") +
  scale_x_date(date_breaks = "3 months", date_labels = "%b %Y",
               expand = expansion(mult = c(0.02, 0.02))) +
  scale_y_continuous(labels = scales::comma_format(),
                     expand = expansion(mult = c(0.02, 0.06))) +
  labs(
    title    = "24-Month Forecast by Model Tier",
    subtitle = "Oct 2025 – Sep 2027. Point forecast with 80% (darker) and 95% (lighter) prediction intervals.",
    x = NULL, y = "Forecasted Caseload",
    caption = "Shared y-axis enables direct comparison of forecast levels and uncertainty widths."
  ) +
  theme(
    plot.title       = element_text(face = "bold", size = 14),
    plot.subtitle    = element_text(size = 11, color = "gray40"),
    plot.caption     = element_text(size = 8,  color = "gray60"),
    axis.text.x      = element_text(angle = 45, hjust = 1),
    strip.text       = element_text(face = "bold", size = 11),
    panel.grid.minor = element_blank()
  )

ggsave(paste0(prints_folder, "g2_faceted_forecast.png"), g2, width = 10, height = 8, dpi = 300)
print(g2)

# ---- g21 ---------------------------------------------------------------------
# Overlaid forecast: both models on one panel to reveal divergence

g21 <- ggplot(ds_forecast_long,
              aes(x = date, y = point_forecast,
                  color = tier_label_display, fill = tier_label_display)) +
  geom_ribbon(aes(ymin = lo_95, ymax = hi_95), alpha = 0.10, colour = NA) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.8, alpha = 0.7) +
  scale_colour_manual(values = g2_colours, name = "Model Tier") +
  scale_fill_manual(  values = g2_colours, guide = "none") +
  scale_x_date(date_breaks = "3 months", date_labels = "%b %Y",
               expand = expansion(mult = c(0.02, 0.02))) +
  scale_y_continuous(labels = scales::comma_format(),
                     expand = expansion(mult = c(0.02, 0.06))) +
  labs(
    title    = "Model Divergence: ARIMA vs Seasonal Naive",
    subtitle = paste0(
      "ARIMA (teal) captures trend dynamics; Seasonal Naive (orange) repeats ",
      "last year's monthly pattern. Gap widens as the horizon extends."
    ),
    x = NULL, y = "Forecasted Caseload",
    caption = "95% prediction intervals shown (ribbons)."
  ) +
  theme(
    plot.title       = element_text(face = "bold", size = 14),
    plot.subtitle    = element_text(size = 11, color = "gray40"),
    plot.caption     = element_text(size = 8,  color = "gray60"),
    axis.text.x      = element_text(angle = 45, hjust = 1),
    legend.position  = "bottom",
    legend.title     = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

ggsave(paste0(prints_folder, "g21_overlaid_forecast.png"), g21, width = 10, height = 6, dpi = 300)
print(g21)

# ---- g3 ----------------------------------------------------------------------
# Actual vs model-fitted over the 24-month backtest window

g3 <- ggplot() +
  geom_line(
    data = ds_backtest,
    aes(x = date, y = actual_caseload),
    color = "black", linewidth = 0.9, linetype = "solid"
  ) +
  geom_line(
    data = ds_backtest,
    aes(x = date, y = fitted_caseload, color = tier_label_display),
    linewidth = 0.9, linetype = "dashed"
  ) +
  facet_wrap(~tier_label_display, ncol = 1) +
  scale_colour_manual(values = g2_colours, guide = "none") +
  scale_x_date(date_breaks = "3 months", date_labels = "%b %Y",
               expand = expansion(mult = c(0.02, 0.02))) +
  scale_y_continuous(labels = scales::comma_format(),
                     expand = expansion(mult = c(0.02, 0.04))) +
  labs(
    title    = "Backtest: Actual vs Model-Fitted (Oct 2023 – Sep 2025)",
    subtitle = "Black solid = actual observed caseload. Coloured dashed = model-fitted values.",
    x = NULL, y = "Caseload",
    caption = paste0("24-month held-out backtest window. ",
                     "Closer alignment of dashed to solid indicates better model tracking.")
  ) +
  theme(
    plot.title       = element_text(face = "bold", size = 14),
    plot.subtitle    = element_text(size = 11, color = "gray40"),
    plot.caption     = element_text(size = 8,  color = "gray60"),
    axis.text.x      = element_text(angle = 45, hjust = 1),
    strip.text       = element_text(face = "bold", size = 11),
    panel.grid.minor = element_blank()
  )

ggsave(paste0(prints_folder, "g3_actual_vs_fitted.png"), g3, width = 10, height = 8, dpi = 300)
print(g3)

# ---- g31 ---------------------------------------------------------------------
# Residual bar chart (actual - fitted) for each model tier

g31 <- ggplot(ds_backtest, aes(x = date, y = residual)) +
  geom_col(aes(fill = over_predict), width = 25) +
  geom_hline(yintercept = 0, linewidth = 0.4, color = "gray40") +
  facet_wrap(~tier_label_display, ncol = 1) +
  scale_fill_manual(
    values = c("FALSE" = col_positive, "TRUE" = col_negative),
    labels = c("FALSE" = "Under-prediction", "TRUE" = "Over-prediction"),
    name   = NULL
  ) +
  scale_x_date(date_breaks = "3 months", date_labels = "%b %Y",
               expand = expansion(mult = c(0.02, 0.02))) +
  scale_y_continuous(labels = scales::comma_format()) +
  labs(
    title    = "Backtest Residuals: Actual minus Fitted",
    subtitle = "Teal bars = model under-predicted (actual > fitted). Orange = over-predicted.",
    x = NULL, y = "Residual (cases)",
    caption = "Residual = actual_caseload - fitted_caseload. Symmetric scatter around zero indicates unbiased model."
  ) +
  theme(
    plot.title       = element_text(face = "bold", size = 14),
    plot.subtitle    = element_text(size = 11, color = "gray40"),
    plot.caption     = element_text(size = 8,  color = "gray60"),
    axis.text.x      = element_text(angle = 45, hjust = 1),
    strip.text       = element_text(face = "bold", size = 11),
    legend.position  = "bottom",
    panel.grid.minor = element_blank()
  )

ggsave(paste0(prints_folder, "g31_residuals.png"), g31, width = 10, height = 8, dpi = 300)
print(g31)

# ---- g32 ---------------------------------------------------------------------
# Percentage error over the backtest window

g32 <- ggplot(ds_backtest, aes(x = date, y = abs(pct_error))) +
  geom_col(aes(fill = tier_label_display), alpha = 0.8, width = 25) +
  geom_hline(
    data = ds_model_perf,
    aes(yintercept = backtest_mape, color = tier_label_display),
    linetype = "dashed", linewidth = 0.7
  ) +
  facet_wrap(~tier_label_display, ncol = 1) +
  scale_fill_manual( values = g2_colours, guide = "none") +
  scale_colour_manual(values = g2_colours, guide = "none") +
  scale_x_date(date_breaks = "3 months", date_labels = "%b %Y",
               expand = expansion(mult = c(0.02, 0.02))) +
  scale_y_continuous(labels = function(x) paste0(x, "%"),
                     expand = expansion(mult = c(0, 0.06))) +
  labs(
    title    = "Backtest: Absolute Percentage Error by Month",
    subtitle = "Bars = monthly absolute % error. Dashed line = MAPE (mean across backtest window).",
    x = NULL, y = "Absolute % Error",
    caption = "Months above the dashed line performed worse than average for that model."
  ) +
  theme(
    plot.title       = element_text(face = "bold", size = 14),
    plot.subtitle    = element_text(size = 11, color = "gray40"),
    plot.caption     = element_text(size = 8,  color = "gray60"),
    axis.text.x      = element_text(angle = 45, hjust = 1),
    strip.text       = element_text(face = "bold", size = 11),
    panel.grid.minor = element_blank()
  )

ggsave(paste0(prints_folder, "g32_pct_error.png"), g32, width = 10, height = 8, dpi = 300)
print(g32)

# ---- g4 ----------------------------------------------------------------------
# Historical caseload annotated with structural breaks

breaks_df <- data.frame(
  date  = as.Date(c("2008-09-01", "2012-04-01", "2014-10-01", "2020-03-01")),
  label = c("2008 Financial\nCrisis", "2012 Alberta\nWorks Reform",
            "2014 Oil Price\nCollapse", "2020 COVID-19\nPandemic"),
  y_pos = c(45000, 42000, 48000, 38000)
)

g4 <- ggplot(ds_full, aes(x = date, y = caseload)) +
  geom_area(fill = col_historical, alpha = 0.15) +
  geom_line(color = col_historical, linewidth = 0.9) +
  geom_vline(
    data = breaks_df,
    aes(xintercept = date),
    linetype = "dashed", color = "#aca4a3", linewidth = 0.5
  ) +
  geom_label(
    data = breaks_df,
    aes(x = date, y = y_pos, label = label),
    hjust = 0, nudge_x = 60, size = 2.8, color = "#545860",
    label.size = 0, fill = "white", alpha = 0.85
  ) +
  scale_x_date(date_breaks = "2 years", date_labels = "%Y",
               expand = expansion(mult = c(0.01, 0.02))) +
  scale_y_continuous(labels = scales::comma_format(),
                     expand = expansion(mult = c(0, 0.06))) +
  labs(
    title    = "Alberta Income Support: 20-Year Historical Caseload",
    subtitle = paste0(
      "April 2005 – September 2025 (", nrow(ds_full), " months). ",
      "Structural breaks marked that caused major forecast deviations."
    ),
    x = NULL, y = "Total Caseload",
    caption = "Source: Alberta Open Data (Income Support program)."
  ) +
  theme(
    plot.title       = element_text(face = "bold", size = 14),
    plot.subtitle    = element_text(size = 11, color = "gray40"),
    plot.caption     = element_text(size = 8,  color = "gray60"),
    axis.text.x      = element_text(angle = 45, hjust = 1),
    panel.grid.minor = element_blank()
  )

ggsave(paste0(prints_folder, "g4_historical.png"), g4, width = 10, height = 6, dpi = 300)
print(g4)

# nolint end
