#' Build the format-agnostic intermediate tool representation
#'
#' Reads docs, walks `formals(fn)`, and applies the user's overrides
#' (`defaults`, `descriptions`, `schemas`, `required`) to produce a
#' representation each output builder consumes.
#'
#' The intermediate shape is:
#'
#' ```
#' list(
#'   name        = chr,
#'   description = chr,
#'   properties  = named list of property-schema lists (excludes hidden args),
#'   required    = character vector (effective required-arg names)
#' )
#' ```
#'
#' This is internal — users see only [generate_tool()] and its `format`
#' argument.
#'
#' @param fn The function.
#' @param fn_name Resolved function name.
#' @param defaults Named list of hidden arguments.
#' @param descriptions Per-argument description overrides.
#' @param schemas Per-argument schema overrides.
#' @param required Override list (NULL = derive from formals).
#' @param description Tool-level description override.
#' @return A list as described above.
#' @noRd
introspect <- function(fn, fn_name, defaults, descriptions, schemas,
                       required, description) {
  docs <- get_docs(fn, fn_name)
  fmls <- formals(fn)
  fmls_names <- setdiff(names(fmls), "...")
  hidden <- names(defaults)

  unknown_hidden <- setdiff(hidden, fmls_names)
  if (length(unknown_hidden) > 0L) {
    warning(
      "defaults contains args not in formals: ",
      paste(unknown_hidden, collapse = ", "),
      call. = FALSE
    )
  }

  if (!is.null(required)) {
    if (!is.character(required)) {
      stop(
        "`required` must be NULL or a character vector.",
        call. = FALSE
      )
    }
    unknown_required <- setdiff(required, fmls_names)
    if (length(unknown_required) > 0L) {
      stop(
        "`required` references args not in formals: ",
        paste(unknown_required, collapse = ", "),
        call. = FALSE
      )
    }
    overlap_hidden <- intersect(required, hidden)
    if (length(overlap_hidden) > 0L) {
      warning(
        "`required` includes hidden args (ignored): ",
        paste(overlap_hidden, collapse = ", "),
        call. = FALSE
      )
    }
  }

  visible <- setdiff(fmls_names, hidden)

  properties <- list()
  derived_required <- character()
  for (arg in visible) {
    schema <- if (!is.null(schemas[[arg]])) {
      schemas[[arg]]
    } else {
      infer_arg_schema(fmls[[arg]])
    }
    schema$description <- coalesce(
      coalesce(descriptions[[arg]], docs$doc$args[[arg]]),
      schema$description
    )
    properties[[arg]] <- schema
    if (missing_default(fmls[[arg]])) {
      derived_required <- c(derived_required, arg)
    }
  }

  effective_required <- if (is.null(required)) {
    derived_required
  } else {
    setdiff(required, hidden)
  }

  tool_description <- coalesce(
    coalesce(description, docs$doc$title),
    sprintf("Call %s().", fn_name)
  )

  return(list(
    name = fn_name,
    description = tool_description,
    properties = properties,
    required = effective_required
  ))
}
