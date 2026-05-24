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

#' Resolve the underlying R function's source name from a call expression
#'
#' Handles the call shapes users actually write when passing a function
#' to [generate_tool()]:
#'
#'   * bare symbol — `my_fn`
#'   * namespace lookup — `pkg::fn`, `pkg:::fn`
#'   * `$` access on an environment-like object (e.g. functions loaded
#'     via `box::use(pkg)` or `sys.source(..., envir = env)`) — `env$fn`
#'   * `[[` access with a string literal — `env[["fn"]]`
#'
#' Returns `NULL` for anything else (anonymous `function(...) ...`
#' literals, dynamic lookups via variable keys, function-returning
#' expressions, etc.). When this returns `NULL`, [generate_tool()]
#' requires the caller to supply `name` explicitly and skips
#' documentation lookup.
#'
#' This name is what `get_docs()` searches for in the source file or
#' in `tools::Rd_db()`; it is **not** the tool name the model sees.
#' The tool name is a separate concern (see `tool_name_from()` and the
#' `name` argument of [generate_tool()]) — overriding the tool name
#' must not interfere with documentation lookup.
#'
#' @param fn_expr The captured expression naming the function.
#' @return A length-1 character vector with the function's source name,
#'   or `NULL` if it cannot be determined.
#' @noRd
resolve_fn_name <- function(fn_expr) {
  if (is.symbol(fn_expr)) {
    return(as.character(fn_expr))
  }
  if (is.call(fn_expr) && length(fn_expr) == 3) {
    op <- as.character(fn_expr[[1]])
    if (op %in% c("::", ":::", "$")) {
      return(as.character(fn_expr[[3]]))
    }
    if (op == "[[") {
      key <- fn_expr[[3]]
      if (is.character(key) && length(key) == 1) {
        return(key)
      }
    }
  }
  return(NULL)
}

#' Pick the tool name shown to the model
#'
#' The explicit `name` argument wins; otherwise fall back to the
#' resolved source name; error if neither is available (anonymous
#' functions must be named explicitly).
#'
#' @param fn_name The resolved source name (may be `NULL`).
#' @param override The user-supplied `name` argument (may be `NULL`).
#' @return A length-1 character vector with the tool name.
#' @noRd
tool_name_from <- function(fn_name, override) {
  if (!is.null(override)) {
    return(override)
  }
  if (!is.null(fn_name)) {
    return(fn_name)
  }
  stop(
    "Cannot infer tool name from an anonymous function; pass `name = \"...\"`.",
    call. = FALSE
  )
}
