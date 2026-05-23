# Getting started with autotool

``` r

library(autotool)
```

`autotool` generates an OpenAI / Anthropic / DeepSeek tool definition
from any R function by reading its signature and its documentation. This
vignette walks through the four common situations:

1.  A base-R function whose docs ship in installed `.Rd` files.
2.  A function from your own source code with roxygen comments.
3.  Hiding implementation-detail arguments from the model.
4.  Overriding what introspection cannot see (complex types).

## 1. Wrapping a base-R function

[`stats::rnorm`](https://rdrr.io/r/stats/Normal.html) has installed
help; `autotool` pulls the title and per-argument descriptions straight
from there.

``` r

tool_rnorm <- generate_tool(stats::rnorm)
tool_rnorm$`function`$name
#> [1] "rnorm"
tool_rnorm$`function`$description
#> [1] "The Normal Distribution"
tool_rnorm$`function`$parameters$properties$mean$description
#> [1] "vector of means."
unlist(tool_rnorm$`function`$parameters$required)
#> [1] "n"
```

The `required` list is derived from “no default in
[`formals()`](https://rdrr.io/r/base/formals.html)” — no manual second
list to keep in sync.

`mean` has default `0` (numeric), so it is typed as `"number"` and the
default propagates to the schema:

``` r

tool_rnorm$`function`$parameters$properties$mean
#> $type
#> [1] "number"
#> 
#> $default
#> [1] 0
#> 
#> $description
#> [1] "vector of means."
```

`n` has no default and R has no static types, so it falls back to
`"string"`. Override that with `schemas` (shown in step 4) or supply a
better description with `descriptions`:

``` r

tool_rnorm <- generate_tool(
  stats::rnorm,
  descriptions = list(n = "Number of random values to draw.")
)
tool_rnorm$`function`$parameters$properties$n
#> $type
#> [1] "string"
#> 
#> $description
#> [1] "Number of random values to draw."
```

## 2. Wrapping a source-loaded function

When a function is loaded from a source file (via
[`source()`](https://rdrr.io/r/base/source.html),
[`sys.source()`](https://rdrr.io/r/base/sys.source.html),
`devtools::load_all()`, or `box::use()`), its `srcref` attribute records
the file. `autotool` reads the `#'` comments above the definition
directly — no `roxygen2` dependency.

``` r

tmp <- tempfile(fileext = ".R")
writeLines(
  c(
    "#' Multiply two numbers together.",
    "#'",
    "#' @param a First factor.",
    "#' @param b Second factor.",
    "multiply <- function(a, b = 1) a * b"
  ),
  tmp
)
env <- new.env()
sys.source(tmp, envir = env, keep.source = TRUE)

tool_multiply <- generate_tool(env$multiply, name = "multiply")
tool_multiply$`function`$description
#> [1] "Multiply two numbers together."
tool_multiply$`function`$parameters$properties$a$description
#> [1] "First factor."
```

## 3. Hiding credentials and other infra arguments

This is the headline feature. Suppose you want to expose a real trading
function to a model but keep its `api_key`, `base_url`, and retry budget
pinned on your side.

``` r

fetch_quotes <- function(
  symbols,
  start,
  end = Sys.time(),
  api_key = NULL,
  base_url = "https://example.com",
  retries = 3L
) {
  return(list(symbols = symbols, start = start, end = end))
}

tool_quotes <- generate_tool(
  fetch_quotes,
  defaults = list(
    api_key  = "sk-not-shown-to-model",
    base_url = "https://example.com",
    retries  = 5L
  ),
  schemas = list(
    symbols = list(
      type = "array",
      items = list(type = "string"),
      description = "Ticker symbols, e.g. ['AAPL','NVDA']"
    ),
    start = list(
      type = "string",
      description = "ISO datetime floor, e.g. '2026-04-01T00:00:00Z'"
    ),
    end = list(
      type = "string",
      description = "ISO datetime ceiling. Default: now."
    )
  )
)
names(tool_quotes$`function`$parameters$properties)
#> [1] "symbols" "start"   "end"
```

The model sees only `symbols`, `start`, `end`. Build a handler once with
[`make_handler()`](https://dereckscompany.github.io/autotool/reference/make_handler.md)
and call it whenever the model dispatches:

``` r

handle_fetch_quotes <- make_handler(
  fetch_quotes,
  defaults = list(
    api_key = "sk-not-shown-to-model",
    base_url = "https://example.com",
    retries = 5L
  )
)

# When the model emits a tool call, parse its arguments and call:
model_emitted <- list(symbols = c("AAPL", "NVDA"), start = "2026-04-01")
handle_fetch_quotes(model_emitted)
#> $symbols
#> [1] "AAPL" "NVDA"
#> 
#> $start
#> [1] "2026-04-01"
#> 
#> $end
#> [1] "2026-05-23 18:37:28 UTC"
```

The pinned values are merged in before the function runs. The model
never sees the key. Plug the closure into your own handler registry
(e.g., `TOOL_HANDLERS <- list(fetch_quotes = handle_fetch_quotes)`) and
dispatch by name in your agent loop.

If you need post-processing — caching, result truncation, logging — just
write a regular 1-arg function instead of using
[`make_handler()`](https://dereckscompany.github.io/autotool/reference/make_handler.md).
The factory is a convenience, not a requirement.

## 4. Overriding what introspection cannot see

R’s lack of static types means `autotool` infers from default values and
falls back to `"string"` otherwise. For complex shapes —
arrays-of-objects, nested records, custom classes — supply a full schema
yourself via `schemas`:

``` r

submit_trades <- function(decisions, memo) invisible(NULL)

tool_submit <- generate_tool(
  submit_trades,
  description = "Submit a batch of trade decisions for execution.",
  schemas = list(
    decisions = list(
      type = "array",
      items = list(
        type = "object",
        properties = list(
          ticker = list(
            type = "string",
            description = "Ticker symbol, e.g. 'AAPL'."
          ),
          action = list(
            type = "string",
            enum = list("buy", "sell", "hold"),
            description = "Trade direction."
          ),
          notional = list(
            type = "number",
            description = "Dollar amount; 0 for hold."
          )
        ),
        required = list("ticker", "action", "notional")
      )
    ),
    memo = list(
      type = "string",
      description = "Short summary of this cycle's actions."
    )
  )
)
str(tool_submit$`function`$parameters$properties$decisions, max.level = 2)
#> List of 2
#>  $ type : chr "array"
#>  $ items:List of 3
#>   ..$ type      : chr "object"
#>   ..$ properties:List of 3
#>   ..$ required  :List of 3
```

## Type-inference reference

| Default value       | Inferred `type`                      |
|---------------------|--------------------------------------|
| no default          | `"string"` (override via `schemas`)  |
| `"value"`           | `"string"` with `default`            |
| `c("a", "b", "c")`  | `"string"` with `enum`               |
| `TRUE` / `FALSE`    | `"boolean"`                          |
| `1L`                | `"integer"`                          |
| `1.5` (or `1`, `0`) | `"number"`                           |
| `list(...)`         | `"object"` (use `schemas` for shape) |

## Compatibility

The output shape matches OpenAI’s and DeepSeek’s `tool` definitions and
is accepted as-is by any OpenAI-compatible server. The inner
`parameters` block is also what
[`ellmer::tool()`](https://ellmer.tidyverse.org/reference/tool.html)’s
`arguments` argument expects — so `autotool` can complement `ellmer`
rather than compete with it.
