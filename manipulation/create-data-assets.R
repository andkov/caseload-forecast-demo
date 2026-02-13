#' ---
#' title: "Create Data Assets for Multi-Source Ferry Testing"
#' author: "Andriy Koval"
#' date: "2025-02-13"
#' ---
#'
#' ============================================================================
#' PURPOSE: Create SQLite and SQL Server data sources for ferry lane testing
#' ============================================================================
#'
#' This script prepares data assets to test a multi-source ferry pattern that
#' can import from four different sources: CSV, URL, SQLite, and SQL Server.
#'
#' **Creates:**
#' 1. SQLite database: ./data-public/raw/open-data-is.sqlite
#'    - Table: open_data_is_sep_2025
#'    - Source: is-aggregated-data-april-2005-sep-2025.csv
#' 
#' 2. SQL Server table: research_project_cache._TEST.open_data_is_sep_2025
#'    - Via ODBC connection
#'    - Identical contents to CSV source
#'
#' **Dependencies:**
#' - Source CSV must exist at ./data-public/raw/is-aggregated-data-april-2005-sep-2025.csv
#' - SQL Server ODBC DSN: RESEARCH_PROJECT_CACHE_UAT (or similar)
#' - Packages: DBI, RSQLite, odbc, readr
#'
#' **Run once to set up test assets, then use ferry lane to import**
#' ============================================================================

#+ echo=F
# rmarkdown::render(input = "./manipulation/create-data-assets.R") # run to knit
# ---- setup -------------------------------------------------------------------
rm(list = ls(all.names = TRUE)) # Clear memory
cat("\014") # Clear console
cat("Working directory:", getwd(), "\n") # Verify root

# ---- load-packages -----------------------------------------------------------
library(magrittr) # for %>% pipe
requireNamespace("DBI")
requireNamespace("RSQLite")
requireNamespace("odbc")
requireNamespace("readr")
requireNamespace("dplyr")
requireNamespace("janitor")  # For clean_names()

# ---- declare-globals ---------------------------------------------------------
# Source CSV file
csv_path <- "./data-public/raw/is-aggregated-data-april-2005-sep-2025.csv"

# SQLite database configuration
sqlite_dir <- "./data-public/raw/"
sqlite_file <- "open-data-is.sqlite"
sqlite_path <- file.path(sqlite_dir, sqlite_file)
sqlite_table <- "open_data_is_sep_2025"

# SQL Server configuration
dsn_cache <- "RESEARCH_PROJECT_CACHE_UAT"  # Adjust if your DSN name differs
schema_cache <- "AMLdemo"
sqlserver_table <- "open_data_is_sep_2025"

# Timing
script_start_time <- Sys.time()

# ---- declare-functions -------------------------------------------------------
# Helper: Log record counts for validation
log_operation <- function(stage, dataset, destination = NULL) {
  cat(sprintf("📊 [%s] %d rows, %d cols", stage, nrow(dataset), ncol(dataset)))
  if (!is.null(destination)) cat(" → ", destination)
  cat("\n")
}

# Helper: Drop table if exists (SQLite)
drop_table_sqlite <- function(connection, table_name) {
  if (DBI::dbExistsTable(connection, table_name)) {
    DBI::dbRemoveTable(connection, table_name)
    cat(sprintf("✅ Dropped existing table: %s\n", table_name))
  }
}

