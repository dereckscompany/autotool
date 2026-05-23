#' Assemble an ellmer::tool() R6 object from the intermediate rep
#'
#' Maps each property in the intermediate to the appropriate
#' `ellmer::type_*()` constructor and wraps the underlying function so
#' that `defaults` are injected on every dispatch (ellmer calls the
#' function with named arguments, so the wrapper merges them via
#' [utils::modifyList()] before forwarding).
#'
#' Errors with a helpful message if `ellmer` isn't installed or if a
#' property's JSON `type` is unknown.
#'
#' @param rep The intermediate from `introspect()`.
#' @param fn The underlying function (needed because ellmer dispatches it).
#' @param defaults Named list of pinned args to inject on every call.
#' @return An ellmer tool object.
#' @noRd
build_ellmer_tool <- function(rep, fn, defaults) {
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop(
      "format = \"ellmer\" requires the ellmer package. ",
      "Install with `renv::install(\"ellmer\")` or use format = \"openai\".",
      call. = FALSE
    )
  }

  args <- list()
  for (arg_name in names(rep$properties)) {
    prop <- rep$properties[[arg_name]]
    args[[arg_name]] <- schema_to_ellmer_type(
      prop,
      required = arg_name %in% rep$required
    )
  }

  wrapped_fn <- wrap_fn_with_defaults(fn, defaults)

  return(ellmer::tool(
    wrapped_fn,
    rep$description,
    arguments = args,
    name = rep$name
  ))
}

#' Strip hidden arguments from a function's formals and bind their pinned
#' values in the function's enclosing environment, so the body still finds
#' them at execution time.
#'
#' Returning a function with only the *visible* arguments lets ellmer's
#' formals-vs-arguments cross-check pass while keeping the hidden values
#' invisible to the model.
#'
#' @param fn The original function.
#' @param defaults Named list of pinned arguments.
#' @return A function whose formals are the visible arguments only.
#' @noRd
wrap_fn_with_defaults <- function(fn, defaults) {
  if (length(defaults) == 0L) {
    return(fn)
  }
  fmls <- formals(fn)
  visible_fmls <- fmls[!names(fmls) %in% names(defaults)]

  new_fn <- fn
  formals(new_fn) <- visible_fmls

  env <- new.env(parent = environment(fn))
  for (nm in names(defaults)) {
    assign(nm, defaults[[nm]], envir = env)
  }
  environment(new_fn) <- env
  return(new_fn)
}

#' Map one property schema (from the intermediate rep) to an ellmer type
#'
#' Recursive: arrays and objects descend into their `items` / `properties`.
#' Catches `enum` even when nominally `type: "string"` (the OpenAI shape
#' marks enums on string properties via the `enum` field).
#'
#' @param schema One entry from `rep$properties`.
#' @param required Whether this argument is required at its level.
#' @return An ellmer type object.
#' @noRd
schema_to_ellmer_type <- function(schema, required = TRUE) {
  desc <- schema$description
  if (!is.null(schema$enum)) {
    return(ellmer::type_enum(
      values = unlist(schema$enum),
      description = desc,
      required = required
    ))
  }
  type <- schema$type
  if (is.null(type)) {
    stop(
      "Cannot map ellmer type: property has no `type` field.",
      call. = FALSE
    )
  }
  return(switch(
    type,
    string = ellmer::type_string(desc, required = required),
    integer = ellmer::type_integer(desc, required = required),
    number = ellmer::type_number(desc, required = required),
    boolean = ellmer::type_boolean(desc, required = required),
    array = build_ellmer_array(schema, desc, required),
    object = build_ellmer_object(schema, desc, required),
    stop(
      "Cannot map JSON type \"",
      type,
      "\" to an ellmer type.",
      call. = FALSE
    )
  ))
}

#' @noRd
build_ellmer_array <- function(schema, desc, required) {
  if (is.null(schema$items)) {
    stop(
      "Array property has no `items` schema; cannot build ellmer type_array().",
      call. = FALSE
    )
  }
  items_type <- schema_to_ellmer_type(schema$items, required = TRUE)
  return(ellmer::type_array(
    items = items_type,
    description = desc,
    required = required
  ))
}

#' @noRd
build_ellmer_object <- function(schema, desc, required) {
  props <- schema$properties
  if (is.null(props)) {
    stop(
      "Object property has no `properties`; cannot build ellmer type_object().",
      call. = FALSE
    )
  }
  inner_required <- unlist(schema$required)
  if (is.null(inner_required)) {
    inner_required <- character()
  }
  inner_args <- lapply(names(props), function(n) {
    return(schema_to_ellmer_type(props[[n]], required = n %in% inner_required))
  })
  names(inner_args) <- names(props)
  return(do.call(
    ellmer::type_object,
    c(
      list(.description = desc, .required = required),
      inner_args
    )
  ))
}
