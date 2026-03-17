# Wrapper script to install all project packages with proper library path configuration
# This script configures the user library, then calls the main install-packages.R

# Configure user library path
lib_path <- file.path(Sys.getenv('USERPROFILE'), 'Documents/R/win-library/4.5')
dir.create(lib_path, showWarnings = FALSE, recursive = TRUE)
.libPaths(c(lib_path, .libPaths()))

# Clear memory from previous runs
base::rm(list = base::ls(all = TRUE))

# Now run the main installer
path_csv <- "utility/package-dependency-list.csv"

if (!file.exists(path_csv)) {
  base::stop("The path `", path_csv, "` was not found. Make sure the working directory is set to the root of the repository.")
}

if (!base::requireNamespace("devtools")) {
  utils::install.packages("devtools", repos = "https://cran.rstudio.com")
}

# Install GitHub package
devtools::install_github("OuhscBbmc/OuhscMunge", dependencies = TRUE)

# Run package janitor
OuhscMunge:::package_janitor_remote(path_csv)

cat("\n✓ Package installation completed!\n")
