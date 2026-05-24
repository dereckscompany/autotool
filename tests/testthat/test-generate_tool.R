test_that("returns the OpenAI-shaped envelope", {
  tool <- generate_tool(stats::rnorm)
  expect_named(tool, c("type", "function"))
  expect_equal(tool$type, "function")
  expect_named(
    tool$`function`,
    c("name", "description", "parameters")
  )
  expect_equal(tool$`function`$parameters$type, "object")
  expect_type(tool$`function`$parameters$properties, "list")
  expect_type(tool$`function`$parameters$required, "list")
})

test_that("Rd backend supplies title and per-arg descriptions", {
  tool <- generate_tool(stats::rnorm)
  expect_equal(tool$`function`$name, "rnorm")
  expect_match(tool$`function`$description, "Normal Distribution")
  expect_match(
    tool$`function`$parameters$properties$mean$description,
    "vector of means"
  )
})

test_that("required is derived from formals with no default", {
  tool <- generate_tool(stats::rnorm)
  expect_equal(unlist(tool$`function`$parameters$required), "n")
})

test_that("type inference picks number / boolean / integer / object", {
  fn <- function(a, b = 1.5, c = TRUE, d = 3L, e = list()) NULL
  tool <- generate_tool(fn, name = "fn")
  props <- tool$`function`$parameters$properties
  expect_equal(props$a$type, "string") # no default → fallback
  expect_equal(props$b$type, "number")
  expect_equal(props$c$type, "boolean")
  expect_equal(props$d$type, "integer")
  expect_equal(props$e$type, "object")
})

test_that("match.arg style multi-character default becomes an enum", {
  fn <- function(order = c("newest", "oldest")) NULL
  tool <- generate_tool(fn, name = "fn")
  prop <- tool$`function`$parameters$properties$order
  expect_equal(prop$type, "string")
  expect_equal(unlist(prop$enum), c("newest", "oldest"))
})

test_that("defaults removes args from the visible schema", {
  fn <- function(query, api_key = NULL, base_url = "x") NULL
  tool <- generate_tool(
    fn,
    name = "fn",
    defaults = list(api_key = "secret", base_url = "y")
  )
  expect_named(tool$`function`$parameters$properties, "query")
  expect_equal(unlist(tool$`function`$parameters$required), "query")
})

test_that("unknown keys in defaults raise a warning", {
  fn <- function(x) NULL
  expect_warning(
    generate_tool(fn, name = "fn", defaults = list(bogus = 1)),
    "not in formals"
  )
})

test_that("descriptions overrides docs and defaults", {
  fn <- function(x = 1) NULL
  tool <- generate_tool(
    fn,
    name = "fn",
    descriptions = list(x = "Overridden text.")
  )
  expect_equal(
    tool$`function`$parameters$properties$x$description,
    "Overridden text."
  )
})

test_that("schemas overrides the whole property entry", {
  fn <- function(symbols) NULL
  tool <- generate_tool(
    fn,
    name = "fn",
    schemas = list(
      symbols = list(
        type = "array",
        items = list(type = "string"),
        description = "Ticker symbols."
      )
    )
  )
  expect_equal(tool$`function`$parameters$properties$symbols$type, "array")
  expect_equal(
    tool$`function`$parameters$properties$symbols$items$type,
    "string"
  )
})

test_that("name override beats the function symbol", {
  fn <- function(x) NULL
  tool <- generate_tool(fn, name = "renamed")
  expect_equal(tool$`function`$name, "renamed")
})

test_that("pkg::fn expressions resolve to the inner name", {
  tool <- generate_tool(stats::rnorm)
  expect_equal(tool$`function`$name, "rnorm")
})

test_that("non-function input is rejected", {
  expect_error(generate_tool(42, name = "n"), "must be a function")
})

test_that("name override changes the tool name but NOT the docs lookup", {
  tmp <- tempfile(fileext = ".R")
  writeLines(
    c(
      "#' Documented under its real source name.",
      "#'",
      "#' @param a An argument.",
      "real_fn <- function(a = 1) a"
    ),
    tmp
  )
  env <- new.env()
  sys.source(tmp, envir = env, keep.source = TRUE)
  tool <- generate_tool(env$real_fn, name = "custom_tool_name")
  # Tool name reflects the override
  expect_equal(tool$`function`$name, "custom_tool_name")
  # But the description and per-arg description still come from roxygen
  # on the source function — the override must not bypass doc lookup.
  expect_match(tool$`function`$description, "Documented under its real source name")
  expect_equal(
    tool$`function`$parameters$properties$a$description,
    "An argument."
  )
  unlink(tmp)
})

test_that("anonymous function requires explicit name and has no docs", {
  tool <- generate_tool(function(x) x, name = "anon")
  expect_equal(tool$`function`$name, "anon")
  expect_equal(tool$`function`$description, "Call anon().")
})

test_that("anonymous function without name errors clearly", {
  expect_error(
    generate_tool(function(x) x),
    "anonymous function"
  )
})

test_that("aliasing a function and passing `name` does NOT recover docs", {
  # `name` is the tool name shown to the model and nothing else. If you
  # want docs, pass the function via an expression we can resolve (bare
  # symbol, pkg::fn, env$fn, env[[ "fn" ]]) — not through a local alias.
  f <- stats::rnorm
  tool <- generate_tool(f, name = "rnorm")
  expect_equal(tool$`function`$name, "rnorm")
  expect_equal(tool$`function`$description, "Call rnorm().")
})

test_that("env[['fn']] expressions resolve their source name", {
  tmp <- tempfile(fileext = ".R")
  writeLines(
    c(
      "#' Squares its input.",
      "#'",
      "#' @param x Number to square.",
      "sq <- function(x) x * x"
    ),
    tmp
  )
  env <- new.env()
  sys.source(tmp, envir = env, keep.source = TRUE)
  tool <- generate_tool(env[["sq"]])
  expect_equal(tool$`function`$name, "sq")
  expect_match(tool$`function`$description, "Squares its input")
  expect_equal(
    tool$`function`$parameters$properties$x$description,
    "Number to square."
  )
  unlink(tmp)
})

test_that("roxygen-via-srcref backend reads #' lines above a definition", {
  tmp <- tempfile(fileext = ".R")
  writeLines(
    c(
      "#' Adds two integers.",
      "#'",
      "#' @param a First addend.",
      "#' @param b Second addend.",
      "my_add <- function(a, b = 0L) a + b"
    ),
    tmp
  )
  env <- new.env()
  sys.source(tmp, envir = env, keep.source = TRUE)
  tool <- generate_tool(env$my_add, name = "my_add")
  expect_match(tool$`function`$description, "Adds two integers")
  props <- tool$`function`$parameters$properties
  expect_equal(props$a$description, "First addend.")
  expect_equal(props$b$description, "Second addend.")
  unlink(tmp)
})
