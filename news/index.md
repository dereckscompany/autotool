# Changelog

## autotool 0.0.2

### Bug fixes

- `generate_tool(fn, name = "x")` no longer hijacks the source-code
  lookup. The `name` argument is for the tool name the model sees;
  documentation lookup (roxygen via `srcref`, Rd via
  [`tools::Rd_db()`](https://rdrr.io/r/tools/Rdutils.html)) now always
  uses the function’s actual source name. Previously, passing `name`
  caused autotool to search the source file for a definition matching
  the override and silently fall back to a `"Call <name>()."` stub when
  nothing matched. Found by dogfooding in `tradebot-mini`.

- Source-name resolution now handles `env$fn` and `env[["fn"]]`
  expressions in addition to bare symbols and `pkg::fn`. Functions
  loaded via [`box::use()`](https://klmr.me/box/reference/use.html) and
  `sys.source(..., envir = env)` are now documented correctly without
  needing `name = "..."` as a workaround.

- Anonymous functions (`function(x) ...` literals passed inline) now
  fail with a clear message asking for `name = "..."` instead of cryptic
  regex errors downstream.

## autotool 0.0.1

Initial public release.

- [`generate_tool()`](https://dereckscompany.github.io/autotool/reference/generate_tool.md)
  builds an LLM tool definition from any R function by introspecting
  [`formals()`](https://rdrr.io/r/base/formals.html) and pulling
  argument descriptions from either roxygen comments (via `srcref`) or
  installed-package help (via
  [`tools::Rd_db()`](https://rdrr.io/r/tools/Rdutils.html)).

- `format` argument selects the output shape: `"openai"` (default)
  returns a plain list matching OpenAI / DeepSeek / any
  OpenAI-compatible server; `"ellmer"` returns an
  [`ellmer::tool()`](https://ellmer.tidyverse.org/reference/tool.html)
  R6 object ready to register with the tidyverse ellmer LLM client.

- `defaults = list(...)` hides arguments from the schema the model sees
  — the right place to pin API keys, base URLs, or any implementation
  detail. Works for both output formats; for `"ellmer"` the hidden
  arguments are stripped from the wrapped function’s visible formals.

- `required` argument overrides the auto-derived required-arg list:
  `NULL` (default) derives it from
  [`formals()`](https://rdrr.io/r/base/formals.html), a character vector
  replaces it explicitly,
  [`character()`](https://rdrr.io/r/base/character.html) marks every
  argument optional.

- `descriptions = list(...)` overrides per-argument description text
  when installed docs are too terse.

- `schemas = list(...)` overrides the full per-argument schema —
  required for arrays-of-objects and other nested shapes R’s lack of
  static types cannot express.

- [`make_handler()`](https://dereckscompany.github.io/autotool/reference/make_handler.md)
  returns a 1-argument closure that merges hidden defaults with the
  model’s tool-call arguments and dispatches to the underlying function.
  Drop it into your own handler registry when using `format = "openai"`.

- Zero hard runtime dependencies — only base R. `ellmer`, `box`, and
  `renv` are in `Suggests` for the format-conversion and vignette paths.
