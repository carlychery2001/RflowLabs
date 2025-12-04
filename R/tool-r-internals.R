# R Internals Search Tools

#' Tool: Search R Source Code
tool_search_r_source <- function() {
  ellmer::tool(
    function(pattern, path = NULL, context = 3, max_results = 50, `_intent` = NULL) {
      result <- tryCatch({
        search_r_source(pattern, path, context, max_results)
      }, error = function(e) {
        paste("Error searching R source:", e$message)
      })

      ellmer::ContentToolResult(
        value = result,
        extra = list(
          display = list(
            markdown = paste0("### [SEARCH] R Source Search: `", pattern, "`\n\n```\n", result, "\n```"),
            title = "R Source Code Search",
            show_request = TRUE,
            open = TRUE
          )
        )
      )
    },
    name = "search_r_source",
    description = "Search through the R interpreter source code (C and R files) to understand R internals, find function implementations, or debug complex R behavior. Use this when you need deep knowledge of how R actually works under the hood.",
    arguments = list(
      pattern = ellmer::type_string("Search pattern (regex supported). Examples: 'do_mean', 'PROTECT', 'allocVector', 'eval('"),
      path = ellmer::type_string("Subdirectory to search (optional). Options: 'main' (core interpreter), 'library' (base packages), 'include' (headers), 'modules'. Leave NULL to search all.", required = FALSE),
      context = ellmer::type_integer("Number of lines of context around matches (default 3)", required = FALSE),
      max_results = ellmer::type_integer("Maximum results to return (default 50)", required = FALSE),
      `_intent` = ellmer::type_string("Why are you searching the R source? What are you trying to understand?", required = FALSE)
    ),
    convert = FALSE
  )
}


#' Tool: Get R Internals Information
tool_get_r_internals <- function() {
  ellmer::tool(
    function(topic = "all", `_intent` = NULL) {
      result <- tryCatch({
        get_r_internals_info(topic)
      }, error = function(e) {
        paste("Error getting R internals info:", e$message)
      })

      ellmer::ContentToolResult(
        value = result,
        extra = list(
          display = list(
            markdown = paste0("### [INFO] R Internals: ", toupper(topic), "\n\n", result),
            title = paste("R Internals -", topic),
            show_request = FALSE,
            open = TRUE
          )
        )
      )
    },
    name = "get_r_internals_info",
    description = "Get comprehensive documentation about R interpreter internals, architecture, memory management, evaluation, parsing, graphics, and common bugs. This is your encyclopedia of R internals knowledge.",
    arguments = list(
      topic = ellmer::type_string("Topic to learn about. Options: 'all' (everything), 'architecture' (core components), 'memory' (GC, SEXP types), 'evaluation' (how R evaluates code), 'parser' (how R parses code), 'graphics' (graphics system), 'common_bugs' (typical R bugs and their sources). Default: 'all'", required = FALSE),
      `_intent` = ellmer::type_string("What problem are you trying to solve?", required = FALSE)
    ),
    convert = FALSE
  )
}


#' Tool: Find R Function Implementation
tool_find_r_function <- function() {
  ellmer::tool(
    function(func_name, `_intent` = NULL) {
      result <- tryCatch({
        capture.output(find_r_function(func_name))
      }, error = function(e) {
        paste("Error finding function:", e$message)
      })

      result_text <- paste(result, collapse = "\n")

      ellmer::ContentToolResult(
        value = result_text,
        extra = list(
          display = list(
            markdown = paste0("### [TARGET] Implementation of `", func_name, "()`\n\n```\n", result_text, "\n```"),
            title = paste("R Function:", func_name),
            show_request = TRUE,
            open = TRUE
          )
        )
      )
    },
    name = "find_r_function",
    description = "Locate where a specific R function is implemented in the source code. Searches for C implementations (do_xxx functions), function table entries, and R-level implementations. Use this to understand exactly how R functions work internally.",
    arguments = list(
      func_name = ellmer::type_string("Name of the R function to find (e.g., 'mean', 'sum', 'lm', 'plot', '[[')"),
      `_intent` = ellmer::type_string("Why do you need to find this function's implementation?", required = FALSE)
    ),
    convert = FALSE
  )
}
