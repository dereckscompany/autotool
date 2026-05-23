test_that("required = NULL derives the list from formals (default)", {
  fn <- function(x, y = 1) NULL
  tool <- generate_tool(fn, name = "fn")
  expect_equal(unlist(tool$`function`$parameters$required), "x")
})

test_that("required = character() marks every argument optional", {
  fn <- function(x, y) NULL
  tool <- generate_tool(fn, name = "fn", required = character())
  expect_length(tool$`function`$parameters$required, 0)
})

test_that("required as an explicit character vector overrides derived", {
  fn <- function(x = 1, y = 2) NULL
  tool <- generate_tool(fn, name = "fn", required = c("x", "y"))
  expect_equal(
    sort(unlist(tool$`function`$parameters$required)),
    c("x", "y")
  )
})

test_that("required errors on unknown argument names", {
  fn <- function(x) NULL
  expect_error(
    generate_tool(fn, name = "fn", required = "nope"),
    "references args not in formals"
  )
})

test_that("required errors when not a character vector", {
  fn <- function(x) NULL
  expect_error(
    generate_tool(fn, name = "fn", required = list("x")),
    "must be NULL or a character vector"
  )
})

test_that("required overlapping defaults warns and the overlap is dropped", {
  fn <- function(x, key = NULL) NULL
  expect_warning(
    tool <- generate_tool(
      fn,
      name = "fn",
      defaults = list(key = "secret"),
      required = c("x", "key")
    ),
    "includes hidden args"
  )
  expect_equal(unlist(tool$`function`$parameters$required), "x")
})
