# nolint start 
# AI agents must consult ./analysis/eda-1/eda-style-guide.md before making changes to this file.
rm(list = ls(all.names = TRUE)) # Clear the memory of variables from previous run. This is not called by knitr, because it's above the first chunk.
cat("\014") # Clear the console
# verify root location
cat("Working directory: ", getwd()) # Must be set to Project Directory
# Project Directory should be the root by default unless overwritten
# ---- load-packages -----------------------------------------------------------
# Choose to be greedy: load only what's needed
# Three ways, from least (1) to most(3) greedy:
# -- 1.Attach these packages so their functions don't need to be qualified: 
# http://r-pkgs.had.co.nz/namespace.html#search-path
library(magrittr)
library(ggplot2)   # graphs
library(forcats)   # factors
library(stringr)   # strings
library(lubridate) # dates
library(labelled)  # labels
library(dplyr)     # data wrangling
library(tidyr)     # data wrangling
library(scales)    # format
library(arrow)     # parquet files
library(janitor)  # tidy data
library(testit)   # For asserting conditions meet expected patterns.
library(fs)       # file system operations
# ---- httpgd (VS Code interactive plots) ------------------------------------
# If the httpgd package is installed, try to start it so VS Code R extension
# can display interactive plots. This is optional and wrapped in tryCatch so
# the script still runs when httpgd is absent or fails to start.
if (requireNamespace("httpgd", quietly = TRUE)) {
	tryCatch({
		# Attempt to start httpgd server (API may vary by version); quiet on success
		if (is.function(httpgd::hgd)) {
			httpgd::hgd()
		} else if (is.function(httpgd::httpgd)) {
			httpgd::httpgd()
		} else {
			# Generic call attempt; will be caught if function not found
			httpgd::hgd()
		}
		message("httpgd started (if available). Configure your VS Code R extension to use it for plots.")
	}, error = function(e) {
		message("httpgd detected but failed to start: ", conditionMessage(e))
	})
} else {
	message("httpgd not installed. To enable interactive plotting in VS Code, install httpgd (binary recommended on Windows) or use other devices (svg/png).")
}

# ---- load-sources ------------------------------------------------------------
base::source("./scripts/common-functions.R") # project-level
base::source("./scripts/operational-functions.R") # project-level

# ---- declare-globals ---------------------------------------------------------

local_root <- "./analysis/eda-2/"
local_data <- paste0(local_root, "data-local/") # for local outputs

if (!fs::dir_exists(local_data)) {fs::dir_create(local_data)}

data_private_derived <- "./data-private/derived/eda-2/"
if (!fs::dir_exists(data_private_derived)) {fs::dir_create(data_private_derived)}

prints_folder <- paste0(local_root, "prints/")
if (!fs::dir_exists(prints_folder)) {fs::dir_create(prints_folder)}

# Path to analysis-ready parquet files from Ellis lane
parquet_path <- "./data-private/derived/open-data-is-2-tables/"

# ---- declare-functions -------------------------------------------------------
# Custom function to format fiscal year dates on axis
format_fiscal_year <- function(date_vec) {
  year <- lubridate::year(date_vec)
  month <- lubridate::month(date_vec)
  fy_year <- ifelse(month >= 4, year, year - 1)
  paste0("FY ", fy_year, "-", sprintf("%02d", (fy_year + 1) %% 100))
}

# ---- load-data --------------------------------------

# Load analysis-ready datasets from Ellis pattern outputs
# These are clean, validated datasets from data-private/derived/open-data-is-2-tables/

# MAIN DATASETS for this analysis:
# - ds0_total: Total caseload time series (Apr 2005 - Sep 2025)
# - ds0_client_type: Client type breakdown (Apr 2012 - Sep 2025)

message("📊 Loading Income Support Caseload Data from Parquet files...")

# Load total caseload (longest time series available)
ds0_total <- arrow::read_parquet(paste0(parquet_path, "total_caseload.parquet"))

# Load client type data (long format for easier ggplot2 faceting)
ds0_client_type <- arrow::read_parquet(paste0(parquet_path, "client_type_long.parquet"))

message("✅ Data loaded successfully:")
message("  - ds0_total (total_caseload): ", nrow(ds0_total), " months (", min(ds0_total$date), " to ", max(ds0_total$date), ")")
message("  - ds0_client_type (client_type_long): ", nrow(ds0_client_type), " observations across ", n_distinct(ds0_client_type$client_type_category), " categories")

