# Pre-render script: generate .qmd files that require executable chunks
# Working directory is _frontend-1/ when called by quarto render.
# Source for pipeline comes from the RAW repo file (never loses the source).
# Source for readme comes from content/docs/readme.md (edited version).

# ── helpers ──────────────────────────────────────────────────────────────────

replace_mermaid_with_include <- function(lines, include_path) {
  # Replace ```mermaid ... ``` fences with a {{< include >}} shortcode.
  open  <- which(trimws(lines) == "```mermaid")
  close <- integer(0)
  for (i in open) {
    rest  <- which(trimws(lines[(i+1):length(lines)]) == "```")
    if (length(rest)) close <- c(close, i + rest[1])
  }
  if (length(open) == 0) return(lines)
  # Replace from first open to matching close (handles one block)
  replacement <- paste0("{{< include ", include_path, " >}}")
  c(lines[seq_len(open[1] - 1)], replacement, lines[(close[1] + 1):length(lines)])
}

copy_to_qmd <- function(src, dst, mermaid_include = NULL) {
  if (!file.exists(src)) stop("source not found: ", src)
  lines <- readLines(src, warn = FALSE)
  if (!is.null(mermaid_include)) {
    lines <- replace_mermaid_with_include(lines, mermaid_include)
  }
  dir.create(dirname(dst), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, dst)
  message("prep: ", src, " -> ", dst, " (", length(lines), " lines)")
}

# ── pipeline.qmd — sourced from RAW manipulation/pipeline.md ─────────────────
copy_to_qmd(
  src             = "../manipulation/pipeline.md",
  dst             = "content/pipeline/pipeline.qmd",
  mermaid_include = "../_pipeline-diagram.qmd"   # relative from content/pipeline/
)

# readme.qmd is a permanent file (content/docs/readme.qmd) — no pre-render needed.

