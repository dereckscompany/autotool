# Changelog

## autotool 0.0.1

Initial public release.

- [`generate_tool()`](https://dereckscompany.github.io/autotool/reference/generate_tool.md)
  builds an OpenAI / Anthropic / DeepSeek tool definition from any R
  function by introspecting
  [`formals()`](https://rdrr.io/r/base/formals.html) and pulling
  argument descriptions from either roxygen comments (via `srcref`) or
  installed- package help (via
  [`tools::Rd_db()`](https://rdrr.io/r/tools/Rdutils.html)).

- [`make_handler()`](https://dereckscompany.github.io/autotool/reference/make_handler.md)
  returns a 1-argument closure that merges hidden defaults with the
  model’s tool-call arguments and dispatches to the underlying function.
  Drop it into your own handler registry.

- `defaults = list(...)` on
  [`generate_tool()`](https://dereckscompany.github.io/autotool/reference/generate_tool.md)
  hides arguments from the schema the model sees — the right place to
  pin API keys, base URLs, or any implementation detail.

- `schemas = list(...)` lets you override the inferred schema for any
  argument (required for arrays-of-objects and other shapes R’s lack of
  static types cannot express).

- Zero hard runtime dependencies — only base R.
