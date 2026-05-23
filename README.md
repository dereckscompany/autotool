
# autotool

> Turn any R function into a JSON-schema tool definition an LLM can call
> — derived automatically from the function’s documentation.

LLM tool calling needs a schema for every function you want the model to
reach. Writing those schemas by hand is repetitive, drifts from the
function signature, and forces credentials into the same object the
model sees. `autotool` derives the schema from the function itself — its
`formals()`, its installed help, or its roxygen comments — and gives you
a single argument (`defaults`) for pinning anything the model should not
influence.

The philosophy: **the function is already the contract**. The model
should see what it needs to fill in and nothing else. You shouldn’t
maintain a second list of argument names just to talk to an LLM.

Zero hard dependencies — only base R and packages shipped with R.

## One line vs ten

Compare wrapping `stats::rnorm` for the model with vs without
`autotool`:

``` r
# Without autotool — ellmer's tool() — every detail typed by hand:
ellmer::tool(
  stats::rnorm,
  "The Normal Distribution",
  arguments = list(
    n = ellmer::type_integer("Number of observations..."),
    mean = ellmer::type_number("Vector of means.", required = FALSE),
    sd = ellmer::type_number("Vector of standard deviations.", required = FALSE)
  )
)

# With autotool:
autotool$generate_tool(stats::rnorm, format = "ellmer")
```

The description, every per-argument description, every type, and the
required/optional flags came out of `?rnorm` and `formals(rnorm)`. You
wrote one line.

## Install

``` r
# install.packages("renv")
renv::install("dereckscompany/autotool")
```

## Example

``` r
box::use(autotool)

tool <- autotool$generate_tool(stats::rnorm)

tool$`function`$name
#> [1] "rnorm"
tool$`function`$description
#> [1] "The Normal Distribution"
tool$`function`$parameters$properties$mean
#> $type
#> [1] "number"
#>
#> $default
#> [1] 0
#>
#> $description
#> [1] "vector of means."
unlist(tool$`function`$parameters$required)
#> [1] "n"
```

`?rnorm` supplied the description, the title, and every per-argument
description. `formals()` supplied the argument shape and the `required`
list.

## Hiding arguments from the model

Pin credentials, base URLs, or any implementation detail with `defaults`
— those arguments disappear from the schema the model sees:

``` r
tool <- autotool$generate_tool(
  fetch_quotes,
  defaults = list(api_key = SECRET, base_url = PROD, retries = 5L)
)
# The model only sees symbols, start, ... — never api_key.
```

Build a handler closure with the same defaults to invoke when the model
dispatches the tool call:

``` r
handle <- autotool$make_handler(
  fetch_quotes,
  defaults = list(api_key = SECRET, base_url = PROD, retries = 5L)
)
handle(model_args)
```

Plug the closure into your own handler registry and dispatch by name in
your agent loop. If you need caching, logging, or other post-processing,
write a regular 1-arg function instead — the factory is a convenience,
not a requirement.

## Output formats

| `format` | Returns | Use with |
|----|----|----|
| `"openai"` (default) | plain list (OpenAI / DeepSeek shape) | OpenAI, DeepSeek, Mistral, vLLM, llama.cpp, any OpenAI-compatible server |
| `"ellmer"` | `ellmer::tool()` object | the tidyverse `ellmer` LLM client |

``` r
ellmer_tool <- autotool$generate_tool(stats::rnorm, format = "ellmer")
chat <- ellmer::chat_openai()
chat$register_tool(ellmer_tool)
```

`defaults` works in both formats — `format = "ellmer"` strips hidden
arguments from the wrapped function’s visible formals automatically.

## Overrides

| Argument | Purpose |
|----|----|
| `defaults` | Hide arguments from the schema and inject their pinned values at call time. |
| `descriptions` | Replace per-argument description text when installed docs are too terse. |
| `schemas` | Replace the full schema for one or more arguments — required for arrays-of-objects and other shapes R’s lack of static types cannot express. |
| `required` | Replace the auto-derived required-arg list (`NULL` = derive; character vector = exact list; `character()` = nothing required). |
| `name` / `description` | Override the tool-level name and description. |

See `vignette("autotool")` for the full walkthrough.

## Licence

MIT. See `LICENSE`.
