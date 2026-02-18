#' ---
#' title: "Ellis Lane 2: Income Support Open Data Transformation"
#' author: "Andriy Koval"
#' date: "2025-02-18"
#' ---
#'
#' ============================================================================
#' ELLIS PATTERN: Transform Raw Data into Analysis-Ready Tables
#' ============================================================================
#'
#' **Purpose**: Transform raw Income Support data into 6 tidy wide-format tables
#'
#' **Input**: ./data-private/derived/open-data-is-1.sqlite (table: open_data_is_raw)
#'
#' **Output**: ./data-private/derived/open-data-is-2.sqlite with 6 tables:
#'   1. total_caseload     - 246 rows (Apr 2005 - Sep 2025, unified from all phases)
#'   2. client_type        - 162 rows × 4 component columns
#'   3. family_composition - 162 rows × 4 component columns  
#'   4. regions            - 90 rows × 8 region columns
#'   5. age_groups         - 66 rows × 15 age bin columns
#'   6. gender             - 66 rows × 3 gender columns
#'
#' All tables share date keys: date, year, month, fiscal_year, month_label
#'
#' ============================================================================

#+ echo=F
# rmarkdown::render(input = "./manipulation/2-ellis.R") # run to knit
# ---- setup -------------------------------------------------------------------
rm(list = ls(all.names = TRUE))
cat("\014")

script_start <- Sys.time()

# ---- load-packages -----------------------------------------------------------
library(magrittr)
library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(janitor)
requireNamespace("DBI")
requireNamespace("RSQLite")
requireNamespace("checkmate")
requireNamespace("arrow")
requireNamespace("fs")

# ---- load-sources ------------------------------------------------------------
base::source("./scripts/common-functions.R")

# ---- declare-globals ---------------------------------------------------------
# Input
input_path <- "./data-private/derived/open-data-is-1.sqlite"
input_table <- "open_data_is_raw"

# Output - SQLite (secondary, for SQL exploration)
output_path <- "./data-private/derived/open-data-is-2.sqlite"
output_dir <- dirname(output_path)
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# Output - Parquet (primary, for analysis)
output_parquet_dir <- "./data-private/derived/open-data-is-2-tables/"
if (!fs::dir_exists(output_parquet_dir)) fs::dir_create(output_parquet_dir, recursive = TRUE)

# ---- declare-functions -------------------------------------------------------
# Helper: Get fiscal year from date (Alberta fiscal year: April 1 - March 31)
get_fiscal_year <- function(date_value) {
  year_val <- year(date_value)
  month_val <- month(date_value)
  
  if (month_val >= 4) {
    # April onwards: FY YYYY-(YY+1)
    fy_start <- year_val
    fy_end <- (year_val + 1) %% 100  # Last 2 digits
    sprintf("FY %d-%02d", fy_start, fy_end)
  } else {
    # Jan-Mar: FY (YYYY-1)-YYYY
    fy_start <- year_val - 1
    fy_end <- year_val %% 100
    sprintf("FY %d-%02d", fy_start, fy_end)
  }
}

# ==============================================================================
# SECTION 1: DATA IMPORT
# ==============================================================================

# ---- load-data ---------------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 1: DATA IMPORT\n")
cat(strrep("=", 70), "\n")

cnn <- DBI::dbConnect(RSQLite::SQLite(), input_path)
ds0 <- DBI::dbGetQuery(cnn, sprintf("SELECT * FROM %s", input_table))
DBI::dbDisconnect(cnn)

# Drop trailing all-NA columns
ds0 <- ds0 %>% select(where(~ !all(is.na(.))))

cat("📥 Loaded from ferry output:", nrow(ds0), "rows,", ncol(ds0), "columns\n")
cat("   Source:", input_path, "\n")

# ---- inspect-data-0 ----------------------------------------------------------
cat("\n📊 Initial Data Inspection:\n")
cat("  - Dimensions:", nrow(ds0), "x", ncol(ds0), "\n")
cat("  - Columns:", paste(names(ds0), collapse = ", "), "\n")
cat("  - Date range:", min(ds0$ref_date), "to", max(ds0$ref_date), "\n")
cat("  - Measure types:", length(unique(ds0$measure_type)), "unique\n")

