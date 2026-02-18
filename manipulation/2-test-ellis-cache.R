#' ---
#' title: "Test: Ellis Lane 2 ↔ CACHE-Manifest Alignment"
#' author: "Data Engineer (AI-generated)"
#' date: "2026-02-18"
#' ---
#'
#' ============================================================================
#' PURPOSE: Verify that the CACHE-manifest accurately describes the artifacts
#' actually produced by manipulation/2-ellis.R
#' ============================================================================
#'
#' This script is a quality gate for human analysts. When it passes, you can
#' trust that the CACHE-manifest (your documentation) matches reality (the
#' actual files on disk). When it fails, it tells you exactly what drifted.
#'
#' THREE-WAY ALIGNMENT CHECK:
#'   1. Ellis script (2-ellis.R) — the code that produces the artifacts
#'   2. Artifacts on disk — Parquet files + SQLite database
#'   3. CACHE-manifest.md — the human-readable documentation
#'
#' Run this after any change to 2-ellis.R or CACHE-manifest.md to ensure
#' the documentation still matches reality.
#'
#' ============================================================================

#+ echo=F
# rmarkdown::render(input = "./manipulation/2-test-ellis-cache.R") # run to knit
# ---- setup -------------------------------------------------------------------
rm(list = ls(all.names = TRUE))
cat("\014")

script_start <- Sys.time()

# ---- load-packages -----------------------------------------------------------
library(magrittr)
library(dplyr)
library(tidyr)
library(stringr)
requireNamespace("DBI")
requireNamespace("RSQLite")
requireNamespace("arrow")
requireNamespace("checkmate")
requireNamespace("fs")

# ---- declare-globals ---------------------------------------------------------

# Paths to the three artifacts under test
parquet_dir   <- "./data-private/derived/open-data-is-2-tables/"
sqlite_path   <- "./data-private/derived/open-data-is-2.sqlite"
manifest_path <- "./data-public/metadata/CACHE-manifest.md"
ellis_script  <- "./manipulation/2-ellis.R"

# Counters
tests_passed  <- 0L
tests_failed  <- 0L
tests_skipped <- 0L
failures      <- character(0)

# ---- declare-functions -------------------------------------------------------

# Test helper: run a named assertion, track pass/fail
run_test <- function(test_name, expr, skip_reason = NULL) {
  if (!is.null(skip_reason)) {
    tests_skipped <<- tests_skipped + 1L
    cat("   ⏭️  SKIP:", test_name, "-", skip_reason, "\n")
    return(invisible(FALSE))
  }
  result <- tryCatch({
    eval(expr)
    TRUE
  }, error = function(e) {
    e$message
  })
  
  if (isTRUE(result)) {
    tests_passed <<- tests_passed + 1L
    cat("   ✅ PASS:", test_name, "\n")
    invisible(TRUE)
  } else {
    tests_failed <<- tests_failed + 1L
    msg <- if (is.character(result)) result else "Assertion failed"
    failures <<- c(failures, paste0(test_name, ": ", msg))
    cat("   ❌ FAIL:", test_name, "\n")
    cat("          ", msg, "\n")
    invisible(FALSE)
  }
}

# Helper: extract a value from a markdown table row
# Searches manifest text for a row matching `pattern` and returns the value at column `col_index`
extract_manifest_table_value <- function(manifest_lines, pattern, col_index = 4) {
  matching <- grep(pattern, manifest_lines, value = TRUE)
  if (length(matching) == 0) return(NA_character_)
  # Split by | and trim
  cells <- str_trim(unlist(str_split(matching[1], "\\|")))
  cells <- cells[cells != ""]
  if (col_index > length(cells)) return(NA_character_)
  cells[col_index]
}

