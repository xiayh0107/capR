.capr_default_registry <- local({
  registry <- NULL
  function(reset = FALSE) {
    if (reset || is.null(registry)) {
      registry <<- structure(
        list2env(
          list(entries = list(), generation = 0L),
          parent = emptyenv()
        ),
        class = c("capr_registry", "environment")
      )
    }
    registry
  }
})

#' Create or access an adapter registry
#'
#' @param global If `TRUE`, return the process-global registry. Otherwise
#'   create a new isolated registry.
#' @return A mutable `capr_registry` environment.
#' @export
cap_registry <- function(global = TRUE) {
  global <- capr_assert_flag(global, "global", "capr_registry_conflict")
  if (global) return(.capr_default_registry())
  structure(
    list2env(
      list(entries = list(), generation = 0L),
      parent = emptyenv()
    ),
    class = c("capr_registry", "environment")
  )
}

capr_validate_registry <- function(registry) {
  if (!inherits(registry, "capr_registry") || !is.environment(registry) ||
      !all(c("entries", "generation") %in% names(registry))) {
    capr_abort("capr_registry_conflict", "invalid capR registry")
  }
  invisible(registry)
}

capr_registry_set_entries <- function(registry, entries) {
  registry$entries <- entries
  registry$generation <- registry$generation + 1L
  registry
}

capr_factory_adapter <- function(factory) {
  if (inherits(factory, "capr_adapter")) {
    adapter <- factory
    factory <- local({
      value <- adapter
      function() value
    })
  } else if (is.function(factory)) {
    adapter <- tryCatch(
      factory(),
      error = function(e) capr_abort(
        "capr_adapter_invalid",
        "adapter factory failed during registration",
        parent = e
      )
    )
  } else {
    capr_abort(
      "capr_adapter_invalid",
      "`adapter_factory` must be an adapter or zero-argument function"
    )
  }
  cap_validate_adapter(adapter)
  list(factory = factory, adapter = adapter)
}

capr_registry_key <- function(class, adapter) {
  paste(
    enc2utf8(class),
    adapter$metadata$id,
    adapter$metadata$version,
    sep = "::"
  )
}

#' Register an adapter
#'
#' @param class Host S3 class.
#' @param adapter_factory A validated adapter or zero-argument factory.
#' @param priority Integer tie-break priority.
#' @param registry Registry returned by `cap_registry()`.
#' @param origin Optional registration origin.
#' @return The registry, invisibly.
#' @export
cap_register_adapter <- function(class, adapter_factory, priority = 0L,
                                 registry = cap_registry(),
                                 origin = "runtime") {
  capr_validate_registry(registry)
  class <- capr_assert_scalar_character(
    class, "class", condition = "capr_registry_conflict"
  )
  if (!is.numeric(priority) || length(priority) != 1L || is.na(priority) ||
      !is.finite(priority) || priority != floor(priority)) {
    capr_abort(
      "capr_registry_conflict",
      "`priority` must be one finite integer",
      class = class
    )
  }
  built <- capr_factory_adapter(adapter_factory)
  adapter <- built$adapter
  key <- capr_registry_key(class, adapter)
  existing_index <- which(vapply(
    registry$entries,
    function(entry) identical(entry$key, key),
    logical(1)
  ))
  entry <- list(
    key = key,
    class = class,
    factory = built$factory,
    metadata = adapter$metadata,
    binding_signature = capr_binding_signature(adapter),
    priority = as.integer(priority),
    origin = enc2utf8(as.character(origin)),
    registration_index = length(registry$entries) + 1L
  )
  if (length(existing_index)) {
    existing <- registry$entries[[existing_index[[1L]]]]
    same <- identical(
      existing[c("class", "metadata", "binding_signature", "priority")],
      entry[c("class", "metadata", "binding_signature", "priority")]
    )
    if (same) return(invisible(registry))
    capr_abort(
      "capr_registry_conflict",
      "conflicting registration for the same adapter identity",
      class = class,
      adapter_id = adapter$metadata$id,
      adapter_version = adapter$metadata$version
    )
  }
  registry <- capr_registry_set_entries(
    registry,
    c(registry$entries, list(entry))
  )
  invisible(registry)
}

