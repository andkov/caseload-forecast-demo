# Load VS Code R session helpers when available.
vscode_init <- file.path(
  Sys.getenv(if (.Platform$OS.type == "windows") "USERPROFILE" else "HOME"),
  ".vscode-R",
  "init.R"
)
if (file.exists(vscode_init)) {
  source(vscode_init)
}

# Prefer httpgd pane plotting in interactive VS Code sessions.
if (interactive() && Sys.getenv("TERM_PROGRAM") == "vscode") {
  if (requireNamespace("httpgd", quietly = TRUE)) {
    options(vsc.plot = FALSE)
    options(device = function(...) {
      httpgd::hgd(silent = TRUE)
      .vsc.browser(httpgd::hgd_url(history = FALSE), viewer = "Beside")
    })
  }
}

