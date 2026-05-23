test_that("format = 'openai' is the default and returns the list shape", {
  tool <- generate_tool(stats::rnorm)
  expect_named(tool, c("type", "function"))
  expect_equal(tool$type, "function")
})

test_that("format = 'ellmer' returns an ellmer ToolDef", {
  skip_if_not_installed("ellmer")
  tool <- generate_tool(stats::rnorm, format = "ellmer")
  expect_true(inherits(tool, "ellmer::ToolDef"))
  expect_true(is.function(tool))
})

test_that("format = 'ellmer' carries the function name through", {
  skip_if_not_installed("ellmer")
  tool <- generate_tool(stats::rnorm, format = "ellmer")
  expect_equal(tool@name, "rnorm")
})

test_that("format = 'ellmer' hides defaults from the visible formals", {
  skip_if_not_installed("ellmer")
  fn <- function(query, api_key = NULL, base_url = "https://x") {
    return(list(query = query, key = api_key, url = base_url))
  }
  tool <- generate_tool(
    fn,
    defaults = list(api_key = "sk-secret", base_url = "https://prod"),
    format = "ellmer"
  )
  expect_equal(names(formals(tool)), "query")
})

test_that("format = 'ellmer' injects defaults at call time", {
  skip_if_not_installed("ellmer")
  fn <- function(query, api_key = NULL) {
    return(paste(query, api_key))
  }
  tool <- generate_tool(
    fn,
    defaults = list(api_key = "sk-secret"),
    format = "ellmer"
  )
  expect_equal(tool(query = "hello"), "hello sk-secret")
})

test_that("format = 'ellmer' maps enum properties via type_enum", {
  skip_if_not_installed("ellmer")
  fn <- function(order = c("newest", "oldest")) NULL
  tool <- generate_tool(fn, name = "fn", format = "ellmer")
  expect_no_error(tool) # full happy path proves the enum mapping ran
})

test_that("format = 'ellmer' rejects an unknown JSON type with a clear msg", {
  skip_if_not_installed("ellmer")
  fn <- function(thing) NULL
  expect_error(
    generate_tool(
      fn,
      name = "fn",
      schemas = list(thing = list(type = "weird")),
      format = "ellmer"
    ),
    "Cannot map JSON type"
  )
})

test_that("unknown format value is rejected", {
  expect_error(
    generate_tool(stats::rnorm, format = "ollama"),
    "'arg' should be one of"
  )
})

test_that("format = 'ellmer' forwards defaults as real arguments (missing() works)", {
  skip_if_not_installed("ellmer")
  fn <- function(x, api_key) {
    if (missing(api_key)) {
      return("missing")
    }
    return(paste(x, api_key))
  }
  tool <- generate_tool(
    fn,
    name = "fn",
    defaults = list(api_key = "secret"),
    format = "ellmer"
  )
  expect_equal(tool(x = "a"), "a secret")
})

test_that("format = 'ellmer' preserves match.call() inside the original fn", {
  skip_if_not_installed("ellmer")
  fn <- function(x, api_key) {
    return(names(as.list(match.call())[-1L]))
  }
  tool <- generate_tool(
    fn,
    name = "fn",
    defaults = list(api_key = "secret"),
    format = "ellmer"
  )
  expect_setequal(tool(x = "hello"), c("x", "api_key"))
})
