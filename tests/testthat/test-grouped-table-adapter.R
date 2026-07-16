make_grouped_adapter_sources <- function() {
  source <- tibble::tibble(
    team = c(
      "GROUP_KEY_SECRET_ALPHA",
      "GROUP_KEY_SECRET_ALPHA",
      "GROUP_KEY_SECRET_BETA",
      "GROUP_KEY_SECRET_BETA"
    ),
    site = c("east", "west", "east", "west"),
    value = c(10L, 20L, 30L, 40L)
  )
  list(
    grouped = dplyr::group_by(source, team),
    regrouped = dplyr::group_by(source, site),
    rowwise = dplyr::rowwise(source, team)
  )
}

test_that("grouped adapter preserves opt-in semantics and source objects", {
  skip_if_not_installed("dplyr")
  skip_if_not_installed("tibble")

  expect_null(getS3method("cap_adapter", "grouped_df", optional = TRUE))
  expect_null(getS3method("cap_adapter", "rowwise_df", optional = TRUE))
  sources <- make_grouped_adapter_sources()
  grouped_before <- serialize(sources$grouped, NULL)
  rowwise_before <- serialize(sources$rowwise, NULL)

  empty_registry <- cap_registry(global = FALSE)
  expect_identical(
    cap_resolve_adapter(
      sources$grouped,
      registry = empty_registry
    )$metadata$id,
    "org.capr.table"
  )
  expect_identical(
    cap_resolve_adapter(
      sources$rowwise,
      registry = empty_registry
    )$metadata$id,
    "org.capr.table"
  )

  adapter <- cap_grouped_table_adapter()
  remote <- structure(
    list(),
    class = c("tbl_lazy", "grouped_df", "tbl_df", "tbl", "data.frame")
  )
  expect_error(
    cap_digest(remote, adapter = adapter),
    class = "capr_adapter_not_found"
  )
  expect_identical(adapter$metadata$id, "org.capr.grouped_table")
  expect_identical(adapter$metadata$maturity, "experimental")
  expect_identical(adapter$metadata$semantic_level, "table")
  expect_identical(adapter$metadata$conformance_claim, "none")
  expect_false(adapter$metadata$capabilities$grouping_keys_disclosed)
  expect_true(cap_test_adapter(adapter, sources$grouped)$ok)
  expect_true(cap_test_adapter(adapter, sources$rowwise)$ok)

  grouped_digest <- cap_digest(
    sources$grouped,
    budget = 800L,
    adapter = adapter
  )
  rowwise_digest <- cap_digest(
    sources$rowwise,
    budget = 800L,
    adapter = adapter
  )
  grouped_info <- grouped_digest$materialization$outcomes[[
    "f1:table@capr_grouping#compact"
  ]]$value
  rowwise_info <- rowwise_digest$materialization$outcomes[[
    "f1:table@capr_grouping#compact"
  ]]$value

  expect_identical(grouped_info$kind, "grouped")
  expect_identical(grouped_info$variables, "team")
  expect_identical(grouped_info$group_count, 2L)
  expect_identical(rowwise_info$kind, "rowwise")
  expect_identical(rowwise_info$variables, "team")
  expect_identical(rowwise_info$group_count, 4L)
  expect_identical(
    grouped_digest$source$identity$grouping,
    list(kind = "grouped", variables = list("team"), groupCount = 2L)
  )
  expect_identical(
    rowwise_digest$source$identity$grouping,
    list(kind = "rowwise", variables = list("team"), groupCount = 4L)
  )

  grouping_body <- cap_parse_digest_text(grouped_digest$text)$fields[[
    "f1:table@capr_grouping#compact"
  ]]$body
  grouping_payload <- capr_canonical_json(list(
    source = grouped_digest$source$identity$grouping,
    value = grouped_info,
    text = grouping_body
  ))
  for (key in c(
    "GROUP_KEY_SECRET_ALPHA",
    "GROUP_KEY_SECRET_BETA"
  )) {
    expect_false(grepl(key, grouping_payload, fixed = TRUE))
  }
  expect_false(grepl(".rows", grouping_payload, fixed = TRUE))
  expect_identical(
    cap_validate_manifest_text(
      grouped_digest$text,
      grouped_digest$manifest
    ),
    list()
  )
  expect_identical(serialize(sources$grouped, NULL), grouped_before)
  expect_identical(serialize(sources$rowwise, NULL), rowwise_before)
})

test_that("grouping changes fingerprints and registered IDs opt in", {
  skip_if_not_installed("dplyr")
  skip_if_not_installed("tibble")

  sources <- make_grouped_adapter_sources()
  adapter <- cap_grouped_table_adapter()
  fingerprint <- function(source) {
    adapter$lifecycle$fingerprint(source, list())$value
  }

  first_fingerprint <- fingerprint(sources$grouped)
  expect_identical(first_fingerprint, fingerprint(sources$grouped))
  expect_false(identical(
    first_fingerprint,
    fingerprint(sources$regrouped)
  ))
  expect_false(identical(
    first_fingerprint,
    fingerprint(sources$rowwise)
  ))

  first <- cap_digest(
    sources$grouped,
    budget = 800L,
    adapter = adapter
  )
  repeated <- cap_digest(
    sources$grouped,
    budget = 800L,
    adapter = adapter
  )
  regrouped <- cap_digest(
    sources$regrouped,
    budget = 800L,
    adapter = adapter
  )
  expect_identical(
    capr_canonical_json(first$artifact),
    capr_canonical_json(repeated$artifact)
  )
  expect_false(identical(first$fingerprint, regrouped$fingerprint))
  expect_false(identical(first$text, regrouped$text))

  registry <- cap_registry(global = FALSE)
  expect_invisible(cap_register_adapter(
    "grouped_df",
    cap_grouped_table_adapter,
    registry = registry
  ))

  # The inherited tbl_df S3 bridge intentionally keeps the default stable
  # table behavior even when an experimental adapter is registered.
  expect_identical(
    cap_resolve_adapter(
      sources$grouped,
      registry = registry
    )$metadata$id,
    "org.capr.table"
  )
  resolved <- cap_resolve_adapter(
    sources$grouped,
    adapter = "org.capr.grouped_table",
    registry = registry
  )
  expect_identical(resolved$metadata$id, "org.capr.grouped_table")
  diagnostics <- cap_resolution_diagnostics(resolved)
  expect_identical(diagnostics$selected$mode, "explicit_id")
  expect_identical(diagnostics$matched_class, "grouped_df")

  registered <- cap_digest(
    sources$grouped,
    budget = 800L,
    adapter = "org.capr.grouped_table",
    registry = registry
  )
  expect_identical(registered$fingerprint, first$fingerprint)
  expect_identical(
    capr_canonical_json(registered$artifact),
    capr_canonical_json(first$artifact)
  )
  expect_identical(registered$provenance$resolution_mode, "explicit_id")
})
