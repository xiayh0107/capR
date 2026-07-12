.capr_descriptor_sections <- c("overview", "structure", "semantics")

capr_descriptor_plain_atomic <- function(x) {
  if (!is.atomic(x) || isS4(x)) return(NULL)
  value <- if (is.object(x)) {
    tryCatch(unclass(x), error = function(e) NULL)
  } else {
    x
  }
  if (is.atomic(value)) value else NULL
}

capr_descriptor_bound_string <- function(x, limit = 160L) {
  if (is.object(limit)) {
    limit <- tryCatch(unclass(limit), error = function(e) NULL)
  }
  if (!is.numeric(limit)) {
    capr_abort(
      "capr_adapter_invalid",
      "descriptor string limit must be one positive integer"
    )
  }
  limit <- as.integer(limit)
  if (length(limit) != 1L || is.na(limit) || limit < 1L) {
    capr_abort(
      "capr_adapter_invalid",
      "descriptor string limit must be one positive integer"
    )
  }
  if (is.factor(x)) {
    codes <- unclass(x)
    levels <- attr(x, "levels", exact = TRUE)
    if (is.object(levels)) {
      levels <- tryCatch(unclass(levels), error = function(e) NULL)
    }
    if (!is.integer(codes) || !is.character(levels)) {
      x <- rep("[invalid factor metadata]", length(codes))
    } else {
      values <- rep(NA_character_, length(codes))
      valid <- !is.na(codes) & codes >= 1L & codes <= length(levels)
      values[valid] <- levels[codes[valid]]
      values[!is.na(codes) & !valid] <- "[invalid factor code]"
      x <- values
    }
  } else {
    if (is.object(x)) {
      x <- tryCatch(unclass(x), error = function(e) NULL)
    }
    if (is.null(x)) return(character())
    if (!is.atomic(x)) {
      return(sprintf("[%s: not traversed]", typeof(x)))
    }
    if (!is.character(x)) {
      # `x` is plain atomic data here, so this primitive conversion cannot
      # dispatch to a host-supplied `as.character()` method.
      x <- as.character(x)
    }
  }

  # Limit before encoding and regular-expression cleanup so work is bounded
  # even when one hostile metadata string is extremely wide.
  prefix <- substr(x, 1L, limit + 1L)
  width <- nchar(prefix, type = "chars")
  truncated <- !is.na(width) & width > limit
  if (any(truncated)) {
    prefix[truncated] <- substr(prefix[truncated], 1L, limit)
  }
  prefix <- enc2utf8(prefix)
  prefix <- gsub("[[:cntrl:]]", " ", prefix)
  prefix <- gsub("[[:space:]]+", " ", prefix)
  prefix[truncated] <- paste0(prefix[truncated], "...")
  prefix
}

