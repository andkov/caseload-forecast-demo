# Post-render script: copy assets that live outside _frontend-1/ into _site/
# Called by Quarto after rendering. Working directory = _frontend-1/

copy_asset <- function(src, dst) {
  if (!file.exists(src)) {
    message("WARNING: source not found, skipping: ", src)
    return(invisible(FALSE))
  }
  dir.create(dirname(dst), recursive = TRUE, showWarnings = FALSE)
  ok <- file.copy(src, dst, overwrite = TRUE)
  if (ok) message("Copied: ", src, " -> ", dst)
  else     message("ERROR: failed to copy: ", src)
  invisible(ok)
}

# ── Analysis HTML reports (redirect targets) ──────────────────────────────────
# Placed at _site/analysis/<report>/<report>.html so that
# meta-refresh targets "../../analysis/<report>/<report>.html" resolve correctly
# from _site/content/analysis/<report>.html
copy_asset("../analysis/eda-2/eda-2.html",       "_site/analysis/eda-2/eda-2.html")
copy_asset("../analysis/report-1/report-1.html", "_site/analysis/report-1/report-1.html")

# ── README image assets ───────────────────────────────────────────────────────
# README.md (root) references libs/images/README-main/*.png relative to repo root.
# content/docs/readme.qmd is a verbatim copy, so the same relative paths apply
# relative to content/docs/ — meaning they resolve to content/docs/libs/images/...
# Quarto copies content/ assets to _site/content/, so we mirror the same tree there.
readme_images <- list.files(
  "../libs/images/README-main",
  pattern = "\\.(png|jpg|jpeg|gif|svg|webp)$",
  full.names = TRUE
)
for (src in readme_images) {
  fname <- basename(src)
  copy_asset(src, paste0("_site/content/docs/libs/images/README-main/", fname))
}
