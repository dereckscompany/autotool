# Generate an LLM tool definition from an R function

Builds a tool definition by introspecting `formals(fn)` for the argument
shape and one of two documentation backends — roxygen-via-`srcref` for
source-loaded functions, or
Rd-via-[`tools::Rd_db()`](https://rdrr.io/r/tools/Rdutils.html) for
installed packages — for descriptions.

## Usage

``` r
generate_tool(
  fn,
  defaults = list(),
  descriptions = list(),
  schemas = list(),
  required = NULL,
  name = NULL,
  description = NULL,
  format = c("openai", "ellmer")
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

- required:

  `NULL` (default) to auto-derive the required list from `formals(fn)`
  (arguments with no default are required), or a character vector
  specifying the exact required-argument names. Pass
  [`character()`](https://rdrr.io/r/base/character.html) to mark every
  argument optional.

- name:

  Override the tool name. Defaults to the function name.

- description:

  Override the tool description. Defaults to the parsed documentation
  title, or a stub like `"Call <fn>()."` when no documentation title and
  no explicit override are available.

- format:

  Output shape. One of `"openai"` (the default plain list) or `"ellmer"`
  (an
  [`ellmer::tool()`](https://ellmer.tidyverse.org/reference/tool.html)
  R6 object).

## Value

A list (for `"openai"`) or an `ellmer` tool object (for `"ellmer"`).

## Details

The output `format` controls the wire shape:

- `"openai"` (default) returns a plain list matching OpenAI's
  chat-completions `tool` schema. Accepted as-is by any
  OpenAI-compatible server (DeepSeek, Mistral, vLLM, llama.cpp, etc.).

- `"ellmer"` returns an
  [`ellmer::tool()`](https://ellmer.tidyverse.org/reference/tool.html)
  R6 object ready to register with an `ellmer::chat_*()` session.
  Requires the `ellmer` package.

The introspection happens once regardless of format; only the final
wrapper differs.

### Hiding implementation-detail arguments

The headline feature is `defaults`. Any argument named there is removed
from the schema the model sees. With `format = "openai"`, pair with
[`make_handler()`](https://dereckscompany.github.io/autotool/reference/make_handler.md)
to merge those values back in when you dispatch the model's tool call.
With `format = "ellmer"`, the returned tool object already wraps the
function so defaults are injected automatically.

### Overriding what introspection sees

- `descriptions = list(arg = "...")` overrides per-argument description
  text — useful when installed-package docs are too terse for an LLM.

- `schemas = list(arg = list(...))` overrides the full schema for one or
  more arguments — necessary for arrays-of-objects and other nested
  shapes R's lack of static types cannot infer.

- `required` overrides the auto-derived required-arg list: `NULL`
  (default) derives it from
  [`formals()`](https://rdrr.io/r/base/formals.html); a character vector
  replaces the derived list entirely.

## See also

[`make_handler()`](https://dereckscompany.github.io/autotool/reference/make_handler.md)
for the matching runtime helper when using `format = "openai"`.

## Examples

``` r
# Default OpenAI / DeepSeek shape
tool <- generate_tool(stats::rnorm)
tool$`function`$name
#> [1] "rnorm"
unlist(tool$`function`$parameters$required)
#> [1] "n"

# Override the required-arg list
tool <- generate_tool(stats::rnorm, required = character())
unlist(tool$`function`$parameters$required) # character(0) — nothing required
#> NULL
```
