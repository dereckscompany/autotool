#' Infer a JSON-schema fragment from an R formal's default value
#'
#' R has no static types on function arguments, so `autotool` infers a
#' best-effort type from each default value:
#'
#'   * No default → `"string"` (unknown).
#'   * `character` length 1 → `"string"` with default.
#'   * `character` length >1 → `"string"` with `enum` (the `match.arg`
#'     idiom: `function(x = c("a", "b", "c"))`).
#'   * `logical` → `"boolean"`.
#'   * `integer` → `"integer"`.
#'   * `numeric` (non-integer) → `"number"`.
#'   * `list` → `"object"`.
#'   * Anything else → `"string"`.
#'
#' For non-trivial argument types (arrays of objects, nested records,
#' classed objects), pass a hand-written schema via the `schemas`
#' argument of [generate_tool()].
#'
#' @param default A single element from `formals(fn)`.
#' @return A named list with at minimum a `type` field.
#' @noRd
infer_arg_schema <- function(default) {
  if (missing_default(default)) {
    return(list(type = "string"))
  }
  val <- tryCatch(eval(default), error = function(e) NULL)
  if (is.null(val)) {
    return(list(type = "string"))
  }
  if (is.character(val) && length(val) > 1) {
    return(list(type = "string", enum = as.list(val)))
  }
  cls <- class(val)[1]
  type <- switch(
    cls,
    character = "string",
    logical = "boolean",
    integer = "integer",
    numeric = "number",
    list = "object",
    "string"
  )
  schema <- list(type = type)
  if (length(val) == 1 && is.atomic(val)) {
    schema$default <- val
  }
  return(schema)
}
