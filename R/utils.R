#' Return the first non-NULL, non-empty-string argument
#'
#' Small internal fallback helper. Returns `x` if it is non-NULL and not
#' an empty string; otherwise returns `y`.
#'
#' @param x,y Values to choose between.
#' @return `x` when present, else `y`.
#' @noRd
coalesce <- function(x, y) {
  if (is.null(x)) {
    return(y)
  }
  if (is.character(x) && length(x) == 1 && !nzchar(x)) {
    return(y)
  }
  return(x)
}

#' Detect an R formal with no default
#'
#' In [formals()], an argument declared without a default is represented
#' as an empty symbol — a length-0 name. This predicate identifies that
#' case.
#'
#' @param default A single element from `formals(fn)`.
#' @return `TRUE` if the formal has no default value.
#' @noRd
missing_default <- function(default) {
  return(is.symbol(default) && !nzchar(as.character(default)))
}

#' Resolve a function name from a call expression
#'
#' Accepts bare symbols (`foo`), namespaced calls (`pkg::foo`,
#' `pkg:::foo`), and an explicit override.
#'
#' @param fn_expr The captured expression naming the function.
#' @param override Optional explicit name; takes precedence.
#' @return A length-1 character vector with the function name.
#' @noRd
extract_fn_name <- function(fn_expr, override = NULL) {
  if (!is.null(override)) {
    return(override)
  }
  if (is.symbol(fn_expr)) {
    return(as.character(fn_expr))
  }
  if (is.call(fn_expr) && length(fn_expr) == 3) {
    op <- as.character(fn_expr[[1]])
    if (op %in% c("::", ":::")) return(as.character(fn_expr[[3]]))
  }
  stop("Cannot infer function name; pass `name = \"...\"`.", call. = FALSE)
}
