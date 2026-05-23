#' Build a tool-call handler from a function and pinned defaults
#'
#' Companion to [generate_tool()]. Returns a 1-argument closure that
#' merges the supplied `defaults` under whatever argument list the LLM
#' produced at tool-call time, then invokes `fn`. Drop the closure into
#' your handler registry, call it with the model's parsed arguments.
#'
#' The merge gives the model's arguments precedence: anything the model
#' supplies for a key in `defaults` overrides the pinned value. That is
#' usually correct — hidden arguments have defaults the model cannot see,
#' so it has no way to supply them — but if you want strict pinning,
#' validate before calling.
#'
#' `fn` and `defaults` are forced at factory-call time, so reassigning
#' the surrounding bindings later does not change the handler's
#' behaviour.
#'
#' @param fn The function to invoke.
#' @param defaults Named list of pinned arguments (typically the same
#'   list passed to [generate_tool()]).
#'
#' @return A function of a single argument (`model_args`) that returns
#'   whatever `fn` returns.
#'
#' @seealso [generate_tool()].
#'
#' @examples
#' add <- function(x, y, scale = 1) (x + y) * scale
#' handler <- make_handler(add, defaults = list(scale = 10))
#' handler(list(x = 2, y = 3))
#' # 50
#'
#' @export
make_handler <- function(fn, defaults = list()) {
  if (!is.function(fn)) {
    stop("`fn` must be a function.", call. = FALSE)
  }
  force(fn)
  force(defaults)
  return(function(model_args) {
    if (is.null(model_args)) {
      model_args <- list()
    }
    args <- utils::modifyList(defaults, as.list(model_args))
    return(do.call(fn, args))
  })
}
