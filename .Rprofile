# Increase languageserver subprocess wait timeout (default ~120s is too short for large renv libraries).
# languageserver reads this option when calling callr::r_session$new(wait_timeout = ...).
options(languageserver.server_timeout = 300)

# Reduce renv startup overhead: suppress status messages and skip sync check.
# synchronized.check = FALSE skips the lockfile comparison that adds ~2s to startup,
# keeping total renv activation under callr's 3-second session wait_timeout.
options(
  renv.config.startup.quiet     = TRUE,
  renv.config.synchronized.check = FALSE
)


if (interactive() && Sys.getenv("RSTUDIO") == "") {
  init_path <- file.path(Sys.getenv(if (.Platform$OS.type == "windows") "USERPROFILE" else "HOME"), ".vscode-R", "init.R")
  source(init_path)
  # Workaround .vsc.attach()
  .First.sys()
}


source("renv/activate.R")
