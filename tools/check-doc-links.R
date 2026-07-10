#!/usr/bin/env Rscript

files <- c(
  list.files(".", pattern = "\\.md$", full.names = TRUE),
  list.files("docs", pattern = "\\.md$", recursive = TRUE, full.names = TRUE)
)
files <- sort(unique(files[file.exists(files)]), method = "radix")
failures <- character()
pattern <- "\\[[^]]+\\]\\(([^)]+)\\)"

for (file in files) {
  lines <- readLines(file, warn = FALSE, encoding = "UTF-8")
  matches <- regmatches(lines, gregexpr(pattern, lines, perl = TRUE))
  links <- unlist(lapply(matches, function(x) {
    if (!length(x) || identical(x, "")) return(character())
    sub("^.*\\(([^)]+)\\)$", "\\1", x)
  }), use.names = FALSE)
  links <- links[
    nzchar(links) &
      !grepl("^(https?://|mailto:|#)", links) &
      !grepl("^<", links)
  ]
  for (link in links) {
    clean <- sub("[#?].*$", "", link)
    clean <- utils::URLdecode(clean)
    target <- normalizePath(
      file.path(dirname(file), clean),
      mustWork = FALSE
    )
    if (!file.exists(target)) {
      failures <- c(failures, sprintf("%s -> %s", file, link))
    }
  }
}

if (length(failures)) {
  message("Broken local Markdown links:")
  message(paste0("  ", failures, collapse = "\n"))
  quit(status = 1L)
}
message(sprintf("Checked local links in %d Markdown files", length(files)))