# ---- tweak-data-1 -------------------------------------
# Ensure date column is proper Date type and create transformed datasets
ds1_total <- ds0_total %>%
  mutate(date = lubridate::as_date(date))

ds1_client_type <- ds0_client_type %>%
  mutate(date = lubridate::as_date(date))

# ---- inspect-data-0 -------------------------------------
# Basic structure of loaded datasets
cat("\n📊 Data Overview:\n")
cat("  - ds0_total (total_caseload):", nrow(ds0_total), "observations of", ncol(ds0_total), "variables\n")
cat("  - ds0_client_type (client_type_long):", nrow(ds0_client_type), "observations of", ncol(ds0_client_type), "variables\n")
cat("  - Ready for time series analysis\n")

# ---- inspect-data-1 -------------------------------------
# Quick glimpse of the total caseload data structure (ds1_total)
cat("\n📋 DS1_TOTAL Structure (Total Caseload):\n")
ds1_total %>% glimpse()

# ---- inspect-data-2 -------------------------------------
# Summary of total caseload
cat("\n📋 DS1_TOTAL Summary (Total Caseload):\n")
ds1_total %>% 
  select(date, year, caseload) %>%
  summary() %>%
  print()

# ---- inspect-data-3 -------------------------------------
# Quick glimpse of client type data structure (ds1_client_type)
cat("\n📋 DS1_CLIENT_TYPE Structure (Client Type Long):\n")
ds1_client_type %>% glimpse()

# ---- inspect-data-4 -------------------------------------
# Client type categories and date range
cat("\n📋 DS1_CLIENT_TYPE Client Type Categories:\n")
ds1_client_type %>%
  distinct(client_type_category, client_type_label) %>%
  arrange(client_type_category) %>%
  print()

cat("\n📋 DS1_CLIENT_TYPE Date Range by Category:\n")
ds1_client_type %>%
  group_by(client_type_category, client_type_label) %>%
  summarise(
    first_month = min(date),
    last_month = max(date),
    n_months = n(),
    .groups = "drop"
  ) %>%
  print()

# ---- g1 -----------------------------------------------------
# Time series of total caseload (2005-2025)
g1_total_caseload_ts <- ds1_total %>%
  ggplot(aes(x = date, y = caseload)) +
  geom_line(color = "steelblue", size = 1) +
  geom_point(color = "steelblue", size = 1.5, alpha = 0.6) +
  scale_x_date(
    date_breaks = "2 years", 
    date_labels = "%Y",
    expand = expansion(mult = c(0.02, 0.02))
  ) +
  scale_y_continuous(
    labels = scales::comma_format(),
    expand = expansion(mult = c(0, 0.05))
  ) +
  labs(
    title = "Alberta Income Support: Total Caseload Over Time",
    subtitle = "Monthly caseload from April 2005 to September 2025 (246 months)", 
    x = NULL,
    y = "Total Caseload",
    caption = "Source: Alberta Open Data - Income Support Monthly Caseload Statistics"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid.minor = element_blank()
  )

# Save to prints folder
ggsave(paste0(prints_folder, "g1_total_caseload_ts.png"), 
       g1_total_caseload_ts, width = 10, height = 6, dpi = 300)
print(g1_total_caseload_ts)

# ---- g2-data-prep -------------------------------------------
# Prepare summary statistics for key historical periods
g2_data <- ds1_total %>%
  mutate(
    period = case_when(
      date < as.Date("2008-09-01") ~ "Pre-2008 Crisis",
      date >= as.Date("2008-09-01") & date < as.Date("2012-04-01") ~ "2008-09 Crisis & Recovery",
      date >= as.Date("2012-04-01") & date < as.Date("2014-07-01") ~ "Stable Period (2012-2014)",
      date >= as.Date("2014-07-01") & date < as.Date("2016-12-01") ~ "Oil Price Collapse (2014-16)",
      date >= as.Date("2016-12-01") & date < as.Date("2020-03-01") ~ "Recovery Period (2017-2019)",
      date >= as.Date("2020-03-01") & date < as.Date("2022-01-01") ~ "COVID-19 Pandemic",
      TRUE ~ "Post-COVID (2022+)"
    )
  ) %>%
  mutate(period = factor(period, levels = c(
    "Pre-2008 Crisis",
    "2008-09 Crisis & Recovery",
    "Stable Period (2012-2014)",
    "Oil Price Collapse (2014-16)",
    "Recovery Period (2017-2019)",
    "COVID-19 Pandemic",
    "Post-COVID (2022+)"
  ))) %>%
  group_by(period) %>%
  summarise(
    avg_caseload = mean(caseload, na.rm = TRUE),
    min_caseload = min(caseload, na.rm = TRUE),
    max_caseload = max(caseload, na.rm = TRUE),
    n_months = n(),
    .groups = "drop"
  )

