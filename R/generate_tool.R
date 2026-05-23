#' Generate an LLM tool definition from an R function
#'
#' Produces an OpenAI- / DeepSeek-shaped tool definition list by
#' introspecting `formals(fn)` for the argument shape and one of two
#' documentation backends — roxygen-via-`srcref` for source-loaded
#' functions, or Rd-via-`tools::Rd_db()` for installed packages — for
#' descriptions.
#'
#' The shape returned is the union schema accepted by OpenAI, DeepSeek,
#' and most OpenAI-compatible servers:
#'
#' ```
#' list(
#'   type = "function",
#'   `function` = list(
#'     name        = "...",
#'     description = "...",
#'     parameters  = list(
#'       type       = "object",
#'       properties = list(...),
#'       required   = list("...")
#'     )
#'   )
#' )
#' ```
#'
#' Anthropic's tool format uses the inner `parameters` block under a
#' different key (`input_schema`) — wrap accordingly when targeting it.
#'
#' ## Hiding implementation-detail arguments
#'
#' The headline feature is `defaults`. Any argument named there is
#' removed from the schema the model sees, and [call_with_defaults()]
#' merges those values back in at call time. This is the right place
#' to pin API keys, base URLs, retry budgets, or anything the model
#' should not influence.
#'
#' ## Overrides
#'
#'   * `descriptions` overrides the per-argument description text
#'     (useful when the installed docs are too terse for an LLM).
#'   * `schemas` overrides the full schema for one or more arguments
#'     (necessary for arrays-of-objects and other nested shapes that
#'     introspection cannot infer).
#'
#' @param fn A function. Bare symbol or `pkg::fn` both work.
#' @param defaults Named list of arguments to hide from the model and
#'   inject at call time.
#' @param descriptions Named list of per-argument description overrides.
#' @param schemas Named list of per-argument schema overrides (lists
#'   matching the OpenAPI property shape).
#' @param name Override the tool name. Defaults to the function name.
#' @param description Override the tool description. Defaults to the
#'   parsed documentation title, or a stub.
#'
#' @return A list ready to drop into a chat-completions request.
#'
#' @seealso [call_with_defaults()] for the matching runtime helper.
#'
#' @examples
#' tool <- generate_tool(
#'   stats::rnorm,
#'   descriptions = list(n = "Number of values to draw.")
#' )
#' tool$`function`$name
#' tool$`function`$parameters$properties$mean
#'
#' @export
generate_tool <- function(
  fn,
  defaults = list(),
  descriptions = list(),
  schemas = list(),
  name = NULL,
  description = NULL
) {
  fn_expr <- substitute(fn)
  fn_name <- extract_fn_name(fn_expr, name)
  if (!is.function(fn)) {
    stop("`fn` must be a function.", call. = FALSE)
  }

  docs <- get_docs(fn, fn_name)
  fmls <- formals(fn)

  hidden <- names(defaults)
  unknown_hidden <- setdiff(hidden, names(fmls))
  if (length(unknown_hidden) > 0) {
    warning(
      "defaults contains args not in formals: ",
      paste(unknown_hidden, collapse = ", "),
      call. = FALSE
    )
  }

  properties <- list()
  required <- character()
  for (arg in names(fmls)) {
    if (arg == "..." || arg %in% hidden) {
      next
    }
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
      required <- c(required, arg)
    }
  }

  tool_description <- coalesce(
    coalesce(description, docs$doc$title),
    sprintf("Call %s().", fn_name)
  )

  return(list(
    type = "function",
    `function` = list(
      name = fn_name,
      description = tool_description,
      parameters = list(
        type = "object",
        properties = properties,
        required = as.list(required)
      )
    )
  ))
}