capr_descriptor_clean <- function(x, depth = 0L, max_depth = 6L,
                                  max_items = 80L) {
  if (depth > max_depth) return("[depth limit]")
  if (is.null(x)) return(NULL)
  if (is.function(x)) return("[function: not executed]")
  if (is.environment(x)) return("[environment: not traversed]")
  if (typeof(x) %in% c("externalptr", "weakref", "promise")) {
    return(sprintf("[%s: not traversed]", typeof(x)))
  }
  if (is.language(x) || is.expression(x)) {
    return("[language object: not evaluated]")
  }
  if (isS4(x)) {
    classes <- unname(class(x))
    slots <- methods::slotNames(x)
    class_count <- min(length(classes), max_items)
    slot_count <- min(length(slots), max_items)
    return(list(
      classes = as.list(capr_descriptor_bound_string(
        classes[seq_len(class_count)]
      )),
      slots = as.list(capr_descriptor_bound_string(
        slots[seq_len(slot_count)]
      ))
    ))
  }
  if (is.atomic(x)) {
    factor_source <- is.factor(x)
    if (!factor_source && is.object(x)) {
      x <- tryCatch(unclass(x), error = function(e) NULL)
      if (is.null(x) || !is.atomic(x)) {
        return("[classed atomic value: not traversed]")
      }
    }
    total <- length(if (factor_source) unclass(x) else x)
    count <- min(total, max_items)
    if (factor_source) {
      codes <- unclass(x)
      levels <- attr(x, "levels", exact = TRUE)
      if (is.object(levels)) {
        levels <- tryCatch(unclass(levels), error = function(e) NULL)
      }
      if (!is.integer(codes) || !is.character(levels)) {
        kept <- rep("[invalid factor metadata]", count)
      } else {
        codes <- codes[seq_len(count)]
        kept <- rep(NA_character_, count)
        valid <- !is.na(codes) & codes >= 1L & codes <= length(levels)
        kept[valid] <- levels[codes[valid]]
        kept[!is.na(codes) & !valid] <- "[invalid factor code]"
      }
      kept <- capr_descriptor_bound_string(kept)
      if (total > count) {
        kept <- c(kept, sprintf("[truncated: %d more]", total - count))
      }
      return(unname(kept))
    }
    if (is.raw(x)) {
      return(sprintf("[raw length=%d]", total))
    }
    x <- x[seq_len(count)]
    if (is.numeric(x)) {
      bad <- !is.finite(x) & !is.na(x)
      if (any(bad)) x[bad] <- NA
    }
    if (is.character(x)) x <- capr_descriptor_bound_string(x)
    if (total > count) {
      x <- c(x, sprintf("[truncated: %d more]", total - count))
    }
    return(unname(x))
  }
  if (!is.list(x)) {
    return(sprintf(
      "[%s: not traversed]",
      capr_descriptor_bound_string(class(x)[[1L]] %||% typeof(x))
    ))
  }

  # Normalized snapshots should contain plain lists only. Strip S3 class
  # metadata before traversal so a hostile `[[` method can never run here.
  if (is.object(x)) {
    x <- tryCatch(unclass(x), error = function(e) NULL)
    if (!is.list(x)) return("[classed list: not traversed]")
  }

  total <- length(x)
  count <- min(total, max_items)
  out <- lapply(seq_len(count), function(index) {
    capr_descriptor_clean(
      .subset2(x, index), depth = depth + 1L,
      max_depth = max_depth, max_items = max_items
    )
  })
  source_names <- capr_descriptor_plain_atomic(
    attr(x, "names", exact = TRUE)
  )
  if (is.character(source_names) && length(source_names) >= count) {
    source_names <- capr_descriptor_bound_string(source_names[seq_len(count)])
    source_names[!nzchar(source_names)] <- sprintf(
      "unnamed_%d", which(!nzchar(source_names))
    )
    source_names <- make.unique(source_names, sep = "_")
    names(out) <- source_names
  }
  if (total > count) {
    marker <- sprintf("[truncated: %d more]", total - count)
    if (is.null(names(out))) {
      out[[length(out) + 1L]] <- marker
    } else {
      out[["truncated"]] <- marker
    }
  }
  out
}

capr_descriptor_snapshot <- function(snapshot, family) {
  if (is.object(snapshot) && !isS4(snapshot)) {
    snapshot <- tryCatch(unclass(snapshot), error = function(e) NULL)
  }
  if (!is.list(snapshot)) {
    capr_abort(
      "capr_adapter_invalid",
      "complex-object snapshot must be a list",
      source_family = family
    )
  }
  if (length(snapshot) > 20L) {
    capr_abort(
      "capr_adapter_invalid",
      "complex-object snapshot has too many top-level sections",
      source_family = family
    )
  }
  snapshot_names <- capr_descriptor_plain_atomic(
    attr(snapshot, "names", exact = TRUE)
  )
  if (!is.character(snapshot_names)) snapshot_names <- character()
  missing <- setdiff(.capr_descriptor_sections, snapshot_names %||% character())
  if (length(missing)) {
    capr_abort(
      "capr_adapter_invalid",
      "complex-object snapshot is missing required sections",
      source_family = family,
      missing = missing
    )
  }
  if (anyDuplicated(snapshot_names)) {
    capr_abort(
      "capr_adapter_invalid",
      "complex-object snapshot section names must be unique",
      source_family = family
    )
  }
  section_index <- match(.capr_descriptor_sections, snapshot_names)
  cleaned <- lapply(section_index, function(index) {
    capr_descriptor_clean(.subset2(snapshot, index))
  })
  names(cleaned) <- .capr_descriptor_sections
  cleaned
}

capr_new_snapshot_cache <- function(x, adapter) {
  cap_validate_adapter(adapter)
  cache <- new.env(parent = emptyenv())
  cache$schema <- "capr.snapshot_cache.v1"
  cache$source <- x
  cache$implementation_signature <- capr_implementation_spec_hash(
    adapter$implementation_spec %||% list()
  )
  cache$entries <- new.env(parent = emptyenv())
  cache
}

capr_cached_descriptor_snapshot <- function(x, context, family, snapshot_fn,
                                            implementation_signature) {
  cache <- context$.capr_snapshot_cache
  cache_ok <- is.environment(cache) &&
    identical(cache$schema, "capr.snapshot_cache.v1") &&
    identical(cache$source, x) &&
    identical(cache$implementation_signature, implementation_signature) &&
    is.environment(cache$entries)
  key <- paste0("descriptor:", family)
  if (cache_ok && exists(key, envir = cache$entries, inherits = FALSE)) {
    entry <- get(key, envir = cache$entries, inherits = FALSE)
    if (is.list(entry) && identical(entry$snapshot_fn, snapshot_fn)) {
      return(entry$snapshot)
    }
  }
  snapshot <- capr_descriptor_snapshot(snapshot_fn(x), family)
  if (cache_ok) {
    assign(
      key,
      list(snapshot_fn = snapshot_fn, snapshot = snapshot),
      envir = cache$entries
    )
  }
  snapshot
}

