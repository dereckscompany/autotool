# Package index

## Tool definitions

Build an LLM tool definition from any R function by introspecting its
signature and documentation.

- [`generate_tool()`](https://dereckscompany.github.io/autotool/reference/generate_tool.md)
  : Generate an LLM tool definition from an R function

## Runtime dispatch

Build a handler closure that merges hidden defaults with the model’s
supplied arguments and invokes the function.

- [`make_handler()`](https://dereckscompany.github.io/autotool/reference/make_handler.md)
  : Build a tool-call handler from a function and pinned defaults