glimpse(ds0)

# ==============================================================================
# SECTION 2: ELLIS TRANSFORMATIONS
# ==============================================================================

cat("\n", strrep("=", 70), "\n")
cat("SECTION 2: ELLIS TRANSFORMATIONS\n")
cat(strrep("=", 70), "\n")

# ---- tweak-data-1-dates ------------------------------------------------------
cat("\n🔧 Step 1: Date parsing and derivation\n")

ds1 <- ds0 %>%
  mutate(
    # Parse YY-MMM format (e.g., "05-Apr" = April 2005)
    ref_date_parsed = lubridate::parse_date_time(ref_date, orders = "y-b"),
    date = as.Date(ref_date_parsed),
    year = year(date),
    month = month(date),
    month_label = format(date, "%b %Y"),  # "Apr 2005"
    fiscal_year = sapply(date, get_fiscal_year)
  ) %>%
  select(-ref_date_parsed)  # Drop intermediate parsing column

cat("   ✓ Date range:", min(ds1$date), "to", max(ds1$date), "\n")
cat("   ✓ Months:", n_distinct(ds1$date), "unique\n")
cat("   ✓ Fiscal years:", n_distinct(ds1$fiscal_year), "unique\n")

# ---- tweak-data-2-values -----------------------------------------------------
cat("\n🔧 Step 2: Value cleaning\n")

ds2 <- ds1 %>%
  mutate(
    # Clean value: trim, remove commas, handle suppressed values
    value_clean = str_trim(value),
    value_clean = str_replace_all(value_clean, ",", ""),
    # Detect suppressed values: "-" or variations with spaces
    value_clean = if_else(str_detect(value_clean, "^-\\s*$"), NA_character_, value_clean),
    value_numeric = as.numeric(value_clean)
  ) %>%
  select(-value, -value_clean) %>%
  rename(value = value_numeric)

cat("   ✓ Suppressed values converted to NA:", sum(is.na(ds2$value)), "cells\n")
cat("   ✓ Non-missing values:", sum(!is.na(ds2$value)), "cells\n")

# ---- tweak-data-3-factors ----------------------------------------------------
cat("\n🔧 Step 3: Factor recoding and measure cleaning\n")

ds3 <- ds2 %>%
  mutate(
    # Recode measure_type as ordered factor
    measure_type = factor(measure_type, 
                          levels = c("Total Caseload", 
                                     "Client Type Level", 
                                     "Family Composition", 
                                     "ALSS Regions", 
                                     "Average Age", 
                                     "Client Gender")),
    
    # Create cleaned measure names
    measure_clean = case_when(
      # Client Type recoding
      measure == "ETW - Working Total" ~ "ETW Working",
      measure == "ETW - Not Working (Available for Work) Total" ~ "ETW Available for Work",
      measure == "ETW - Not Working (Unavailable for Work) Total" ~ "ETW Unavailable for Work",
      measure == "BFE - Total" ~ "BFE",
      measure == "Client Caseload Total" ~ "Total",
      
      # Family Composition recoding
      measure == "Single Total" ~ "Single",
      measure == "Single Parent Total" ~ "Single Parent",
      measure == "Couples with Children Total" ~ "Couples with Children",
      measure == "Childless Couples Total" ~ "Childless Couples",
      measure == "All Types Total" ~ "Total",
      
      # Regions - keep as-is (preserving North Central / Unknown taxonomy change)
      measure == "All Regions Total" ~ "Total",
      measure %in% c("Calgary", "Central", "Edmonton", "North Central", 
                     "North East", "North West", "South", "Unknown") ~ measure,
      
      # Average Age - keep as-is
      measure == "All Ages Total" ~ "Total",
      str_detect(measure, "^Age ") ~ measure,
      
      # Client Gender - keep as-is
      measure == "All Gender Total" ~ "Total",
      measure %in% c("Female", "Male", "Other") ~ measure,
      
      # Total Caseload - passthrough
      measure == "Total Caseload" ~ "Total Caseload",
      
      TRUE ~ measure  # Fallback: keep original
    )
  )

