# autotool

> Turn any R function into a JSON-schema tool definition an LLM can
> call.

LLM tool calling needs a schema for every function you want the model to
reach. Writing those schemas by hand is repetitive, drifts from the
function signature, and forces credentials into the same object the
model sees. `autotool` derives the schema from the function itself — its
[`formals()`](https://rdrr.io/r/base/formals.html), its installed help,
or its roxygen comments — and gives you a single argument (`defaults`)
for pinning anything the model should not influence.

The philosophy: **the function is already the contract**. The model
should see what it needs to fill in and nothing else. You shouldn’t
maintain a second list of argument names just to talk to an LLM.

Zero hard dependencies — only base R and packages shipped with R.

## Install

``` r

# install.packages("remotes")
remotes::install_github("dereckscompany/autotool")
```

## Example

``` r

library(autotool)

tool <- generate_tool(stats::rnorm)

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

That’s the whole API for the simple case.
[`?rnorm`](https://rdrr.io/r/stats/Normal.html) supplied the
description, the title, and the per-argument descriptions;
[`formals()`](https://rdrr.io/r/base/formals.html) supplied the argument
shape and the `required` list.

## Hiding arguments from the model

The headline feature. Pin credentials, base URLs, or any implementation
detail with `defaults` — those arguments disappear from the schema the
model sees:

``` r

tool <- generate_tool(
  fetch_quotes,
  defaults = list(api_key = SECRET, base_url = PROD, retries = 5L)
)
# The model only sees the trading-relevant args (symbols, start, ...).
```

Build a handler closure with the same defaults to invoke when the model
dispatches the tool call:

``` r

handle_fetch_quotes <- make_handler(
  fetch_quotes,
  defaults = list(api_key = SECRET, base_url = PROD, retries = 5L)
)
handle_fetch_quotes(model_args)
```

Plug the closure into your own handler registry and dispatch by name in
your agent loop. If you need post-processing — caching, logging, result
munging — just write your own 1-arg function; the factory is a
convenience, not a requirement.

For nested shapes (arrays of objects, etc.) that introspection cannot
infer from R’s types, pass an explicit `schemas = list(arg = ...)`
override. See
[`vignette("autotool")`](https://dereckscompany.github.io/autotool/articles/autotool.md)
for the full walkthrough.

## License

MIT. See `LICENSE`.
