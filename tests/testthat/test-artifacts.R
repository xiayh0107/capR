test_that("canonical digest artifacts round trip without sidecars", {
  digest <- cap_digest(data.frame(a = 1:2), budget = 500)
  directory <- tempfile()
  cap_write_artifacts(digest, directory, include_sidecars = FALSE)
  expect_true(all(file.exists(file.path(
    directory,
    c("digest.txt", "digest.json", "manifest.json")
  ))))
  expect_false(file.exists(file.path(
    directory, "resolution.capr.json"
  )))
  reread <- cap_read_artifacts(directory)
  expect_identical(reread$text, digest$text)
  expect_identical(
    capr_canonical_json(reread$manifest),
    capr_canonical_json(digest$manifest)
  )
})

test_that("sidecars remain separate and malformed sets fail closed", {
  digest <- cap_digest(data.frame(a = 1:2), budget = 500)
  directory <- tempfile()
  cap_write_artifacts(digest, directory)
  expect_true(file.exists(file.path(
    directory, "resolution.capr.json"
  )))
  digest_json <- paste(
    readLines(file.path(directory, "digest.json"), warn = FALSE),
    collapse = "\n"
  )
  expect_false(grepl(
    "capr.resolution.v1", digest_json, fixed = TRUE
  ))
  unlink(file.path(directory, "manifest.json"))
  expect_error(
    cap_read_artifacts(directory),
    class = "capr_artifact_invalid"
  )
})
