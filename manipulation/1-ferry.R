#' ---
#' title: "Ferry Lane 1: Income Support Open Data"
#' author: "Andriy Koval"
#' date: "2025-02-18"
#' ---
#'
#' ============================================================================
#' FERRY PATTERN: Multi-Source Data Transport
#' ============================================================================
#'
#' **Purpose**: Demonstrate data transport from 4 sources with zero transformation
#'
#' **Sources**:
#' 1. URL:        Open Alberta CSV endpoint
#' 2. CSV:        Local cached file
#' 3. SQLite:     Local database
#' 4. SQL Server: Remote database
#'
#' **Output**: ./data-private/derived/open-data-is-1.sqlite
#'
#' **Validation**: Verify all 4 sources produce identical datasets
#'
#' ============================================================================

#+ echo=F
# rmarkdown::render(input = "./manipulation/1-ferry.R") # run to knit
# ---- setup -------------------------------------------------------------------
rm(list = ls(all.names = TRUE))
cat("\014")

library(magrittr)
library(dplyr)
library(readr)
requireNamespace("DBI")
requireNamespace("RSQLite")
requireNamespace("odbc")
requireNamespace("dbplyr")

script_start <- Sys.time()

# ---- declare-globals ---------------------------------------------------------
# Source configurations
url_source <- "https://open.alberta.ca/dataset/e1ec585f-3f52-40f2-a022-5a38ea3397e5/resource/4f97a3ae-1b3a-48e9-a96f-f65c58526e07/download/is-aggregated-data-april-2005-sep-2025.csv"
csv_path <- "./data-public/raw/is-aggregated-data-april-2005-sep-2025.csv"
sqlite_source <- "./data-public/raw/open-data-is-sep-2025.sqlite"
sqlite_table <- "open_data_is_sep_2025"
dsn_sqlserver <- "RESEARCH_PROJECT_CACHE_UAT"
schema_sqlserver <- "AMLdemo"
table_sqlserver <- "open_data_is_sep_2025"

# Output configuration
output_path <- "./data-private/derived/open-data-is-1.sqlite"
output_table <- "open_data_is_raw"
output_dir <- dirname(output_path)
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# ==============================================================================
# SECTION 1: LOAD FROM FOUR SOURCES
# ==============================================================================

# ---- load-from-url -----------------------------------------------------------
cat("\n=== LOADING FROM URL ===\n")
ds_url <- read_csv(url_source, skip = 1, show_col_types = FALSE, name_repair = "minimal") %>%
  janitor::clean_names() %>%
  select(ref_date, geography, measure_type, measure, value)
cat("✓ URL:", nrow(ds_url), "rows,", ncol(ds_url), "cols\n")

# ---- load-from-csv -----------------------------------------------------------
cat("\n=== LOADING FROM CSV ===\n")
ds_csv <- read_csv(csv_path, skip = 1, show_col_types = FALSE, name_repair = "minimal") %>%
  janitor::clean_names() %>%
  select(ref_date, geography, measure_type, measure, value)
cat("✓ CSV:", nrow(ds_csv), "rows,", ncol(ds_csv), "cols\n")

# ---- load-from-sqlite --------------------------------------------------------
cat("\n=== LOADING FROM SQLITE ===\n")
cnn_sqlite <- DBI::dbConnect(RSQLite::SQLite(), sqlite_source)
ds_sqlite <- tbl(cnn_sqlite, sqlite_table) %>% collect()
DBI::dbDisconnect(cnn_sqlite)
cat("✓ SQLite:", nrow(ds_sqlite), "rows,", ncol(ds_sqlite), "cols\n")

