# Generate an LLM tool definition from an R function

Produces an OpenAI- / DeepSeek-shaped tool definition list by
introspecting `formals(fn)` for the argument shape and one of two
documentation backends — roxygen-via-`srcref` for source-loaded
functions, or
Rd-via-[`tools::Rd_db()`](https://rdrr.io/r/tools/Rdutils.html) for
installed packages — for descriptions.

## Usage

``` r
generate_tool(
  fn,
  defaults = list(),
  descriptions = list(),
  schemas = list(),
  name = NULL,
  description = NULL
)
```

## Arguments

- fn:

  A function. Bare symbol or `pkg::fn` both work.

- defaults:

  Named list of arguments to hide from the model and inject at call
  time.

- descriptions:

  Named list of per-argument description overrides.

- schemas:

  Named list of per-argument schema overrides (lists matching the
  OpenAPI property shape).

- name:

  Override the tool name. Defaults to the function name.

- description:

  Override the tool description. Defaults to the parsed documentation
  title, or a stub.

## Value

A list ready to drop into a chat-completions request.

## Details

The shape returned is the union schema accepted by OpenAI, DeepSeek, and
most OpenAI-compatible servers:

    list(
      type = "function",
      `function` = list(
        name        = "...",
        description = "...",
        parameters  = list(
          type       = "object",
          properties = list(...),
          required   = list("...")
        )
      )
    )

Anthropic's tool format uses the inner `parameters` block under a
different key (`input_schema`) — wrap accordingly when targeting it.

### Hiding implementation-detail arguments

The headline feature is `defaults`. Any argument named there is removed
from the schema the model sees. Pair it with
[`make_handler()`](https://dereckscompany.github.io/autotool/reference/make_handler.md)
to build a dispatch closure that merges those values back in at call
time. This is the right place to pin API keys, base URLs, retry budgets,
or anything the model should not influence.

### Overrides

- `descriptions` overrides the per-argument description text (useful
  when the installed docs are too terse for an LLM).

- `schemas` overrides the full schema for one or more arguments
  (necessary for arrays-of-objects and other nested shapes that
  introspection cannot infer).

## See also

[`make_handler()`](https://dereckscompany.github.io/autotool/reference/make_handler.md)
for the matching runtime helper.

## Examples

``` r
tool <- generate_tool(
  stats::rnorm,
  descriptions = list(n = "Number of values to draw.")
)
tool$`function`$name
#> [1] "rnorm"
tool$`function`$parameters$properties$mean
#> $type
#> [1] "number"
#> 
#> $default
#> [1] 0
#> 
#> $description
#> [1] "vector of means."
#> 
```