cat("   ✓ Measure types:", length(levels(ds3$measure_type)), "levels\n")
cat("   ✓ Unique measure_clean values:", n_distinct(ds3$measure_clean), "\n")

# ---- tweak-data-4-dedup ------------------------------------------------------
cat("\n🔧 Step 4: Data quality deduplication (Nov 2020 anomaly)\n")

# Identify the Nov 2020 duplicate issue
nov2020_family_dups <- ds3 %>%
  filter(date == as.Date("2020-11-01"),
         measure_type == "Family Composition",
         measure_clean == "Total")

if (nrow(nov2020_family_dups) > 1) {
  cat("   ⚠️  Nov 2020 Family Composition duplicate found:", 
      nrow(nov2020_family_dups), "rows with values:", 
      paste(nov2020_family_dups$value, collapse = ", "), "\n")
  cat("   ✓ Keeping correction row (44,850), dropping bad row (48,850)\n")
}

# Add data quality flag for Nov 2020 Average Age suspect total
ds4 <- ds3 %>%
  mutate(
    data_quality_flag = case_when(
      date == as.Date("2020-11-01") & 
        measure_type == "Average Age" & 
        measure_clean == "Total" & 
        value == 48850 ~ "suspect_total",
      TRUE ~ NA_character_
    )
  )

# Deduplicate: keep last occurrence (the correction row)
ds4 <- ds4 %>%
  group_by(date, measure_type, measure_clean) %>%
  slice_tail(n = 1) %>%
  ungroup()

cat("   ✓ Deduplication complete. Rows after dedup:", nrow(ds4), "\n")

# ---- tweak-data-5-types ------------------------------------------------------
cat("\n🔧 Step 5: Data type verification\n")

ds_long <- ds4 %>%
  mutate(
    # Ensure proper types for SQLite compatibility
    measure_type = as.character(measure_type),
    geography = as.character(geography),
    measure = as.character(measure),
    measure_clean = as.character(measure_clean),
    fiscal_year = as.character(fiscal_year),
    month_label = as.character(month_label),
    data_quality_flag = as.character(data_quality_flag),
    # Ensure numeric/integer types
    year = as.integer(year),
    month = as.integer(month),
    value = as.numeric(value),
    # Date type
    date = as.Date(date)
  )

cat("   ✓ Data types standardized for SQLite\n")
cat("   ✓ Final long dataset:", nrow(ds_long), "rows,", ncol(ds_long), "cols\n")

# ==============================================================================
# SECTION 3: VALIDATION
# ==============================================================================

# ---- verify-values -----------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 3: DATA VALIDATION\n")
cat(strrep("=", 70), "\n")

cat("\n🔍 Running checkmate assertions...\n")

# Date assertions
checkmate::assert_date(ds_long$date, 
                       any.missing = FALSE, 
                       lower = as.Date("2005-04-01"), 
                       upper = as.Date("2025-09-01"))
cat("   ✓ date: valid Date type within expected range\n")

# Integer assertions
checkmate::assert_integer(ds_long$year, 
                          any.missing = FALSE, 
                          lower = 2005, 
                          upper = 2025)
cat("   ✓ year: valid integers 2005-2025\n")

checkmate::assert_integer(ds_long$month, 
                          any.missing = FALSE, 
                          lower = 1, 
                          upper = 12)
cat("   ✓ month: valid integers 1-12\n")

# Character assertions
checkmate::assert_character(ds_long$geography, 
                            any.missing = FALSE, 
                            pattern = "^Alberta$")
cat("   ✓ geography: all 'Alberta'\n")

checkmate::assert_character(ds_long$measure_type, 
                            any.missing = FALSE)
cat("   ✓ measure_type: valid character\n")

checkmate::assert_character(ds_long$measure_clean, 
                            any.missing = FALSE)
cat("   ✓ measure_clean: valid character\n")

checkmate::assert_character(ds_long$fiscal_year, 
                            any.missing = FALSE, 
                            pattern = "^FY \\d{4}-\\d{2}$")