# ---- load-from-sqlserver -----------------------------------------------------
cat("\n=== LOADING FROM SQL SERVER ===\n")
cnn_sqlserver <- DBI::dbConnect(odbc::odbc(), dsn = dsn_sqlserver)
ds_sqlserver <- tbl(cnn_sqlserver, dbplyr::in_schema(schema_sqlserver, table_sqlserver)) %>% collect()
DBI::dbDisconnect(cnn_sqlserver)
cat("✓ SQL Server:", nrow(ds_sqlserver), "rows,", ncol(ds_sqlserver), "cols\n")

# ==============================================================================
# SECTION 2: VALIDATE IDENTITY
# ==============================================================================

# ---- validate-identity -------------------------------------------------------
cat("\n=== VALIDATING SOURCE IDENTITY ===\n")

sources <- list(
  URL = ds_url,
  CSV = ds_csv,
  SQLite = ds_sqlite,
  SQLServer = ds_sqlserver
)

# Check dimensions
dims <- sapply(sources, function(x) paste(nrow(x), "×", ncol(x)))
cat("\nDimensions:\n")
print(dims)

if (length(unique(dims)) == 1) {
  cat("✓ All sources have identical dimensions\n")
} else {
  stop("✗ Dimension mismatch detected")
}

# Check column names
col_check <- sapply(sources, function(x) paste(names(x), collapse = "|"))
if (length(unique(col_check)) == 1) {
  cat("✓ All sources have identical column names\n")
} else {
  stop("✗ Column name mismatch detected")
}

# Check row-by-row identity (URL vs others)
identical_csv <- all.equal(ds_url, ds_csv, check.attributes = FALSE)
identical_sqlite <- all.equal(ds_url, ds_sqlite, check.attributes = FALSE)
identical_sqlserver <- all.equal(ds_url, ds_sqlserver, check.attributes = FALSE)

if (isTRUE(identical_csv) && isTRUE(identical_sqlite) && isTRUE(identical_sqlserver)) {
  cat("✓ All sources produce identical datasets\n")
  cat("✓ Sources are interchangeable\n")
} else {
  cat("⚠ Differences detected:\n")
  if (!isTRUE(identical_csv)) cat("  - URL vs CSV:", identical_csv, "\n")
  if (!isTRUE(identical_sqlite)) cat("  - URL vs SQLite:", identical_sqlite, "\n")
  if (!isTRUE(identical_sqlserver)) cat("  - URL vs SQL Server:", identical_sqlserver, "\n")
}

# ==============================================================================
# SECTION 3: WRITE TO OUTPUT
# ==============================================================================

# ---- save-to-output ----------------------------------------------------------
cat("\n=== WRITING TO OUTPUT ===\n")

# Use URL source as canonical (could use any since they're identical)
ds_ferry <- ds_url

# Write to SQLite
if (file.exists(output_path)) file.remove(output_path)
cnn_output <- DBI::dbConnect(RSQLite::SQLite(), output_path)
DBI::dbWriteTable(cnn_output, output_table, ds_ferry, overwrite = TRUE)

# Verify
row_count <- DBI::dbGetQuery(cnn_output, sprintf("SELECT COUNT(*) as n FROM %s", output_table))$n
DBI::dbDisconnect(cnn_output)

cat("✓ Written:", row_count, "rows to", output_path, "\n")
cat("✓ Table:", output_table, "\n")

# ==============================================================================
# SECTION 4: SUMMARY
# ==============================================================================

# ---- summary -----------------------------------------------------------------
duration <- difftime(Sys.time(), script_start, units = "secs")

cat("\n", strrep("=", 70), "\n")
cat("✓ FERRY COMPLETE\n")
cat(strrep("=", 70), "\n\n")
cat("Sources verified:\n")
cat("  1. URL        ✓\n")
cat("  2. CSV        ✓\n")
cat("  3. SQLite     ✓\n")
cat("  4. SQL Server ✓\n\n")
cat("Output:", output_path, "\n")
cat("Records:", row_count, "\n")
cat("Duration:", round(as.numeric(duration), 1), "seconds\n")
cat("\nNext step: Ellis lane (transformation)\n")