message("📊 g2_data prepared: ", nrow(g2_data), " historical periods")

# ---- g2 -----------------------------------------------------
# Average caseload by historical period
g2_period_avg <- g2_data %>%
  ggplot(aes(x = period, y = avg_caseload, fill = period)) +
  geom_col(alpha = 0.8, show.legend = FALSE) +
  geom_text(aes(label = scales::comma(round(avg_caseload, 0))), 
            vjust = -0.3, size = 3) +
  scale_y_continuous(
    labels = scales::comma_format(),
    expand = expansion(mult = c(0, 0.1))
  ) +
  scale_fill_brewer(palette = "Set2") +
  labs(
    title = "Average Caseload by Historical Period",
    subtitle = "Economic and policy context shapes caseload patterns", 
    x = NULL,
    y = "Average Monthly Caseload",
    caption = "Data: Alberta Open Data"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid.major.x = element_blank()
  )

# Save to prints folder
ggsave(paste0(prints_folder, "g2_period_avg.png"), 
       g2_period_avg, width = 10, height = 6, dpi = 300)
print(g2_period_avg)

# ---- g3 -----------------------------------------------------
# Client type breakdown time series (stacked area chart)
g3_client_type_area <- ds1_client_type %>%
  filter(!is.na(count)) %>%  # Remove suppressed values
  ggplot(aes(x = date, y = count, fill = client_type_label)) +
  geom_area(alpha = 0.7, position = "stack") +
  scale_x_date(
    date_breaks = "2 years", 
    date_labels = "%Y",
    expand = expansion(mult = c(0.02, 0.02))
  ) +
  scale_y_continuous(
    labels = scales::comma_format(),
    expand = expansion(mult = c(0, 0.05))
  ) +
  scale_fill_manual(
    values = c(
      "ETW: Working" = "#2166ac",
      "ETW: Available for Work" = "#4393c3",
      "ETW: Unavailable for Work" = "#92c5de",
      "Barrier-Free Employment" = "#d6604d"
    )
  ) +
  labs(
    title = "Client Type Composition Over Time",
    subtitle = "Stacked area chart showing evolution of client categories (April 2012 - September 2025)", 
    x = NULL,
    y = "Caseload Count",
    fill = "Client Type",
    caption = "Source: Alberta Open Data | ETW = Expected to Work"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

# Save to prints folder
ggsave(paste0(prints_folder, "g3_client_type_area.png"), 
       g3_client_type_area, width = 10, height = 6, dpi = 300)
print(g3_client_type_area)

# ---- g4 -----------------------------------------------------
# Client type faceted time series (separate line for each type)
g4_client_type_facet <- ds1_client_type %>%
  filter(!is.na(count)) %>%  # Remove suppressed values
  ggplot(aes(x = date, y = count, color = client_type_label)) +
  geom_line(size = 1) +
  geom_point(size = 0.8, alpha = 0.5) +
  facet_wrap(~ client_type_label, ncol = 2, scales = "free_y") +
  scale_x_date(
    date_breaks = "2 years", 
    date_labels = "%Y",
    expand = expansion(mult = c(0.02, 0.02))
  ) +
  scale_y_continuous(
    labels = scales::comma_format(),
    expand = expansion(mult = c(0, 0.05))
  ) +
  scale_color_manual(
    values = c(
      "ETW: Working" = "#2166ac",
      "ETW: Available for Work" = "#4393c3",
      "ETW: Unavailable for Work" = "#92c5de",
      "Barrier-Free Employment" = "#d6604d"
    )
  ) +
  labs(
    title = "Client Type Trends: Individual Time Series",
    subtitle = "Each panel shows trajectory for one client category (April 2012 - September 2025)", 
    x = NULL,
    y = "Caseload Count",
    caption = "Source: Alberta Open Data | ETW = Expected to Work"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "none",
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold", size = 10)
  )

# Save to prints folder
ggsave(paste0(prints_folder, "g4_client_type_facet.png"), 
       g4_client_type_facet, width = 10, height = 8, dpi = 300)
print(g4_client_type_facet)

# ---- g5-data-prep -------------------------------------------
# Prepare year-over-year comparison for most recent fiscal year
g5_data <- ds1_total %>%
  filter(year >= 2020) %>%
  mutate(
    month_name = lubridate::month(date, label = TRUE, abbr = TRUE),
    fiscal_year_label = paste0("FY ", 
                               ifelse(month >= 4, year, year - 1), 
                               "-", 
                               sprintf("%02d", (ifelse(month >= 4, year, year - 1) + 1) %% 100))
  ) %>%
  arrange(date)

message("📊 g5_data prepared: ", nrow(g5_data), " months for year-over-year comparison")

# ---- g5 -----------------------------------------------------
# Year-over-year caseload comparison (recent years)
g5_yoy_comparison <- g5_data %>%
  ggplot(aes(x = month, y = caseload, color = factor(year), group = year)) +
  geom_line(size = 1) +
  geom_point(size = 2) +
  scale_x_continuous(
    breaks = 1:12,
    labels = c("Jan", "Feb", "Mar", "Apr", "May", "Jun", 
               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
  ) +
  scale_y_continuous(
    labels = scales::comma_format(),
    expand = expansion(mult = c(0, 0.05))
  ) +
  scale_color_brewer(palette = "Set1", name = "Year") +
  labs(
    title = "Year-over-Year Caseload Comparison (2020-2025)",
    subtitle = "Monthly patterns across recent years showing seasonal and pandemic effects", 
    x = "Month",
    y = "Total Caseload",
    caption = "Source: Alberta Open Data"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    legend.position = "right",
    panel.grid.minor = element_blank()
  )

# Save to prints folder
ggsave(paste0(prints_folder, "g5_yoy_comparison.png"), 
       g5_yoy_comparison, width = 10, height = 6, dpi = 300)
print(g5_yoy_comparison)

# ---- g6-data-prep -------------------------------------------
# Calculate growth rates and prepare trend data
g6_data <- ds1_total %>%
  arrange(date) %>%
  mutate(
    # Month-over-month change
    mom_change = caseload - lag(caseload),
    mom_pct = (caseload / lag(caseload) - 1) * 100,
    # Year-over-year change
    yoy_change = caseload - lag(caseload, 12),
    yoy_pct = (caseload / lag(caseload, 12) - 1) * 100
  ) %>%
  filter(!is.na(yoy_pct))  # Remove first 12 months without YoY comparison

message("📊 g6_data prepared: ", nrow(g6_data), " months with growth rates")

# ---- g6 -----------------------------------------------------
# Year-over-year percentage change time series
g6_yoy_growth <- g6_data %>%
  ggplot(aes(x = date, y = yoy_pct)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_line(color = "steelblue", size = 1) +
  geom_point(aes(color = yoy_pct > 0), size = 1.5, alpha = 0.6) +
  scale_color_manual(
    values = c("TRUE" = "#d73027", "FALSE" = "#1a9850"),
    labels = c("Decrease", "Increase"),
    name = "Direction"
  ) +
  scale_x_date(
    date_breaks = "2 years", 
    date_labels = "%Y",
    expand = expansion(mult = c(0.02, 0.02))
  ) +
  scale_y_continuous(
    labels = scales::percent_format(scale = 1),
    expand = expansion(mult = c(0.1, 0.1))
  ) +
  labs(
    title = "Year-over-Year Caseload Growth Rate",
    subtitle = "Percentage change compared to same month previous year", 
    x = NULL,
    y = "YoY Growth Rate (%)",
    caption = "Source: Alberta Open Data"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

# Save to prints folder
ggsave(paste0(prints_folder, "g6_yoy_growth.png"), 
       g6_yoy_growth, width = 10, height = 6, dpi = 300)
print(g6_yoy_growth)

# nolint end
