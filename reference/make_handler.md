# Build a tool-call handler from a function and pinned defaults

Companion to
[`generate_tool()`](https://dereckscompany.github.io/autotool/reference/generate_tool.md).
Returns a 1-argument closure that merges the supplied `defaults` under
whatever argument list the LLM produced at tool-call time, then invokes
`fn`. Drop the closure into your handler registry, call it with the
model's parsed arguments.

## Usage

``` r
make_handler(fn, defaults = list())
```

## Arguments

- fn:

  The function to invoke.

- defaults:

  Named list of pinned arguments (typically the same list passed to
  [`generate_tool()`](https://dereckscompany.github.io/autotool/reference/generate_tool.md)).

## Value

A function of a single argument (`model_args`) that returns whatever
`fn` returns.

## Details

The merge gives the model's arguments precedence: anything the model
supplies for a key in `defaults` overrides the pinned value. That is
usually correct — hidden arguments have defaults the model cannot see,
so it has no way to supply them — but if you want strict pinning,
validate before calling.

`fn` and `defaults` are forced at factory-call time, so reassigning the
surrounding bindings later does not change the handler's behaviour.

## See also

[`generate_tool()`](https://dereckscompany.github.io/autotool/reference/generate_tool.md).

## Examples

``` r
add <- function(x, y, scale = 1) (x + y) * scale
handler <- make_handler(add, defaults = list(scale = 10))
handler(list(x = 2, y = 3))
#> [1] 50
# 50
```
