#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
output <- if (length(args)) args[[1L]] else "schema-artifacts"
dir.create(output, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output, "schema-only"), showWarnings = FALSE)
suppressPackageStartupMessages(library(capR))

root <- system.file(
  "extdata", "cap-digest", "v1.0.0", "fixtures",
  package = "capR"
)
if (!nzchar(root)) {
  root <- file.path(
    "inst", "extdata", "cap-digest", "v1.0.0", "fixtures"
  )
}
read_json <- function(...) {
  jsonlite::fromJSON(
    file.path(root, ...),
    simplifyVector = FALSE
  )
}
source <- read_json("followup-basic", "source.json")
policy_fixture <- read_json("followup-basic", "policy.json")
columns <- lapply(source$columns, function(column) {
  values <- unlist(column$examples, use.names = FALSE)
  if (identical(column$type, "dbl")) values <- as.numeric(values)
  length(values) <- source$rows
  values
})
names(columns) <- vapply(
  source$columns, `[[`, character(1), "name"
)
table <- as.data.frame(
  columns,
  check.names = FALSE,
  stringsAsFactors = FALSE,
  optional = TRUE
)
attr(table, "capr_label") <- source$label
attr(table, "capr_uri") <- "fixture://basic-table/source.json"
attr(table, "capr_fixture_fingerprint") <- policy_fixture$fingerprint
attr(table, "capr_fixture_sample_rows") <- source$sampleRows
attr(table, "capr_digest_id") <- "cap-digest-basic-table"

policy <- cap_policy(max_budget = 500, max_followup_budget = 340)
digest <- cap_digest(table, budget = 500, policy = policy)
cap_write_artifacts(digest, file.path(output, "digest"))
validation <- cap_validate_response(
  digest,
  read_json("followup-basic", "response.json")
)
writeLines(
  capr_canonical_json(
    read_json("followup-basic", "response.json"),
    pretty = TRUE
  ),
  file.path(output, "schema-only", "contract-response.json"),
  useBytes = TRUE
)
cap_write_artifacts(validation, file.path(output, "validation"))
gate <- cap_gate(digest, validation, policy = policy)
cap_write_artifacts(gate, file.path(output, "gate"))
patch <- cap_patch(digest, gate, table, policy = policy)
cap_write_artifacts(patch, file.path(output, "patch"))
pack_report <- cap_pack_conformance_report(cap_load_pack())
cap_write_artifacts(
  pack_report,
  file.path(output, "pack-conformance")
)
pack <- cap_load_pack()
writeLines(
  capr_canonical_json(pack$frontmatter, pretty = TRUE),
  file.path(output, "schema-only", "digest-pack.json"),
  useBytes = TRUE
)
writeLines(
  capr_canonical_json(digest$catalog, pretty = TRUE),
  file.path(output, "schema-only", "field-catalog.json"),
  useBytes = TRUE
)
dir.create(file.path(output, "schema-only", "fields"))
for (field in digest$catalog$fields) {
  filename <- paste0(
    gsub("[^a-z0-9]+", "-", tolower(field$id)),
    ".json"
  )
  writeLines(
    capr_canonical_json(field, pretty = TRUE),
    file.path(output, "schema-only", "fields", filename),
    useBytes = TRUE
  )
}
conformance <- cap_run_fixtures()
cap_write_artifacts(
  conformance,
  file.path(output, "conformance")
)
message(normalizePath(output, mustWork = TRUE))