capr_descriptor_label <- function(x, context, default) {
  label <- context$label %||% attr(x, "capr_label", exact = TRUE) %||% default
  label <- capr_descriptor_plain_atomic(label)
  capr_assert_scalar_character(
    label, "label", condition = "capr_artifact_invalid"
  )
}

capr_descriptor_fingerprint <- function(x, context, family, snapshot_fn,
                                        implementation_signature) {
  override <- context$fingerprint
  if (!is.null(override)) {
    override <- capr_descriptor_plain_atomic(override)
    return(list(
      available = TRUE,
      algorithm = "fixture-declared",
      value = capr_assert_scalar_character(
        override, "fingerprint", condition = "capr_artifact_invalid"
      )
    ))
  }
  snapshot <- capr_cached_descriptor_snapshot(
    x, context, family, snapshot_fn, implementation_signature
  )
  list(
    available = TRUE,
    algorithm = sprintf("capr-%s-metadata-v1-sha256", family),
    value = paste0(
      "capr_", family, "_metadata_v1:",
      capr_sha256(capr_canonical_json(snapshot))
    ),
    caveat = "bounded_metadata_only"
  )
}

capr_descriptor_source_ref <- function(x, context, family, label,
                                       snapshot_fn,
                                       implementation_signature) {
  snapshot <- capr_cached_descriptor_snapshot(
    x, context, family, snapshot_fn, implementation_signature
  )
  fingerprint <- capr_descriptor_fingerprint(
    x, context, family, snapshot_fn, implementation_signature
  )$value
  uri <- context$uri %||% attr(x, "capr_uri", exact = TRUE) %||%
    paste0("r-host://", family, "/", sub("^.*:", "", fingerprint))
  uri <- capr_descriptor_plain_atomic(uri)
  classes <- unname(class(x))
  class_count <- min(length(classes), 80L)
  list(
    schema = "cap.source_ref.v1",
    uri = capr_assert_scalar_character(
      uri, "uri", condition = "capr_artifact_invalid"
    ),
    sourceType = family,
    label = capr_descriptor_label(x, context, label),
    identity = list(
      host = "R",
      classes = as.list(capr_descriptor_bound_string(
        classes[seq_len(class_count)]
      )),
      overview = snapshot$overview
    ),
    trust = "host"
  )
}

capr_descriptor_field_catalog <- function(family, catalog_id, labels) {
  section_description <- c(
    overview = "Bounded object kind, class, and size metadata.",
    structure = "Bounded component and schema metadata without payload values.",
    semantics = "Bounded domain invariants and relationships."
  )
  costs <- c(overview = 90L, structure = 240L, semantics = 220L)
  priors <- c(overview = 1.30, structure = 1.10, semantics = 1.05)
  fields <- lapply(.capr_descriptor_sections, function(section) {
    list(
      schema = "cap.field.v1",
      id = sprintf("f1:%s@%s#compact", family, section),
      label = labels[[section]],
      description = unname(section_description[[section]]),
      sourceTypes = list(family),
      timing = "assemble",
      trust = "derived",
      exec = "local_cheap",
      contracts = list(
        extractor = sprintf("capr.%s.%s", family, section),
        redactor = sprintf("capr.%s.metadata_only", family),
        renderer = sprintf("capr.%s.%s.text_v1", family, section)
      ),
      selectionHints = list(
        priorValue = unname(priors[[section]]),
        intentTags = as.list(c(section, "structure", family))
      ),
      levels = list(list(
        level = 1L,
        estimatedCost = unname(costs[[section]]),
        description = unname(section_description[[section]])
      ))
    )
  })
  list(
    schema = "cap.field_catalog.v1",
    catalogId = catalog_id,
    sourceType = family,
    versions = list(
      cap = "2026-07-05-draft",
      fields = "f1",
      catalog = "v1-experimental"
    ),
    fields = fields
  )
}

