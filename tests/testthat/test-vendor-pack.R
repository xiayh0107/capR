copy_vendor_tree <- function() {
  source <- capR:::capr_vendor_root()
  destination <- tempfile()
  dir.create(destination)
  files <- list.files(
    source,
    all.files = TRUE,
    full.names = TRUE,
    no.. = TRUE
  )
  expect_true(all(file.copy(
    files,
    destination,
    recursive = TRUE,
    copy.mode = TRUE
  )))
  destination
}

test_that("vendored CAP-Digest release verifies against its lock", {
  verification <- cap_verify_vendor()
  expect_true(verification$ok)
  expect_identical(
    verification$commit,
    "d7890d4449107a88faed0e0c653d3751b57575f2"
  )
  info <- cap_vendor_info()
  expect_identical(info$tag, "cap-digest-v1.0.0")
  expect_true(all(c(
    "basic-table", "followup-basic", "pack-table-basic"
  ) %in% info$fixture_scope))

  vendor_files <- list.files(
    capR:::capr_vendor_root(),
    recursive = TRUE,
    full.names = TRUE
  )
  expect_false(any(vapply(vendor_files, function(path) {
    bytes <- readBin(path, what = "raw", n = file.info(path)$size)
    any(bytes == as.raw(0x0d))
  }, logical(1))))
})

test_that("vendor verification detects mutation, omission, and additions", {
  mutated <- copy_vendor_tree()
  path <- file.path(mutated, "reference-version.txt")
  writeLines("mutated", path)
  expect_error(
    cap_verify_vendor(mutated),
    class = "capr_artifact_invalid"
  )

  missing <- copy_vendor_tree()
  unlink(file.path(missing, "reference-version.txt"))
  expect_error(
    cap_verify_vendor(missing),
    class = "capr_artifact_invalid"
  )

  added <- copy_vendor_tree()
  writeLines("unexpected", file.path(added, "unexpected.txt"))
  expect_error(
    cap_verify_vendor(added),
    class = "capr_artifact_invalid"
  )
})

test_that("table-basic pack validation matches published fixture", {
  pack <- cap_load_pack()
  expect_s3_class(pack, "cap_digest_pack")
  expect_false(pack$executable_metadata)
  expect_identical(pack$conformance_claim, "none")
  actual <- cap_validate_pack(pack)
  expected <- read_fixture_json(
    "pack-table-basic", "expected-pack.json"
  )
  expect_identical(
    capr_canonical_json(actual),
    capr_canonical_json(expected)
  )
  report <- cap_pack_conformance_report(pack)
  expect_identical(report$schema, "cap.pack_conformance_report.v1")
  expect_true(all(vapply(
    report$checks, `[[`, logical(1), "passed"
  )))
})

test_that("pack hosting rejects external and executable metadata by default", {
  external <- copy_vendor_tree()
  expect_error(
    cap_load_pack(root = external),
    class = "capr_artifact_invalid"
  )
  field <- file.path(
    external,
    "packs", "table-basic", "fields", "shape.yaml"
  )
  write("command: rm -rf /", file = field, append = TRUE)
  expect_error(
    cap_load_pack(root = external, allow_external = TRUE),
    class = "capr_artifact_invalid"
  )
})
