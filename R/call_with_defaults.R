#' Dispatch a model tool call after merging hidden defaults
#'
#' Companion to [generate_tool()]. When the model emits a tool call,
#' you receive an argument list it produced from the visible schema.
#' This function merges those args with the `defaults` you pinned at
#' definition time (credentials, base URLs, etc.) and invokes the
#' underlying function.
#'
#' The merge gives the model's args precedence: anything the model
#' supplies for a key in `defaults` will override the pinned value.
#' That is usually correct — hidden args have defaults the model never
#' sees, so it cannot supply them — but if you want strict pinning,
#' validate before calling.
#'
#' @param fn The function to invoke.
#' @param model_args A (possibly empty) named list of arguments the
#'   model produced.
#' @param defaults Named list of pinned defaults (typically the same
#'   one passed to [generate_tool()]).
#'
#' @return Whatever `fn` returns.
#'
#' @seealso [generate_tool()].
#'
#' @examples
#' add <- function(x, y, scale = 1) (x + y) * scale
#' call_with_defaults(add, list(x = 2, y = 3), defaults = list(scale = 10))
#' # 50
#'
#' @export
call_with_defaults <- function(fn, model_args, defaults = list()) {
  if (!is.function(fn)) {
    stop("`fn` must be a function.", call. = FALSE)
  }
  if (is.null(model_args)) {
    model_args <- list()
  }
  args <- utils::modifyList(defaults, as.list(model_args))
  return(do.call(fn, args))
}
