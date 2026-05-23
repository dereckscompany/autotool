test_that("merges defaults under model args and invokes the function", {
  fn <- function(x, y, scale = 1) (x + y) * scale
  out <- call_with_defaults(
    fn,
    list(x = 2, y = 3),
    defaults = list(scale = 10)
  )
  expect_equal(out, 50)
})

test_that("model args win over defaults when both supply a key", {
  fn <- function(x = 0, y = 0) x + y
  out <- call_with_defaults(
    fn,
    list(x = 5),
    defaults = list(x = 99, y = 1)
  )
  expect_equal(out, 6)
})

test_that("NULL model_args is treated as an empty list", {
  fn <- function(x = 7) x
  expect_equal(call_with_defaults(fn, NULL), 7)
})

test_that("non-function input is rejected", {
  expect_error(
    call_with_defaults("not a function", list()),
    "must be a function"
  )
})
