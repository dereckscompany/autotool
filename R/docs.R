#' Parse roxygen comments above a function definition
#'
#' Reads the source file pointed to by the function's `srcref`, walks
#' backwards from the `<name> <- function` line collecting `#'` comment
#' lines, and parses them as a flat roxygen block. Supports `@param`
#' (per-argument description) and the leading title paragraph.
#'
#' This is intentionally a tiny parser — it does not depend on
#' `roxygen2`. It handles the common cases used in idiomatic R code and
#' returns `NULL` when the function definition cannot be located in the
#' source file.
#'
#' @param src_file Absolute path to the source file.
#' @param fn_name Function name to search for.
#' @return A list `list(title = chr, args = named list of chr)`, or NULL.
#' @noRd
parse_roxygen_for_fn <- function(src_file, fn_name) {
  lines <- readLines(src_file, warn = FALSE)
  pattern <- sprintf("^\\s*(`?%s`?)\\s*(<-|=)\\s*function", fn_name)
  match_line <- grep(pattern, lines)
  if (length(match_line) == 0) {
    return(NULL)
  }

  i <- match_line[1] - 1
  roxy <- character()
  while (i > 0 && grepl("^\\s*#'", lines[i])) {
    roxy <- c(lines[i], roxy)
    i <- i - 1
  }
  if (length(roxy) == 0) {
    return(NULL)
  }

  content <- sub("^\\s*#'\\s?", "", roxy)
  title <- NULL
  args <- list()
  current_tag <- "title"
  current_arg <- NULL
  buf <- character()

  flush <- function() {
    text <- trimws(paste(buf, collapse = " "))
    text <- gsub("\\s+", " ", text)
    if (current_tag == "title" && nzchar(text) && is.null(title)) {
      title <<- text
    } else if (current_tag == "param" && !is.null(current_arg)) {
      args[[current_arg]] <<- text
    }
    return(invisible(NULL))
  }

  for (line in content) {
    if (grepl("^@", line)) {
      flush()
      buf <- character()
      m <- regmatches(line, regexec("^@(\\S+)\\s*(.*)$", line))[[1]]
      tag <- m[2]
      rest <- m[3]
      if (tag == "param") {
        p <- regmatches(rest, regexec("^(\\S+)\\s*(.*)$", rest))[[1]]
        current_arg <- p[2]
        buf <- p[3]
      } else {
        current_arg <- NULL
        buf <- rest
      }
      current_tag <- tag
    } else {
      buf <- c(buf, line)
    }
  }
  flush()
  return(list(title = title, args = args))
}

#' Flatten an Rd node tree to whitespace-collapsed text
#'
#' @param node A node from a `tools::Rd_db()` entry.
#' @return A character scalar.
#' @noRd
rd_text <- function(node) {
  return(trimws(gsub("\\s+", " ", paste(unlist(node), collapse = ""))))
}

#' Look up structured documentation for an installed-package function
#'
#' Walks `tools::Rd_db(pkg)` to find the Rd entry whose `\alias` matches
#' `fn_name`, then pulls the `\title` and per-`\item` entries from the
#' `\arguments` block.
#'
#' @param pkg Installed-package name.
#' @param fn_name Function name to locate.
#' @return `list(title = chr, args = named list of chr)`, or NULL.
#' @noRd
parse_rd_for_fn <- function(pkg, fn_name) {
  rd_db <- tryCatch(tools::Rd_db(pkg), error = function(e) NULL)
  if (is.null(rd_db) || length(rd_db) == 0) {
    return(NULL)
  }

  target <- NULL
  for (rd in rd_db) {
    tags <- vapply(rd, attr, character(1), "Rd_tag")
    alias_idx <- which(tags == "\\alias")
    aliases <- vapply(rd[alias_idx], rd_text, character(1))
    if (fn_name %in% aliases) {
      target <- rd
      break
    }
  }
  if (is.null(target)) {
    return(NULL)
  }

  tags <- vapply(target, attr, character(1), "Rd_tag")
  title_idx <- which(tags == "\\title")
  title <- if (length(title_idx)) rd_text(target[[title_idx[1]]]) else NULL

  args <- list()
  args_idx <- which(tags == "\\arguments")
  if (length(args_idx)) {
    block <- target[[args_idx[1]]]
    for (item in block) {
      if (identical(attr(item, "Rd_tag"), "\\item") && length(item) >= 2) {
        name_raw <- rd_text(item[[1]])
        desc <- rd_text(item[[2]])
        for (nm in trimws(strsplit(name_raw, ",")[[1]])) {
          args[[nm]] <- desc
        }
      }
    }
  }
  return(list(title = title, args = args))
}

#' Dispatch to the appropriate documentation backend
#'
#' Tries, in order:
#'   1. Roxygen via the function's `srcref` (source-loaded functions).
#'   2. Rd via `tools::Rd_db()` (installed-package functions).
#'   3. Empty docs (anonymous functions, deparse'd closures).
#'
#' @param fn The function object.
#' @param fn_name The function's name.
#' @return `list(source = c("roxygen", "rd", "none"), doc = list(title=, args=))`.
#' @noRd
get_docs <- function(fn, fn_name) {
  if (is.null(fn_name)) {
    return(list(source = "none", doc = list(title = NULL, args = list())))
  }
  src_file <- tryCatch(
    utils::getSrcFilename(fn, full.names = TRUE),
    error = function(e) NULL
  )
  has_src <- length(src_file) == 1 && !is.na(src_file) && nzchar(src_file) && file.exists(src_file)
  if (has_src) {
    doc <- parse_roxygen_for_fn(src_file, fn_name)
    if (!is.null(doc)) return(list(source = "roxygen", doc = doc))
  }
  env <- environment(fn)
  if (!is.null(env) && isNamespace(env)) {
    pkg <- getNamespaceName(env)
    doc <- parse_rd_for_fn(pkg, fn_name)
    if (!is.null(doc)) return(list(source = "rd", doc = doc))
  }
  return(list(source = "none", doc = list(title = NULL, args = list())))
}
