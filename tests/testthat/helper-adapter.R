test_adapter <- function(id = "org.example.table", version = "1.0.0",
                         provider = "testthat", provider_version = "1.0.0",
                         maturity = "community", claim = "none",
                         extractor = function(x, level = "base", context = list()) {
                           list(rows = nrow(x), columns = ncol(x))
                         }) {
  cap_new_adapter(
    id = id,
    version = version,
    provider = provider,
    provider_version = provider_version,
    source_family = "table",
    maturity = maturity,
    semantic_level = "table",
    conformance_claim = claim,
    capabilities = list(
      followup = TRUE,
      remote = FALSE,
      credentials = FALSE,
      deterministic = TRUE
    ),
    source_ref = function(x, context = list()) {
      list(
        schema = "cap.source_ref.v1",
        sourceType = "table",
        uri = "r-host://test/table",
        label = "test table"
      )
    },
    field_catalog = function(x, context = list()) {
      list(
        schema = "cap.field_catalog.v1",
        catalogId = "org.example.test.v1",
        sourceType = "table",
        versions = list(
          cap = "2026-07-05-draft",
          fields = "f1",
          catalog = "v1"
        ),
        fields = list(list(
          schema = "cap.field.v1",
          id = "f1:table@shape#base",
          label = "Shape",
          description = "Test table dimensions.",
          sourceTypes = list("table"),
          timing = "assemble",
          trust = "code",
          exec = "local_cheap",
          levels = list(list(
            level = 1L,
            estimatedCost = 20L,
            description = "Test dimensions."
          )),
          contracts = list(
            extractor = "test.shape",
            redactor = "test.identity",
            renderer = "test.shape.text_v1"
          )
        ))
      )
    },
    fingerprint = function(x, context = list()) {
      list(
        available = TRUE,
        algorithm = "test-v1",
        value = digest::digest(
          list(dim = dim(x), names = names(x)),
          algo = "sha256"
        )
      )
    },
    bindings = list(
      extractors = list("test.shape" = extractor),
      redactors = list("test.identity" = function(value, ...) {
        list(
          value = value,
          redacted = FALSE,
          warnings = character(),
          caveats = list(),
          rules = character()
        )
      }),
      renderers = list(
        "test.shape.text_v1" = function(value, ...) {
          sprintf("%d x %d", value$rows, value$columns)
        }
      )
    )
  )
}