cat("   ✓ fiscal_year: valid 'FY YYYY-YY' format\n")

# Numeric assertions (allow NA for suppressed values)
checkmate::assert_numeric(ds_long$value, 
                          lower = 0)
cat("   ✓ value: numeric, non-negative (NA allowed for suppressed)\n")

# Composite key uniqueness
dupes <- ds_long %>%
  count(date, measure_type, measure_clean) %>%
  filter(n > 1)

if (nrow(dupes) > 0) {
  cat("   ✗ DUPLICATE KEYS FOUND:\n")
  print(dupes)
  stop("Composite key uniqueness violated")
} else {
  cat("   ✓ Composite key unique: date × measure_type × measure_clean\n")
}

cat("\n✅ All validation checks passed\n")

# ==============================================================================
# SECTION 4: BUILD ANALYSIS-READY TABLES
# ==============================================================================

cat("\n", strrep("=", 70), "\n")
cat("SECTION 4: BUILD ANALYSIS-READY TABLES\n")
cat(strrep("=", 70), "\n")

# ---- pivot-1-total-caseload --------------------------------------------------
cat("\n📊 Table 1: total_caseload\n")

# Phase 1 (Apr 2005 - Mar 2012): use explicit "Total Caseload" rows
phase1_total <- ds_long %>%
  filter(measure_type == "Total Caseload") %>%
  select(date, year, month, fiscal_year, month_label, value) %>%
  rename(caseload = value)

# Phase 2-5 (Apr 2012 - Sep 2025): use "Client Caseload Total" from Client Type Level
phase2_total <- ds_long %>%
  filter(measure_type == "Client Type Level", 
         measure_clean == "Total") %>%
  select(date, year, month, fiscal_year, month_label, value) %>%
  rename(caseload = value)

# Union to create unified 246-month table
total_caseload <- bind_rows(phase1_total, phase2_total) %>%
  arrange(date)

cat("   ✓ Rows:", nrow(total_caseload), "(expected: 246)\n")
cat("   ✓ Date range:", min(total_caseload$date), "to", max(total_caseload$date), "\n")
cat("   ✓ Columns:", paste(names(total_caseload), collapse = ", "), "\n")

# ---- pivot-2-client-type -----------------------------------------------------
cat("\n📊 Table 2: client_type\n")

client_type <- ds_long %>%
  filter(measure_type == "Client Type Level",
         measure_clean != "Total") %>%
  select(date, year, month, fiscal_year, month_label, measure_clean, value) %>%
  pivot_wider(names_from = measure_clean, 
              values_from = value) %>%
  janitor::clean_names()

cat("   ✓ Rows:", nrow(client_type), "\n")
cat("   ✓ Columns:", paste(names(client_type), collapse = ", "), "\n")

# ---- pivot-3-family-composition ----------------------------------------------
cat("\n📊 Table 3: family_composition\n")

family_composition <- ds_long %>%
  filter(measure_type == "Family Composition",
         measure_clean != "Total") %>%
  select(date, year, month, fiscal_year, month_label, measure_clean, value) %>%
  pivot_wider(names_from = measure_clean, 
              values_from = value) %>%
  janitor::clean_names()

cat("   ✓ Rows:", nrow(family_composition), "\n")
cat("   ✓ Columns:", paste(names(family_composition), collapse = ", "), "\n")

# ---- pivot-4-regions ---------------------------------------------------------
cat("\n📊 Table 4: regions\n")

regions <- ds_long %>%
  filter(measure_type == "ALSS Regions",
         measure_clean != "Total") %>%
  select(date, year, month, fiscal_year, month_label, measure_clean, value) %>%
  pivot_wider(names_from = measure_clean, 
              values_from = value) %>%
  janitor::clean_names()

cat("   ✓ Rows:", nrow(regions), "\n")
cat("   ✓ Columns:", paste(names(regions), collapse = ", "), "\n")

# ---- pivot-5-age-groups ------------------------------------------------------
cat("\n📊 Table 5: age_groups\n")

