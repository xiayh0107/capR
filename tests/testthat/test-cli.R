run_capr_cli <- function(args, error_on_status = TRUE) {
  script <- system.file("exec", "capr", package = "capR")
  if (!nzchar(script)) {
    script <- source_test_path("exec", "capr")
  }
  command <- c("--vanilla", script, args)
  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    command,
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  if (error_on_status && status != 0L) {
    stop(paste(output, collapse = "\n"), call. = FALSE)
  }
  list(output = output, status = status)
}

test_that("CLI help discloses exact scope and unsupported behavior", {
  result <- run_capr_cli("help")
  text <- paste(result$output, collapse = "\n")
  expect_match(text, "CAP-Digest v1.0 L0-L3")
  expect_match(text, "remote/credentialed")
  expect_match(text, "CAP-Core")
  expect_match(text, "Exit codes")
})

test_that("CLI digest matches direct public API artifacts", {
  input <- tempfile(fileext = ".csv")
  output <- tempfile()
  source <- data.frame(a = 1:2, b = c("x", "y"))
  utils::write.csv(source, input, row.names = FALSE)
  result <- run_capr_cli(c(
    "digest",
    "--input", input,
    "--output", output,
    "--label", "cli-table",
    "--budget", "500"
  ))
  expect_identical(result$status, 0L)
  from_cli <- cap_read_artifacts(output)
  direct <- cap_digest(
    utils::read.csv(input, check.names = FALSE),
    label = "cli-table",
    budget = 500
  )
  expect_identical(from_cli$text, direct$text)
  expect_identical(
    capr_canonical_json(from_cli$manifest),
    capr_canonical_json(direct$manifest)
  )
})

test_that("CLI rejects arbitrary non-CSV source input", {
  input <- tempfile(fileext = ".R")
  writeLines("system('false')", input)
  result <- run_capr_cli(
    c("digest", "--input", input, "--output", tempfile()),
    error_on_status = FALSE
  )
  expect_identical(result$status, 2L)
  expect_match(
    paste(result$output, collapse = "\n"),
    "CSV file"
  )
})

test_that("CLI runs the complete fixture suite non-interactively", {
  output <- tempfile(fileext = ".json")
  result <- run_capr_cli(c(
    "run-fixtures", "--output", output
  ))
  expect_identical(result$status, 0L)
  report <- jsonlite::fromJSON(output, simplifyVector = FALSE)
  expect_true(report$ok)
  expect_length(report$checks, 5L)
})

test_that("CLI validation, gate, and patch reuse public API behavior", {
  input <- tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(order_id = c("A001", "A002"), amount = c(12.5, 19)),
    input,
    row.names = FALSE
  )
  digest_dir <- tempfile()
  run_capr_cli(c(
    "digest", "--input", input, "--output", digest_dir,
    "--label", "orders", "--budget", "500"
  ))
  response_path <- tempfile(fileext = ".json")
  response <- list(
    claims = list(),
    evidence = list(),
    warnings = list(),
    requests = list(list(
      fieldId = "f1:table@sample#k10",
      level = 1L,
      budget = 300L,
      reason = "Need sample rows."
    ))
  )
  writeLines(
    jsonlite::toJSON(
      response,
      auto_unbox = TRUE,
      null = "null",
      pretty = TRUE
    ),
    response_path
  )
  validation_dir <- tempfile()
  validated <- run_capr_cli(c(
    "validate-response",
    "--digest", digest_dir,
    "--response", response_path,
    "--output", validation_dir
  ))
  expect_identical(validated$status, 0L)
  gate_dir <- tempfile()
  gated <- run_capr_cli(c(
    "gate",
    "--digest", digest_dir,
    "--validation", file.path(validation_dir, "validation.json"),
    "--output", gate_dir,
    "--followup-budget", "300"
  ))
  expect_identical(gated$status, 0L)
  patch_dir <- tempfile()
  patched <- run_capr_cli(c(
    "patch",
    "--digest", digest_dir,
    "--gate", file.path(gate_dir, "gate.json"),
    "--source", input,
    "--output", patch_dir
  ))
  expect_identical(patched$status, 0L)
  patch <- jsonlite::fromJSON(
    file.path(patch_dir, "patch.json"),
    simplifyVector = FALSE
  )
  expect_identical(patch$schema, "cap.digest_patch.v1")
  expect_identical(
    patch$operations[[1L]]$fieldId,
    "f1:table@sample#k10"
  )
})
