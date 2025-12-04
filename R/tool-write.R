# Simple file writing tool
tool_write_text_file <- function() {
  ellmer::tool(
    function(path, content, `_intent` = NULL) {
      tryCatch(
        {
          dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
          writeLines(content, path)
          
          ellmer::ContentToolResult(
            value = paste0("Successfully wrote to ", path),
            extra = list(
              display = list(
                markdown = paste0("**File written:** `", path, "`"),
                title = paste("Wrote:", basename(path)),
                show_request = FALSE,
                open = TRUE
              )
            )
          )
        },
        error = function(e) {
          ellmer::ContentToolResult(
            error = paste0("Error writing file: ", conditionMessage(e))
          )
        }
      )
    },
    name = "write_text_file",
    description = "Write content to a text file. Creates the file if it doesn't exist.",
    arguments = list(
      path = ellmer::type_string("Path to the file to write"),
      content = ellmer::type_string("Content to write to the file"),
      `_intent` = ellmer::type_string("Why you're writing this file", required = FALSE)
    ),
    convert = FALSE
  )
}
