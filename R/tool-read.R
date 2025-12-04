# Simple file reading tool
tool_read_text_file <- function() {
  ellmer::tool(
    function(path, `_intent` = NULL) {
      if (!file.exists(path)) {
        return(ellmer::ContentToolResult(
          error = paste0("File not found: ", path)
        ))
      }
      
      content <- tryCatch(
        paste(readLines(path, warn = FALSE), collapse = "\n"),
        error = function(e) {
          return(ellmer::ContentToolResult(
            error = paste0("Error reading file: ", conditionMessage(e))
          ))
        }
      )
      
      ellmer::ContentToolResult(
        value = content,
        extra = list(
          display = list(
            markdown = paste0("```\n", content, "\n```"),
            title = paste("Read:", basename(path)),
            show_request = FALSE,
            open = FALSE
          )
        )
      )
    },
    name = "read_text_file",
    description = "Read the contents of a text file",
    arguments = list(
      path = ellmer::type_string("Path to the file to read"),
      `_intent` = ellmer::type_string("Why you're reading this file", required = FALSE)
    ),
    convert = FALSE
  )
}