age_groups <- ds_long %>%
  filter(measure_type == "Average Age",
         measure_clean != "Total") %>%
  select(date, year, month, fiscal_year, month_label, measure_clean, value) %>%
  pivot_wider(names_from = measure_clean, 
              values_from = value) %>%
  janitor::clean_names()

cat("   ✓ Rows:", nrow(age_groups), "\n")
cat("   ✓ Columns:", paste(names(age_groups), collapse = ", "), "\n")

# ---- pivot-6-gender ----------------------------------------------------------
cat("\n📊 Table 6: gender\n")

gender <- ds_long %>%
  filter(measure_type == "Client Gender",
         measure_clean != "Total") %>%
  select(date, year, month, fiscal_year, month_label, measure_clean, value) %>%
  pivot_wider(names_from = measure_clean, 
              values_from = value) %>%
  janitor::clean_names()

cat("   ✓ Rows:", nrow(gender), "\n")
cat("   ✓ Columns:", paste(names(gender), collapse = ", "), "\n")

# ==============================================================================
# SECTION 4B: CREATE LONG-FORMAT TABLES
# ==============================================================================

cat("\n", strrep("=", 70), "\n")
cat("SECTION 4B: CREATE LONG-FORMAT TABLES (for faceted viz & modeling)\n")
cat(strrep("=", 70), "\n")

# ---- pivot-long-1-client-type ------------------------------------------------
cat("\n📊 Table 7: client_type_long\n")

client_type_long <- client_type %>%
  pivot_longer(
    cols = c(etw_working, etw_available_for_work, etw_unavailable_for_work, bfe),
    names_to = "client_type_category",
    values_to = "count"
  ) %>%
  mutate(
    client_type_label = case_when(
      client_type_category == "etw_working" ~ "ETW: Working",
      client_type_category == "etw_available_for_work" ~ "ETW: Available for Work",
      client_type_category == "etw_unavailable_for_work" ~ "ETW: Unavailable for Work",
      client_type_category == "bfe" ~ "Barrier-Free Employment",
      TRUE ~ client_type_category
    )
  )

cat("   ✓ Rows:", nrow(client_type_long), "(162 months × 4 categories)\n")
cat("   ✓ Columns:", paste(names(client_type_long), collapse = ", "), "\n")

# ---- pivot-long-2-family-composition -----------------------------------------
cat("\n📊 Table 8: family_composition_long\n")

family_composition_long <- family_composition %>%
  pivot_longer(
    cols = c(single, single_parent, couples_with_children, childless_couples),
    names_to = "family_type_category",
    values_to = "count"
  ) %>%
  mutate(
    family_type_label = case_when(
      family_type_category == "single" ~ "Single",
      family_type_category == "single_parent" ~ "Single Parent",
      family_type_category == "couples_with_children" ~ "Couples with Children",
      family_type_category == "childless_couples" ~ "Childless Couples",
      TRUE ~ family_type_category
    )
  )

cat("   ✓ Rows:", nrow(family_composition_long), "(162 months × 4 categories)\n")
cat("   ✓ Columns:", paste(names(family_composition_long), collapse = ", "), "\n")

# ---- pivot-long-3-regions ----------------------------------------------------
cat("\n📊 Table 9: regions_long\n")

regions_long <- regions %>%
  pivot_longer(
    cols = c(calgary, central, edmonton, north_central, north_east, north_west, south, unknown),
    names_to = "region_category",
    values_to = "count"
  ) %>%
  mutate(
    region_label = case_when(
      region_category == "calgary" ~ "Calgary",
      region_category == "central" ~ "Central",
      region_category == "edmonton" ~ "Edmonton",
      region_category == "north_central" ~ "North Central",
      region_category == "north_east" ~ "North East",
      region_category == "north_west" ~ "North West",
      region_category == "south" ~ "South",
      region_category == "unknown" ~ "Unknown",
      TRUE ~ region_category
    )
  )

cat("   ✓ Rows:", nrow(regions_long), "(90 months × 8 regions)\n")
cat("   ✓ Columns:", paste(names(regions_long), collapse = ", "), "\n")

