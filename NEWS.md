# autotool 0.0.1

Initial public release.

* `generate_tool()` builds an LLM tool definition from any R function by
  introspecting `formals()` and pulling argument descriptions from either
  roxygen comments (via `srcref`) or installed-package help
  (via `tools::Rd_db()`).

* `format` argument selects the output shape:
  `"openai"` (default) returns a plain list matching OpenAI / DeepSeek
  / any OpenAI-compatible server; `"ellmer"` returns an
  `ellmer::tool()` R6 object ready to register with the tidyverse
  ellmer LLM client.

* `defaults = list(...)` hides arguments from the schema the model sees
  — the right place to pin API keys, base URLs, or any implementation
  detail. Works for both output formats; for `"ellmer"` the hidden
  arguments are stripped from the wrapped function's visible formals.

* `required` argument overrides the auto-derived required-arg list:
  `NULL` (default) derives it from `formals()`, a character vector
  replaces it explicitly, `character()` marks every argument optional.

* `descriptions = list(...)` overrides per-argument description text
  when installed docs are too terse.

* `schemas = list(...)` overrides the full per-argument schema —
  required for arrays-of-objects and other nested shapes R's lack of
  static types cannot express.

* `make_handler()` returns a 1-argument closure that merges hidden
  defaults with the model's tool-call arguments and dispatches to the
  underlying function. Drop it into your own handler registry when
  using `format = "openai"`.

* Zero hard runtime dependencies — only base R. `ellmer`, `box`, and
  `renv` are in `Suggests` for the format-conversion and vignette
  paths.
