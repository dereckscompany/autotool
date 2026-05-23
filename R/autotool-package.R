#' autotool: Generate LLM Tool Definitions from R Functions
#'
#' Build OpenAI / Anthropic / DeepSeek tool definitions directly from any
#' R function by introspecting its signature plus its roxygen or installed
#' package help. Hide implementation-detail arguments (credentials, base
#' URLs, retry budgets) so the model never sees them, then inject them at
#' call time.
#'
#' The package has two entry points:
#'
#'   * [generate_tool()] turns a function into a tool definition list.
#'   * [make_handler()] builds a 1-argument closure that merges your
#'     pinned defaults with the model-supplied arguments and invokes
#'     the underlying function.
#'
#' @keywords internal
"_PACKAGE"