# Helper: Drop table if exists (SQL Server)
drop_table_sqlserver <- function(connection, schema, table_name) {
  full_table_name <- paste0("[", schema, "].[", table_name, "]")
  
  check_query <- sprintf("
    IF OBJECT_ID('%s.%s', 'U') IS NOT NULL
      SELECT 1 AS table_exists
    ELSE
      SELECT 0 AS table_exists
  ", schema, table_name)
  
  result <- DBI::dbGetQuery(connection, check_query)
  
  if (result$table_exists == 1) {
    drop_query <- sprintf("DROP TABLE %s", full_table_name)
    DBI::dbExecute(connection, drop_query)
    cat(sprintf("✅ Dropped existing table: %s\n", full_table_name))
  }
}

# ==============================================================================
# SECTION 1: LOAD SOURCE DATA
# ==============================================================================

# ---- load-csv ----------------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("STEP 1: Load Source CSV\n")
cat(strrep("=", 70), "\n")

if (!file.exists(csv_path)) {
  stop("❌ Source CSV not found: ", csv_path, "\n",
       "   Please ensure the file exists before running this script.")
}

# Read CSV with readr for consistent parsing
# Note: First row is a title, second row contains column names
# Skip first row, use second row as column names
ds_source <- readr::read_csv(
  file = csv_path,
  skip = 1,              # Skip title row
  col_names = TRUE,      # Use first row after skip (original line 2) as column names
  show_col_types = FALSE,
  name_repair = "minimal"  # Keep original names without modification
)

log_operation("CSV loaded", ds_source, csv_path)
cat("\n🔍 Data structure (raw):\n")
dplyr::glimpse(ds_source)

# Show first few column names for verification
cat("\n📋 Original column names:\n")
cat(paste("  ", names(ds_source)[1:min(5, ncol(ds_source))]), sep = "\n")

# Clean column names to ensure database compatibility
# Empty names and special characters cause issues with SQLite/SQL Server
cat("\n\n🧹 Cleaning column names for database compatibility...\n")
ds_source <- ds_source %>% 
  janitor::clean_names()

cat("📋 Cleaned column names:\n")
cat(paste("  ", names(ds_source)[1:min(5, ncol(ds_source))]), sep = "\n")

# Remove unnecessary columns (empty columns that are all NA)
cat("\n\n🗑️  Removing unnecessary columns...\n")
ds_source <- ds_source %>%
  dplyr::select(ref_date, geography, measure_type, measure, value)

cat(sprintf("✅ Kept %d essential columns\n", ncol(ds_source)))
cat("📋 Final columns:\n")
cat(paste("  ", names(ds_source)), sep = "\n")
cat("\n")

# ==============================================================================
# SECTION 2: CREATE SQLITE DATABASE
# ==============================================================================

# ---- create-sqlite -----------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("STEP 2: Create SQLite Database\n")
cat(strrep("=", 70), "\n")

# Ensure directory exists
if (!dir.exists(sqlite_dir)) {
  dir.create(sqlite_dir, recursive = TRUE)
  cat(sprintf("📁 Created directory: %s\n", sqlite_dir))
}

# Connect to SQLite database (creates if doesn't exist)
cnn_sqlite <- DBI::dbConnect(RSQLite::SQLite(), sqlite_path)
cat(sprintf("🔌 Connected to SQLite: %s\n", sqlite_path))

# Drop existing table if present
drop_table_sqlite(cnn_sqlite, sqlite_table)

# Write data to SQLite
DBI::dbWriteTable(
  conn = cnn_sqlite,
  name = sqlite_table,
  value = ds_source,
  overwrite = FALSE,  # Already dropped if existed
  append = FALSE
)

log_operation("SQLite write", ds_source, 
              paste0(sqlite_path, "/", sqlite_table))

# Verify write
row_count_sqlite <- DBI::dbGetQuery(
  cnn_sqlite, 
  sprintf("SELECT COUNT(*) AS n FROM %s", sqlite_table)
)$n

cat(sprintf("✅ Verified: %d rows in SQLite table\n", row_count_sqlite))

# Disconnect
DBI::dbDisconnect(cnn_sqlite)
cat("🔌 Disconnected from SQLite\n")

# ==============================================================================
# SECTION 3: CREATE SQL SERVER TABLE
# ==============================================================================

# ---- create-sqlserver --------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("STEP 3: Create SQL Server Table\n")
cat(strrep("=", 70), "\n")

# Connect to SQL Server
tryCatch({
  cnn_cache <- DBI::dbConnect(odbc::odbc(), dsn = dsn_cache)
  cat(sprintf("🔌 Connected to SQL Server: %s\n", dsn_cache))
}, error = function(e) {
  stop("❌ Failed to connect to SQL Server DSN: ", dsn_cache, "\n",
       "   Error: ", e$message, "\n",
       "   Please verify ODBC connection is configured.")
})

# Drop existing table if present
drop_table_sqlserver(cnn_cache, schema_cache, sqlserver_table)

# Write data to SQL Server
# Note: Using schema.table notation for SQL Server
full_table_name <- paste0(schema_cache, ".", sqlserver_table)

DBI::dbWriteTable(
  conn = cnn_cache,
  name = DBI::Id(schema = schema_cache, table = sqlserver_table),
  value = ds_source,
  overwrite = FALSE,  # Already dropped if existed
  append = FALSE
)

log_operation("SQL Server write", ds_source, 
              paste0(dsn_cache, ".", schema_cache, ".", sqlserver_table))

# Verify write
row_count_sqlserver <- DBI::dbGetQuery(
  cnn_cache,
  sprintf("SELECT COUNT(*) AS n FROM [%s].[%s]", schema_cache, sqlserver_table)
)$n

cat(sprintf("✅ Verified: %d rows in SQL Server table\n", row_count_sqlserver))

# Disconnect
DBI::dbDisconnect(cnn_cache)
cat("🔌 Disconnected from SQL Server\n")

# ==============================================================================
# SECTION 4: SUMMARY
# ==============================================================================

# ---- summary -----------------------------------------------------------------
cat("\n", strrep("=", 70), "\n")
cat("✅ DATA ASSET CREATION COMPLETE\n")
cat(strrep("=", 70), "\n\n")

cat("📦 Assets created:\n")
cat(sprintf("   1. SQLite database: %s\n", sqlite_path))
cat(sprintf("      - Table: %s (%d rows)\n", sqlite_table, row_count_sqlite))
cat(sprintf("   2. SQL Server table: %s.%s.%s\n", 
            dsn_cache, schema_cache, sqlserver_table))
cat(sprintf("      - Rows: %d\n", row_count_sqlserver))
cat("\n")

# Validation check
if (row_count_sqlite == nrow(ds_source) && 
    row_count_sqlserver == nrow(ds_source)) {
  cat("✅ VALIDATION PASSED: All tables have identical row counts\n")
} else {
  cat("⚠️  WARNING: Row count mismatch detected\n")
  cat(sprintf("   Source CSV: %d rows\n", nrow(ds_source)))
  cat(sprintf("   SQLite: %d rows\n", row_count_sqlite))
  cat(sprintf("   SQL Server: %d rows\n", row_count_sqlserver))
}

# Execution time
script_duration <- difftime(Sys.time(), script_start_time, units = "secs")
cat(sprintf("\n⏱️  Execution time: %.1f seconds\n", as.numeric(script_duration)))

cat("\n🎯 Next step: Create ferry lane script to import from these sources\n")
cat("   Ferry sources ready:\n")
cat("   - CSV:        ./data-public/raw/is-aggregated-data-april-2005-sep-2025.csv\n")
cat("   - URL:        https://open.alberta.ca/dataset/.../is-aggregated-data-april-2005-sep-2025.csv\n")
cat(sprintf("   - SQLite:     %s/%s\n", sqlite_path, sqlite_table))
cat(sprintf("   - SQL Server: %s.%s.%s\n", dsn_cache, schema_cache, sqlserver_table))
cat("\n")
