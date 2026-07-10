build_interop_artifacts <- function(root) {
  table <- fixture_table("followup-basic")
  policy <- cap_policy(max_budget = 500, max_followup_budget = 340)
  digest <- cap_digest(table, budget = 500, policy = policy)
  cap_write_artifacts(digest, file.path(root, "digest"))
  validation <- cap_validate_response(
    digest,
    read_fixture_json("followup-basic", "response.json")
  )
  cap_write_artifacts(validation, file.path(root, "validation"))
  gate <- cap_gate(digest, validation, policy = policy)
  cap_write_artifacts(gate, file.path(root, "gate"))
  patch <- cap_patch(digest, gate, table, policy = policy)
  cap_write_artifacts(patch, file.path(root, "patch"))
  cap_write_artifacts(
    cap_pack_conformance_report(cap_load_pack()),
    file.path(root, "pack-conformance")
  )
  cap_write_artifacts(
    cap_run_fixtures(),
    file.path(root, "conformance")
  )
  invisible(root)
}

python3_path <- function() {
  path <- Sys.which("python3")
  if (!nzchar(path)) skip("python3 is unavailable")
  path
}

test_that("conformance report covers every fixture exactly once", {
  report <- cap_run_fixtures()
  expect_true(report$ok)
  expect_identical(report$level, 3L)
  expect_identical(
    vapply(report$checks, `[[`, character(1), "name"),
    c(
      "fixtures/basic-table",
      "fixtures/digest-text-negative",
      "fixtures/security-adversarial",
      "fixtures/followup-basic",
      "fixtures/pack-table-basic"
    )
  )
  expect_identical(
    report$implementation$stableSourceFamily,
    "table"
  )
  incomplete <- cap_conformance_report(report$checks[-1L])
  expect_false(incomplete$ok)
  expect_true(any(vapply(
    incomplete$checks,
    function(check) identical(
      unlist(check$problems),
      "required fixture check was omitted"
    ),
    logical(1)
  )))
})

test_that("strict Draft 2020-12 harness validates fixtures", {
  skip_if(
    nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")),
    "external schema harness is enforced by its dedicated release gate"
  )
  python <- python3_path()
  available <- system2(
    python,
    c("-c", shQuote(
      "from jsonschema import Draft202012Validator"
    )),
    stdout = FALSE,
    stderr = FALSE
  )
  skip_if(available != 0L, "python jsonschema is unavailable")
  script <- source_test_path(
    "tools", "schema-harness", "validate.py"
  )
  skip_if_not(
    file.exists(script),
    "source schema harness is unavailable in the installed check sandbox"
  )
  report <- tempfile(fileext = ".json")
  output <- suppressWarnings(system2(
    python,
    c(
      shQuote(script),
      "--vendor-root", shQuote(capR:::capr_vendor_root()),
      "--report", shQuote(report)
    ),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  expect_identical(status, 0L, info = paste(output, collapse = "\n"))
  expect_true(file.exists(report), info = paste(output, collapse = "\n"))
  result <- jsonlite::fromJSON(report, simplifyVector = FALSE)
  expect_true(result$ok)
  expect_identical(result$validator$draft, "2020-12")
})

test_that("independent harness agrees and detects corruption", {
  skip_if(
    nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")),
    "external interop harness is enforced by its dedicated release gate"
  )
  python <- python3_path()
  script <- source_test_path(
    "tools", "interop-harness", "interop.py"
  )
  skip_if_not(
    file.exists(script),
    "source interop harness is unavailable in the installed check sandbox"
  )
  artifacts <- tempfile()
  dir.create(artifacts)
  build_interop_artifacts(artifacts)
  output_dir <- tempfile()
  output <- suppressWarnings(system2(
    python,
    c(
      shQuote(script),
      "--artifact-root", shQuote(artifacts),
      "--vendor-root", shQuote(capR:::capr_vendor_root()),
      "--output-dir", shQuote(output_dir)
    ),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  expect_identical(status, 0L, info = paste(output, collapse = "\n"))
  comparison <- jsonlite::fromJSON(
    file.path(output_dir, "capr-interop-comparison.json"),
    simplifyVector = FALSE
  )
  expect_true(comparison$ok)

  unlink(file.path(artifacts, "digest", "manifest.json"))
  corrupted_output <- tempfile()
  corrupted <- suppressWarnings(system2(
    python,
    c(
      shQuote(script),
      "--artifact-root", shQuote(artifacts),
      "--vendor-root", shQuote(capR:::capr_vendor_root()),
      "--output-dir", shQuote(corrupted_output)
    ),
    stdout = TRUE,
    stderr = TRUE
  ))
  expect_identical(attr(corrupted, "status"), 1L)
  failed <- jsonlite::fromJSON(
    file.path(corrupted_output, "capr-interop-comparison.json"),
    simplifyVector = FALSE
  )
  expect_false(failed$ok)
})