# ---- pivot-long-4-age-groups -------------------------------------------------
cat("\n📊 Table 10: age_groups_long\n")

age_groups_long <- age_groups %>%
  pivot_longer(
    cols = c(age_18_19, age_20_24, age_25_29, age_30_34, age_35_39, 
             age_40_44, age_45_49, age_50_54, age_55_59, 
             age_60, age_61, age_62, age_63, age_64, age_65),
    names_to = "age_category",
    values_to = "count"
  ) %>%
  mutate(
    age_label = case_when(
      age_category == "age_18_19" ~ "Age 18-19",
      age_category == "age_20_24" ~ "Age 20-24",
      age_category == "age_25_29" ~ "Age 25-29",
      age_category == "age_30_34" ~ "Age 30-34",
      age_category == "age_35_39" ~ "Age 35-39",
      age_category == "age_40_44" ~ "Age 40-44",
      age_category == "age_45_49" ~ "Age 45-49",
      age_category == "age_50_54" ~ "Age 50-54",
      age_category == "age_55_59" ~ "Age 55-59",
      age_category == "age_60" ~ "Age 60",
      age_category == "age_61" ~ "Age 61",
      age_category == "age_62" ~ "Age 62",
      age_category == "age_63" ~ "Age 63",
      age_category == "age_64" ~ "Age 64",
      age_category == "age_65" ~ "Age 65+",
      TRUE ~ age_category
    )
  )

cat("   ✓ Rows:", nrow(age_groups_long), "(66 months × 15 age bins)\n")
cat("   ✓ Columns:", paste(names(age_groups_long), collapse = ", "), "\n")

# ---- pivot-long-5-gender -----------------------------------------------------
cat("\n📊 Table 11: gender_long\n")

gender_long <- gender %>%
  pivot_longer(
    cols = c(female, male, other),
    names_to = "gender_category",
    values_to = "count"
  ) %>%
  mutate(
    gender_label = case_when(
      gender_category == "female" ~ "Female",
      gender_category == "male" ~ "Male",
      gender_category == "other" ~ "Other",
      TRUE ~ gender_category
    )
  )

cat("   ✓ Rows:", nrow(gender_long), "(66 months × 3 genders)\n")
cat("   ✓ Columns:", paste(names(gender_long), collapse = ", "), "\n")

# ==============================================================================
# SECTION 5: SAVE TO OUTPUT
# ==============================================================================

# ---- save-to-parquet ---------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 5A: SAVE TO PARQUET (Primary Output)\n")
cat(strrep("=", 70), "\n")

cat("\n📦 Writing 11 tables to Parquet...\n")

# Wide format tables (6)
arrow::write_parquet(total_caseload, file.path(output_parquet_dir, "total_caseload.parquet"))
cat("   ✓ total_caseload.parquet (", nrow(total_caseload), "rows)\n")

arrow::write_parquet(client_type, file.path(output_parquet_dir, "client_type_wide.parquet"))
cat("   ✓ client_type_wide.parquet (", nrow(client_type), "rows)\n")

arrow::write_parquet(family_composition, file.path(output_parquet_dir, "family_composition_wide.parquet"))
cat("   ✓ family_composition_wide.parquet (", nrow(family_composition), "rows)\n")

arrow::write_parquet(regions, file.path(output_parquet_dir, "regions_wide.parquet"))
cat("   ✓ regions_wide.parquet (", nrow(regions), "rows)\n")

arrow::write_parquet(age_groups, file.path(output_parquet_dir, "age_groups_wide.parquet"))
cat("   ✓ age_groups_wide.parquet (", nrow(age_groups), "rows)\n")

arrow::write_parquet(gender, file.path(output_parquet_dir, "gender_wide.parquet"))
cat("   ✓ gender_wide.parquet (", nrow(gender), "rows)\n")

# Long format tables (5)
arrow::write_parquet(client_type_long, file.path(output_parquet_dir, "client_type_long.parquet"))
cat("   ✓ client_type_long.parquet (", nrow(client_type_long), "rows)\n")

