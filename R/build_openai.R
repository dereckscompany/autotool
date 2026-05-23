#' Assemble the OpenAI / DeepSeek tool definition from the intermediate rep
#'
#' This is the default output shape — `type: "function"` envelope wrapping
#' a `parameters` object with `properties` and `required`. Accepted by
#' OpenAI's chat-completions endpoint and any OpenAI-compatible server
#' (DeepSeek, Mistral, vLLM, llama.cpp, etc.).
#'
#' Anthropic's tool format uses the same inner schema but renames
#' `parameters` to `input_schema` and drops the `type: "function"`
#' envelope. If you target Anthropic, wrap the inner `parameters` block
#' yourself or wait for a dedicated `format = "anthropic"` builder.
#'
#' @param rep The intermediate from `introspect()`.
#' @return A plain list ready to `jsonlite::toJSON()` and POST.
#' @noRd
build_openai_tool <- function(rep) {
  return(list(
    type = "function",
    `function` = list(
      name = rep$name,
      description = rep$description,
      parameters = list(
        type = "object",
        properties = rep$properties,
        required = as.list(rep$required)
      )
    )
  ))
}
