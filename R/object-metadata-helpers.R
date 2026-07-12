capr_data_frame_row_count <- function(x) {
  classes <- unname(class(x))
  if (!is.list(x) || !any(classes %in% c(
    "data.frame", "tbl_df", "tbl", "tbl_ts", "sf"
  ))) {
    capr_abort(
      "capr_adapter_invalid",
      "row-count metadata requires a data-frame-backed object"
    )
  }
  rows <- tryCatch(
    .row_names_info(x, type = 2L),
    error = function(e) NA_real_
  )
  if (!is.numeric(rows) || length(rows) != 1L || is.na(rows) ||
      !is.finite(rows) || rows < 0 || rows > .Machine$integer.max) {
    capr_abort(
      "capr_adapter_invalid",
      "data-frame row metadata is malformed or outside the supported bound"
    )
  }
  as.integer(rows)
}
