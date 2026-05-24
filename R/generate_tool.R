#' Generate an LLM tool definition from an R function
#'
#' Builds a tool definition by introspecting `formals(fn)` for the argument
#' shape and one of two documentation backends — roxygen-via-`srcref` for
#' source-loaded functions, or Rd-via-`tools::Rd_db()` for installed
#' packages — for descriptions.
#'
#' The output `format` controls the wire shape:
#'
#'   * `"openai"` (default) returns a plain list matching OpenAI's
#'     chat-completions `tool` schema. Accepted as-is by any
#'     OpenAI-compatible server (DeepSeek, Mistral, vLLM, llama.cpp,
#'     etc.).
#'   * `"ellmer"` returns an [`ellmer::tool()`][ellmer::tool] R6 object
#'     ready to register with an `ellmer::chat_*()` session. Requires
#'     the `ellmer` package.
#'
#' The introspection happens once regardless of format; only the final
#' wrapper differs.
#'
#' ## Hiding implementation-detail arguments
#'
#' The headline feature is `defaults`. Any argument named there is
#' removed from the schema the model sees. With `format = "openai"`,
#' pair with [make_handler()] to merge those values back in when you
#' dispatch the model's tool call. With `format = "ellmer"`, the
#' returned tool object already wraps the function so defaults are
#' injected automatically.
#'
#' ## Overriding what introspection sees
#'
#'   * `descriptions = list(arg = "...")` overrides per-argument
#'     description text — useful when installed-package docs are too
#'     terse for an LLM.
#'   * `schemas = list(arg = list(...))` overrides the full schema for
#'     one or more arguments — necessary for arrays-of-objects and
#'     other nested shapes R's lack of static types cannot infer.
#'   * `required` overrides the auto-derived required-arg list:
#'     `NULL` (default) derives it from `formals()`; a character
#'     vector replaces the derived list entirely.
#'
#' @param fn A function. Bare symbol or `pkg::fn` both work.
#' @param defaults Named list of arguments to hide from the model and
#'   inject at call time.
#' @param descriptions Named list of per-argument description overrides.
#' @param schemas Named list of per-argument schema overrides (lists
#'   matching the OpenAPI property shape).
#' @param required `NULL` (default) to auto-derive the required list
#'   from `formals(fn)` (arguments with no default are required), or a
#'   character vector specifying the exact required-argument names.
#'   Pass `character()` to mark every argument optional.
#' @param name Override the tool name. Defaults to the function name.
#' @param description Override the tool description. Defaults to the
#'   parsed documentation title, or a stub like `"Call <fn>()."` when no
#'   documentation title and no explicit override are available.
#' @param format Output shape. One of `"openai"` (the default plain list)
#'   or `"ellmer"` (an `ellmer::tool()` R6 object).
#'
#' @return A list (for `"openai"`) or an `ellmer` tool object (for
#'   `"ellmer"`).
#'
#' @seealso [make_handler()] for the matching runtime helper when using
#'   `format = "openai"`.
#'
#' @examples
#' # Default OpenAI / DeepSeek shape
#' tool <- generate_tool(stats::rnorm)
#' tool$`function`$name
#' unlist(tool$`function`$parameters$required)
#'
#' # Override the required-arg list
#' tool <- generate_tool(stats::rnorm, required = character())
#' unlist(tool$`function`$parameters$required) # character(0) — nothing required
#'
#' @export
generate_tool <- function(
  fn,
  defaults = list(),
  descriptions = list(),
  schemas = list(),
  required = NULL,
  name = NULL,
  description = NULL,
  format = c("openai", "ellmer")
) {
  fn_expr <- substitute(fn)
  if (!is.function(fn)) {
    stop("`fn` must be a function.", call. = FALSE)
  }
  format <- match.arg(format)

  fn_name <- resolve_fn_name(fn_expr)
  tool_name <- tool_name_from(fn_name, name)

  rep <- introspect(
    fn = fn,
    fn_name = fn_name,
    tool_name = tool_name,
    defaults = defaults,
    descriptions = descriptions,
    schemas = schemas,
    required = required,
    description = description
  )

  return(switch(
    format,
    openai = build_openai_tool(rep),
    ellmer = build_ellmer_tool(rep, fn, defaults)
  ))
}
