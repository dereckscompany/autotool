test_that("returns a function that merges defaults under model args", {
  fn <- function(x, y, scale = 1) (x + y) * scale
  handler <- make_handler(fn, defaults = list(scale = 10))
  expect_type(handler, "closure")
  expect_equal(handler(list(x = 2, y = 3)), 50)
})

test_that("model args win over defaults when both supply a key", {
  fn <- function(x = 0, y = 0) x + y
  handler <- make_handler(fn, defaults = list(x = 99, y = 1))
  expect_equal(handler(list(x = 5)), 6)
})

test_that("NULL model_args is treated as an empty list", {
  fn <- function(x = 7) x
  handler <- make_handler(fn, defaults = list())
  expect_equal(handler(NULL), 7)
})

test_that("defaults default to an empty list", {
  fn <- function(x = 3) x
  handler <- make_handler(fn)
  expect_equal(handler(list()), 3)
})

test_that("non-function input is rejected at factory time", {
  expect_error(make_handler("not a function"), "must be a function")
})

test_that("fn and defaults are captured by value at factory time", {
  scale_var <- 10
  fn <- function(x, scale) x * scale
  handler <- make_handler(fn, defaults = list(scale = scale_var))
  scale_var <- 999
  expect_equal(handler(list(x = 2)), 20)
})

test_that("handler can be called repeatedly with different args", {
  fn <- function(x, scale = 1) x * scale
  handler <- make_handler(fn, defaults = list(scale = 3))
  expect_equal(handler(list(x = 1)), 3)
  expect_equal(handler(list(x = 4)), 12)
  expect_equal(handler(list(x = 10, scale = 2)), 20)
  expect_equal(handler(list(x = 1)), 3)
})