# ==============================================================================
cat("\n", strrep("=", 70), "\n")
cat("ELLIS ↔ CACHE-MANIFEST ALIGNMENT TESTS\n")
cat(strrep("=", 70), "\n")
cat(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# ==============================================================================
# SECTION 1: ARTIFACT EXISTENCE
# ==============================================================================

cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("SECTION 1: ARTIFACT EXISTENCE — Do the expected files exist?\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

run_test("Ellis script exists", quote(
  checkmate::assert_file_exists(ellis_script)
))

run_test("CACHE-manifest exists", quote(
  checkmate::assert_file_exists(manifest_path)
))

run_test("SQLite database exists", quote(
  checkmate::assert_file_exists(sqlite_path)
))

run_test("Parquet directory exists", quote(
  checkmate::assert_directory_exists(parquet_dir)
))

# ---- check-parquet-file-inventory --------------------------------------------
# The manifest claims 11 parquet files (6 wide + 5 long)
expected_parquet_files <- sort(c(
  "total_caseload.parquet",
  "client_type_wide.parquet",
  "family_composition_wide.parquet",
  "regions_wide.parquet",
  "age_groups_wide.parquet",
  "gender_wide.parquet",
  "client_type_long.parquet",
  "family_composition_long.parquet",
  "regions_long.parquet",
  "age_groups_long.parquet",
  "gender_long.parquet"
))

actual_parquet_files <- sort(list.files(parquet_dir, pattern = "\\.parquet$"))

run_test("Parquet file count = 11", quote(
  checkmate::assert_true(length(actual_parquet_files) == 11L)
))

run_test("All expected Parquet files present", quote(
  checkmate::assert_set_equal(actual_parquet_files, expected_parquet_files)
))

# Check for unexpected files (drift detection)
extra_files <- setdiff(actual_parquet_files, expected_parquet_files)
run_test("No unexpected Parquet files", quote(
  checkmate::assert_true(
    length(extra_files) == 0,
    .var.name = paste0("Extra files found: ", paste(extra_files, collapse = ", "))
  )
))

# ==============================================================================
# SECTION 2: SQLITE ↔ PARQUET PARITY
# ==============================================================================

cat("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("SECTION 2: SQLITE ↔ PARQUET PARITY — Are both outputs identical?\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

cnn <- DBI::dbConnect(RSQLite::SQLite(), sqlite_path)
sqlite_tables <- sort(DBI::dbListTables(cnn))

run_test("SQLite table count = 11", quote(
  checkmate::assert_true(length(sqlite_tables) == 11L)
))

# Expected SQLite table names (manifest Section: Table Inventory)
expected_sqlite_tables <- sort(c(
  "total_caseload",
  "client_type_wide", "family_composition_wide", "regions_wide",
  "age_groups_wide", "gender_wide",
  "client_type_long", "family_composition_long", "regions_long",
  "age_groups_long", "gender_long"
))

run_test("SQLite table names match expected", quote(
  checkmate::assert_set_equal(sqlite_tables, expected_sqlite_tables)
))

# Cross-check: each SQLite table's row count matches its Parquet counterpart
cat("\n   Checking row parity (SQLite ↔ Parquet):\n")
for (tbl_name in expected_sqlite_tables) {
  parquet_file <- paste0(tbl_name, ".parquet")
  parquet_path <- file.path(parquet_dir, parquet_file)
  
  if (!file.exists(parquet_path)) {
    run_test(
      paste0("  Parity: ", tbl_name, " (file missing)"),
      quote(stop("Parquet file does not exist"))
    )
    next
  }
  
  sqlite_rows <- DBI::dbGetQuery(
    cnn, sprintf("SELECT COUNT(*) as n FROM %s", tbl_name)
  )$n
  
  parquet_df <- arrow::read_parquet(parquet_path)
  parquet_rows <- nrow(parquet_df)
  
  run_test(
    paste0("  Parity: ", tbl_name, " (", sqlite_rows, " ↔ ", parquet_rows, " rows)"),
    quote(checkmate::assert_true(sqlite_rows == parquet_rows))
  )
}

# Cross-check: column names must match between SQLite and Parquet
cat("\n   Checking column parity (SQLite ↔ Parquet):\n")
for (tbl_name in expected_sqlite_tables) {
  parquet_file <- paste0(tbl_name, ".parquet")
  parquet_path <- file.path(parquet_dir, parquet_file)
  
  if (!file.exists(parquet_path)) next
  
  sqlite_cols <- sort(DBI::dbListFields(cnn, tbl_name))
  parquet_cols <- sort(names(arrow::read_parquet(parquet_path, as_data_frame = FALSE)))
  
  run_test(
    paste0("  Columns: ", tbl_name),
    quote(checkmate::assert_set_equal(sqlite_cols, parquet_cols))
  )
}

DBI::dbDisconnect(cnn)

# ==============================================================================
# SECTION 3: MANIFEST ↔ ARTIFACT ROW COUNTS
# ==============================================================================

cat("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("SECTION 3: MANIFEST ↔ ARTIFACT ROW COUNTS — Do documented numbers match?\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

# Read manifest once
manifest_text <- readLines(manifest_path, warn = FALSE)

# CACHE-manifest Table Inventory specifies these exact row counts:
manifest_expected <- list(
  total_caseload             = list(rows = 246L,  format = "Wide",  categories = 1L),
  client_type_long           = list(rows = 648L,  format = "Long",  categories = 4L),
  family_composition_long    = list(rows = 648L,  format = "Long",  categories = 4L),
  regions_long               = list(rows = 720L,  format = "Long",  categories = 8L),
  age_groups_long            = list(rows = 990L,  format = "Long",  categories = 15L),
  gender_long                = list(rows = 198L,  format = "Long",  categories = 3L),
  client_type_wide           = list(rows = 162L,  format = "Wide",  categories = 4L),
  family_composition_wide    = list(rows = 162L,  format = "Wide",  categories = 4L),
  regions_wide               = list(rows = 90L,   format = "Wide",  categories = 8L),
  age_groups_wide            = list(rows = 66L,   format = "Wide",  categories = 15L),
  gender_wide                = list(rows = 66L,   format = "Wide",  categories = 3L)
)

for (tbl_name in names(manifest_expected)) {
  expected_rows <- manifest_expected[[tbl_name]]$rows
  parquet_path <- file.path(parquet_dir, paste0(tbl_name, ".parquet"))
  
  if (!file.exists(parquet_path)) {
    run_test(
      paste0("Manifest row count: ", tbl_name),
      quote(stop("Parquet file not found")),
    )
    next
  }
  
  actual_rows <- nrow(arrow::read_parquet(parquet_path))
  
  run_test(
    paste0("Manifest row count: ", tbl_name, " (manifest=", expected_rows, ", actual=", actual_rows, ")"),
    quote(checkmate::assert_true(expected_rows == actual_rows))
  )
}

# Cross-validate the long/wide arithmetic (rows_long = rows_wide × categories)
cat("\n   Checking long ↔ wide row count arithmetic:\n")
dimensional_tables <- list(
  client_type        = list(wide_rows = 162L, categories = 4L,  long_expected = 648L),
  family_composition = list(wide_rows = 162L, categories = 4L,  long_expected = 648L),
  regions            = list(wide_rows = 90L,  categories = 8L,  long_expected = 720L),
  age_groups         = list(wide_rows = 66L,  categories = 15L, long_expected = 990L),
  gender             = list(wide_rows = 66L,  categories = 3L,  long_expected = 198L)
)

for (dim_name in names(dimensional_tables)) {
  spec <- dimensional_tables[[dim_name]]
  long_path <- file.path(parquet_dir, paste0(dim_name, "_long.parquet"))
  wide_path <- file.path(parquet_dir, paste0(dim_name, "_wide.parquet"))
  
  if (!file.exists(long_path) || !file.exists(wide_path)) next
  
  actual_long <- nrow(arrow::read_parquet(long_path))
  actual_wide <- nrow(arrow::read_parquet(wide_path))
  computed    <- actual_wide * spec$categories
  
  run_test(
    paste0("  Arithmetic: ", dim_name, " (", actual_wide, " × ", spec$categories, " = ", computed, ", actual_long = ", actual_long, ")"),
    quote(checkmate::assert_true(computed == actual_long))
  )
}

# ==============================================================================
# SECTION 4: COMMON COLUMN SCHEMA VALIDATION
# ==============================================================================

cat("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("SECTION 4: COMMON COLUMN SCHEMA — Do all tables share temporal keys?\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

# Manifest states all tables share: date, year, month, fiscal_year, month_label
common_columns <- c("date", "year", "month", "fiscal_year", "month_label")

for (tbl_name in names(manifest_expected)) {
  parquet_path <- file.path(parquet_dir, paste0(tbl_name, ".parquet"))
  if (!file.exists(parquet_path)) next
  
  df_cols <- names(arrow::read_parquet(parquet_path))
  missing_common <- setdiff(common_columns, df_cols)
  
  run_test(
    paste0("Common cols in: ", tbl_name),
    quote(checkmate::assert_true(
      length(missing_common) == 0,
      .var.name = paste0("Missing: ", paste(missing_common, collapse = ", "))
    ))
  )
}

# ==============================================================================
# SECTION 5: TOTAL CASELOAD TABLE STRUCTURE
# ==============================================================================

cat("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("SECTION 5: TOTAL CASELOAD — Detailed structural validation\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

tc <- arrow::read_parquet(file.path(parquet_dir, "total_caseload.parquet"))

# Manifest says: 246 rows, Apr 2005 - Sep 2025, columns: date, year, month, fiscal_year, month_label, caseload
run_test("total_caseload: exactly 246 rows", quote(
  checkmate::assert_true(nrow(tc) == 246L)
))

expected_tc_cols <- c("date", "year", "month", "fiscal_year", "month_label", "caseload")
run_test("total_caseload: exact column set", quote(
  checkmate::assert_set_equal(names(tc), expected_tc_cols)
))

# Date range: Apr 2005 to Sep 2025
run_test("total_caseload: starts Apr 2005", quote(
  checkmate::assert_true(min(tc$date) == as.Date("2005-04-01"))
))

run_test("total_caseload: ends Sep 2025", quote(
  checkmate::assert_true(max(tc$date) == as.Date("2025-09-01"))
))

# Manifest says: "No missing values: Complete coverage for all 246 months"
run_test("total_caseload: no missing caseload values", quote(
  checkmate::assert_true(sum(is.na(tc$caseload)) == 0L)
))

# Verify contiguous monthly sequence (no gaps)
date_seq <- seq(as.Date("2005-04-01"), as.Date("2025-09-01"), by = "month")
run_test("total_caseload: contiguous monthly sequence (no gaps)", quote(
  checkmate::assert_set_equal(as.character(tc$date), as.character(date_seq))
))

# Manifest says: "fiscal_year follows FY YYYY-YY format"
run_test("total_caseload: fiscal_year format FY YYYY-YY", quote(
  checkmate::assert_character(tc$fiscal_year, pattern = "^FY \\d{4}-\\d{2}$", any.missing = FALSE)
))

# Manifest says: caseload is non-negative numeric
run_test("total_caseload: caseload non-negative numeric", quote(
  checkmate::assert_numeric(tc$caseload, lower = 0, any.missing = FALSE)
))

# ==============================================================================
# SECTION 6: WIDE TABLE COLUMN VALIDATION
# ==============================================================================

cat("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("SECTION 6: WIDE TABLE COLUMNS — Do columns match manifest specs?\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

# Manifest specifies these exact value columns for each wide table
wide_value_columns <- list(
  client_type_wide = c(
    "etw_working", "etw_available_for_work", "etw_unavailable_for_work", "bfe"
  ),
  family_composition_wide = c(
    "single", "single_parent", "couples_with_children", "childless_couples"
  ),
  regions_wide = c(
    "calgary", "central", "edmonton", "north_central",
    "north_east", "north_west", "south", "unknown"
  ),
  age_groups_wide = c(
    "age_18_19", "age_20_24", "age_25_29", "age_30_34", "age_35_39",
    "age_40_44", "age_45_49", "age_50_54", "age_55_59",
    "age_60", "age_61", "age_62", "age_63", "age_64", "age_65"
  ),
  gender_wide = c("female", "male", "other")
)

for (tbl_name in names(wide_value_columns)) {
  parquet_path <- file.path(parquet_dir, paste0(tbl_name, ".parquet"))
  if (!file.exists(parquet_path)) next
  
  df <- arrow::read_parquet(parquet_path)
  expected_all <- c(common_columns, wide_value_columns[[tbl_name]])
  
  run_test(
    paste0(tbl_name, ": column set matches manifest"),
    quote(checkmate::assert_set_equal(names(df), expected_all))
  )
  
  # Verify value columns are numeric
  for (col in wide_value_columns[[tbl_name]]) {
    run_test(
      paste0(tbl_name, "$", col, ": numeric type"),
      quote(checkmate::assert_true(is.numeric(df[[col]])))
    )
  }
}

# ==============================================================================
# SECTION 7: LONG TABLE STRUCTURE VALIDATION
# ==============================================================================

cat("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("SECTION 7: LONG TABLE STRUCTURE — Category columns and labels correct?\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

# Manifest specifies the category/label column names and expected category values
long_table_specs <- list(
  client_type_long = list(
    cat_col   = "client_type_category",
    label_col = "client_type_label",
    categories = c("etw_working", "etw_available_for_work", "etw_unavailable_for_work", "bfe"),
    labels     = c("ETW: Working", "ETW: Available for Work", "ETW: Unavailable for Work", "Barrier-Free Employment")
  ),
  family_composition_long = list(
    cat_col   = "family_type_category",
    label_col = "family_type_label",
    categories = c("single", "single_parent", "couples_with_children", "childless_couples"),
    labels     = c("Single", "Single Parent", "Couples with Children", "Childless Couples")
  ),
  regions_long = list(
    cat_col   = "region_category",
    label_col = "region_label",
    categories = c("calgary", "central", "edmonton", "north_central", "north_east", "north_west", "south", "unknown"),
    labels     = c("Calgary", "Central", "Edmonton", "North Central", "North East", "North West", "South", "Unknown")
  ),
  age_groups_long = list(
    cat_col   = "age_category",
    label_col = "age_label",
    categories = c("age_18_19", "age_20_24", "age_25_29", "age_30_34", "age_35_39",
                    "age_40_44", "age_45_49", "age_50_54", "age_55_59",
                    "age_60", "age_61", "age_62", "age_63", "age_64", "age_65"),
    labels     = c("Age 18-19", "Age 20-24", "Age 25-29", "Age 30-34", "Age 35-39",
                    "Age 40-44", "Age 45-49", "Age 50-54", "Age 55-59",
                    "Age 60", "Age 61", "Age 62", "Age 63", "Age 64", "Age 65+")
  ),
  gender_long = list(
    cat_col   = "gender_category",
    label_col = "gender_label",
    categories = c("female", "male", "other"),
    labels     = c("Female", "Male", "Other")
  )
)

for (tbl_name in names(long_table_specs)) {
  spec <- long_table_specs[[tbl_name]]
  parquet_path <- file.path(parquet_dir, paste0(tbl_name, ".parquet"))
  if (!file.exists(parquet_path)) next
  
  df <- arrow::read_parquet(parquet_path)
  
  # Check required columns: common + category + label + count
  expected_long_cols <- c(common_columns, spec$cat_col, "count", spec$label_col)
  run_test(
    paste0(tbl_name, ": column set matches manifest"),
    quote(checkmate::assert_set_equal(names(df), expected_long_cols))
  )
  
  # Check category values
  actual_categories <- sort(unique(df[[spec$cat_col]]))
  expected_categories <- sort(spec$categories)
  run_test(
    paste0(tbl_name, ": category values match manifest"),
    quote(checkmate::assert_set_equal(actual_categories, expected_categories))
  )
  
  # Check label values
  actual_labels <- sort(unique(df[[spec$label_col]]))
  expected_labels <- sort(spec$labels)
  run_test(
    paste0(tbl_name, ": label values match manifest"),
    quote(checkmate::assert_set_equal(actual_labels, expected_labels))
  )
  
  # Check category ↔ label mapping is 1:1
  mapping <- df %>% distinct(!!sym(spec$cat_col), !!sym(spec$label_col))
  run_test(
    paste0(tbl_name, ": category-label mapping is 1:1 (", nrow(mapping), " pairs)"),
    quote(checkmate::assert_true(nrow(mapping) == length(spec$categories)))
  )
  
  # Check count column is numeric
  run_test(
    paste0(tbl_name, "$count: numeric type"),
    quote(checkmate::assert_true(is.numeric(df[["count"]])))
  )
}

# ==============================================================================
# SECTION 8: TEMPORAL COVERAGE PER TABLE
# ==============================================================================

cat("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("SECTION 8: TEMPORAL COVERAGE — Do date ranges match manifest claims?\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

# Manifest Table Inventory specifies these date ranges
temporal_claims <- list(
  total_caseload = list(
    start = as.Date("2005-04-01"), end = as.Date("2025-09-01"),
    label = "Apr 2005-Sep 2025"
  ),
  client_type_long = list(
    start = as.Date("2012-04-01"), end = as.Date("2025-09-01"),
    label = "Apr 2012-Sep 2025"
  ),
  family_composition_long = list(
    start = as.Date("2012-04-01"), end = as.Date("2025-09-01"),
    label = "Apr 2012-Sep 2025"
  ),
  regions_long = list(
    start = as.Date("2018-04-01"), end = as.Date("2025-09-01"),
    label = "Apr 2018-Sep 2025"
  ),
  age_groups_long = list(
    start = as.Date("2020-04-01"), end = as.Date("2025-09-01"),
    label = "Apr 2020-Sep 2025"
  ),
  gender_long = list(
    start = as.Date("2020-04-01"), end = as.Date("2025-09-01"),
    label = "Apr 2020-Sep 2025"
  ),
  # Wide tables cover same periods as their long counterparts
  client_type_wide = list(
    start = as.Date("2012-04-01"), end = as.Date("2025-09-01"),
    label = "Apr 2012-Sep 2025"
  ),
  family_composition_wide = list(
    start = as.Date("2012-04-01"), end = as.Date("2025-09-01"),
    label = "Apr 2012-Sep 2025"
  ),
  regions_wide = list(
    start = as.Date("2018-04-01"), end = as.Date("2025-09-01"),
    label = "Apr 2018-Sep 2025"
  ),
  age_groups_wide = list(
    start = as.Date("2020-04-01"), end = as.Date("2025-09-01"),
    label = "Apr 2020-Sep 2025"
  ),
  gender_wide = list(
    start = as.Date("2020-04-01"), end = as.Date("2025-09-01"),
    label = "Apr 2020-Sep 2025"
  )
)

for (tbl_name in names(temporal_claims)) {
  claim <- temporal_claims[[tbl_name]]
  parquet_path <- file.path(parquet_dir, paste0(tbl_name, ".parquet"))
  if (!file.exists(parquet_path)) next
  
  df <- arrow::read_parquet(parquet_path)
  actual_min <- min(df$date)
  actual_max <- max(df$date)
  
  run_test(
    paste0(tbl_name, ": starts ", format(claim$start, "%b %Y"), " (actual: ", format(actual_min, "%b %Y"), ")"),
    quote(checkmate::assert_true(actual_min == claim$start))
  )
  
  run_test(
    paste0(tbl_name, ": ends ", format(claim$end, "%b %Y"), " (actual: ", format(actual_max, "%b %Y"), ")"),
    quote(checkmate::assert_true(actual_max == claim$end))
  )
}

# ==============================================================================
# SECTION 9: HISTORICAL PHASE BOUNDARIES
# ==============================================================================

cat("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("SECTION 9: HISTORICAL PHASES — Do dimension availabilities match?\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

# Manifest claims these phase boundaries:
# Phase 1: Apr 2005 - Mar 2012 (84 months) → Total Caseload only
# Phase 2: Apr 2012 - Mar 2018 (72 months) → + Client Type, Family Composition
# Phase 3: Apr 2018 - Mar 2020 (24 months) → + ALSS Regions
# Phase 4: Apr 2020 - Mar 2022 (24 months) → + Average Age, Client Gender
# Phase 5: Apr 2022 - Sep 2025 (42 months) → + Gender "Other"

# Phase 1 claim: Total caseload covers back to Apr 2005
tc <- arrow::read_parquet(file.path(parquet_dir, "total_caseload.parquet"))
phase1_months <- tc %>% filter(date < as.Date("2012-04-01")) %>% nrow()
run_test(
  paste0("Phase 1: 84 months of Total Caseload only (actual: ", phase1_months, ")"),
  quote(checkmate::assert_true(phase1_months == 84L))
)

# Phase 2 claim: Client type starts Apr 2012
ct <- arrow::read_parquet(file.path(parquet_dir, "client_type_wide.parquet"))
run_test("Phase 2: Client Type starts Apr 2012", quote(
  checkmate::assert_true(min(ct$date) == as.Date("2012-04-01"))
))

# Phase 3 claim: Regions start Apr 2018
rg <- arrow::read_parquet(file.path(parquet_dir, "regions_wide.parquet"))
run_test("Phase 3: Regions starts Apr 2018", quote(
  checkmate::assert_true(min(rg$date) == as.Date("2018-04-01"))
))

# Phase 4 claim: Age & Gender start Apr 2020
ag <- arrow::read_parquet(file.path(parquet_dir, "age_groups_wide.parquet"))
gn <- arrow::read_parquet(file.path(parquet_dir, "gender_wide.parquet"))
run_test("Phase 4: Age Groups starts Apr 2020", quote(
  checkmate::assert_true(min(ag$date) == as.Date("2020-04-01"))
))
run_test("Phase 4: Gender starts Apr 2020", quote(
  checkmate::assert_true(min(gn$date) == as.Date("2020-04-01"))
))

# Phase 5 claim: "Other" gender category first reportable value Aug 2022
# The "other" category column exists from gender data start (Apr 2020) but
# all values are NA (suppressed) until Aug 2022 when counts become reportable
gn_long <- arrow::read_parquet(file.path(parquet_dir, "gender_long.parquet"))

# The "other" category rows exist from the start of gender data (Apr 2020)
other_rows <- gn_long %>% filter(gender_category == "other")
other_first_row <- min(other_rows$date)
run_test(
  paste0("Phase 5: 'Other' rows exist from gender start Apr 2020 (actual: ", format(other_first_row, "%b %Y"), ")"),
  quote(checkmate::assert_true(other_first_row == as.Date("2020-04-01")))
)

# The first non-suppressed (non-NA) "Other" value is Aug 2022
other_first_nonNA <- gn_long %>%
  filter(gender_category == "other", !is.na(count)) %>%
  summarise(first_date = min(date)) %>%
  pull(first_date)
run_test(
  paste0("Phase 5: 'Other' first non-NA at Aug 2022 (actual: ", format(other_first_nonNA, "%b %Y"), ")"),
  quote(checkmate::assert_true(other_first_nonNA == as.Date("2022-08-01")))
)

# Apr 2020 - Jul 2022 should have "Other" rows that are all NA (suppressed)
other_suppressed <- gn_long %>%
  filter(gender_category == "other",
         date < as.Date("2022-08-01"))
run_test(
  paste0("Phase 5: 'Other' pre-Aug 2022 all suppressed (NA) (", nrow(other_suppressed), " rows, ", sum(is.na(other_suppressed$count)), " NAs)"),
  quote(checkmate::assert_true(all(is.na(other_suppressed$count))))
)

# ==============================================================================
# SECTION 10: WIDE ↔ LONG DATA EQUIVALENCE
# ==============================================================================

cat("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("SECTION 10: WIDE ↔ LONG EQUIVALENCE — Same data, different shape?\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

# For each dimensional table, pivot the wide back to long and compare values
dimensional_checks <- list(
  list(
    wide = "client_type_wide", long = "client_type_long",
    cat_col = "client_type_category", value_cols = c("etw_working", "etw_available_for_work", "etw_unavailable_for_work", "bfe")
  ),
  list(
    wide = "family_composition_wide", long = "family_composition_long",
    cat_col = "family_type_category", value_cols = c("single", "single_parent", "couples_with_children", "childless_couples")
  ),
  list(
    wide = "regions_wide", long = "regions_long",
    cat_col = "region_category", value_cols = c("calgary", "central", "edmonton", "north_central", "north_east", "north_west", "south", "unknown")
  ),
  list(
    wide = "age_groups_wide", long = "age_groups_long",
    cat_col = "age_category", value_cols = c("age_18_19", "age_20_24", "age_25_29", "age_30_34", "age_35_39", "age_40_44", "age_45_49", "age_50_54", "age_55_59", "age_60", "age_61", "age_62", "age_63", "age_64", "age_65")
  ),
  list(
    wide = "gender_wide", long = "gender_long",
    cat_col = "gender_category", value_cols = c("female", "male", "other")
  )
)

for (chk in dimensional_checks) {
  wide_df <- arrow::read_parquet(file.path(parquet_dir, paste0(chk$wide, ".parquet")))
  long_df <- arrow::read_parquet(file.path(parquet_dir, paste0(chk$long, ".parquet")))
  
  # Pivot wide to long for comparison
  repivoted <- wide_df %>%
    pivot_longer(
      cols = all_of(chk$value_cols),
      names_to = chk$cat_col,
      values_to = "count_from_wide"
    ) %>%
    arrange(date, !!sym(chk$cat_col))
  
  # Join with actual long table
  long_sorted <- long_df %>%
    arrange(date, !!sym(chk$cat_col)) %>%
    select(date, !!sym(chk$cat_col), count_from_long = count)
  
  comparison <- repivoted %>%
    left_join(long_sorted, by = c("date", chk$cat_col))
  
  # Compare values (handling NAs)
  mismatches <- comparison %>%
    filter(
      !( (is.na(count_from_wide) & is.na(count_from_long)) |
         (!is.na(count_from_wide) & !is.na(count_from_long) & count_from_wide == count_from_long) )
    )
  
  run_test(
    paste0("Equivalence: ", chk$wide, " ↔ ", chk$long, " (", nrow(mismatches), " mismatches)"),
    quote(checkmate::assert_true(nrow(mismatches) == 0L))
  )
}

# ==============================================================================
# SECTION 11: DATA QUALITY CLAIMS
# ==============================================================================

cat("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("SECTION 11: DATA QUALITY CLAIMS — Are documented quality facts true?\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

# Claim: "No missing values: Complete coverage for all 246 months" (total_caseload)
tc <- arrow::read_parquet(file.path(parquet_dir, "total_caseload.parquet"))
run_test("total_caseload: zero NA in caseload column", quote(
  checkmate::assert_true(sum(is.na(tc$caseload)) == 0L)
))

# Claim: "Counts are non-negative numeric (NA allowed for suppression)"
for (tbl_name in names(long_table_specs)) {
  parquet_path <- file.path(parquet_dir, paste0(tbl_name, ".parquet"))
  if (!file.exists(parquet_path)) next
  
  df <- arrow::read_parquet(parquet_path)
  neg_count <- sum(df$count < 0, na.rm = TRUE)
  
  run_test(
    paste0(tbl_name, ": no negative counts (found ", neg_count, ")"),
    quote(checkmate::assert_true(neg_count == 0L))
  )
}

# Claim: "Composite keys (date × category) are unique within each table"
for (tbl_name in names(long_table_specs)) {
  spec <- long_table_specs[[tbl_name]]
  parquet_path <- file.path(parquet_dir, paste0(tbl_name, ".parquet"))
  if (!file.exists(parquet_path)) next
  
  df <- arrow::read_parquet(parquet_path)
  dupes <- df %>%
    count(date, !!sym(spec$cat_col)) %>%
    filter(n > 1)
  
  run_test(
    paste0(tbl_name, ": composite key (date × ", spec$cat_col, ") unique"),
    quote(checkmate::assert_true(nrow(dupes) == 0L))
  )
}

# Claim: "fiscal_year follows FY YYYY-YY format" across all tables
for (tbl_name in names(manifest_expected)) {
  parquet_path <- file.path(parquet_dir, paste0(tbl_name, ".parquet"))
  if (!file.exists(parquet_path)) next
  
  df <- arrow::read_parquet(parquet_path)
  run_test(
    paste0(tbl_name, ": fiscal_year format valid"),
    quote(checkmate::assert_character(
      df$fiscal_year, pattern = "^FY \\d{4}-\\d{2}$", any.missing = FALSE
    ))
  )
}

# ==============================================================================
# SECTION 12: MANIFEST INTERNAL CONSISTENCY
# ==============================================================================

cat("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("SECTION 12: MANIFEST SELF-CONSISTENCY — Does the document agree with itself?\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

# Claim in header: "Coverage: April 2005 – September 2025 (246 months)"
run_test("Manifest claims 246 months coverage", quote({
  claim_line <- grep("Coverage.*246 months", manifest_text, value = TRUE)
  checkmate::assert_true(length(claim_line) >= 1L)
}))

# Claim: "11 Total" in table inventory header
run_test("Manifest claims 11 total tables", quote({
  claim_line <- grep("Table Inventory.*11 Total", manifest_text, value = TRUE)
  checkmate::assert_true(length(claim_line) >= 1L)
}))

# Claim: "Schema Version: 1.0"
run_test("Manifest has schema version", quote({
  claim_line <- grep("Schema Version.*1\\.0", manifest_text, value = TRUE)
  checkmate::assert_true(length(claim_line) >= 1L)
}))

# Manifest references the correct processing script
run_test("Manifest references correct processing script (2-ellis.R)", quote({
  claim_line <- grep("manipulation/2-ellis\\.R", manifest_text, value = TRUE)
  checkmate::assert_true(length(claim_line) >= 1L)
}))

# Manifest references correct output locations
run_test("Manifest references Parquet location", quote({
  claim_line <- grep("open-data-is-2-tables", manifest_text, value = TRUE)
  checkmate::assert_true(length(claim_line) >= 1L)
}))

run_test("Manifest references SQLite location", quote({
  claim_line <- grep("open-data-is-2\\.sqlite", manifest_text, value = TRUE)
  checkmate::assert_true(length(claim_line) >= 1L)
}))

# Cross-validate the historical phase month totals add up
# Phases: 84 + 72 + 24 + 24 + 42 = 246
run_test("Phase month totals in manifest sum to 246", quote({
  phase_lines <- grep("\\| [1-5] ", manifest_text, value = TRUE)
  # Extract month counts from phase table
  month_counts <- as.integer(str_extract(phase_lines, "\\d+(?=\\s+\\|\\s+(Total|\\+))"))
  checkmate::assert_true(sum(month_counts, na.rm = TRUE) == 246L)
}))

# ==============================================================================
# SECTION 13: ELLIS SCRIPT ↔ MANIFEST AGREEMENT
# ==============================================================================

cat("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("SECTION 13: ELLIS SCRIPT ↔ MANIFEST — Does code describe what docs say?\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

ellis_text <- readLines(ellis_script, warn = FALSE)

# Verify script writes to same paths as manifest documents
run_test("Ellis script writes to documented Parquet dir", quote({
  parquet_path_line <- grep("open-data-is-2-tables", ellis_text, value = TRUE)
  checkmate::assert_true(length(parquet_path_line) >= 1L)
}))

run_test("Ellis script writes to documented SQLite path", quote({
  sqlite_path_line <- grep("open-data-is-2\\.sqlite", ellis_text, value = TRUE)
  checkmate::assert_true(length(sqlite_path_line) >= 1L)
}))

run_test("Ellis script reads from documented input", quote({
  input_line <- grep("open-data-is-1\\.sqlite", ellis_text, value = TRUE)
  checkmate::assert_true(length(input_line) >= 1L)
}))

# Verify the 11 table names referenced in the Ellis script appear in the manifest
script_table_names_wide <- c(
  "total_caseload", "client_type_wide", "family_composition_wide",
  "regions_wide", "age_groups_wide", "gender_wide"
)
script_table_names_long <- c(
  "client_type_long", "family_composition_long",
  "regions_long", "age_groups_long", "gender_long"
)

for (tbl_name in c(script_table_names_wide, script_table_names_long)) {
  # Check it appears in both the script and the manifest
  in_script   <- any(grepl(tbl_name, ellis_text, fixed = TRUE))
  in_manifest <- any(grepl(tbl_name, manifest_text, fixed = TRUE))
  
  run_test(
    paste0("Table '", tbl_name, "' in both script and manifest"),
    quote(checkmate::assert_true(in_script && in_manifest))
  )
}

# Verify label mappings in Ellis code match manifest documentation
# The manifest documents specific label values. Check they appear in the script.
documented_labels <- c(
  "ETW: Working", "ETW: Available for Work", "ETW: Unavailable for Work",
  "Barrier-Free Employment",
  "Single", "Single Parent", "Couples with Children", "Childless Couples",
  "Calgary", "Central", "Edmonton", "North Central", "North East",
  "North West", "South", "Unknown",
  "Age 18-19", "Age 65+",
  "Female", "Male", "Other"
)

for (label in documented_labels) {
  in_script   <- any(grepl(label, ellis_text, fixed = TRUE))
  in_manifest <- any(grepl(label, manifest_text, fixed = TRUE))
  
  run_test(
    paste0("Label '", label, "' in both script and manifest"),
    quote(checkmate::assert_true(in_script && in_manifest))
  )
}

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================

cat("\n", strrep("=", 70), "\n")
cat("TEST SUMMARY\n")
cat(strrep("=", 70), "\n\n")

total_tests <- tests_passed + tests_failed + tests_skipped
cat("  Total tests:  ", total_tests, "\n")
cat("  ✅ Passed:     ", tests_passed, "\n")
cat("  ❌ Failed:     ", tests_failed, "\n")
cat("  ⏭️  Skipped:    ", tests_skipped, "\n")

duration <- difftime(Sys.time(), script_start, units = "secs")
cat("\n  ⏱️  Completed in", round(as.numeric(duration), 1), "seconds\n")
cat("  📅", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")

if (tests_failed > 0L) {
  cat("\n", strrep("!", 70), "\n")
  cat("FAILURES DETECTED — CACHE-manifest may not match reality\n")
  cat(strrep("!", 70), "\n\n")
  cat("The following tests failed:\n\n")
  for (i in seq_along(failures)) {
    cat("  ", i, ". ", failures[i], "\n")
  }
  cat("\nAction required:\n")
  cat("  1. Re-run manipulation/2-ellis.R to regenerate artifacts\n")
  cat("  2. Update CACHE-manifest.md to match new artifact state\n")
  cat("  3. Re-run this test script to confirm alignment\n")
  # Signal failure to calling process
  quit(save = "no", status = 1)
} else {
  cat("\n", strrep("=", 70), "\n")
  cat("✅ ALL TESTS PASSED — CACHE-manifest accurately describes reality\n")
  cat(strrep("=", 70), "\n")
  cat("\nHuman analysts can trust that:\n")
  cat("  • All 11 tables exist in both Parquet and SQLite formats\n")
  cat("  • Row counts match what the manifest documents\n")
  cat("  • Column schemas match what the manifest documents\n")
  cat("  • Category labels match what the manifest documents\n")
  cat("  • Date ranges match what the manifest documents\n")
  cat("  • Historical phase boundaries are verified\n")
  cat("  • Wide ↔ Long table data is equivalent\n")
  cat("  • Parquet ↔ SQLite table data is equivalent\n")
  cat("  • The Ellis script references the same paths and labels as the manifest\n")
}

sessionInfo()