arrow::write_parquet(family_composition_long, file.path(output_parquet_dir, "family_composition_long.parquet"))
cat("   ✓ family_composition_long.parquet (", nrow(family_composition_long), "rows)\n")

arrow::write_parquet(regions_long, file.path(output_parquet_dir, "regions_long.parquet"))
cat("   ✓ regions_long.parquet (", nrow(regions_long), "rows)\n")

arrow::write_parquet(age_groups_long, file.path(output_parquet_dir, "age_groups_long.parquet"))
cat("   ✓ age_groups_long.parquet (", nrow(age_groups_long), "rows)\n")

arrow::write_parquet(gender_long, file.path(output_parquet_dir, "gender_long.parquet"))
cat("   ✓ gender_long.parquet (", nrow(gender_long), "rows)\n")

cat("\n✅ All 11 Parquet files saved to:", output_parquet_dir, "\n")

# ---- save-to-sqlite ----------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SECTION 5B: SAVE TO SQLITE (Secondary, for SQL exploration)\n")
cat(strrep("=", 70), "\n")

# Delete existing file for clean state
if (file.exists(output_path)) {
  file.remove(output_path)
  cat("   ✓ Removed existing SQLite file\n")
}

# Connect to output database
cnn_out <- DBI::dbConnect(RSQLite::SQLite(), output_path)

# Write wide format tables
DBI::dbWriteTable(cnn_out, "total_caseload", total_caseload, overwrite = TRUE)
DBI::dbWriteTable(cnn_out, "client_type_wide", client_type, overwrite = TRUE)
DBI::dbWriteTable(cnn_out, "family_composition_wide", family_composition, overwrite = TRUE)
DBI::dbWriteTable(cnn_out, "regions_wide", regions, overwrite = TRUE)
DBI::dbWriteTable(cnn_out, "age_groups_wide", age_groups, overwrite = TRUE)
DBI::dbWriteTable(cnn_out, "gender_wide", gender, overwrite = TRUE)

# Write long format tables
DBI::dbWriteTable(cnn_out, "client_type_long", client_type_long, overwrite = TRUE)
DBI::dbWriteTable(cnn_out, "family_composition_long", family_composition_long, overwrite = TRUE)
DBI::dbWriteTable(cnn_out, "regions_long", regions_long, overwrite = TRUE)
DBI::dbWriteTable(cnn_out, "age_groups_long", age_groups_long, overwrite = TRUE)
DBI::dbWriteTable(cnn_out, "gender_long", gender_long, overwrite = TRUE)

# Verify tables exist
tables <- DBI::dbListTables(cnn_out)
cat("\n   📋 Tables in SQLite database (", length(tables), "total):\n")
for (tbl in sort(tables)) {
  row_count <- DBI::dbGetQuery(cnn_out, sprintf("SELECT COUNT(*) as n FROM %s", tbl))$n
  cat("      -", tbl, ":", row_count, "rows\n")
}

DBI::dbDisconnect(cnn_out)

cat("\n✅ All 11 tables saved to SQLite:", output_path, "\n")

# ==============================================================================
# SECTION 6: SESSION INFO
# ==============================================================================

# ---- session-info ------------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("SESSION INFO\n")
cat(strrep("=", 70), "\n")

duration <- difftime(Sys.time(), script_start, units = "secs")
cat("\n⏱️  Ellis completed in", round(as.numeric(duration), 1), "seconds\n")
cat("📅 Executed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("👤 User:", Sys.info()["user"], "\n")
cat("\n📊 Output Summary:\n")
cat("   - Parquet files:", output_parquet_dir, "(11 files, primary)\n")
cat("   - SQLite database:", output_path, "(11 tables, secondary)\n")
cat("   - Wide format tables: 6 (total_caseload + 5 dimensions)\n")
cat("   - Long format tables: 5 (with descriptive factor labels)\n")
cat("   - Total caseload: 246 months (Apr 2005 - Sep 2025)\n")
cat("   - Dimensions: client_type, family_composition, regions, age_groups, gender\n")
cat("   - Data quality: Nov 2020 correction applied\n")
cat("   - Azure ML ready: Parquet format with schema preservation\n")

sessionInfo()