#' Unregister adapters
#'
#' @param class Optional host class.
#' @param id Optional adapter ID.
#' @param version Optional adapter version.
#' @inheritParams cap_register_adapter
#' @return The number of removed entries.
#' @export
cap_unregister_adapter <- function(class = NULL, id = NULL, version = NULL,
                                   registry = cap_registry()) {
  capr_validate_registry(registry)
  keep <- vapply(registry$entries, function(entry) {
    matched <- (is.null(class) || identical(entry$class, class)) &&
      (is.null(id) || identical(entry$metadata$id, id)) &&
      (is.null(version) || identical(entry$metadata$version, version))
    !matched
  }, logical(1))
  removed <- sum(!keep)
  if (removed) capr_registry_set_entries(registry, registry$entries[keep])
  invisible(removed)
}

#' List registered adapters
#' @inheritParams cap_register_adapter
#' @return A deterministically ordered data frame.
#' @export
cap_list_adapters <- function(registry = cap_registry()) {
  capr_validate_registry(registry)
  if (!length(registry$entries)) {
    return(data.frame(
      class = character(), id = character(), version = character(),
      provider = character(), provider_version = character(),
      source_family = character(), maturity = character(),
      priority = integer(), origin = character(),
      stringsAsFactors = FALSE
    ))
  }
  rows <- lapply(registry$entries, function(entry) {
    m <- entry$metadata
    data.frame(
      class = entry$class, id = m$id, version = m$version,
      provider = m$provider, provider_version = m$provider_version,
      source_family = m$source_family, maturity = m$maturity,
      priority = entry$priority, origin = entry$origin,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out[order(
    out$class, -out$priority, out$id, out$version,
    method = "radix"
  ), , drop = FALSE]
}

#' Snapshot and restore a registry
#'
#' Snapshots are process-local and include adapter factories. Serialized lock
#' files use `cap_resolution_sidecar()` instead.
#'
#' @inheritParams cap_register_adapter
#' @return A snapshot or restored registry.
#' @export
cap_registry_snapshot <- function(registry = cap_registry()) {
  capr_validate_registry(registry)
  structure(
    list(
      schema = "capr.registry_snapshot.v1",
      generation = registry$generation,
      entries = registry$entries
    ),
    class = "capr_registry_snapshot"
  )
}

#' @rdname cap_registry_snapshot
#' @param snapshot A snapshot from `cap_registry_snapshot()`.
#' @export
cap_registry_restore <- function(snapshot, registry = cap_registry()) {
  capr_validate_registry(registry)
  if (!inherits(snapshot, "capr_registry_snapshot") ||
      !identical(snapshot$schema, "capr.registry_snapshot.v1")) {
    capr_abort("capr_registry_conflict", "invalid registry snapshot")
  }
  registry$entries <- snapshot$entries
  registry$generation <- as.integer(snapshot$generation)
  invisible(registry)
}

capr_make_candidate <- function(entry, class_index, mode) {
  list(
    entry = entry,
    class_index = as.integer(class_index),
    priority = entry$priority,
    mode = mode,
    id = entry$metadata$id,
    version = entry$metadata$version
  )
}

capr_attach_resolution <- function(adapter, selected, rejected, matched_class = NULL) {
  attr(adapter, "capr_resolution") <- list(
    schema = "capr.resolution_diagnostics.v1",
    selected = selected,
    rejected = rejected,
    matched_class = matched_class
  )
  adapter
}

#' Inspect adapter resolution diagnostics
#' @param adapter A resolved adapter.
#' @return Structured selected and rejected candidate diagnostics.
#' @export
cap_resolution_diagnostics <- function(adapter) {
  cap_validate_adapter(adapter)
  attr(adapter, "capr_resolution") %||% list(
    schema = "capr.resolution_diagnostics.v1",
    selected = list(mode = "unresolved"),
    rejected = list(),
    matched_class = NULL
  )
}

capr_resolve_explicit_id <- function(id, registry) {
  matches <- Filter(
    function(entry) identical(entry$metadata$id, id),
    registry$entries
  )
  if (!length(matches)) {
    capr_abort(
      "capr_adapter_not_found",
      sprintf("explicit adapter `%s` is not registered", id),
      adapter_id = id
    )
  }
  identities <- unique(vapply(
    matches,
    function(entry) paste(
      entry$metadata$id, entry$metadata$version,
      entry$metadata$provider, entry$binding_signature,
      sep = "::"
    ),
    character(1)
  ))
  if (length(identities) != 1L) {
    capr_abort(
      "capr_adapter_ambiguous",
      sprintf("explicit adapter ID `%s` resolves to multiple identities", id),
      adapter_id = id,
      candidates = identities
    )
  }
  matches[[1L]]
}

#' Resolve one adapter deterministically
#'
#' @param x Source object.
#' @param adapter Optional explicit adapter object or registered adapter ID.
#' @param registry Adapter registry.
#' @param allow_fallback Whether structural fallback is permitted.
#' @return One validated adapter with resolution diagnostics.
#' @export
cap_resolve_adapter <- function(x, adapter = NULL, registry = cap_registry(),
                                allow_fallback = FALSE) {
  capr_validate_registry(registry)
  allow_fallback <- capr_assert_flag(
    allow_fallback, "allow_fallback", "capr_fallback_disallowed"
  )
  if (inherits(adapter, "capr_adapter")) {
    cap_validate_adapter(adapter)
    return(capr_attach_resolution(
      adapter,
      list(mode = "explicit_object", id = adapter$metadata$id),
      list()
    ))
  }
  if (is.character(adapter) && length(adapter) == 1L && !is.na(adapter)) {
    entry <- capr_resolve_explicit_id(enc2utf8(adapter), registry)
    resolved <- entry$factory()
    cap_validate_adapter(resolved)
    return(capr_attach_resolution(
      resolved,
      list(mode = "explicit_id", id = resolved$metadata$id),
      list(),
      entry$class
    ))
  }
  if (!is.null(adapter)) {
    capr_abort(
      "capr_adapter_invalid",
      "`adapter` must be NULL, an adapter object, or an adapter ID"
    )
  }

  bridge <- cap_adapter(x)
  if (!is.null(bridge)) {
    cap_validate_adapter(bridge)
    return(capr_attach_resolution(
      bridge,
      list(mode = "s3_bridge", id = bridge$metadata$id),
      list()
    ))
  }

  host_classes <- class(x)
  if (!length(host_classes)) host_classes <- typeof(x)
  candidates <- list()
  for (entry in registry$entries) {
    class_index <- match(entry$class, host_classes, nomatch = 0L)
    if (class_index > 0L) {
      candidates[[length(candidates) + 1L]] <- capr_make_candidate(
        entry,
        class_index,
        if (class_index == 1L) "registry_exact" else "registry_inherited"
      )
    }
  }
  if (length(candidates)) {
    specificity <- min(vapply(candidates, `[[`, integer(1), "class_index"))
    candidates <- Filter(function(x) x$class_index == specificity, candidates)
    best_priority <- max(vapply(candidates, `[[`, integer(1), "priority"))
    finalists <- Filter(function(x) x$priority == best_priority, candidates)
    effective <- unique(vapply(
      finalists,
      function(candidate) paste(
        candidate$id,
        candidate$version,
        candidate$entry$metadata$provider,
        candidate$entry$binding_signature,
        sep = "::"
      ),
      character(1)
    ))
    if (length(effective) > 1L) {
      capr_abort(
        "capr_adapter_ambiguous",
        "multiple adapters have equal effective precedence",
        host_classes = host_classes,
        candidates = effective,
        priority = best_priority
      )
    }
    selected <- finalists[[1L]]
    resolved <- selected$entry$factory()
    cap_validate_adapter(resolved)
    rejected <- lapply(
      Filter(function(candidate) !identical(candidate$entry$key, selected$entry$key), candidates),
      function(candidate) list(
        id = candidate$id,
        version = candidate$version,
        reason = "lower_effective_precedence"
      )
    )
    return(capr_attach_resolution(
      resolved,
      list(
        mode = selected$mode,
        id = selected$id,
        version = selected$version,
        priority = selected$priority
      ),
      rejected,
      selected$entry$class
    ))
  }

  if (allow_fallback) {
    fallback <- cap_structural_adapter()
    return(capr_attach_resolution(
      fallback,
      list(mode = "fallback", id = fallback$metadata$id),
      list()
    ))
  }
  capr_abort(
    "capr_adapter_not_found",
    "no adapter matched the source and structural fallback is disabled",
    host_classes = host_classes,
    fallback_allowed = FALSE
  )
}