capr_descriptor_redact <- function(value, field = NULL, context = list()) {
  caveats <- if (!is.null(field) && grepl("@overview#", field$id, fixed = TRUE)) {
    list(list(
      code = "capr_caveat_metadata_only",
      fieldId = field$id,
      message = paste(
        "experimental adapter inspected bounded metadata only; payload",
        "values, executable code, external resources, and active bindings",
        "were not evaluated"
      ),
      rule = "bounded-metadata-only"
    ))
  } else {
    list()
  }
  list(
    value = value,
    redacted = FALSE,
    warnings = character(),
    caveats = caveats,
    rules = character()
  )
}

capr_descriptor_render <- function(value, field = NULL, context = list()) {
  rendered <- capr_canonical_json(value, pretty = TRUE)
  if (nchar(rendered, type = "chars") > 5000L) {
    rendered <- paste0(substr(rendered, 1L, 4984L), "\n[truncated]")
  }
  paste0("<data>", capr_escape_data(rendered), "</data>")
}

capr_builtin_implementation_spec <- function(prefixes = character(),
                                             symbols = character(),
                                             constants = list()) {
  namespace <- environment(capr_builtin_implementation_spec)
  available <- ls(envir = namespace, all.names = TRUE)
  matched <- available[vapply(available, function(name) {
    any(startsWith(name, prefixes)) || name %in% symbols
  }, logical(1))]
  matched <- capr_stable_sort(unique(matched))
  functions <- lapply(matched, function(name) {
    value <- get(name, envir = namespace, inherits = FALSE)
    if (is.function(value)) capr_function_source_signature(value) else NULL
  })
  keep <- !vapply(functions, is.null, logical(1))
  functions <- functions[keep]
  names(functions) <- matched[keep]
  list(
    builder = capr_function_source_signature(capr_builtin_implementation_spec),
    functions = functions,
    constants = constants
  )
}

capr_new_descriptor_adapter <- function(id, family, label, snapshot_fn,
                                        semantic_level = "domain",
                                        capabilities = list(),
                                        implementation_spec = list()) {
  labels <- list(
    overview = sprintf("%s overview", label),
    structure = sprintf("%s structure", label),
    semantics = sprintf("%s semantics", label)
  )
  catalog_id <- sprintf("%s.v1", id)
  base_capabilities <- list(
    followup = FALSE,
    remote = FALSE,
    credentials = FALSE,
    deterministic = TRUE,
    metadata_only = TRUE,
    evaluates_user_code = FALSE,
    materializes_payload = FALSE
  )
  capabilities <- utils::modifyList(base_capabilities, capabilities)
  descriptor_spec <- list(
    builder = "capr-descriptor-adapter-v2",
    family = family,
    label = label,
    semantic_level = semantic_level,
    capabilities = capabilities,
    snapshot = capr_function_source_signature(snapshot_fn),
    helpers = list(
      bound_string = capr_function_source_signature(
        capr_descriptor_bound_string
      ),
      clean = capr_function_source_signature(capr_descriptor_clean),
      normalize = capr_function_source_signature(capr_descriptor_snapshot),
      cache = capr_function_source_signature(
        capr_cached_descriptor_snapshot
      )
    ),
    declared = implementation_spec
  )
  implementation_signature <- capr_implementation_spec_hash(descriptor_spec)
  extractors <- stats::setNames(
    lapply(.capr_descriptor_sections, function(section) {
      force(section)
      function(x, level = 1L, context = list()) {
        capr_cached_descriptor_snapshot(
          x, context, family, snapshot_fn, implementation_signature
        )[[section]]
      }
    }),
    sprintf("capr.%s.%s", family, .capr_descriptor_sections)
  )
  renderers <- stats::setNames(
    rep(list(capr_descriptor_render), length(.capr_descriptor_sections)),
    sprintf(
      "capr.%s.%s.text_v1", family, .capr_descriptor_sections
    )
  )

  cap_new_adapter(
    id = id,
    version = "0.1.0",
    provider = "capR",
    provider_version = .capr_version(),
    source_family = family,
    maturity = "experimental",
    semantic_level = semantic_level,
    conformance_claim = "none",
    capabilities = capabilities,
    source_ref = function(x, context = list()) {
      capr_descriptor_source_ref(
        x, context, family, label, snapshot_fn, implementation_signature
      )
    },
    field_catalog = function(x, context = list()) {
      capr_cached_descriptor_snapshot(
        x, context, family, snapshot_fn, implementation_signature
      )
      capr_descriptor_field_catalog(family, catalog_id, labels)
    },
    fingerprint = function(x, context = list()) {
      capr_descriptor_fingerprint(
        x, context, family, snapshot_fn, implementation_signature
      )
    },
    bindings = list(
      extractors = extractors,
      redactors = stats::setNames(
        list(capr_descriptor_redact),
        sprintf("capr.%s.metadata_only", family)
      ),
      renderers = renderers
    ),
    implementation_spec = descriptor_spec
  )
}
